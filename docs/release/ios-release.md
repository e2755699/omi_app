# iOS 發布（Codemagic → TestFlight 內測＋外部測試）

> 狀態（2026-10-06）：**第一次真實發布 1.0.0 (1) 已內測可用，外部測試已送 Beta 審查**（等 Apple 結果）。Codemagic → GitHub 的自動觸發因 token 無效失敗，該次改用 `gh` 手動補查；換好 token 後再驗一次。細節見「驗收矩陣」。
> 商店資料、TestFlight 測試資訊與正式送審準備見 [app-store-listing.md](app-store-listing.md)。

## 怎麼發布

| 改了什麼 | 打什麼 tag | 結果 |
| --- | --- | --- |
| 只有 Dart 程式碼（大部分功能） | `patch-<數字>`，例如 `patch-3`（數字每次加一） | Shorebird patch，約 10 分鐘；夥伴重開 App 會在背景下載，下次開啟生效。不經過 Apple |
| 原生程式（`ios/`、`android/`）、新增帶原生程式的套件、圖片／字型等資源、Info.plist | `v<新版本>`，例如 `v1.0.1`（先改 `pubspec.yaml` 的 `version`） | Shorebird release 打包 → TestFlight 內測 → 自動送外部測試（新版本號第一次要 Beta 審查） |

```bash
git tag patch-3
git push origin patch-3
```

- patch 一律套用到**最新的 release**。Shorebird 偵測到原生程式或資源檔有變會擋下來，這時改發新版本 tag。
- tag 必須是 `v<pubspec 版本>`（新版本）或 `patch-<數字>`（patch），不符會被擋下。
- 第一次啟用 Shorebird 時要先打一次 `v1.0.0`，產生可以被 patch 的基底版（1.0.0 (2)）。
- 也可以在 Codemagic 手動 Start new build（workflow `iOS → TestFlight` 或 `iOS patch`）。
- **不會**自動送 App Store 正式審查或公開上架。

## 資料流

```
git push tag v1.0.1                              git push tag patch-3
  │                                                │
  ▼                                                ▼
Codemagic ios-testflight（mac_mini_m2）           Codemagic ios-patch（mac_mini_m2）
  0 準備：發布工具、安裝 Shorebird                  0 準備：發布工具、安裝 Shorebird
  1 預檢 asc.py preflight：API 授權、Bundle ID、     1 品質檢查 analyze／test／發布工具測試
    App、群組、tag=版本、配 build 號；外部群組沒有    2 shorebird patch ios --release-version=latest
    就建、測試資訊缺什麼只警告                          --no-codesign（只送 Dart 差異，不需簽章）
  2 品質檢查 analyze／test／發布工具測試               → 擷取 release 版本與 patch 編號
  3 簽章 fetch-signing-files --create（沿用憑證）
  4 建置 shorebird release ios（--build-name/number）
  5 上傳 app-store-connect publish（只上傳）
  └ publishing script（成功失敗都跑）→ workflow_dispatch ios-release-report.yml（ref=master）
  │
  ▼
GitHub Actions：ios-release-report.yml（ubuntu）
  - outcome=uploaded：asc.py verify --external 有限退避查 Apple（30 秒到 5 分鐘一次，最多 90 分鐘）
      內測成功條件：指定 App＋版本＋build、processingState=VALID、未過期、
                   internalBuildState=IN_BETA_TESTING、「Omi Internal」包含此 build
      內測可用後：設定 What to Test → 加入「Omi 夥伴」→ 送 Beta App Review（已送過不重送）
  - outcome=patched：不查 Apple，直接留言「🩹 Patch N 已發布」
  - report.py 留言（@擁有者 → GitHub 寄信）；不是 ready 時 run 失敗 → 另一封 Actions 失敗信
  │
  ▼
GitHub Actions：testflight-external-watch.yml（每小時）
  - asc.py external-watch：最近 build 的 externalBuildState
      IN_BETA_TESTING / BETA_APPROVED → 🎉 外部測試可用；BETA_REJECTED → ❌；送審超過 72 小時 → ❓
  - 同一結果只留言一次；公開連結不貼在公開 repo
```

內測結果：`ready`（API 證實可用）、`failed`（Apple 明確拒絕或 CI 失敗沒上傳）、`unknown`（授權、網路、逾時、找不到 build）。外部測試另外標示：`submitted`、`ready`、`failed`、`blocked`（多半是測試資訊沒填齊，不會重送）。外部有問題不會蓋掉內測結果。patch 的成功依據是 Shorebird CLI 回報「Published Patch N」。

## 版本與 build 號

- 版本 ＝ `pubspec.yaml` 的 `x.y.z`；新版本 tag 必須是 `v<x.y.z>`。
- build 號 ＝ max(Apple 上這個 App 用過的最大 build 號 + 1, Codemagic `$BUILD_NUMBER`)；Shorebird 的 release 版本記成 `x.y.z+build`。
- patch 編號由 Shorebird 自動遞增；`patch-<數字>` 的數字只是給人看的 tag 名稱，不必等於 patch 編號。
- Codemagic 免費方案一次只跑一個 build，不會撞號。

## 簽章模式

**自動 provisioning（API）**：Codemagic CLI 用 API key 找符合 `CERTIFICATE_PRIVATE_KEY` 的 Apple Distribution 憑證和 App Store profile，沒有就建立。

- Omi 用**專屬**的 API key（`omi-ci`，App 管理權限）和專屬簽章私鑰，和黃絲帶互不影響。黃絲帶的 key 與私鑰只存在 Codemagic 的 Secret（讀不回）和 Apple（`.p8` 只能下載一次），無法沿用。
- 簽章私鑰在擁有者電腦的 `~/.omi-release/ios_distribution_private_key.pem` 留一份備份（Codemagic 讀不回）；之後一律用同一把，不要換，否則每換一次就多建一張憑證。
- Apple 每個帳號最多 3 張有效的 Distribution 憑證。第一次 build 前已有 2 張（黃絲帶 CI 建的，2027/09、2027/10 到期），Omi 第一次 build 會建第 3 張。到期的不佔名額；要再開新專案前，先確認哪張沒在用再撤銷（CI 不會自動撤銷）。

## 秘密與設定位置（不記錄值）

| 名稱 | 放在哪 | 內容 |
| --- | --- | --- |
| `APP_STORE_CONNECT_ISSUER_ID` | Codemagic 群組 `app_store_connect`＋GitHub Actions secrets | Issuer ID |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | 同上 | `omi-ci` 的 Key ID |
| `APP_STORE_CONNECT_PRIVATE_KEY` | 同上 | `omi-ci` 的 `.p8` 全文 |
| `CERTIFICATE_PRIVATE_KEY` | Codemagic 群組 `app_store_connect` | Omi 專屬簽章私鑰 PEM（RSA 2048） |
| `GITHUB_DISPATCH_TOKEN` | Codemagic 群組 `github_report` | fine-grained token，只限 `e2755699/omi_app`，Actions: Read and write |
| `SHOREBIRD_TOKEN` | Codemagic 群組 `shorebird` | Shorebird Console → Account → API Keys（`sb_api_` 開頭，免費方案只有 Full access） |

Codemagic 個人帳號的變數群組只屬於單一 App，而且 Secret 值讀不回，所以不能引用黃絲帶的 `yellow_ribbon_ci`。

**放秘密（擁有者本人執行，一個指令）**：

```bash
python tool/release/setup_secrets.py --issuer-id <Issuer ID> --key-id <Key ID>
```

只換其中幾項時用 `--only`（例如換 GitHub token、加 Shorebird key）：

```bash
python tool/release/setup_secrets.py --only github,shorebird
```

Shorebird 那一項會順便：沒有「Omi」這個 Shorebird App 就建立，並在 repo 根目錄寫出 `shorebird.yaml`（app_id 不是秘密，要 commit；`pubspec.yaml` 的 assets 也要列入它）。

`.p8` 放在 `~/.omi-release/`（或下載資料夾）會自動找到；簽章私鑰第一次自動產生並備份在同一處。兩個 token 不用在終端機貼上：照提示複製好按 Enter，腳本直接讀剪貼簿、立刻打 API 驗證，讀完清掉剪貼簿（Windows 終端機的 Ctrl+V 常常無效，所以這樣設計）。它會先用 API 唯讀確認 key 可用，再透過 Codemagic API 建立／更新兩個群組（全部 Secret），並用 `gh secret set` 寫進 GitHub Actions secrets。之後要輪替時，重跑同一個指令即可。

非秘密設定集中在 [tool/release/config.json](../../tool/release/config.json)：Bundle ID、內部／外部群組名稱、What to Test 文字、Shorebird App 名稱、Codemagic app id。改 Bundle ID 時 Xcode 專案也要一起改，預檢會比對。

## 設定進度

| 項目 | 狀態 |
| --- | --- |
| Bundle ID `com.jacklope.omiApp` | ✅ 2026-10-06 已註冊（Apple Developer） |
| App Store Connect App「Omi～快樂的 Σίσυφος」 | ✅ 已建立，Apple ID `6819375327`，SKU `omi-ios` |
| 內部群組「Omi Internal」 | ✅ 已建立，自動分發開啟，帳號持有人已加入 |
| 外部群組「Omi 夥伴」 | ✅ 第一次預檢自動建立（開公開連結） |
| Codemagic App | ✅ 已加入（app id `6ac3e6dec18dba32d6229cd5`） |
| 隱私權政策頁 | ✅ `web/privacy/` → https://e2755699.github.io/omi_app/privacy/ |
| TestFlight 測試資訊 | ✅ 描述、隱私網址、demo 審查備註、回饋信箱、審查聯絡人都已儲存 |
| App Store Connect API key `omi-ci` | ✅ App 管理權限，Key ID `Y756B38PS2`；`.p8` 在擁有者的 `~/.omi-release/` |
| Codemagic 變數群組、GitHub Actions secrets | ✅ 2026-10-06 由 `setup_secrets.py` 寫入 |
| `GITHUB_DISPATCH_TOKEN` | ✅ 2026-10-06 Regenerate 後由新版 `setup_secrets.py` 驗證寫入；build #2 自動觸發查驗成功 |
| Shorebird（帳號、API key、App、`shorebird.yaml`） | ✅ 2026-10-06：App「Omi」、基底版 1.0.0+2 已登記；`SHOREBIRD_TOKEN` 在 Codemagic 群組 `shorebird` |
| GitHub → Codemagic webhook（推 tag 自動觸發） | ⚠️ 還沒建立：Codemagic 顯示「No deliveries」，推 `v1.0.0` 沒觸發，改手動 Start build。待擁有者同意後按 Codemagic → Webhooks →「Update webhook」 |

## 排錯與重試

| 現象 | 處理 |
| --- | --- |
| 預檢 `授權失敗` / 401 / 403 | key 被撤銷、權限不夠或秘密貼錯（`.p8` 要含 BEGIN/END 行）。修好後重跑 |
| 預檢 `tag 和 pubspec 版本不一致` | 改 pubspec 後打新 tag；不要移動已推送的 tag |
| 簽章失敗（憑證數量上限） | 已有 3 張有效憑證，且都不符合 `CERTIFICATE_PRIVATE_KEY`（多半是私鑰被換掉）。換回 `~/.omi-release/` 那把；真的要撤銷哪張由擁有者決定，CI 不會自動撤銷 |
| 上傳失敗 | 報告會查 Apple 20 分鐘看是否其實已收到；不要用同一個 build 號重傳，重跑會配新號 |
| 通知 `unknown: timeout_*` | Apple 處理太久。GitHub Actions → iOS release report → Run workflow，填 `uploaded`、版本、build 號補查 |
| 外部測試 `blocked` | TestFlight → 測試資訊 補齊（錯誤訊息會寫缺什麼），再補查一次（同上 Run workflow）；已送審的不會重送 |
| Beta 審查被拒 | 看 App Store Connect 的退件說明，修正後發新版本 |
| 沒收到任何通知 | Codemagic build 被取消／逾時（不跑回報腳本），或 `GITHUB_DISPATCH_TOKEN` 失效 → 看 Codemagic build log 最後一步 |

## 輪替

- **API key**：建新 key → 重跑 `setup_secrets.py` → 跑一次確認 → 撤銷舊的 `omi-ci`（只有 Omi 在用，不影響黃絲帶）。
- **GitHub token**：到期前重建，更新 Codemagic `GITHUB_DISPATCH_TOKEN`。
- **簽章私鑰**：不換。

## 成本假設（2026-10-06 查官方頁面）

- Codemagic 個人免費方案：每月 500 分鐘 Mac mini M2（和黃絲帶共用）、一次 1 個 build；預估一次發布 15–20 分鐘（未實測）。
- GitHub Actions：公開 repo 的標準 runner 免費；外部審查監看每小時跑一次，沒有送審中的 build 時幾秒結束。改私有 repo 後計入每月免費額度。

## 已知缺口

- 沒用 Apple webhook（沒有可公開接收 HTTPS 的服務），改用有截止時間的 API 查詢與每小時排程。
- Codemagic build 被取消或逾時不會通知。
- 通知只有 GitHub 一條管道（issue 留言＋Actions 失敗信）。

## 驗收矩陣

等級：未實作／已配置／模擬測試通過／真實雲端實跑通過／Apple API 確認／通知已送出／收件確認。

| 情境 | 目前狀態 | 證據 |
| --- | --- | --- |
| 正常發布：建置 → 上傳 → 內測可用 → 通知 | **真實雲端實跑通過、Apple API 確認、通知已送出**（手動 Codemagic build；收件待擁有者確認） | Codemagic build #1（[連結](https://codemagic.io/app/6ac3e6dec18dba32d6229cd5/build/6ac4425b7394575b200b76db)，`ba5abb1`）→ 1.0.0 (1)，Apple build `a2b7493a-23bc-4963-b96e-e932e5278924`：`VALID`、`IN_BETA_TESTING`、在「Omi Internal」（[Actions run 37395758576](https://github.com/e2755699/omi_app/actions/runs/37395758576)，2026-10-06 00:52 UTC）→ issue #1 留言 |
| Codemagic → GitHub 自動觸發查驗 | **真實實跑通過**（build #2）；build #1 曾因 token 無效 401，已修 | [Actions run 37401643955](https://github.com/e2755699/omi_app/actions/runs/37401643955) |
| tag 觸發（`git push origin v1.0.0`） | **實跑失敗**：GitHub → Codemagic 沒有 webhook，推 tag 沒觸發；手動對 tag 啟動 build #2 | Codemagic Webhooks 頁「No deliveries yet」 |
| 自動 provisioning（乾淨 runner，經 API 建立憑證＋profile） | **真實雲端實跑通過** | build #1 簽章步驟 3 秒成功；Apple Developer 出現新的 Distribution 憑證（API 建立，2027/10/06 到期，目前 3/3） |
| 預檢、品質檢查（analyze／test／發布工具測試） | **真實雲端實跑通過** | build #1：預檢 6 秒、品質檢查 46 秒 |
| 外部測試：What to Test、加群組、送審（不重送） | **真實實跑：已送審**（`WAITING_FOR_BETA_REVIEW`）；審查結果待 Apple | 同上 Actions run 的 `external` 欄位；模擬：`ExternalTest.*` |
| 外部審查結果通知（每小時排程） | 已配置；排程空跑實跑通過；真實結果待審查完成 | `testflight-external-watch.yml` |
| 外部測試資料不齊 → blocked、不重送 | 模擬通過 | `test_missing_test_info_is_blocked_and_not_retried` |
| 外部問題不蓋掉內測 ready | 模擬通過 | `test_external_problem_does_not_override_internal_ready` |
| 審查結果通知（通過／被拒／逾時，去重） | 模擬通過 | `test_watch_events` |
| 外部通知不含公開連結 | 模擬通過 | `test_external_notice_never_contains_public_link` |
| 品質檢查失敗 → 不上傳、通知 CI 失敗 | 已配置；通知文字模擬通過 | `test_ci_failure_is_not_reported_as_apple_failure` |
| Apple 處理失敗／過期 → failed | 模擬通過 | `test_apple_rejection_is_failed`、`test_expired_build_is_failed` |
| 401/403 不重試；429/5xx 有限退避 | 模擬通過 | `ClientTest.*` |
| 逾時 → unknown；找不到 build → unknown | 模擬通過 | `test_deadline_*`、`test_missing_build_*` |
| Codemagic 回報腳本 payload／錯誤訊息 | 本機模擬通過（假 curl：204／401／503） | 2026-10-06 |
| 通知真的寄到信箱 | issue 留言已送出（@擁有者）；**收件未確認** | issue #1 |
| Shorebird release（基底版）→ TestFlight 內測 → 通知 | **真實雲端實跑通過、Apple API 確認、通知已送出** | Codemagic build #2（tag `v1.0.0` @ `5892f27`）→ 1.0.0 (2)，Apple build `69696aab-7f82-4a05-b6f1-023b1c187ae5` `IN_BETA_TESTING`；Shorebird Console 顯示 release 1.0.0+2 |
| 外部送審遇到同版本已有 build 在審查（`ANOTHER_BUILD_IN_REVIEW`） | 真實發生（build 2）→ blocked；每小時排程在審查結束後自動補送最新 build（模擬通過，空跑實跑通過，**補送未實跑**） | `PendingSubmissionTest.*`；watch run 2026-10-06 02:00 UTC |
| Shorebird patch → 通知 | 已配置；patch 輸出擷取與通知文字模擬通過，**未實跑** | `test_patch_*`、本機模擬 patch log |
| build 取消／逾時 | **不支援** | — |

待補：擁有者確認收到通知信；換好 token 後一次 tag 觸發的完整自動流程；Beta 審查結果與外部通知。
