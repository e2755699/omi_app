# Omi Supabase

開發專案：[omi-app-dev](https://supabase.com/dashboard/project/iprkeejfleqyrqvliqya)，東京區。建立時費用查詢為 US$0／月。

## 目前完成

- `migrations/` 已依順序套用到開發專案，檔名版本對齊遠端 migration history（UTC）。
- 8 張業務資料表與 1 張私人邀請表，全部啟用 RLS。
- 群組建立、邀請碼輪替、加入、設定、離組、加油 RPC。
- 私人照片 bucket `weekly-photos`，5 MiB、JPEG／PNG／WebP。
- Supabase Security Advisor 無警告（2026-10-10 查驗）。Performance Advisor 只有新建索引尚未使用的 INFO。

## 尚未完成

Discord OAuth provider 已啟用，Chrome 真實登入、教學草稿返回、群組建立、打卡／私人心得同步及重新載入保留資料已通過。照片上傳亦已通過：私人 Storage 收到 PNG，資料庫 metadata 正確，App 重開可顯示本機快取。Android／iOS、雙裝置同步、另一裝置下載照片、照片中斷重試與更換移除仍待實測。

雲端模式的小工具目前引導開啟 App，避免背景寫入另一份訪客紀錄。帳號刪除、雲端隱私政策、群組照片牆、照片孤兒檔清理及真機驗收仍未完成，這是開發版，尚未公開部署。

## 驗證

本機測試需要 Node.js 與 `@electric-sql/pglite`。可安裝在暫存資料夾，不需要啟動完整 Docker stack：

```powershell
npm.cmd install --prefix "$env:TEMP\omi-supabase-verify" --no-audit --no-fund @electric-sql/pglite@0.5.8
node tool/backend/test-database.mjs "$env:TEMP\omi-supabase-verify\node_modules\@electric-sql\pglite\dist\index.js"
```

實際執行 Postgres 的 migration、函數、trigger、資料限制與 RLS；Auth／Storage 的基礎 schema 為測試替身，不能取代雲端整合驗證。

目前 51 項資料庫斷言、37 項 Flutter 測試通過。`test/sync_test.dart` 使用真正 SQLite，`test/cloud_repository_test.dart` 驗證 HTTP 分頁與版本條件，`test/cloud_workspace_test.dart` 驗證匯入、私人心得與隊友日期，`test/account_controller_test.dart` 驗證 OAuth 回呼辨識與精確返回網址。Chrome 已執行 `tool/backend/web_storage_probe.dart`，重新載入確認 IndexedDB 保留資料。

```powershell
flutter test
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5187 -t tool/backend/web_storage_probe.dart
```

Web 需一起部署 `web/sqlite3.wasm` 與 `web/sqflite_sw.js`；這些是 `sqflite_common_ffi_web:setup` 產物。測試 probe 使用獨立資料庫，不連接 Supabase。

`tests/cloud_smoke.sql` 已在雲端開發專案通過：測試用帳號與資料在同一交易裡建立，結束全部 rollback。它驗證真實 auth.users 外鍵、同組／跨組／離組隔離、心得私密、版本衝突、重複加油與匿名拒絕。它不驗證 Discord、Storage HTTP、Realtime 或 App 同步。

## Flutter 啟動

一般 `flutter run` 為本機模式，教學最後可以跳過登入。連接已配置的開發專案：

```powershell
flutter run --dart-define-from-file=config/supabase.dev.json
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5173 --dart-define-from-file=config/supabase.dev.json
flutter build apk --release --dart-define-from-file=config/supabase.dev.json
```

設定檔只有公開的 URL 與 publishable key，不含管理權限密鑰。不要把資料庫密碼、Discord Client Secret 或 Supabase secret key 放進這個檔案。

Discord OAuth 回呼：`https://iprkeejfleqyrqvliqya.supabase.co/auth/v1/callback`。
Supabase 已保存的 redirect allow list：手機 `omiapp://auth-callback`、本機 `http://127.0.0.1:5173/`；開發 Site URL 為後者。`https://e2755699.github.io/omi_app/` 尚未加入 allow list，公開雲端部署前另行配置。

詳細範圍、隱私與同步設計見 [後端規劃](../docs/backend/supabase-plan.md)。

TestFlight 1.2.0 起，Codemagic 完整 release 與 patch 使用同一份公開開發設定。Pages 仍維持本機模式。版本／Apple 查驗結果見 [iOS 發布](../docs/release/ios-release.md)；未完成項目見 [TODO](../TODO.md)。
