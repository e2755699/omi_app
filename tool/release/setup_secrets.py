#!/usr/bin/env python3
"""一次把 iOS 發布需要的秘密放進 Codemagic 和 GitHub（由帳號擁有者在自己電腦執行）。

  python tool/release/setup_secrets.py --issuer-id <Issuer ID> --key-id <Key ID> --p8 <AuthKey_xxx.p8 位置>

不是秘密的值用參數帶進來；兩個 token 不用貼上：照提示複製好按 Enter，腳本直接從剪貼簿讀
（讀完就清掉剪貼簿，不顯示、不存檔、不印出），並馬上打 API 確認是對的 token。
簽章私鑰第一次自動產生，備份在 ~/.omi-release/，之後重跑自動沿用（不會再多建 Apple 憑證）。

做的事：用 App Store Connect API 唯讀確認 key 可用 → 寫進 Codemagic 變數群組
（app_store_connect、github_report，全部 Secret）→ 用 gh 寫進 GitHub Actions secrets。
需要：pip install -r tool/release/requirements.txt，以及已登入的 gh CLI。
"""

from __future__ import annotations

import argparse
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
RELEASE_DIR = Path.home() / ".omi-release"
# Codemagic 的 Secret 讀不回來，所以簽章私鑰在本機留一份（不在 repo 裡）
SIGNING_KEY_BACKUP = RELEASE_DIR / "ios_distribution_private_key.pem"


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


# ---------------------------------------------------------------- 剪貼簿與檢查


def read_clipboard() -> str:
    """讀剪貼簿（不經過終端機貼上，避免 Ctrl+V 在某些終端機無效）。"""
    try:
        import tkinter

        root = tkinter.Tk()
        root.withdraw()
        try:
            return root.clipboard_get().strip()
        finally:
            root.destroy()
    except Exception:  # noqa: BLE001 — 沒有 tkinter 或剪貼簿不是文字，改用 PowerShell
        pass
    if sys.platform == "win32":
        result = subprocess.run(["powershell", "-NoProfile", "-Command", "Get-Clipboard -Raw"],
                                capture_output=True, text=True)
        return result.stdout.strip()
    return ""


def clear_clipboard() -> None:
    if sys.platform == "win32":
        subprocess.run(["powershell", "-NoProfile", "-Command", "Set-Clipboard -Value ' '"], capture_output=True)


def ask_token(title: str, how: str, check) -> str:
    print(f"\n{title}\n   {how}")
    while True:
        input("   複製好之後按 Enter：")
        value = read_clipboard()
        problem = check(value) if value else "剪貼簿是空的"
        if not problem:
            clear_clipboard()
            print("   ✓ 收到並確認可用（已清掉剪貼簿）")
            return value
        print(f"   ✗ {problem}，請重新複製後再按 Enter")


def check_codemagic(app_id: str):
    def check(token: str) -> str | None:
        try:
            codemagic_call(token, "GET", f"/apps/{app_id}/variable-groups?page_size=1")
        except urllib.error.HTTPError as error:
            return f"Codemagic 不接受這個 token（HTTP {error.code}），剪貼簿裡可能是別的東西"
        except urllib.error.URLError as error:
            return f"連不到 Codemagic（{error.reason}）"
        return None
    return check


def check_github(repo: str):
    def check(token: str) -> str | None:
        if not token.startswith("github_pat_"):
            return "這不像 GitHub fine-grained token（應該是 github_pat_ 開頭）"
        req = urllib.request.Request(f"https://api.github.com/repos/{repo}")
        req.add_header("Authorization", f"Bearer {token}")
        try:
            urllib.request.urlopen(req, timeout=30).close()
        except urllib.error.HTTPError as error:
            return f"GitHub 不接受這個 token（HTTP {error.code}）"
        return None
    return check


def read_pem(path: Path, kind: str) -> str:
    text = path.read_text(encoding="utf-8").strip()
    if not re.search(r"-----BEGIN [A-Z ]*PRIVATE KEY-----", text):
        sys.exit(f"{path.name} 看起來不是{kind}（找不到 BEGIN ... PRIVATE KEY）")
    return text + "\n"


def find_p8(given: str | None, key_id: str) -> Path:
    """參數給的位置 → ~/.omi-release → 下載資料夾，依序找 AuthKey_<Key ID>.p8。"""
    candidates = [Path(given.strip('"').strip("'")).expanduser()] if given else []
    candidates += [RELEASE_DIR / f"AuthKey_{key_id}.p8", Path.home() / "Downloads" / f"AuthKey_{key_id}.p8"]
    for path in candidates:
        if path.is_file():
            return path
    sys.exit("找不到 .p8：" + "、".join(str(p) for p in candidates))


def signing_key() -> str:
    if SIGNING_KEY_BACKUP.is_file():
        print(f"\n簽章私鑰：沿用 {SIGNING_KEY_BACKUP}")
        return read_pem(SIGNING_KEY_BACKUP, "簽章私鑰")
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric import rsa

    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    pem = key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.TraditionalOpenSSL,
                            serialization.NoEncryption()).decode()
    RELEASE_DIR.mkdir(exist_ok=True)
    SIGNING_KEY_BACKUP.write_text(pem, encoding="utf-8")
    print(f"\n簽章私鑰：已產生新的並備份到 {SIGNING_KEY_BACKUP}（重跑會自動沿用）")
    return pem


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--issuer-id", required=True)
    parser.add_argument("--key-id", required=True)
    parser.add_argument("--p8", help="AuthKey_<Key ID>.p8 的位置；省略時在 ~/.omi-release 和下載資料夾找")
    args = parser.parse_args(argv)
    config = asc.CONFIG

    print("== iOS 發布秘密設定 ==")
    p8 = find_p8(args.p8, args.key_id)
    private_key = read_pem(p8, " App Store Connect 的 .p8")
    print(f"\nApp Store Connect key：{args.key_id}（{p8}）")
    try:
        app = asc.find_app(asc.AscClient(args.issuer_id, args.key_id, private_key), config["bundle_id"])
    except (asc.AuthError, asc.ApiError) as error:
        sys.exit(f"   ✗ API key 無法使用：{error}")
    print(f"   ✓ 可以用（{'找到' if app else '還沒建立'} {config['bundle_id']}）")

    cert_key = signing_key()

    cm_token = ask_token("Codemagic API token",
                         "到 https://codemagic.io/settings →「API token」按 Show → 複製",
                         check_codemagic(config["codemagic_app_id"]))
    gh_token = ask_token("GitHub token",
                         "在剛剛 GitHub 產生 token 的頁面按複製（github_pat_ 開頭）",
                         check_github(config["github_repo"]))

    values = {
        "APP_STORE_CONNECT_ISSUER_ID": args.issuer_id,
        "APP_STORE_CONNECT_KEY_IDENTIFIER": args.key_id,
        "APP_STORE_CONNECT_PRIVATE_KEY": private_key,
        "CERTIFICATE_PRIVATE_KEY": cert_key,
        "GITHUB_DISPATCH_TOKEN": gh_token,
    }

    print("\n寫進 Codemagic…")
    try:
        done = upsert_codemagic(lambda *a: codemagic_call(cm_token, *a), config["codemagic_app_id"], values)
    except urllib.error.HTTPError as error:
        sys.exit(f"   ✗ Codemagic API 失敗：HTTP {error.code}")
    for line in done:
        print(f"   ✓ {line}")

    print("\n寫進 GitHub Actions secrets…")
    for name in GITHUB_SECRETS:
        result = subprocess.run(["gh", "secret", "set", name, "--repo", config["github_repo"]],
                                input=values[name], text=True, capture_output=True)
        if result.returncode != 0:
            sys.exit(f"   ✗ gh secret set {name} 失敗：{result.stderr.strip()}（gh 有登入嗎？）")
        print(f"   ✓ {name}")

    print("\n完成。可以回去跟 Claude 說「好了」。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
