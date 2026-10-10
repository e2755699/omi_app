# Android APK 與下載頁

## 入口與範圍

- 社群固定網址：<https://e2755699.github.io/omi_app/download/>（本次變更合併到 master、Pages 部署成功後可用）。
- 網頁版繼續在 <https://e2755699.github.io/omi_app/>。
- HTML：`web/download/index.html`；Flutter web 建置會複製到 `build/web/download/index.html`，現有 Pages workflow 部署整個 `build/web`。
- APK 放 GitHub Releases，不進 Git，也不放 Pages artifact。
- 本次只建立下載入口並發布一份本機測試 APK；Android 全自動建置發布尚未接通。iOS 繼續使用原有 Codemagic 流程。

## 首次版本

| 項目 | 值 |
| --- | --- |
| 來源 | 公開 master：`fca3c3fc95317a873a380e8c05c96916474d9ca6` |
| 版本／versionCode | 1.1.0／2（命令列覆寫 build 號；不改 iOS 版本） |
| Application ID | `com.omi.omi_app` |
| tag | `android-v1.1.0-2`；刻意不使用 iOS 的 `v*` 或 `patch-*` |
| asset | `omi-android.apk`、`SHA256SUMS.txt` |
| 簽章 | 沿用這台 Windows 的既有 debug signing config；適用目前社群測試 |
| 大小／最低系統 | 55,842,817 bytes（53.3 MiB）／Android 7.0（API 24） |
| APK SHA-256 | `3a57996c58e22a7a5b036f4a06b044ee6c22984c35dc2912254ea18ee3af724d` |
| 公開簽章憑證 SHA-256 | `74c189f5114f8aa9ce3e457881e859ff3966258fab8016e22bdf43e2a906f4f7` |

目前 master 的隊友仍為示範資料，打卡與照片保存在裝置上；未包含另一分支尚未合併的後端。

## 日常更新

1. 在來源 commit 的乾淨 checkout 執行 `flutter pub get`、`flutter analyze`、`flutter test`。
2. **同一台簽章電腦**執行 `flutter build apk --release --build-number <比前次大的數字>`。來源、版本與 build 號記入 release notes。
3. 使用 Android SDK 的 `aapt dump badging` 核對 application ID、versionCode、minSdk；`apksigner verify --print-certs` 驗證 APK 並比對前一版簽章憑證指紋。
4. 將 APK 複製為 `omi-android.apk`，產生 `SHA256SUMS.txt`。先建立 draft release 並上傳附件，核对完整後才公開；公開後重新下載，核對 SHA-256。
5. 修改 `web/download/index.html` 的版本、日期、大小、更新內容，以及兩個指向指定 Android tag 的連結。合併到 master 後由既有 Pages workflow 部署。先發布 APK，再部署頁面，避免下載按鈕指向不存在的檔案。
6. 驗證公開 `/download/` 與 APK 連結，再將同一個下載頁網址交給社群。

下載按鈕使用指定 tag 的 asset URL。不要改成全 repository 的 `releases/latest/download/...`：日後 iOS Release 成為 latest 時可能沒有 APK。GitHub 官方格式見 [Linking to releases](https://docs.github.com/en/repositories/releasing-projects-on-github/linking-to-releases)。

若上傳中斷，先查 `gh release view <tag> --json assets,isDraft`，核對已存在的附件，避免直接覆寫公開 APK 或移動 tag。Pages 失敗可從 Actions 重跑既有部署，不用重新打包 APK。查驗網路失敗屬於「無法確認」，不能宣稱下載可用。

## 簽章與自動化限制

現有 Gradle release 使用 debug signing config。不要直接搬到每次重新建立 debug key 的雲端 runner：簽章不同會讓已安裝使用者無法覆蓋更新。後續自動化需先由擁有者將固定簽章與密碼放入 CI secret store，再接 GitHub Actions 或既有 Codemagic 的 Android 工作。

這次不讀取、輸出或搬移簽章私鑰，也不建立新的簽章。只用 APK 裡的公開憑證核對。使用者更新時先保留舊 App；解除安裝會丟失本機資料。正式簽章與 Google Play 上架另行處理。

## 驗收（2026-10-10，Asia/Taipei）

| 項目 | 狀態／證據 |
| --- | --- |
| Flutter analyze | 通過，0 issue |
| Flutter test | 13 項通過 |
| 桌面／390 px 手機下載頁 | 瀏覽器實際渲染通過 |
| APK 建置、版本、簽章 | 本機實跑通過；`aapt` 確認 1.1.0 (2)、minSdk 24；`apksigner verify --print-certs` 通過且與原工作目錄 APK 的簽章一致 |
| 雲端附件與 SHA-256 | 真實實跑通過；Release ID `408496127`，APK asset ID `626685527`，GitHub API digest 與未登入重新下載的 SHA-256 均與本機一致 |
| 公開 Release | [android-v1.1.0-2](https://github.com/e2755699/omi_app/releases/tag/android-v1.1.0-2)，標為 prerelease；tag 指向上述來源 commit |
| Flutter web 打包 | 本機 release build 通過，下載頁包含於 `build/web/download/index.html` |
| Pages 正式部署與公開下載頁 | 待 master 合併與部署 |
| Android 真機乾淨安裝、覆蓋安裝、保留資料 | 未驗；簽章一致不代表已完成真機驗收 |
| APK 無人值守發布與通知 | 未實作；本次不新增通知管道 |

Pages 仍用現有標準 GitHub Actions runner；APK 本次在本機打包，未新增雲端服務或付費 runner。未做整體帳戶費用保證。
