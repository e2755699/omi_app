# iOS 發布（Codemagic → TestFlight）

> 狀態（2026-10-06）：**已配置，尚未真實實跑**。帳號設定完成、跑過第一次後，更新下面的「驗收矩陣」。
> 商店資料與正式送審準備見 [app-store-listing.md](app-store-listing.md)。

## 怎麼發布（單一入口）

```bash
# 1. pubspec.yaml 的 version 改成要發的版本（build 號不用管，CI 會配）
# 2. commit 後打 tag，tag 一定要是 v<版本>
git tag v1.0.0
git push origin v1.0.0
```

推 tag 之後全自動：Codemagic 建置上傳 → GitHub Actions 查驗 TestFlight 內測可用 → 「📦 iOS 發布通知」issue 留言（GitHub 寄信給你）。

也可以在 Codemagic 手動 Start new build（選 workflow `iOS → TestFlight`、任意 branch）——適合先試流程，版本照 pubspec。

**不會**自動送 App Store 審查、不會發給外部測試者、不會公開上架。

## 資料流

```
git push tag v1.0.0
  │
  ▼
Codemagic（mac_mini_m2，codemagic.yaml）
  1 預檢     tool/release/asc.py preflight：API 授權、Bundle ID（沒有就註冊）、App、內部群組、tag=版本、配 build 號
  2 品質檢查 flutter analyze / flutter test / 發布工具測試
  3 簽章     app-store-connect fetch-signing-files --create（沒有就經 API 建 Distribution 憑證＋profile）
  4 建置     flutter build ipa（版本、build 號由預檢決定）
  5 上傳     app-store-connect publish（只上傳；不 --testflight，不占 Mac 等 Apple 處理）
  └ publishing script（成功失敗都跑）→ workflow_dispatch ios-release-report.yml（ref=master）
  │
  ▼
GitHub Actions（ubuntu，.github/workflows/ios-release-report.yml）
  - outcome=uploaded：tool/release/asc.py verify 有限退避查 Apple（30s→5 分鐘，最多 90 分鐘）
      成功條件：指定 App＋版本＋build、processingState=VALID、未過期、
               internalBuildState=IN_BETA_TESTING、內部群組「Omi Internal」包含此 build
      可用但還沒進群組 → 加進群組一次（不重送）
  - outcome=ci_failed：不查 Apple（上傳步驟失敗例外：查 20 分鐘看是否其實已傳到）
  - tool/release/report.py 留言到 issue（@擁有者 → GitHub 寄信）；結果不是 ready 時 run 失敗 → 另一封 Actions 失敗信
```

結果分三種：`ready`（API 證實內測可用）、`failed`（Apple 明確拒絕／過期，或 CI 失敗沒有上傳）、`unknown`（授權錯誤、網路、逾時、找不到 build）。CI 編譯失敗的留言寫「CI 失敗：<步驟>」，不會寫成 Apple 失敗。

## 版本與 build 號

- 版本（CFBundleShortVersionString）＝ `pubspec.yaml` 的 `x.y.z`；用 tag 觸發時 tag 必須是 `v<x.y.z>`，不符就在預檢擋下。
- build 號（CFBundleVersion）＝ max(Apple 上這個 App 用過的最大 build 號 + 1, Codemagic `$BUILD_NUMBER`)。pubspec 的 `+N` 不使用。
- Codemagic 免費方案一次只跑一個 build，不會兩個 build 搶同一個號；若升級並行，同時推兩個 tag 可能撞號，Apple 會拒收第二個（重推一個新 tag 即可，不要改舊 tag）。

## 簽章模式

**自動 provisioning（API）**：Codemagic CLI 用 App Store Connect API key 找符合 `CERTIFICATE_PRIVATE_KEY` 的 Apple Distribution 憑證和 App Store profile，沒有就建立。每次都是乾淨的 runner，不依賴任何人的 Mac 或 Xcode 登入。

- API key（`.p8`）是「自動化身分」；`CERTIFICATE_PRIVATE_KEY` 是「簽章私鑰」，兩者不同。
- 憑證、profile 一年到期：到期後下一次 build 會用同一把私鑰自動建新的（**未實測**）。Apple 每個 Team 的 Distribution 憑證數量有上限；不要每次換私鑰，否則會一直建新憑證。
- 不會撤銷任何現有憑證。

## 秘密與設定位置（不記錄值）

| 名稱 | 放在哪 | 內容 | 權限／備註 |
| --- | --- | --- | --- |
| `APP_STORE_CONNECT_ISSUER_ID` | Codemagic 群組 `app_store_connect`＋GitHub Actions secrets | Issuer ID | |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | 同上 | Key ID | |
| `APP_STORE_CONNECT_PRIVATE_KEY` | 同上 | `.p8` 全文 | 團隊金鑰，角色 **App Manager**（建憑證／profile、管理 TestFlight 群組） |
| `CERTIFICATE_PRIVATE_KEY` | Codemagic 群組 `app_store_connect` | 簽章用 RSA 2048 私鑰 PEM 全文 | 只在 Codemagic；產生方式見下方 |
| `GITHUB_DISPATCH_TOKEN` | Codemagic 群組 `github_report` | GitHub fine-grained token | 只限 `e2755699/omi_app`，Repository permissions → **Actions: Read and write**；其他全不給 |

Codemagic 的變數都要勾 **Secret**。GitHub secrets 在 repo → Settings → Secrets and variables → Actions。

非秘密設定集中在 [tool/release/config.json](../../tool/release/config.json)（Bundle ID、內部群組名稱、repo）。改 Bundle ID 時 Xcode 專案（`ios/Runner.xcodeproj/project.pbxproj`）也要一起改，預檢會比對兩邊。

## 一次性設定（帳號擁有者操作）

1. **Apple Developer Program** 有效會員（年費）。
2. **App Store Connect API key**：Users and Access → Integrations → App Store Connect API → Team Keys → ＋，角色 App Manager。`.p8` 只能下載一次，存到 repo 以外。
3. **簽章私鑰**（在自己電腦產生，存 repo 以外）：
   ```bash
   openssl genrsa -traditional -out omi_ios_distribution_private_key.pem 2048
   ```
4. **Codemagic**：用 GitHub 登入 → Add application → `e2755699/omi_app` → 選 codemagic.yaml 設定。App settings → Environment variables 建立上表兩個群組（全部勾 Secret）。
5. **GitHub**：建立 fine-grained token（上表權限，建議 1 年到期），放進 Codemagic；Actions secrets 放三個 `APP_STORE_CONNECT_*`。
6. **第一次跑 Codemagic**（手動 Start new build）：預檢會自動註冊 Bundle ID，然後停在「App Store Connect 還沒有這個 App」——這是預期的。
7. **App Store Connect 建 App**（Apple 不開放用 API 建）：我的 App → ＋ 新增 App → iOS、名稱、主要語言、套件 ID 選 `config.json` 的 Bundle ID、SKU（例如 `omi-ios`）。
8. **TestFlight 內部群組**：App → TestFlight → 內部測試 → ＋，名稱 `Omi Internal`（和 config.json 一致），加入自己（測試者必須是 App Store Connect 團隊成員）。
9. 再跑一次 → 應該一路到上傳；約 5–30 分鐘後 issue 收到 ✅ 留言，iPhone 上的 TestFlight App 可安裝。

## 排錯與重試

| 現象 | 處理 |
| --- | --- |
| 預檢 `授權失敗` / 401 / 403 | key 被撤銷、角色不夠或秘密貼錯（`.p8` 要含 BEGIN/END 行）。修好後重跑；不會自動重試 |
| 預檢 `tag 和 pubspec 版本不一致` | 刪掉錯的 tag 前先確認沒有上傳；改 pubspec 後打新 tag |
| 簽章失敗（憑證數量上限） | 到 Apple Developer → Certificates 檢查 Distribution 憑證；需要時由帳號擁有者決定撤銷哪一張（CI 不會自動撤銷） |
| 上傳失敗 | 報告會自動查 Apple 20 分鐘看是否其實已收到。**不要**直接用同一個 build 號重傳；重跑 Codemagic 會配新號 |
| 通知 `unknown: timeout_*` | Apple 處理太久。到 GitHub Actions → iOS release report → Run workflow，填 `uploaded`、版本、build 號補查 |
| 通知 `missing_export_compliance` | Info.plist 的 `ITSAppUsesNonExemptEncryption` 被拿掉或 App 開始用加密；在 App Store Connect 回答出口合規後補查 |
| 沒收到任何通知 | Codemagic build 被取消或逾時（這兩種不會跑回報腳本），或 `GITHUB_DISPATCH_TOKEN` 失效 → 看 Codemagic build log 的最後一步 |

重跑規則：同一個 tag 重跑 Codemagic 是安全的（預檢會配新的 build 號）；不要移動或改寫已推送的 tag。

## 輪替

- **API key**：建新 key → 更新 Codemagic＋GitHub 的三個變數 → 跑一次確認 → 撤銷舊 key。
- **GitHub token**：到期前重建，更新 Codemagic `GITHUB_DISPATCH_TOKEN`。
- **簽章私鑰**：通常不換。換了會建立新憑證（占上限），舊憑證到期前仍可用。

## 成本假設（2026-10-06 查官方頁面）

- Codemagic 個人免費方案：每月 500 分鐘 Mac mini M2、一次 1 個 build、單次上限 120 分鐘；免費方案沒有 Linux 機器。預估一次發布約 15–20 分鐘（未實測）。
- GitHub Actions：repo 公開時標準 runner 免費；改成私有後計入每月免費額度（查驗通常 10–30 分鐘，最多約 100 分鐘）。

## 已知缺口與之後可以升級的

- **沒有用 Apple webhook**：目前沒有可公開接收 HTTPS 的服務，改用有截止時間的 API 查詢。之後有後端時可以訂閱 `BUILD_UPLOAD_STATE_UPDATED` 改為事件觸發。
- Codemagic build **被取消或逾時**不會通知（Codemagic 不跑 publishing script）。
- 通知只有 GitHub 一條管道（issue 留言＋Actions 失敗信）；GitHub 本身故障時沒有備援。

## 驗收矩陣

等級：未實作／已配置／模擬測試通過／真實雲端實跑通過／Apple API 確認／通知已送出／收件確認。

| 情境 | 目前狀態 | 證據 |
| --- | --- | --- |
| 正常發布（tag → TestFlight 內測可用 → 通知） | 已配置；查驗邏輯模擬測試通過 | `tool/release/test_release.py`（19 項，2026-10-06 本機） |
| 自動 provisioning（乾淨 runner 建立／取得憑證＋profile） | 已配置，**未實跑** | — |
| 品質檢查失敗 → 不上傳、通知 CI 失敗 | 已配置；通知文字模擬通過 | `ReportTest.test_ci_failure_is_not_reported_as_apple_failure` |
| Apple 處理失敗 / 過期 → failed | 模擬測試通過 | `test_apple_rejection_is_failed`、`test_expired_build_is_failed` |
| 401/403 → 不重試、unknown | 模擬測試通過 | `test_auth_error_stops_immediately`、`test_401_is_not_retried` |
| 429/5xx → 有限退避 | 模擬測試通過 | `test_503_is_retried_then_succeeds`、`test_503_retries_are_bounded` |
| 長時間未完成 → 截止時間後 unknown | 模擬測試通過 | `test_deadline_gives_unknown_with_last_state` |
| 找不到 build → unknown（不冒充 Apple 失敗） | 模擬測試通過 | `test_missing_build_becomes_unknown_not_failed` |
| 群組已自動分發 → 只查不加 | 模擬測試通過 | `test_auto_distributed_group_is_only_checked` |
| 加入群組失敗 → 不重送 | 模擬測試通過 | `test_failed_assignment_is_not_retried` |
| token 不送到非 Apple 網址 | 模擬測試通過 | `test_refuses_to_send_token_elsewhere` |
| 重跑報告不重複通知 | 已配置（issue 留言用 marker 去重），未實跑 | — |
| Codemagic 回報腳本 payload | 本機模擬通過（假 curl，成功／簽章失敗兩種） | 2026-10-06 |
| 通知真的寄到信箱 | 未驗 | — |
| build 取消／逾時 | **不支援**（見已知缺口） | — |

第一次真實發布後補上：Codemagic build 連結、版本／build、Apple build ID、Actions run、issue 留言連結、是否收到信。
