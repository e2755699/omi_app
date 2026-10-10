#!/usr/bin/env python3
"""App Store Connect 發布工具：CI 預檢、配 build 號、上傳後查驗 TestFlight 內測可用。

API key 從環境變數讀（和 Codemagic CLI 同名），不會印出秘密：
  APP_STORE_CONNECT_ISSUER_ID / APP_STORE_CONNECT_KEY_IDENTIFIER / APP_STORE_CONNECT_PRIVATE_KEY

  python tool/release/asc.py preflight --min-build-number "$BUILD_NUMBER" --env-file "$CM_ENV"
  python tool/release/asc.py verify --version 1.0.0 --build-number 7 --external --out release-result.json
  python tool/release/asc.py external-watch --out external-events.json

verify 的結束碼：0 = ready（內測可用）、1 = failed（Apple 明確拒絕）、2 = unknown（無法確認）。
--external：內測可用後再送外部測試（結果放在 result["external"]，不影響內測的結束碼）。
external-watch：排程用，列出外部審查有結果或逾時的 build，交給 report.py 通知。
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONFIG = json.loads((Path(__file__).with_name("config.json")).read_text(encoding="utf-8"))
API_ORIGIN = "https://api.appstoreconnect.apple.com"
KEY_ENV = ("APP_STORE_CONNECT_ISSUER_ID", "APP_STORE_CONNECT_KEY_IDENTIFIER", "APP_STORE_CONNECT_PRIVATE_KEY")

# 暫時性錯誤才重試；401/403 是授權問題，重試也沒用。
RETRY_STATUS = {429, 500, 502, 503, 504}
MAX_ATTEMPTS = 5


class AuthError(Exception):
    """API key 無效或權限不足。"""


class ApiError(Exception):
    def __init__(self, status: int | None, message: str):
        super().__init__(f"HTTP {status}: {message}" if status else message)
        self.status = status


# ---------------------------------------------------------------- API client


class AscClient:
    def __init__(self, issuer_id: str, key_id: str, private_key: str, sleep=time.sleep):
        self._issuer_id = issuer_id
        self._key_id = key_id
        self._private_key = private_key.replace("\\n", "\n")
        self._sleep = sleep
        self._token = ""
        self._token_exp = 0.0

    @classmethod
    def from_env(cls) -> "AscClient":
        missing = [name for name in KEY_ENV if not os.environ.get(name, "").strip()]
        if missing:
            raise AuthError("缺少環境變數：" + ", ".join(missing))
        return cls(*(os.environ[name].strip() for name in KEY_ENV))

    def _bearer(self) -> str:
        now = time.time()
        if now > self._token_exp - 60:
            import jwt  # 只有真的要打 API 才需要 PyJWT

            self._token_exp = now + 15 * 60  # Apple 上限 20 分鐘
            self._token = jwt.encode(
                {"iss": self._issuer_id, "iat": int(now), "exp": int(self._token_exp), "aud": "appstoreconnect-v1"},
                self._private_key,
                algorithm="ES256",
                headers={"kid": self._key_id, "typ": "JWT"},
            )
        return self._token

    def request(self, method: str, path_or_url: str, params: dict | None = None, body: dict | None = None) -> dict:
        url = path_or_url if path_or_url.startswith("https://") else API_ORIGIN + path_or_url
        if not url.startswith(API_ORIGIN + "/"):
            raise ApiError(None, f"拒絕把 token 送到非 Apple API 的網址：{url}")
        if params:
            url += ("&" if "?" in url else "?") + urllib.parse.urlencode(params)
        data = json.dumps(body).encode() if body is not None else None

        for attempt in range(1, MAX_ATTEMPTS + 1):
            req = urllib.request.Request(url, data=data, method=method)
            req.add_header("Authorization", "Bearer " + self._bearer())
            if data is not None:
                req.add_header("Content-Type", "application/json")
            try:
                with urllib.request.urlopen(req, timeout=60) as resp:
                    raw = resp.read()
                    return json.loads(raw) if raw else {}
            except urllib.error.HTTPError as error:
                detail = _error_detail(error)
                if error.code in (401, 403):
                    raise AuthError(f"HTTP {error.code}: {detail}") from None
                if error.code not in RETRY_STATUS or attempt == MAX_ATTEMPTS:
                    raise ApiError(error.code, detail) from None
                wait = _retry_after(error) or 2**attempt
            except (urllib.error.URLError, TimeoutError) as error:
                if attempt == MAX_ATTEMPTS:
                    raise ApiError(None, f"網路錯誤：{error}") from None
                wait = 2**attempt
            self._sleep(min(wait, 60))
        raise AssertionError("unreachable")

    def get(self, path: str, params: dict | None = None) -> dict:
        return self.request("GET", path, params)

    def get_all(self, path: str, params: dict | None = None) -> list[dict]:
        page = self.get(path, params)
        items = list(page.get("data", []))
        while (next_url := page.get("links", {}).get("next")):
            page = self.get(next_url)  # request() 會擋掉非 Apple 的網址
            items.extend(page.get("data", []))
        return items

    def post(self, path: str, body: dict) -> dict:
        return self.request("POST", path, body=body)

    def patch(self, path: str, body: dict) -> dict:
        return self.request("PATCH", path, body=body)


def _error_detail(error: urllib.error.HTTPError) -> str:
    try:
        errors = json.loads(error.read()).get("errors", [])
        return "; ".join(f"{e.get('code')}: {e.get('detail') or e.get('title')}" for e in errors) or error.reason
    except Exception:  # noqa: BLE001 — 錯誤訊息解析失敗就用原本的 reason
        return str(error.reason)


def _retry_after(error: urllib.error.HTTPError) -> int | None:
    value = error.headers.get("Retry-After") if error.headers else None
    return int(value) if value and value.isdigit() else None


# ---------------------------------------------------------------- 查詢


def find_bundle_id(client, identifier: str) -> dict | None:
    items = client.get_all("/v1/bundleIds", {"filter[identifier]": identifier, "limit": 200})
    return next((item for item in items if item["attributes"]["identifier"] == identifier), None)


def find_app(client, bundle_id: str) -> dict | None:
    items = client.get_all("/v1/apps", {"filter[bundleId]": bundle_id, "limit": 200})
    return next((item for item in items if item["attributes"]["bundleId"] == bundle_id), None)


def find_beta_group(client, app_id: str, name: str) -> dict | None:
    items = client.get_all("/v1/betaGroups", {"filter[app]": app_id, "filter[name]": name, "limit": 200})
    return next((item for item in items if item["attributes"]["name"] == name), None)


def latest_build_number(client, app_id: str) -> int:
    """這個 App 用過的最大 build 號（不分版本）；只看純數字的 build 號。"""
    builds = client.get_all("/v1/builds", {"filter[app]": app_id, "fields[builds]": "version", "limit": 200})
    numbers = [int(b["attributes"]["version"]) for b in builds if str(b["attributes"].get("version", "")).isdigit()]
    return max(numbers, default=0)


def next_build_number(latest: int, ci_floor: int) -> int:
    """Apple 上最大的 build 號 +1，且不小於 CI 自己的流水號（同一條 workflow 不會重複）。"""
    return max(latest + 1, ci_floor)


# ---------------------------------------------------------------- 外部測試


def ensure_external_group(client, app_id: str, name: str) -> tuple[dict, bool]:
    """找外部群組，沒有就建一個（開公開連結）。回傳（群組, 是否新建）。"""
    group = find_beta_group(client, app_id, name)
    if group:
        return group, False
    created = client.post("/v1/betaGroups", {"data": {
        "type": "betaGroups",
        "attributes": {"name": name, "publicLinkEnabled": True, "feedbackEnabled": True},
        "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
    }})
    return created["data"], True


def sync_beta_metadata(client, app_id: str, config: dict) -> None:
    """更新版本公開文字；保留既有聯絡資訊與審查帳號，不輸出個資。"""
    locs = client.get_all(f"/v1/apps/{app_id}/betaAppLocalizations", {"limit": 50})
    loc = next((item for item in locs if item["attributes"].get("locale") == config["beta_locale"]), None)
    if loc is None:
        raise ApiError(404, "Configured beta locale missing; create it in App Store Connect first")
    desired = {"description": config["beta_description"], "privacyPolicyUrl": config["privacy_policy_url"]}
    if any(loc["attributes"].get(key) != value for key, value in desired.items()):
        client.patch(f"/v1/betaAppLocalizations/{loc['id']}", {"data": {
            "type": "betaAppLocalizations", "id": loc["id"], "attributes": desired}})
    detail = client.get(f"/v1/apps/{app_id}/betaAppReviewDetail")["data"]
    if detail["attributes"].get("notes") != config["beta_review_notes"]:
        client.patch(f"/v1/betaAppReviewDetails/{detail['id']}", {"data": {
            "type": "betaAppReviewDetails", "id": detail["id"],
            "attributes": {"notes": config["beta_review_notes"]}}})
    print("TestFlight description, privacy URL and review notes are current")


def missing_test_info(client, app_id: str, locale: str) -> list[str]:
    """外部測試送審前 Apple 要求的測試資訊，缺哪些（只讀）。"""
    missing = []
    locs = client.get_all(f"/v1/apps/{app_id}/betaAppLocalizations", {"limit": 50})
    loc = next((l["attributes"] for l in locs if l["attributes"].get("locale") == locale), None)
    if not loc or not loc.get("description"):
        missing.append("Beta App 描述")
    if not loc or not loc.get("feedbackEmail"):
        missing.append("回饋電子郵件")
    detail = client.get(f"/v1/apps/{app_id}/betaAppReviewDetail")["data"]["attributes"]
    for key, label in (("contactFirstName", "審查聯絡人名字"), ("contactLastName", "審查聯絡人姓氏"),
                       ("contactPhone", "審查聯絡人電話"), ("contactEmail", "審查聯絡人信箱")):
        if not detail.get(key):
            missing.append(label)
    return missing


EXTERNAL_READY = {"IN_BETA_TESTING", "BETA_APPROVED", "READY_FOR_BETA_TESTING"}
EXTERNAL_FAILED = {"BETA_REJECTED", "EXPIRED", "PROCESSING_EXCEPTION"}
EXTERNAL_IN_REVIEW = {"WAITING_FOR_BETA_REVIEW", "IN_BETA_REVIEW"}


def classify_external(state: str | None) -> str:
    if state in EXTERNAL_READY:
        return "ready"
    if state in EXTERNAL_FAILED:
        return "failed"
    if state in EXTERNAL_IN_REVIEW:
        return "in_review"
    return "pending"


def distribute_external(client, build_id: str, group_id: str, locale: str, what_to_test: str) -> dict:
    """內測可用後：填 What to Test、加入外部群組、送 Beta App Review（已送過就不重送）。"""
    out: dict = {"group_id": group_id}
    try:
        locs = client.get_all(f"/v1/builds/{build_id}/betaBuildLocalizations", {"limit": 50})
        loc = next((l for l in locs if l["attributes"].get("locale") == locale), None)
        if loc is None:
            client.post("/v1/betaBuildLocalizations", {"data": {
                "type": "betaBuildLocalizations",
                "attributes": {"locale": locale, "whatsNew": what_to_test},
                "relationships": {"build": {"data": {"type": "builds", "id": build_id}}},
            }})
        elif loc["attributes"].get("whatsNew") != what_to_test:
            client.patch(f"/v1/betaBuildLocalizations/{loc['id']}", {"data": {
                "type": "betaBuildLocalizations", "id": loc["id"], "attributes": {"whatsNew": what_to_test}}})

        members = client.get_all(f"/v1/betaGroups/{group_id}/builds", {"fields[builds]": "version", "limit": 200})
        if not any(m["id"] == build_id for m in members):
            client.post(f"/v1/betaGroups/{group_id}/relationships/builds",
                        {"data": [{"type": "builds", "id": build_id}]})

        try:
            submission = client.get(f"/v1/builds/{build_id}/betaAppReviewSubmission").get("data")
        except ApiError as error:
            if error.status != 404:
                raise
            submission = None
        if not submission:
            client.post("/v1/betaAppReviewSubmissions", {"data": {
                "type": "betaAppReviewSubmissions",
                "relationships": {"build": {"data": {"type": "builds", "id": build_id}}},
            }})
            out["submitted"] = True

        state = client.get(f"/v1/builds/{build_id}/buildBetaDetail")["data"]["attributes"].get("externalBuildState")
    except AuthError as error:
        return {**out, "status": "unknown", "reason": "auth_error", "error": str(error)}
    except ApiError as error:  # 多半是測試資訊沒填齊，Apple 會在錯誤裡說缺什麼；不重送
        return {**out, "status": "blocked", "reason": "api_error", "error": str(error)}
    status = classify_external(state)
    return {**out, "status": "submitted" if status in ("in_review", "pending") else status, "state": state}


# ---------------------------------------------------------------- 專案檔


def read_pubspec_version(path: Path = ROOT / "pubspec.yaml") -> str:
    match = re.search(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+[0-9]+)?\s*$", path.read_text(encoding="utf-8"), re.M)
    if not match:
        raise ValueError("pubspec.yaml 找不到 version: x.y.z")
    return match.group(1)


def tag_matches_version(tag: str, version: str) -> bool:
    """發新版本的 tag 必須是 v<pubspec 版本>。日常小改動用 patch-<數字>（Shorebird，另一個 workflow）。"""
    return tag == f"v{version}"


def read_app_bundle_ids(path: Path = ROOT / "ios/Runner.xcodeproj/project.pbxproj") -> set[str]:
    """Xcode 專案裡要上架簽章的 Bundle ID（App 與桌面小工具擴充），不含單元測試。"""
    ids = set(re.findall(r"PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);", path.read_text(encoding="utf-8")))
    return {i.strip('"') for i in ids if not i.endswith(".RunnerTests")}


# ---------------------------------------------------------------- preflight


def preflight(args) -> int:
    bundle_id = CONFIG["bundle_id"]
    widget_id = CONFIG["widget_bundle_id"]
    problems: list[str] = []

    version = read_pubspec_version()
    tag = os.environ.get("CM_TAG", "")
    if tag and not tag_matches_version(tag, version):
        problems.append(f"tag {tag} 和 pubspec 版本 {version} 不一致（應該是 v{version}；小改動請用 patch-<數字>）")
    project_ids = read_app_bundle_ids()
    if project_ids != {bundle_id, widget_id}:
        problems.append(
            f"Xcode 專案的 Bundle ID {sorted(project_ids)} 和 tool/release/config.json 的 {sorted({bundle_id, widget_id})} 不一致")

    try:
        client = AscClient.from_env()
        bundle = find_bundle_id(client, bundle_id)
        if bundle is None and args.create_bundle_id:
            client.post("/v1/bundleIds", {"data": {"type": "bundleIds", "attributes": {
                "identifier": bundle_id, "name": CONFIG["bundle_name"], "platform": "IOS"}}})
            print(f"已在 Apple Developer 註冊 Bundle ID {bundle_id}")
            bundle = True
        if bundle is None:
            problems.append(f"Apple Developer 還沒有 Bundle ID {bundle_id}")

        # 桌面小工具擴充要有自己的 Bundle ID（App Group 能力要擁有者在 Apple Developer 手動開）。
        if find_bundle_id(client, widget_id) is None:
            if args.create_bundle_id:
                client.post("/v1/bundleIds", {"data": {"type": "bundleIds", "attributes": {
                    "identifier": widget_id, "name": f"{CONFIG['bundle_name']} Widget", "platform": "IOS"}}})
                print(f"已在 Apple Developer 註冊 Bundle ID {widget_id}")
            else:
                problems.append(f"Apple Developer 還沒有桌面小工具的 Bundle ID {widget_id}")

        app = find_app(client, bundle_id) if bundle else None
        if bundle and app is None:
            problems.append(
                f"App Store Connect 還沒有這個 App：到「我的 App」→ ＋ 新增 App，套件 ID 選 {bundle_id}，建好後重跑")
        group = find_beta_group(client, app["id"], CONFIG["beta_group"]) if app else None
        if app and group is None:
            problems.append(f"TestFlight 還沒有內部測試群組「{CONFIG['beta_group']}」：TestFlight → 內部測試 → ＋ 建立")
        elif group and not group["attributes"].get("isInternalGroup"):
            problems.append(f"群組「{CONFIG['beta_group']}」不是內部測試群組")

        # 外部測試只發警告：缺資料時內測照常發布，外部送審會在通知裡標示 blocked。
        if app and CONFIG.get("external_group"):
            try:
                _, created = ensure_external_group(client, app["id"], CONFIG["external_group"])
                if created:
                    print(f"已建立外部測試群組「{CONFIG['external_group']}」（公開連結已開啟）")
                for item in missing_test_info(client, app["id"], CONFIG["beta_locale"]):
                    print(f"::warning::外部測試資訊缺少「{item}」：App Store Connect → TestFlight → 測試資訊")
            except ApiError as error:
                print(f"::warning::外部測試群組／測試資訊檢查失敗（不影響內測）：{error}")
    except AuthError as error:
        print(f"::error::App Store Connect API 授權失敗：{error}")
        return 3

    if problems:
        for problem in problems:
            print(f"::error::{problem}")
        return 1

    # 在昂貴建置前更新過期的「只有本機／示範隊友」說明；失敗就停止本次發布。
    try:
        sync_beta_metadata(client, app["id"], CONFIG)
    except ApiError as error:
        print(f"::error::TestFlight metadata update failed: {error}")
        return 1
    build_number = next_build_number(latest_build_number(client, app["id"]), args.min_build_number)
    values = {
        "BUNDLE_ID": bundle_id,
        "WIDGET_BUNDLE_ID": widget_id,
        "APP_STORE_APP_ID": app["id"],
        "BETA_GROUP": CONFIG["beta_group"],
        "RELEASE_VERSION": version,
        "RELEASE_BUILD_NUMBER": str(build_number),
    }
    for key, value in values.items():
        print(f"{key}={value}")
    if args.env_file:
        with open(args.env_file, "a", encoding="utf-8") as env_file:
            env_file.writelines(f"{key}={value}\n" for key, value in values.items())
    return 0


# ---------------------------------------------------------------- verify


@dataclass
class Observation:
    status: str  # ready / failed / unknown / pending
    phase: str
    reason: str
    details: dict = field(default_factory=dict)

    @property
    def final(self) -> bool:
        return self.status != "pending"


def observe(client, app_id: str, group_id: str, version: str, build_number: str, *, assign: bool) -> Observation:
    """查一次指定 App／版本／build 的狀態。assign=True 時，可用但還沒進群組就加進去一次。"""
    builds = client.get_all("/v1/builds", {
        "filter[app]": app_id,
        "filter[version]": build_number,
        "filter[preReleaseVersion.version]": version,
        "fields[builds]": "version,processingState,expired,uploadedDate",
        "limit": 10,
    })
    if not builds:
        return Observation("pending", "apple_upload", "build_not_found")
    if len(builds) > 1:
        return Observation("unknown", "apple_upload", "ambiguous_build", {"build_ids": [b["id"] for b in builds]})

    build = builds[0]
    attrs = build["attributes"]
    details = {"build_id": build["id"], "processingState": attrs.get("processingState"), "expired": attrs.get("expired")}
    state = attrs.get("processingState")
    if state in ("FAILED", "INVALID"):
        return Observation("failed", "apple_processing", state.lower(), details)
    if state != "VALID":
        return Observation("pending", "apple_processing", (state or "unknown").lower(), details)
    if attrs.get("expired"):
        return Observation("failed", "apple_processing", "expired", details)

    beta = client.get(f"/v1/builds/{build['id']}/buildBetaDetail")["data"]["attributes"]
    internal = beta.get("internalBuildState")
    details["internalBuildState"] = internal
    if internal == "PROCESSING_EXCEPTION":
        return Observation("failed", "testflight", "processing_exception", details)
    if internal == "MISSING_EXPORT_COMPLIANCE":
        return Observation("pending", "testflight", "missing_export_compliance", details)

    members = client.get_all(f"/v1/betaGroups/{group_id}/builds", {"fields[builds]": "version", "limit": 200})
    in_group = any(m["id"] == build["id"] for m in members)
    details["in_group"] = in_group
    if in_group and internal == "IN_BETA_TESTING":
        return Observation("ready", "testflight", "in_beta_testing", details)
    if not in_group and assign and internal in ("READY_FOR_BETA_TESTING", "IN_BETA_TESTING"):
        # 只試一次（details["assigned"]），失敗也不重送，之後只查詢。
        details["assigned"] = True
        try:
            client.post(f"/v1/betaGroups/{group_id}/relationships/builds",
                        {"data": [{"type": "builds", "id": build["id"]}]})
        except ApiError as error:
            details["assign_error"] = str(error)
            return Observation("pending", "testflight", "assign_failed", details)
        return Observation("pending", "testflight", "assigned_to_group", details)
    return Observation("pending", "testflight", f"internal_{(internal or 'unknown').lower()}", details)


# 有截止時間的有限退避：Apple 處理通常 5–30 分鐘。
BACKOFF = (30, 45, 60, 90, 120, 180, 300)
STUCK_LIMIT = {"missing_export_compliance": 3}


def wait_for_ready(client, app_id, group_id, version, build_number, *, deadline_s, find_deadline_s,
                   clock=time.monotonic, sleep=time.sleep) -> Observation:
    start = clock()
    assigned = False
    repeats: dict[str, int] = {}
    last = Observation("pending", "apple_upload", "not_checked")
    for attempt in range(10_000):
        try:
            last = observe(client, app_id, group_id, version, build_number, assign=not assigned)
            assigned = assigned or bool(last.details.get("assigned"))
        except AuthError as error:
            return Observation("unknown", "authorization", "auth_error", {"error": str(error)})
        except ApiError as error:  # 已在 client 內有限重試過；記下來，下一輪再試
            last = Observation("pending", last.phase, "api_error", {**last.details, "error": str(error)})
        if last.final:
            return last

        repeats[last.reason] = repeats.get(last.reason, 0) + 1
        if repeats[last.reason] >= STUCK_LIMIT.get(last.reason, 10_000):
            return Observation("unknown", last.phase, last.reason, last.details)
        elapsed = clock() - start
        if last.reason == "build_not_found" and elapsed >= find_deadline_s:
            return Observation("unknown", "apple_upload", "build_not_found_by_deadline", last.details)
        delay = BACKOFF[min(attempt, len(BACKOFF) - 1)]
        if elapsed + delay > deadline_s:
            return Observation("unknown", last.phase, f"timeout_while_{last.reason}", last.details)
        sleep(delay)
    raise AssertionError("unreachable")


def verify(args) -> int:
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", args.version) or not args.build_number.isdigit():
        print("::error::版本要是 x.y.z、build 號要是整數")
        return 2
    bundle_id = CONFIG["bundle_id"]
    result = {"bundle_id": bundle_id, "version": args.version, "build_number": args.build_number,
              "beta_group": CONFIG["beta_group"]}
    try:
        client = AscClient.from_env()
        app = find_app(client, bundle_id)
        group = find_beta_group(client, app["id"], CONFIG["beta_group"]) if app else None
        if not app or not group:
            outcome = Observation("unknown", "config", "app_or_group_missing")
        else:
            result["app_id"] = app["id"]
            outcome = wait_for_ready(
                client, app["id"], group["id"], args.version, args.build_number,
                deadline_s=min(args.deadline_minutes, 100) * 60, find_deadline_s=args.find_deadline_minutes * 60)
            # 內測確定可用才送外部測試；審查結果由 external-watch 排程另外通知。
            if outcome.status == "ready" and args.external and CONFIG.get("external_group"):
                try:
                    external_group, _ = ensure_external_group(client, app["id"], CONFIG["external_group"])
                except ApiError as error:  # 外部失敗不能蓋掉已確認的內測結果
                    result["external"] = {"status": "blocked", "reason": "group_error", "error": str(error)}
                else:
                    result["external"] = distribute_external(
                        client, outcome.details["build_id"], external_group["id"],
                        CONFIG["beta_locale"], CONFIG["what_to_test"])
    except AuthError as error:
        outcome = Observation("unknown", "authorization", "auth_error", {"error": str(error)})
    except ApiError as error:
        outcome = Observation("unknown", "api", "api_error", {"error": str(error)})

    result.update(asdict(outcome))
    result["checked_at"] = datetime.now(timezone.utc).isoformat(timespec="seconds")
    text = json.dumps(result, ensure_ascii=False, indent=2)
    print(text)
    if args.out:
        Path(args.out).write_text(text + "\n", encoding="utf-8")
    return {"ready": 0, "failed": 1}.get(outcome.status, 2)


# ---------------------------------------------------------------- external-watch


def external_events(builds: list[dict], now: datetime, max_age_hours: int) -> list[dict]:
    """最近送審的 build 中，哪些有結果要通知：ready / failed，或審查超過期限的 unknown。

    builds：[{version, build_number, uploaded, state}]；還沒送審或審查中（未逾時）的不通知。
    """
    events = []
    for build in builds:
        age_h = (now - datetime.fromisoformat(build["uploaded"])).total_seconds() / 3600
        status = classify_external(build["state"])
        if status in ("ready", "failed"):
            events.append({**build, "status": status})
        elif status == "in_review" and age_h > max_age_hours:
            events.append({**build, "status": "unknown", "reason": "review_timeout"})
    return events


def pending_submission(builds: list[dict]) -> dict | None:
    """要補送外部審查的 build：沒有任何 build 在審查中時，最新一個「還沒送審」且比已通過的都新的 build。

    Apple 規定同一版本一次只能有一個 build 在 Beta 審查（ANOTHER_BUILD_IN_REVIEW），
    所以審查中送不進去的新 build，要等審查結束再補送。builds 依上傳時間新到舊排列。
    """
    if any(classify_external(b["state"]) == "in_review" for b in builds):
        return None
    newest_ready = next((b for b in builds if classify_external(b["state"]) == "ready"), None)
    for build in builds:
        if build["state"] == "READY_FOR_BETA_SUBMISSION":
            if newest_ready and (datetime.fromisoformat(build["uploaded"])
                                 <= datetime.fromisoformat(newest_ready["uploaded"])):
                return None
            return build
    return None


def external_watch(args) -> int:
    client = AscClient.from_env()
    app = find_app(client, CONFIG["bundle_id"])
    if not app:
        print("::error::找不到 App")
        return 2
    page = client.get("/v1/builds", {"filter[app]": app["id"], "sort": "-uploadedDate", "limit": 10,
                                     "fields[builds]": "version,uploadedDate"})
    now = datetime.now(timezone.utc)
    builds = []
    for build in page.get("data", []):
        uploaded = build["attributes"]["uploadedDate"]
        # 只看最近的；超過期限再多留一天，讓逾時通知有機會發出去
        if (now - datetime.fromisoformat(uploaded)).total_seconds() > (args.max_age_hours + 24) * 3600:
            continue
        state = client.get(f"/v1/builds/{build['id']}/buildBetaDetail")["data"]["attributes"].get("externalBuildState")
        version = client.get(f"/v1/builds/{build['id']}/preReleaseVersion")["data"]["attributes"]["version"]
        builds.append({"id": build["id"], "version": version, "build_number": build["attributes"]["version"],
                       "uploaded": uploaded, "state": state})
    events = external_events(builds, now, args.max_age_hours)

    if args.submit_pending and (pending := pending_submission(builds)):
        group, _ = ensure_external_group(client, app["id"], CONFIG["external_group"])
        result = distribute_external(client, pending["id"], group["id"], CONFIG["beta_locale"], CONFIG["what_to_test"])
        print(f"補送外部審查 {pending['version']} ({pending['build_number']})：{result}")
        events.append({**pending, "status": "resubmitted" if result["status"] != "blocked" else "blocked",
                       "state": result.get("state", pending["state"]), "error": result.get("error", "")})
    for event in events:
        event.pop("id", None)
    text = json.dumps(events, ensure_ascii=False, indent=2)
    print(text)
    if args.out:
        Path(args.out).write_text(text + "\n", encoding="utf-8")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("preflight", help="建置前檢查 API 授權、App、群組、版本，並算出 build 號")
    p.add_argument("--min-build-number", type=int, default=0, help="build 號下限（Codemagic 的 $BUILD_NUMBER）")
    p.add_argument("--create-bundle-id", action="store_true", help="Bundle ID 不存在就註冊")
    p.add_argument("--env-file", help="把結果用 KEY=value 附加到這個檔案（Codemagic 的 $CM_ENV）")
    p.set_defaults(func=preflight)

    v = sub.add_parser("verify", help="等到指定 build 在 TestFlight 內測可用（或確定失敗／逾時）")
    v.add_argument("--version", required=True)
    v.add_argument("--build-number", required=True)
    v.add_argument("--deadline-minutes", type=int, default=90)
    v.add_argument("--find-deadline-minutes", type=int, default=30, help="多久還查不到這個 build 就放棄")
    v.add_argument("--external", action="store_true", help="內測可用後送外部測試（What to Test、外部群組、Beta 審查）")
    v.add_argument("--out", help="結果 JSON 寫到這裡")
    v.set_defaults(func=verify)

    w = sub.add_parser("external-watch", help="列出最近外部測試審查有結果（或逾時）的 build")
    w.add_argument("--max-age-hours", type=int, default=72)
    w.add_argument("--submit-pending", action="store_true",
                   help="沒有 build 在審查中時，把最新還沒送審的 build 補送外部測試")
    w.add_argument("--out", help="事件 JSON 寫到這裡")
    w.set_defaults(func=external_watch)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
