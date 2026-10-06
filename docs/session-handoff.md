# Omi 專案現況（2026-10-06 交接）

> 長期規則與指令看 `CLAUDE.md`；這份是當下進度的快照。

## App 是什麼
- **Omi～快樂的 Σίσυφος**：Discord 社群「Omi 新計劃」的 100 天好習慣挑戰 App（2026-10-09 → 2027-01-16）。規則來自「The Rules」：Move／Nourish／Learn／Recover／Reflect，Nourish 3 選 2 和作息時間可以個人化。
- Flutter 3.47.5（PATH 上的 flutter 壞了，用 `C:\Users\USER\.cache\flutter-sdks\flutter-3.47.5\bin`）。
- **目前是 Demo**：資料只存在本機（shared_preferences），隊友是示範資料，挑戰沒開始時預設假裝在第 30 天；挑戰日期寫死在 `lib/models/challenge.dart`。
- 已有的體驗：
  - 設定是一步步的教學；首頁是挑戰進度 HUD、每一項各一條能量槽、每日打卡、隊友。
  - 打卡頁是機械鍵盤鍵帽（按下＝完成），Reflect 也在這頁寫。
  - 隊友卡片可以集氣／慶祝。
  - Android 有桌面小工具（iOS 沒有）。
- 設計語言：像素風（黑色缺角邊框、硬陰影、分段能量條、自繪 5×7 字型、黃色 PixelTag）。
- 待討論的點子在 `TODO.md`（實體獎章、願望撲滿等）。

## Repo 與發布
- GitHub `e2755699/omi_app`（公開，但 LICENSE 是 All rights reserved）。
- 網頁版 Demo：https://e2755699.github.io/omi_app/ ，每次 push master 約 2 分鐘自動部署；隱私權政策在 `/privacy/`。
- **iOS（Codemagic → TestFlight）**，細節見 `docs/release/ios-release.md`：
  - 怎麼發：只改 Dart 打 `patch-<數字>`（Shorebird code push）；動到原生／資源檔／Info.plist 改 pubspec 版本後打 `v<版本>`（TestFlight）。`-betaN` 已不用。
  - 流程：Codemagic 預檢 → analyze／test → 透過 API 自動簽章 → 打包上傳 → 通知 GitHub Actions → 用 API 查驗內測可用 → 自動送外部測試 → 在 issue #1「📦 iOS 發布通知」留言。外部審查結果由每小時一次的排程通知。
  - 現況：**1.0.0 (1) 已經可以內測**（擁有者已收到邀請）；**外部測試已送 Beta 審查，等 Apple 結果**（10/6 08:52 送出）。通過後公開連結在 App Store Connect → TestFlight →「Omi 夥伴」群組，不要貼到公開 repo。
  - 帳號：
    - Bundle ID `com.jacklope.omiApp`
    - App Store Connect 的 App 名稱「Omi～快樂的 Σίσυφος」
    - 內部群組「Omi Internal」、外部群組「Omi 夥伴」
    - Omi 專屬 API key `omi-ci`；`.p8` 和簽章私鑰在擁有者電腦的 `~/.omi-release/`，不在 repo 裡
  - 秘密要更新時，由擁有者執行 `python tool/release/setup_secrets.py --issuer-id … --key-id …`（token 用剪貼簿讀，會先驗證）。
- 商店資料草稿、正式送審的阻擋項：`docs/release/app-store-listing.md`。

## 還沒完成
1. **Codemagic 存的 GitHub token 無效**：發版最後一步通知 GitHub 會 401，目前要手動補跑 `gh workflow run ios-release-report.yml …`。這把 token 也曾出現在截圖裡。→ 擁有者到 GitHub 按 Regenerate，再重跑 `setup_secrets.py`。
2. 等 Beta 審查通過 → 把公開連結給 Discord。在那之前，先給大家網頁版 Demo。
3. **Shorebird：CI 已改好、還沒啟用**（2026-10-06，擁有者決定要用）。待擁有者：
   - 用 Google 登入 https://console.shorebird.dev（停在 Google 授權頁時按「繼續」）
   - Account → API Keys → Create（名稱 `omi-codemagic`、1 年、Full access）
   - 在 GitHub 的 `omi-codemagic-dispatch` token 按 Regenerate
   - 執行 `python tool/release/setup_secrets.py --only github,shorebird`：會讀剪貼簿裡的 Codemagic token、GitHub token、Shorebird key，在 Shorebird 建「Omi」App，並寫出 `shorebird.yaml`

   之後由 Claude：commit `shorebird.yaml`、在 `pubspec.yaml` 的 flutter assets 加 `- shorebird.yaml`（兩個要同一個 commit，不然網頁版 build 會壞），再打 `v1.0.0` 產生基底版 1.0.0 (2)。接著測一次 `patch-1`，把結果寫進驗收矩陣。Shorebird 有 Flutter 3.47.5（`flutter_release/3.47.5`）。
4. Google Play：擁有者還沒買開發者帳號，買了再做。
5. 正式上架 App Store 前要處理：
   - 拿掉 Demo 內容、挑戰日期不要寫死（審查指南 2.2）
   - 像素風 App 圖示（現在是 Flutter 預設圖示）
   - 支援頁
   - 價格／付費協議／歐盟 DSA
   - iPad 要不要支援
   - 截圖
   - 送審要擁有者確認

## 擁有者的工作習慣
- 用繁體中文溝通。每一輪改完都要 build 一個 APK。
- 能自己做的就直接做；需要擁有者本人的步驟（登入、產生秘密、個資、商業決定），要先把網頁開到那一頁、一步一步帶。帳號頁面優先用 Claude in Chrome（他平常的 Chrome 已經登入）。
- push 到公開 repo 前先確認。不要合併 worktree／feature branch 到 master。
- CI／發布相關的工作，照他的 Codex skill `C:\Users\USER\.codex\skills\automate-release-ci\` 做。
