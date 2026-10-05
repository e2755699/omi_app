#!/usr/bin/env python3
"""一次把 iOS 發布需要的秘密放進 Codemagic 和 GitHub（由帳號擁有者在自己電腦執行）。

  python tool/release/setup_secrets.py

會依序詢問（貼上的 token 不會顯示在畫面上，也不會存檔或印出）：
  1. Codemagic API token        https://codemagic.io/settings → API token → Show
  2. App Store Connect Issuer ID、Key ID、.p8 檔案位置（沿用黃絲帶那把即可）
  3. 簽章私鑰檔案位置（沿用黃絲帶的 CERTIFICATE_PRIVATE_KEY；直接 Enter 會產生新的）
  4. GitHub fine-grained token（給 Codemagic 觸發查驗用）

然後：先用 App Store Connect API 唯讀確認 key 可用 → 寫進 Codemagic 變數群組
（app_store_connect、github_report，全部 Secret）→ 用 gh 寫進 GitHub Actions secrets。
需要：pip install -r tool/release/requirements.txt，以及已登入的 gh CLI。
"""

from __future__ import annotations

import getpass
import json
import re
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc  # noqa: E402

CODEMAGIC_API = "https://codemagic.io/api/v3"
GROUPS = {
    "app_store_connect": ["APP_STORE_CONNECT_ISSUER_ID", "APP_STORE_CONNECT_KEY_IDENTIFIER",
                          "APP_STORE_CONNECT_PRIVATE_KEY", "CERTIFICATE_PRIVATE_KEY"],
    "github_report": ["GITHUB_DISPATCH_TOKEN"],
}
GITHUB_SECRETS = ["APP_STORE_CONNECT_ISSUER_ID", "APP_STORE_CONNECT_KEY_IDENTIFIER", "APP_STORE_CONNECT_PRIVATE_KEY"]


# ---------------------------------------------------------------- Codemagic


def codemagic_call(token: str, method: str, path: str, body: dict | None = None):
    req = urllib.request.Request(CODEMAGIC_API + path, method=method,
                                 data=json.dumps(body).encode() if body is not None else None)
    req.add_header("x-auth-token", token)
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=30) as resp:
        raw = resp.read()
        return json.loads(raw) if raw else None


def upsert_codemagic(call, app_id: str, values: dict[str, str]) -> list[str]:
    """建立缺少的群組，變數已存在就更新、沒有就匯入；全部設為 Secret。回傳做過的事（只有名稱）。"""
    done = []
    groups = {g["name"]: g["id"] for g in call("GET", f"/apps/{app_id}/variable-groups?page_size=100")["data"]}
    for group_name, names in GROUPS.items():
        group_id = groups.get(group_name)
        if group_id is None:
            group_id = call("POST", f"/apps/{app_id}/variable-groups", {"name": group_name})["data"]["id"]
            done.append(f"建立群組 {group_name}")
        existing = {v["name"]: v["id"] for v in
                    call("GET", f"/variable-groups/{group_id}/variables?page_size=100")["data"]}
        new = []
        for name in names:
            if name in existing:
                call("PATCH", f"/variable-groups/{group_id}/variables/{existing[name]}",
                     {"value": values[name], "secure": True})
                done.append(f"更新 {group_name}/{name}")
            else:
                new.append({"name": name, "value": values[name]})
        if new:
            call("POST", f"/variable-groups/{group_id}/variables", {"secure": True, "variables": new})
            done += [f"新增 {group_name}/{v['name']}" for v in new]
    return done


# ---------------------------------------------------------------- 輸入


def ask_path(prompt: str, allow_empty: bool = False) -> Path | None:
    while True:
        raw = input(prompt).strip().strip('"').strip("'")
        if not raw and allow_empty:
            return None
        path = Path(raw).expanduser()
        if path.is_file():
            return path
        print(f"  找不到檔案：{path}")


def read_pem(path: Path, kind: str) -> str:
    text = path.read_text(encoding="utf-8").strip()
    if not re.search(r"-----BEGIN [A-Z ]*PRIVATE KEY-----", text):
        sys.exit(f"{path.name} 看起來不是{kind}（找不到 BEGIN ... PRIVATE KEY）")
    return text + "\n"


def new_signing_key() -> str:
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric import rsa

    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    pem = key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.TraditionalOpenSSL,
                            serialization.NoEncryption()).decode()
    path = Path.home() / ".omi-release" / "ios_distribution_private_key.pem"
    path.parent.mkdir(exist_ok=True)
    path.write_text(pem, encoding="utf-8")
    print(f"  已產生新的簽章私鑰並備份到 {path}（請妥善保存，之後每次都要用同一把）")
    return pem


def main() -> int:
    config = asc.CONFIG
    print("== iOS 發布秘密設定（輸入的 token 不會顯示）==\n")

    cm_token = getpass.getpass("1. Codemagic API token（codemagic.io/settings → API token → Show）：").strip()

    print("\n2. App Store Connect API key（App Store Connect → 使用者與存取 → 整合 → 團隊金鑰）")
    issuer = input("   Issuer ID：").strip()
    p8 = ask_path("   .p8 檔案位置（可直接把檔案拖進來）：")
    guess = re.match(r"AuthKey_([A-Z0-9]+)\.p8$", p8.name)
    key_id = input(f"   Key ID{f'（Enter 用 {guess.group(1)}）' if guess else ''}：").strip() or (guess and guess.group(1))
    private_key = read_pem(p8, " App Store Connect 的 .p8")

    print("\n3. 簽章私鑰（沿用黃絲帶的 CERTIFICATE_PRIVATE_KEY，就不會多建一張發行憑證）")
    cert_path = ask_path("   檔案位置（沒有就直接 Enter，會產生新的並多建一張憑證）：", allow_empty=True)
    if cert_path:
        cert_key = read_pem(cert_path, "簽章私鑰")
    elif input("   確定要產生新的簽章私鑰嗎？(y/N) ").strip().lower() == "y":
        cert_key = new_signing_key()
    else:
        return 1

    gh_token = getpass.getpass("\n4. GitHub fine-grained token（只限 omi_app，Actions: Read and write）：").strip()

    print("\n檢查 App Store Connect API key（唯讀）…")
    try:
        app = asc.find_app(asc.AscClient(issuer, key_id, private_key), config["bundle_id"])
    except (asc.AuthError, asc.ApiError) as error:
        sys.exit(f"  API key 無法使用：{error}")
    print(f"  ✓ 可以讀到 App（{'找到' if app else '還沒建立'} {config['bundle_id']}）")

    values = {
        "APP_STORE_CONNECT_ISSUER_ID": issuer,
        "APP_STORE_CONNECT_KEY_IDENTIFIER": key_id,
        "APP_STORE_CONNECT_PRIVATE_KEY": private_key,
        "CERTIFICATE_PRIVATE_KEY": cert_key,
        "GITHUB_DISPATCH_TOKEN": gh_token,
    }

    print("\n寫進 Codemagic…")
    try:
        done = upsert_codemagic(lambda *a: codemagic_call(cm_token, *a), config["codemagic_app_id"], values)
    except urllib.error.HTTPError as error:
        sys.exit(f"  Codemagic API 失敗：HTTP {error.code}（token 對嗎？）")
    for line in done:
        print(f"  ✓ {line}")

    print("\n寫進 GitHub Actions secrets…")
    for name in GITHUB_SECRETS:
        result = subprocess.run(["gh", "secret", "set", name, "--repo", config["github_repo"]],
                                input=values[name], text=True, capture_output=True)
        if result.returncode != 0:
            sys.exit(f"  gh secret set {name} 失敗：{result.stderr.strip()}（gh 有登入嗎？）")
        print(f"  ✓ {name}")

    print("\n完成。可以回去跟 Claude 說「好了」。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
