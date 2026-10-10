# Omi～快樂的 Σίσυφος

The Omi Challenge（84 天刻意生活）的打卡 App。薛西弗斯每天把石頭推上山；Omi 想說的是，每天再推一次，本身就是一種快樂。

把每天的好習慣變成看得見的能量槽，按下機械鍵盤的鍵帽就是打卡，和隊友一起集氣、慶祝。

> 目前是 **開發／測試版**：可不登入使用，訪客紀錄只存在裝置上，也看不到其他玩家。Discord 已啟用，Chrome 真實登入、群組建立、打卡／私人心得同步及照片上傳已驗證；手機與雙裝置驗收仍待完成。預設建置仍是本機模式，TestFlight 1.2.0 與帶開發設定的 APK 可連雲端。詳見 [後端規劃](docs/backend/supabase-plan.md)。

- **網頁版 Demo**：https://e2755699.github.io/omi_app/ （每次 push `master` 自動更新）
- **iOS**：TestFlight **1.2.0 (4)** 內測已可用，外部 Beta 審查中（[查驗紀錄](docs/release/ios-release.md)）
- **Android**：[APK 下載頁](https://e2755699.github.io/omi_app/download/)；社群測試版，Google Play 尚未上架
- **挑戰期間**：主辦第一輪 2026-10-09 → 2026-12-31（84 天）。App 裡每個人從開始用的那天算 Day 1（教學可選今天或下週一），結束固定 12/31。規則與 FAQ：[The Omi Challenge Wiki](https://app.notion.com/p/The-Omi-Challenge-Wiki-3bb548081c1880f18874fce64262ecb5)；需求整理：[docs/PRD.md](docs/PRD.md)

## 挑戰規則（The Rules）

| 面向 | 每天／每週要做的事 |
| --- | --- |
| **Move** | 每週有氧 150 分鐘＋肌力 2 次 |
| **Nourish** | 不喝酒，再從「蔬果、蛋白質 1.2 g/kg、喝水 30 ml/kg」三選至少二（整個挑戰固定） |
| **Learn** | 每天閱讀 20 分鐘 |
| **Recover** | 8 小時睡眠機會、固定就寢／起床時間（±60 分鐘） |
| **Reflect** | 每天寫一句「今天我注意到的事」；每週回顧 3 題（第三題就是下週計畫）、一張照片 |

Nourish 的三選至少二和作息時間在開跑前決定、之後固定。

## 功能

- **設定教學**：照主辦的 Challenge Setup 表一步一步帶：決定加入與開跑日、三選至少二、要讀的書、作息、Week 1 計畫。
- **首頁**：挑戰進度 HUD（達成幾天）→ 每一項各一條能量槽 → 每日打卡 → 本週任務 → 隊友。
- **每日打卡**：一排機械鍵盤鍵帽，按下＝完成，再寫一句今天注意到的事。
- **本週任務**：回顧三題＋每週一張照片，照片排成照片牆。
- **登入**：教學最後一步提供 Discord 登入與「先在本機使用」；首頁可再開啟帳號頁。Discord provider 已啟用，登入不會自動上傳本機紀錄。
- **隊友**：本機模式不顯示其他玩家；完成 Discord 設定的開發建置可建立／加入群組、查看隊友進度與加油。
- **桌面小工具（Android／iOS）**：本機模式可按鍵帽打卡（iOS 需要 17 以上）。雲端模式目前引導開啟 App 記錄與同步，背景寫入及跨裝置更新尚未完成。
- **像素風**：黑色缺角邊框、硬陰影、分段能量條、自繪 5×7 字型、有按鈕感的鍵帽。

## 開發

需要 **Flutter 3.47.5**。

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

```
lib/
  main.dart / app.dart     進入點、主題、路由
  models/                  挑戰、規則（The Rules）、進度、打卡紀錄
  data/                    ChallengeStore（本機儲存）、雲端同步、桌面小工具橋接
  screens/                 標題、設定教學、首頁、每日打卡、本週任務、照片牆、項目詳情、隊友、iOS 小工具預覽
  widgets/                 像素 UI 元件、鍵帽、能量槽、字型、隊友卡片
android/                   含桌面小工具（CheerWidgetProvider.kt）
ios/CheerWidget/            iOS 桌面小工具（WidgetKit，SwiftUI）；ios/Runner/ToggleIntent.swift 是鍵帽按下時的 AppIntent
ios/                       Bundle ID com.jacklope.omiApp
web/                       網頁版；web/privacy/ 是隱私權政策頁
tool/release/              iOS 發布工具（預檢、查驗、通知、設定秘密）
docs/release/              發布流程、商店資料、送審準備
```

## 發布

| 情況 | 做法 |
| --- | --- |
| 網頁版 | push 到 `master` 就會自動部署（`.github/workflows/pages.yml`） |
| Android APK | tag `v*` → GitHub Actions 建 APK 放 draft release（需簽章 secret）→ 核對後公開、更新 `/download/`；見 [Android 發布](docs/release/android-release.md) |
| iOS：只改 Dart 程式碼 | 打 tag `patch-<數字>` → Shorebird code push，夥伴重開 App 就更新 |
| iOS：動到原生程式／資源檔／Info.plist | 改 `pubspec.yaml` 的版本後打 tag `v<版本>` → TestFlight（內測＋外部測試） |

```bash
git tag patch-3 && git push origin patch-3
```

每次發布的結果都會留言在 GitHub issue「📦 iOS 發布通知」。流程、秘密、排錯見 [docs/release/ios-release.md](docs/release/ios-release.md)；商店資料與正式送審準備見 [docs/release/app-store-listing.md](docs/release/app-store-listing.md)。

## 隱私

預設本機建置不需要帳號，紀錄和照片保留在裝置上。現行公開版詳見 [隱私權政策](https://e2755699.github.io/omi_app/privacy/)。

TestFlight 1.2.0 起與帶 Supabase 設定的開發建置可透過 Discord 登入；選擇群組後，該空間的紀錄會同步至 Supabase。心得與體重只給本人看，群組成員可讀進度及已分享照片。原本的訪客資料只有另外確認匯入才上傳。隱私政策已補充雲端資料；帳號刪除、真機與雙裝置驗收尚未完成。Pages 仍是本機模式。

## 授權

Copyright (c) 2026 Dustin Liu. **All rights reserved.**

這個 repo 公開可見，但**不是開放原始碼**。未經書面同意，不得複製、修改、散布或用於任何產品。詳見 [LICENSE](LICENSE)。
