# iOS 發布（Codemagic → TestFlight 內測＋外部測試）

> 狀態（2026-10-06）：**已配置，尚未真實實跑**。帳號設定進度見下方「設定進度」；跑過第一次後更新「驗收矩陣」。
> 商店資料、TestFlight 測試資訊與正式送審準備見 [app-store-listing.md](app-store-listing.md)。

## 怎麼發布（單一入口）

```bash
# 1. pubspec.yaml 的 version 改成要發的版本（build 號不用管，CI 會配）
# 2. commit 後打 tag，tag 一定要是 v<版本>
git tag v1.0.0
git push origin v1.0.0
```

推 tag 之後全自動：Codemagic 建置上傳 → GitHub Actions 查驗內測可用 → 送外部測試（Beta 審查）→ 「📦 iOS 發布通知」issue 留言（GitHub 寄信給你）→ 審查有結果時再留言一次。

也可以在 Codemagic 手動 Start new build（workflow `iOS → TestFlight`、任意 branch），版本照 pubspec。

**不會**自動送 App Store 正式審查或公開上架。

## 資料流

```
git push tag v1.0.0
  │
  ▼
Codemagic（mac_mini_m2，codemagic.yaml）
  1 預檢     tool/release/asc.py preflight：API 授權、Bundle ID、App、內部群組、tag=版本、配 build 號；
             外部群組沒有就建（開公開連結），測試資訊缺什麼只發警告
  2 品質檢查 flutter analyze / flutter test / 發布工具測試
  3 簽章     app-store-connect fetch-signing-files --create（沿用既有 Distribution 憑證，沒有才建）
  4 建置     flutter build ipa
  5 上傳     app-store-connect publish（只上傳，不占 Mac 等 Apple 處理）
  └ publishing script（成功失敗都跑）→ workflow_dispatch ios-release-report.yml（ref=master）
  │
  ▼
GitHub Actions：ios-release-report.yml（ubuntu）
  - asc.py verify --external：有限退避查 Apple（30 秒到 5 分鐘一次，最多 90 分鐘）
      內測成功條件：指定 App＋版本＋build、processingState=VALID、未過期、
                   internalBuildState=IN_BETA_TESTING、「Omi Internal」包含此 build
      內測可用後：設定 What to Test → 加入「Omi 夥伴」→ 送 Beta App Review（已送過不重送）
  - report.py 留言（@擁有者 → GitHub 寄信）；內測不是 ready 時 run 失敗 → 另一封 Actions 失敗信
  │
  ▼
GitHub Actions：testflight-external-watch.yml（每小時）
  - asc.py external-watch：最近 build 的 externalBuildState
      IN_BETA_TESTING / BETA_APPROVED → 🎉 外部測試可用；BETA_REJECTED → ❌；送審超過 72 小時 → ❓
  - 同一結果只留言一次；公開連結不貼在公開 repo
```

內測結果：`ready`（API 證實可用）、`failed`（Apple 明確拒絕或 CI 失敗沒上傳）、`unknown`（授權、網路、逾時、找不到 build）。外部測試另外標示：`submitted`、`ready`、`failed`、`blocked`（多半是測試資訊沒填齊，不會重送）。外部有問題不會蓋掉內測結果。

## 版本與 build 號

- 版本 ＝ `pubspec.yaml` 的 `x.y.z`；用 tag 觸發時 tag 必須是 `v<x.y.z>`，不符就在預檢擋下。
- build 號 ＝ max(Apple 上這個 App 用過的最大 build 號 + 1, Codemagic `$BUILD_NUMBER`)。
- Codemagic 免費方案一次只跑一個 build，不會撞號。

## 簽章模式

**自動 provisioning（API）**：Codemagic CLI 用 API key 找符合 `CERTIFICATE_PRIVATE_KEY` 的 Apple Distribution 憑證和 App Store profile，沒有就建立。

- 同一個 Apple Team 已有 2 張 Distribution 憑證（2027/09、2027/10 到期，都是黃絲帶 CI 建的）。**沿用黃絲帶的 `CERTIFICATE_PRIVATE_KEY`** 就會直接用現有憑證；換新私鑰會再建一張，Apple 對數量有上限。
- API key 也沿用既有團隊金鑰（`yellow-ribbon-ci` 或 `codemagic`，都是 App 管理權限），不必新建。
- 不會撤銷任何現有憑證。

## 秘密與設定位置（不記錄值）

| 名稱 | 放在哪 | 內容 |
| --- | --- | --- |
| `APP_STORE_CONNECT_ISSUER_ID` | Codemagic 群組 `app_store_connect`＋GitHub Actions secrets | Issuer ID |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | 同上 | 沿用的 key 的 Key ID |
| `APP_STORE_CONNECT_PRIVATE_KEY` | 同上 | 該 key 的 `.p8` 全文 |
| `CERTIFICATE_PRIVATE_KEY` | Codemagic 群組 `app_store_connect` | 黃絲帶用的同一把簽章私鑰 PEM |
| `GITHUB_DISPATCH_TOKEN` | Codemagic 群組 `github_report` | fine-grained token，只限 `e2755699/omi_app`，Actions: Read and write |

Codemagic 個人帳號的變數群組只屬於單一 App，而且 Secret 值讀不回，所以不能直接引用黃絲帶的 `yellow_ribbon_ci`，要在 omi_app 重新放一次（值相同）。

非秘密設定集中在 [tool/release/config.json](../../tool/release/config.json)：Bundle ID、內部／外部群組名稱、What to Test 文字。改 Bundle ID 時 Xcode 專案也要一起改，預檢會比對。

## 設定進度

| 項目 | 狀態 |
| --- | --- |
| Bundle ID `com.jacklope.omiApp` | ✅ 2026-10-06 已註冊（Apple Developer） |
| App Store Connect App「Omi～快樂的 Σίσυφος」 | ✅ 已建立，Apple ID `6819375327`，SKU `omi-ios` |
| 內部群組「Omi Internal」 | ✅ 已建立，自動分發開啟，帳號持有人已加入 |
| 外部群組「Omi 夥伴」 | 第一次預檢自動建立（開公開連結） |
| Codemagic App | ✅ 已加入（app id `6ac3e6dec18dba32d6229cd5`） |
| 隱私權政策頁 | ✅ `web/privacy/` → https://e2755699.github.io/omi_app/privacy/ |
| TestFlight 測試資訊（描述、隱私網址、審查備註） | 代填；回饋信箱、審查聯絡人（姓名／電話／信箱）待擁有者填 |
| Codemagic 變數群組、GitHub secrets、GitHub token | 待擁有者（秘密只能本人放） |

## 排錯與重試

| 現象 | 處理 |
| --- | --- |
| 預檢 `授權失敗` / 401 / 403 | key 被撤銷、權限不夠或秘密貼錯（`.p8` 要含 BEGIN/END 行）。修好後重跑 |
| 預檢 `tag 和 pubspec 版本不一致` | 改 pubspec 後打新 tag；不要移動已推送的 tag |
| 簽章失敗（憑證數量上限） | 多半是 `CERTIFICATE_PRIVATE_KEY` 不是黃絲帶那把。換回同一把；CI 不會自動撤銷憑證 |
| 上傳失敗 | 報告會查 Apple 20 分鐘看是否其實已收到；不要用同一個 build 號重傳，重跑會配新號 |
| 通知 `unknown: timeout_*` | Apple 處理太久。GitHub Actions → iOS release report → Run workflow，填 `uploaded`、版本、build 號補查 |
| 外部測試 `blocked` | TestFlight → 測試資訊 補齊（錯誤訊息會寫缺什麼），再補查一次（同上 Run workflow）；已送審的不會重送 |
| Beta 審查被拒 | 看 App Store Connect 的退件說明，修正後發新版本 |
| 沒收到任何通知 | Codemagic build 被取消／逾時（不跑回報腳本），或 `GITHUB_DISPATCH_TOKEN` 失效 → 看 Codemagic build log 最後一步 |

## 輪替

- **API key**：建新 key → 更新 Codemagic＋GitHub 的三個變數 → 跑一次確認 → 撤銷舊 key（黃絲帶也在用的話兩邊一起換）。
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
| 正常發布（tag → 內測可用 → 通知） | 已配置；查驗邏輯模擬通過 | `tool/release/test_release.py`（28 項，2026-10-06 本機） |
| 自動 provisioning（乾淨 runner，沿用既有憑證） | 已配置，**未實跑** | — |
| 外部測試：What to Test、加群組、送審（不重送） | 模擬通過 | `ExternalTest.*` |
| 外部測試資料不齊 → blocked、不重送 | 模擬通過 | `test_missing_test_info_is_blocked_and_not_retried` |
| 外部問題不蓋掉內測 ready | 模擬通過 | `test_external_problem_does_not_override_internal_ready` |
| 審查結果通知（通過／被拒／逾時，去重） | 模擬通過 | `test_watch_events` |
| 外部通知不含公開連結 | 模擬通過 | `test_external_notice_never_contains_public_link` |
| 品質檢查失敗 → 不上傳、通知 CI 失敗 | 已配置；通知文字模擬通過 | `test_ci_failure_is_not_reported_as_apple_failure` |
| Apple 處理失敗／過期 → failed | 模擬通過 | `test_apple_rejection_is_failed`、`test_expired_build_is_failed` |
| 401/403 不重試；429/5xx 有限退避 | 模擬通過 | `ClientTest.*` |
| 逾時 → unknown；找不到 build → unknown | 模擬通過 | `test_deadline_*`、`test_missing_build_*` |
| Codemagic 回報腳本 payload | 本機模擬通過（假 curl） | 2026-10-06 |
| 通知真的寄到信箱 | 未驗 | — |
| build 取消／逾時 | **不支援** | — |

第一次真實發布後補上：Codemagic build 連結、版本／build、Apple build ID、Actions run、issue 留言、是否收到信、Beta 審查結果。
