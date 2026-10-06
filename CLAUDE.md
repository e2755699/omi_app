# CLAUDE.md

給在這個 repo 工作的 Claude 看的說明。使用者（擁有者）用**繁體中文**溝通；UI 文字、程式註解、commit 以外的文件都用繁體中文。

## 專案

**Omi～快樂的 Σίσυφος**：Discord 社群「Omi 新計劃」的 100 天好習慣挑戰 App（2026-10-09 → 2027-01-16），規則見 README。Flutter 跨 Android／iOS／Web。

**目前是 Demo／測試階段**：
- 資料只存在本機（`shared_preferences`），隊友是 `lib/data/demo_data.dart` 的示範資料。
- 挑戰還沒開始時，預設假裝已經進行到第 30 天（`ChallengeStore.load(demoDay: 30)`）。
- 挑戰日期寫死在 `lib/models/challenge.dart`。
- 擁有者說過「先用 Demo 討論需求，完成後再討論架構」：**不要自己加後端或改架構**，等擁有者決定。
- 正式上架 App Store 前要拿掉 Demo 內容（審查指南 2.2），清單在 `docs/release/app-store-listing.md`。

## 指令

這台 Windows 的 PATH 上的 `flutter` 是壞的，請用：

```bash
export PATH="/c/Users/USER/.cache/flutter-sdks/flutter-3.47.5/bin:$PATH"
flutter pub get
flutter analyze          # 必須 0 issue（CI 會擋）
flutter test
flutter build apk --release        # 每一輪改完都要給擁有者一個 APK：build/app/outputs/flutter-apk/app-release.apk
MSYS_NO_PATHCONV=1 flutter build web --release --base-href /omi_app/   # Git Bash 要關路徑轉換
python -m unittest discover -s tool/release -p "test_*.py"             # 發布工具的測試
```

C 槽空間不多（約 6–7 GB），不要隨意安裝大型工具或留下大量 build 產物。

## 程式結構

- `lib/models/`：`Challenge`（日期、第幾天、週次）、`rules.dart`（The Rules 的項目定義）、進度、打卡紀錄、個人設定。
- `lib/data/challenge_store.dart`：唯一的資料來源（`ChangeNotifier`），讀寫本機、計算進度。
- `lib/data/home_widget_bridge.dart`：Android 桌面小工具（`android/.../CheerWidgetProvider.kt`）的資料同步；iOS 沒有小工具。
- `lib/screens/`：`title_screen` → `setup_tutorial`（一步步教學）→ `home_screen`（HUD → 能量槽 → 每日打卡 → 隊友）→ `daily_record_screen`（鍵帽打卡＋Reflect）。
- `lib/widgets/`：像素 UI（`pixel_ui.dart` 的 `PixelColors`、邊框、陰影）、`keycap.dart`、`energy_tile.dart`、`pixel_text.dart`（自繪 5×7 字型）、`responsive.dart`（寬螢幕版面）。

## 設計語言（擁有者喜歡，維持一致）

像素風：黑色缺角邊框、硬陰影、分段能量條、自繪 5×7 字型、黃色 PixelTag 標籤、配色沿用 `PixelColors`（參考 leftsideescalator.com）。打卡就是按機械鍵盤鍵帽。新畫面先用既有元件，不要引入其他風格。

## 發布（細節：`docs/release/ios-release.md`）

- **網頁版**：push `master` → `.github/workflows/pages.yml` 自動部署到 GitHub Pages。
- **iOS 只改 Dart**：打 tag `patch-<數字>` → Codemagic `ios-patch` → Shorebird patch。
- **iOS 動到原生程式、資源檔或 Info.plist**：改 `pubspec.yaml` 版本，打 tag `v<版本>` → Codemagic `ios-testflight`（Shorebird release）→ TestFlight 內測，並自動送外部測試。
- 每次結果都由 `.github/workflows/ios-release-report.yml` 用 App Store Connect API 查驗，再留言在 issue「📦 iOS 發布通知」。外部 Beta 審查結果由每小時的 `testflight-external-watch.yml` 通知。
- 非秘密設定在 `tool/release/config.json`。秘密只放在 Codemagic／GitHub 的 secret store，由擁有者執行 `tool/release/setup_secrets.py` 放入。
- CI／發布相關工作照擁有者的 Codex skill 做：`C:\Users\USER\.codex\skills\automate-release-ci\`，包括驗收矩陣與證據要寫回 `docs/release/ios-release.md`。
- **不會**自動送 App Store 正式審查或公開上架；那一步一定要擁有者確認。

## 工作規則

- **能自己做的就直接做**。只有擁有者本人才能做的步驟（登入、產生或下載秘密、把秘密放進 secret store、個資、永久或商業決定），要先把瀏覽器開到那一頁、一次帶一步、做完自己確認結果。不要丟一份待辦清單給他。帳號頁面優先用 Claude in Chrome（他平常的 Chrome 已登入）。
- **不要碰秘密**：不讀、不搜尋、不輸入 `.p8`、私鑰、token。它們在擁有者電腦的 `~/.omi-release/`，不在 repo 裡。
- **push 到這個公開 repo 前先確認**（擁有者同意過的範圍除外）。
- **不要合併** worktree／feature branch 到 master（`.claude/settings.json` 已禁止 `git merge`）；回報 branch 與 diff，讓擁有者決定。
- 改了發布流程、秘密名稱或驗收結果，同一輪更新 `docs/release/`、README 與 `TODO.md`。
- 想法類需求先記到 `TODO.md`「之後發想」，等擁有者確認再做。
