# Omi～快樂的 Σίσυφος

100 天挑戰打卡 App：把每天的好習慣變成看得見的能量槽，和隊友一起集氣、慶祝。

> 目前是 **Demo 版**，用來討論需求。正式版上架後，這個 Demo 會下架。

- **Demo：** https://e2755699.github.io/omi_app/
- 平台：Android、iOS、Web（Flutter）

## 開發

需要 Flutter 3.47.5。

```bash
flutter pub get
flutter test
flutter run
```

推到 `master` 後，GitHub Actions 會自動 build 網頁版並部署到 GitHub Pages（見 `.github/workflows/pages.yml`）。

## 發布 iOS（TestFlight）

改好 `pubspec.yaml` 的版本後推 tag `v<版本>`（例如 `git push origin v1.0.0`）：Codemagic 建置、簽章、上傳 → GitHub Actions 查驗 TestFlight 內測可用 → 在「📦 iOS 發布通知」issue 留言通知。

- 流程、需要的秘密、排錯：[docs/release/ios-release.md](docs/release/ios-release.md)
- 商店資料與送審準備：[docs/release/app-store-listing.md](docs/release/app-store-listing.md)

## 授權

Copyright (c) 2026 Dustin Liu. **All rights reserved.**

這個 repo 公開可見，但**不是開放原始碼**。未經書面同意，不得複製、修改、散布或用於任何產品。詳見 [LICENSE](LICENSE)。
