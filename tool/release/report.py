#!/usr/bin/env python3
"""把一次 iOS 發布的結果留言到「iOS 發布通知」issue（GitHub 會寄信通知 repo 擁有者）。

由 .github/workflows/ios-release-report.yml 呼叫；輸入都從環境變數來：
  OUTCOME（uploaded / ci_failed）、FAILED_PHASE、VERSION、BUILD_NUMBER、SOURCE_REF、SOURCE_COMMIT、
  CODEMAGIC_BUILD_URL，以及 GitHub Actions 內建的 GITHUB_TOKEN / GITHUB_REPOSITORY / GITHUB_RUN_ID 等。

  python tool/release/report.py --result-file release-result.json --status-file final-status.txt
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

LABEL = "ios-release"
ISSUE_TITLE = "📦 iOS 發布通知"

PHASE_TEXT = {
    "setup": "環境準備",
    "preflight": "預檢（API 授權／App／群組／版本）",
    "gates": "品質檢查（analyze／test）",
    "signing": "簽章",
    "build": "建置 IPA",
    "upload": "上傳 App Store Connect",
    "apple_upload": "Apple 接收上傳",
    "apple_processing": "Apple 處理 build",
    "testflight": "TestFlight 內測分發",
    "authorization": "App Store Connect API 授權",
    "config": "App Store Connect 設定",
    "api": "App Store Connect API",
    "verifier": "查驗工作",
    "patch": "Shorebird patch（只能含 Dart 修改；動到原生程式或資源檔要改發新版本）",
}


EXTERNAL_TEXT = {
    "submitted": "已送 Beta 審查，結果出來會再通知（通常數小時到一天）",
    "ready": "外部測試可用",
    "failed": "Beta 審查未通過",
    "blocked": "沒有送出：Apple 拒絕送審，原因見後面",
    "unknown": "無法確認",
}


def external_text(external: dict) -> str:
    error = external.get("error", "")
    if "ANOTHER_BUILD_IN_REVIEW" in error:
        return "還沒送：同版本已有 build 在 Beta 審查中（Apple 一次只收一個）。審查結束後，每小時的排程會自動補送最新的 build"
    text = EXTERNAL_TEXT.get(external.get("status"), external.get("status", ""))
    if external.get("status") == "blocked" and ("betaAppReviewDetail" in error or "contact" in error.lower()):
        text = "沒有送出：TestFlight 測試資訊沒填齊"
    return text + (f"（`{error}`）" if error else "")


def compose_external(env: dict, event: dict) -> tuple[str, str]:
    """外部測試審查結果的留言（排程查到結果時用）。不貼公開連結：這是公開 repo。"""
    label = f"{event.get('version', '?')} ({event.get('build_number', '?')})"
    status = event.get("status")
    title = {
        "ready": f"🎉 外部測試可用：{label}——拿公開連結的人現在可以安裝了",
        "failed": f"❌ Beta 審查未通過：{label}",
        "resubmitted": f"📨 已補送外部 Beta 審查：{label}（上一個審查結束了，換最新的 build）",
        "blocked": f"⚠️ 補送外部 Beta 審查失敗：{label}——{external_text(event)}",
    }.get(status, f"❓ Beta 審查超過期限仍沒有結果：{label}")
    repo = env.get("GITHUB_REPOSITORY", "")
    run_url = f"{env.get('GITHUB_SERVER_URL', 'https://github.com')}/{repo}/actions/runs/{env.get('GITHUB_RUN_ID', '')}"
    key = f"{event.get('version')}+{event.get('build_number')}:external:{status}"
    owner = env.get("GITHUB_REPOSITORY_OWNER", "")
    lines = [
        f"### {title}", "", "| 項目 | 內容 |", "| --- | --- |",
        f"| 版本 (build) | {label} |",
        f"| Apple 狀態 | `{event.get('state')}` |",
        "| 公開連結 | App Store Connect → TestFlight → 外部測試群組（不貼在公開 repo） |",
        f"| 查驗紀錄 | {run_url} |",
        "", f"@{owner}" if owner else "", f"<!-- ios-release-report key={key} -->",
    ]
    return key, "\n".join(lines).strip() + "\n"


def final_status(outcome: str, result: dict | None) -> str:
    """整體結果：ready / failed / unknown。TestFlight 成功只能來自 Apple API 查驗；
    patch 成功來自 Shorebird CLI 回報已發布（patch 不經過 Apple）。"""
    if result:
        return result.get("status", "unknown")
    if outcome == "patched":
        return "ready"
    return "failed" if outcome == "ci_failed" else "unknown"


def compose(env: dict, result: dict | None) -> tuple[str, str]:
    """回傳（去重用的 key, 留言內容）。"""
    outcome = env.get("OUTCOME", "")
    status = final_status(outcome, result)
    version, build = env.get("VERSION") or "?", env.get("BUILD_NUMBER") or "?"
    patch = env.get("PATCH_NUMBER", "")
    label = f"{version} ({build})"
    ci_phase = PHASE_TEXT.get(env.get("FAILED_PHASE", ""), env.get("FAILED_PHASE") or "未知步驟")
    is_patch = outcome == "patched" or env.get("FAILED_PHASE") == "patch" or "patch-" in env.get("SOURCE_REF", "")

    if outcome == "patched":
        title = f"🩹 Patch {patch or '?'} 已發布到 {label}——夥伴重開 App 會在背景下載，下次開啟生效"
    elif outcome == "ci_failed" and is_patch:
        title = f"❌ Patch 失敗：{ci_phase} — 夥伴的 App 不會變"
    elif outcome == "ci_failed" and status != "ready":
        if result:  # 上傳步驟失敗，但有去 Apple 查
            title = f"❌ CI 失敗：{ci_phase}（Apple 查驗：{status}）— {label} 沒有可用的新 build"
        else:
            title = f"❌ CI 失敗：{ci_phase} — {label} 沒有上傳"
    elif status == "ready":
        prefix = "⚠️ CI 回報上傳失敗，但 Apple 已收到且" if outcome == "ci_failed" else "✅"
        title = f"{prefix} TestFlight 內測可用：{label}"
    elif status == "failed":
        title = f"❌ Apple 處理失敗：{label}"
    elif not result:
        title = f"❓ 無法確認：{label}（查驗工作沒有產生結果）"
    else:
        title = f"❓ 無法確認：{label}"

    repo = env.get("GITHUB_REPOSITORY", "")
    run_url = f"{env.get('GITHUB_SERVER_URL', 'https://github.com')}/{repo}/actions/runs/{env.get('GITHUB_RUN_ID', '')}"
    commit = env.get("SOURCE_COMMIT", "")
    rows = [
        ("版本 (build)", label),
        ("來源", f"`{env.get('SOURCE_REF') or '?'}` @ `{commit[:12] or '?'}`"),
        ("Codemagic", env.get("CODEMAGIC_BUILD_URL") or "—"),
        ("查驗紀錄", run_url),
    ]
    if result:
        phase = PHASE_TEXT.get(result.get("phase", ""), result.get("phase", ""))
        rows.append(("Apple 狀態", f"{phase}：`{result.get('reason')}`"))
        details = result.get("details") or {}
        if details:
            rows.append(("細節", "`" + json.dumps(details, ensure_ascii=False) + "`"))
        if external := result.get("external"):
            rows.append(("外部測試", external_text(external)))
        rows.append(("查驗時間 (UTC)", result.get("checked_at", "")))

    if patch:
        rows.insert(1, ("Patch", f"#{patch}（Shorebird stable）"))
    key = f"{version}+{build}{f'#patch{patch}' if patch else ''}:{outcome}:{status}"
    owner = env.get("GITHUB_REPOSITORY_OWNER", "")
    lines = [f"### {title}", "", "| 項目 | 內容 |", "| --- | --- |"]
    lines += [f"| {name} | {value} |" for name, value in rows]
    lines += ["", f"@{owner}" if owner else "", f"<!-- ios-release-report key={key} -->"]
    return key, "\n".join(lines).strip() + "\n"


# ---------------------------------------------------------------- GitHub


class GitHub:
    def __init__(self, token: str, repo: str, api: str = "https://api.github.com"):
        self.token, self.repo, self.api = token, repo, api

    def call(self, method: str, path: str, body: dict | None = None):
        req = urllib.request.Request(f"{self.api}/repos/{self.repo}{path}", method=method,
                                     data=json.dumps(body).encode() if body is not None else None)
        req.add_header("Authorization", f"Bearer {self.token}")
        req.add_header("Accept", "application/vnd.github+json")
        req.add_header("X-GitHub-Api-Version", "2022-11-28")
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else None

    def notification_issue(self) -> int:
        issues = self.call("GET", f"/issues?state=open&labels={LABEL}&per_page=10")
        if issues:
            return issues[0]["number"]
        try:
            self.call("POST", "/labels", {"name": LABEL, "color": "f5c400", "description": "iOS 發布結果通知"})
        except urllib.error.HTTPError as error:
            if error.code != 422:  # 422 = 標籤已存在
                raise
        issue = self.call("POST", "/issues", {
            "title": ISSUE_TITLE,
            "labels": [LABEL],
            "body": "每次 iOS 發布（Codemagic → TestFlight）的結果都會留言在這裡，GitHub 會寄通知信。\n"
                    "說明見 docs/release/ios-release.md。請保持這個 issue 開著。",
        })
        return issue["number"]

    def already_posted(self, number: int, key: str) -> bool:
        marker = f"<!-- ios-release-report key={key} -->"
        comments = self.call("GET", f"/issues/{number}/comments?per_page=100&sort=created&direction=desc")
        return any(marker in (c.get("body") or "") for c in comments or [])


def post_external_events(env: dict, path: Path, dry_run: bool) -> int:
    events = json.loads(path.read_text(encoding="utf-8")) if path.exists() else []
    if not events:
        print("沒有新的外部測試審查結果")
        return 0
    github = None if dry_run else GitHub(env["GITHUB_TOKEN"], env["GITHUB_REPOSITORY"])
    number = github.notification_issue() if github else 0
    for event in events:
        key, body = compose_external(env, event)
        print(body)
        if github is None or github.already_posted(number, key):
            continue
        github.call("POST", f"/issues/{number}/comments", {"body": body})
        print(f"已留言到 issue #{number}")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--result-file", default="release-result.json")
    parser.add_argument("--status-file", help="把整體結果（ready/failed/unknown）寫到這裡")
    parser.add_argument("--external-events", help="external-watch 的事件 JSON：每個事件各留一則（已留過的略過）")
    parser.add_argument("--dry-run", action="store_true", help="只印出留言，不呼叫 GitHub")
    args = parser.parse_args(argv)

    env = dict(os.environ)
    if args.external_events:
        return post_external_events(env, Path(args.external_events), args.dry_run)
    for name, pattern in (("VERSION", r"[0-9]+\.[0-9]+\.[0-9]+"), ("BUILD_NUMBER", r"[0-9]+"), ("PATCH_NUMBER", r"[0-9]+"),
                          ("SOURCE_COMMIT", r"[0-9a-f]{7,40}")):
        if env.get(name) and not re.fullmatch(pattern, env[name]):
            print(f"::warning::{name} 格式不對，忽略：{env[name]!r}")
            env[name] = ""
    if env.get("CODEMAGIC_BUILD_URL") and not env["CODEMAGIC_BUILD_URL"].startswith("https://codemagic.io/"):
        env["CODEMAGIC_BUILD_URL"] = ""
    if not re.fullmatch(r"[A-Za-z0-9._/-]*", env.get("SOURCE_REF", "")):
        env["SOURCE_REF"] = ""

    path = Path(args.result_file)
    result = json.loads(path.read_text(encoding="utf-8")) if path.exists() else None
    key, body = compose(env, result)
    status = final_status(env.get("OUTCOME", ""), result)
    if args.status_file:
        Path(args.status_file).write_text(status, encoding="utf-8")
    if summary := env.get("GITHUB_STEP_SUMMARY"):
        with open(summary, "a", encoding="utf-8") as f:
            f.write(body)
    print(body)
    if args.dry_run:
        return 0

    github = GitHub(env["GITHUB_TOKEN"], env["GITHUB_REPOSITORY"])
    number = github.notification_issue()
    if github.already_posted(number, key):
        print(f"issue #{number} 已經有這次結果的留言，不重複通知")
        return 0
    github.call("POST", f"/issues/{number}/comments", {"body": body})
    print(f"已留言到 issue #{number}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
