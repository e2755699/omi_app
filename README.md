# Omi～快樂的 Σίσυφος

The Omi Challenge（84 天刻意生活）的打卡 App。薛西弗斯每天把石頭推上山；Omi 想說的是，每天再推一次，本身就是一種快樂。

把每天的好習慣變成看得見的能量槽，按下機械鍵盤的鍵帽就是打卡，和隊友一起集氣、慶祝。

> 目前是 **Demo／測試版**：資料只存在裝置上，隊友是示範資料。正式上架前會補齊後端（真實隊友進度）與完整功能。

- **網頁版 Demo**：https://e2755699.github.io/omi_app/ （每次 push `master` 自動更新）
- **iOS**：TestFlight 測試中（內測已開放，外部測試送審中）
- **Android**：[APK 下載頁](https://e2755699.github.io/omi_app/download/)（部署後可用）；社群測試版，Google Play 尚未上架
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
- **隊友**：還沒完成的可以「集氣加油」，完成的可以「慶祝」。
- **桌面小工具（Android／iOS）**：顯示收到的加油數，直接在桌面按鍵帽打卡（iOS 需要 17 以上；點標頭或「寫 Reflect」會開啟 App）。
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
  data/                    ChallengeStore（本機儲存）、示範隊友、桌面小工具橋接
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
| Android APK | 同一台簽章電腦打包 → GitHub Releases → 更新 `/download/`；見 [Android 發布](docs/release/android-release.md) |
| iOS：只改 Dart 程式碼 | 打 tag `patch-<數字>` → Shorebird code push，夥伴重開 App 就更新 |
| iOS：動到原生程式／資源檔／Info.plist | 改 `pubspec.yaml` 的版本後打 tag `v<版本>` → TestFlight（內測＋外部測試） |

```bash
git tag patch-3 && git push origin patch-3
```

每次發布的結果都會留言在 GitHub issue「📦 iOS 發布通知」。流程、秘密、排錯見 [docs/release/ios-release.md](docs/release/ios-release.md)；商店資料與正式送審準備見 [docs/release/app-store-listing.md](docs/release/app-store-listing.md)。

## 隱私

App 不需要帳號、不連網、不收集資料，所有紀錄和照片只存在裝置上。詳見 [隱私權政策](https://e2755699.github.io/omi_app/privacy/)。

## 授權

Copyright (c) 2026 Dustin Liu. **All rights reserved.**

這個 repo 公開可見，但**不是開放原始碼**。未經書面同意，不得複製、修改、散布或用於任何產品。詳見 [LICENSE](LICENSE)。
