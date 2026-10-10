# Supabase 後端規劃

2026-10-10：擁有者選定 Supabase，新建專案，採 Discord 登入。登入放在新手教學最後一步；可不登入繼續使用，資料只存本機，也看不到其他玩家。

## 目標與範圍

讓目前的本機 Demo 逐步具備帳號、群組、真實隊友進度、加油與照片同步。保留現有像素風與 ChallengeStore 對畫面的介面。

本次建立資料庫基礎與權限、教學最後一步的可選 Discord 登入、群組介面、離線佇列、衝突處理與本機匯入。Discord provider 已啟用，Chrome 已實際完成登入、返回教學草稿、建立群組、打卡、私人心得與照片上傳；手機與雙裝置驗收仍未完成。雲端資源建立狀態以本文件「部署紀錄」為準。

## 結構

```text
Flutter 畫面（雲端模式）
  → ChallengeStore
  → 本機資料庫 + 待同步操作佇列
  → 同步協調器
  → Supabase Auth（Discord）
  → Postgres（資料 + RLS + 群組 RPC）
  → Storage（私人照片 bucket）
```

第一版一個群組代表一輪挑戰，使用者可以加入多個群組；每組各自保存開跑日與紀錄。群組的結束日是資料，不再寫死在伺服器程式。第一輪資料填 2026-10-09 至 2026-12-31。

Discord 登入只驗證身分，不代表已加入某個 Discord 伺服器；App 的群組資格由邀請碼控制，第一版不需要 Discord Bot。

## 資料與隱私

| 資料表 | 內容 | 可讀範圍 |
| --- | --- | --- |
| profiles | 顯示名稱、emoji 頭像 | 本人與目前同組成員 |
| challenge_groups | 名稱、期間、時區、建立者 | 目前成員與建立者 |
| memberships | 開跑日、Nourish 選項、成員狀態 | 本人與目前同組成員 |
| personal_settings | 體重、作息、書籍、Week 1 計畫 | 僅本人 |
| checkins | 每日項目與數量，不含心得文字 | 本人與目前同組成員 |
| reflections | 每日心得、每週三題 | 僅本人 |
| weekly_photos | 每週照片的 Storage 路徑 | 本人與目前同組成員 |
| cheers | 發送者、接收者、日期、加油／慶祝 | 目前同組成員 |
| private.group_invites | 邀請碼雜湊、期限 | 不提供資料表 API，只透過 RPC 使用 |

Reflect 是否完成由 reflections 的資料庫 trigger 寫成 checkins 的數量，心得文字永遠不進隊友資料表。體重與作息不混在可共享的會員資料列。所有公開 schema 中的資料表開啟 RLS，未登入者沒有業務資料存取權。

照片使用私人 bucket `weekly-photos`，路徑為 `group_id/user_id/week_start/file_name`。只有本人可上傳、刪除；本人可讀取自己的檔案以清理上傳中斷留下的檔案，同組成員只能讀取已登記在 weekly_photos 的照片。App 取得 15 分鐘 signed URL；成員離組後無法再取得其他人的 URL，但已取得的 URL 在過期前仍可能有效，已下載的照片也無法收回。群組照片牆與孤兒檔自動清理尚未實作，目前畫面只呈現自己的照片。

## 日期與一致性

- 日期用 PostgreSQL `date`，不用 UTC 時戳推斷打卡日。
- 第一版 App 群組固定 Asia/Taipei，畫面明示使用台北時間；本機訪客維持裝置日期。這是為了與伺服器一致而採用的暫定選擇，旅行者仍依群組日曆打卡。資料庫 RPC 可指定 IANA 時區，但 App 暫不支援其他時區群組。
- 每日紀錄主鍵為 `(group_id, user_id, period_date, item_id)`；有氧、肌力仍逐日存數量，由現有規則算每週進度。
- 每週回顧與照片用該週的週一，允許第一週的週一早於個人開跑日。
- 不接受未來紀錄或挑戰範圍外紀錄；有氧 0–1440 分鐘／日、肌力 0–100 次／日，其餘鍵帽 0 或 1。
- 取消打卡寫 `amount = 0`，不是刪掉資料列。反思清空寫空文字；照片移除先清除 metadata，Storage 檔案清理待後續補上。
- 加油只能給同組其他目前成員，每個收件人每天一次，日期由伺服器決定。
- 開跑日到了就不可改；Nourish 可改，和目前 App 行為一致。

## 離線同步

訪客保留原有 shared_preferences 儲存。雲端工作區使用 SQLite，每一列同時保存 payload、伺服器版本、本機 revision、dirty 與衝突內容；本機寫入與待同步標記在同一交易完成。手機用 sqflite，Web 用 SQLite WASM／IndexedDB。雲端工作區小工具先引導開啟 App；訪客的小工具仍可直接打卡。

1. 每個帳號與群組使用隔離的本機資料；登出停止同步、清除隊友記憶體與小工具的帳號資料。切換空間關閉舊編輯頁，表單保存前再次核對空間，避免跨帳號寫入。
2. 操作送出「設定為 1／0／指定數量」，不送 toggle 或 increment，重試不會重複累加。
3. 每列有伺服器 `version`。更新時帶讀到的版本，以資料庫 trigger 驗證並加一；過期版本回報衝突。新增遭遇主鍵衝突時先讀回，不能盲目覆寫。
4. 網路中斷後重試前比對伺服器結果；伺服器已套用且內容一致即可確認完成。內容不同則保留本機草稿並要求使用者選擇，不以裝置時鐘決定輸贏。
5. 每次編輯、回到 App、切換群組或手動同步會重試；尚未加入連線狀態偵測與 Realtime。完整讀取使用分頁，避免 API 預設 1,000 列截斷紀錄。
6. 舊 Demo 匯入只包含本人資料；不匯入假隊友、假加油與預覽日期。保留原本訪客資料，顯示目的群組與分享範圍確認，跳過不適用日期、既有雲端列，照片另存副本以防訪客換照片時刪掉待上傳檔案。

## Discord 與專案建立

專案 `omi-app-dev` 已建立於使用者確認的 `e2755699's Org`，東京區。建立費用工具回報 US$0／月，未啟用付費方案。

建立順序：連接 Supabase 帳號 → 確认組織與新專案設定 → 建專案 → 套用 migration → 跑權限測試 → 配置 Discord → 接 Flutter。

Discord Developer Portal 建立 Omi 應用，OAuth redirect 設為 `https://iprkeejfleqyrqvliqya.supabase.co/auth/v1/callback`。Client Secret 由擁有者直接存進 Supabase Auth provider 設定，不貼對話、不進 repo。Flutter 的 App 回呼 `omiapp://auth-callback` 與 Web 網址另列在 Supabase redirect allow list，不能把兩種回呼混用。現有小工具的 `omiapp://checkin` 路徑保持相容，登入使用獨立路徑並實測冷啟動。

App 只配置 Supabase URL 與 publishable key；資料庫密碼、service_role／secret key 不進 App。Discord 為第三方登入，正式 iOS 上架前另確認當時 Apple 登入政策與是否需要補充登入選項。

## 分段驗收

1. 資料庫：migration 能套用；未登入／本人／同組／跨組／離組權限；不得讀他人心得、體重；重複加油與過期邀請被拒絕。
2. 登入：Web、Android、iOS 的 Discord 登入、取消、登出、重新啟動與 session 過期。
3. 同步：飛航模式打卡、重試、同時兩裝置修改、取消打卡、舊資料匯入、切帳號隔離。
4. 照片：上傳、中斷重試、換照片、刪除、跨組與離組讀取拒絕，孤兒檔清理。
5. 小工具：App 關閉時打卡、重新開啟同步、登出後停用；iOS 真機與 Android 驗證。
6. 上線：更新現有「不連網、不收集資料」的隱私文字與商店資料，完成帳號刪除與資料刪除流程。

## 部署紀錄

- 工作分支：`codex/supabase-backend`。
- 已選定：新專案、Discord 登入、教學最後可跳過登入。
- 雲端專案：[omi-app-dev](https://supabase.com/dashboard/project/iprkeejfleqyrqvliqya)，已建立且健康。
- 三份 migration 已套用；9 張表開啟 RLS；private schema 保存特權實作，公開 RPC 使用 security invoker 包裝。
- 本機 Postgres 51 項斷言通過；真實雲端交易測試通過，測試資料全部 rollback；安全 Advisor 沒有警告。
- Discord provider：已啟用，Client ID `1558290248033894441`；秘密由擁有者直接保存到 Supabase。公開 Auth settings 確認 Discord 啟用、anonymous 關閉。
- 登入 URL：開發 Site URL `http://127.0.0.1:5173/`；allow list 為 `http://127.0.0.1:5173/`、`omiapp://auth-callback`。GitHub Pages 尚未加入，也未部署雲端版。
- Flutter：37 項測試通過；包含本機訪客、OAuth 草稿與回呼網址、真 SQLite 佇列、斷線重試、衝突、HTTP 分頁／條件更新、匯入與隊友日期。預設建置只用本機；本輪 APK 透過 dart-define 啟用開發雲端。
- Chrome：SQLite worker 交易與 IndexedDB 持久儲存實測，重新載入顯示開啟次數 2、累積寫入 20，資料保留正常。
- Chrome 實際登入：擁有者確認 Discord `email identify` 授權後，返回教學第 11 步並顯示「Discord 已登入 ✓」；角色草稿保留。
- App 建立 `Omi sync test 20261010`（`53619864-62bd-4480-8083-2398efdd9412`），測試暱稱 `Omi test`。閱讀與每日反思各 1 筆、version 1；伺服器查詢確認私人心得等於合成測試文字，未匯入訪客資料。重新載入保留登入、群組與 2/7 每日進度，待同步與衝突皆為 0。這個測試群組仍保留於開發專案。
- 照片上傳實測通過：擁有者開啟 Chrome 外掛檔案存取後，用 `web/icons/Icon-192.png` 測試。修正 Web 上 `1 << 32` 溢位為 0、造成照片檔名亂數產生失敗；改用數值常數 `0x100000000`。App 上傳成功，伺服器確認 `weekly_photos` version 1、週期 `2026-10-05`，且私人 Storage 對應檔案存在（image/png，3,724 bytes）。重新載入 App 顯示照片完成 100%，再次進入本週任務能顯示圖示。此驗證包含本機照片快取，尚不代表另一裝置已能下載照片。
- 實測修正：一般 Web 啟動不再誤當 OAuth 回呼；返回網址完全移除 query／fragment，避免多出 `?#` 與精確 allow list 不符。
- Chrome 登出／再次登入：登出後回到本機 0/7 進度；以相同已核准權限再次登入，實際 OAuth request 的返回網址不再帶 `?#`，回到原群組 2/7 進度。
- 尚待驗證／補齊：Android／iOS 登入、照片跨裝置下載／中斷重試／更換移除、雙裝置同步、iOS 原生建置、雲端小工具打卡、照片清理、帳號刪除、雲端隱私政策。尚未 push、發布或合併 master。

### 本輪建置

- `flutter analyze --no-pub`：0 issue。
- `flutter test --no-pub`：37 項通過。
- Android release APK：`build/app/outputs/flutter-apk/app-release.apk`，64,478,906 bytes；使用 `--dart-define-from-file=config/supabase.dev.json` 連接開發雲端，未公開發布。
- APK SHA-256：`6CB699C9F4BC2DDE61102B51C5C3AC243BBBCD4F18CFBA0BE7F2ED11353412BC`。
- 先前 Web release：使用 `/omi_app/` base href，包含 SQLite worker 與 WASM 資產；本輪 Chrome 用帶雲端設定的 debug web-server 驗證。
- `home_widget` 有未來 Flutter／Kotlin Gradle 相容性提醒，這次 Android 建置成功；未在本輪升級不相關套件。

## 官方參考

- [Flutter 整合](https://supabase.com/docs/guides/getting-started/tutorials/with-flutter)
- [Discord 登入](https://supabase.com/docs/guides/auth/social-login/auth-discord)
- [Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [私人 Storage bucket](https://supabase.com/docs/guides/storage/buckets/fundamentals)
- [資料庫 migration](https://supabase.com/docs/guides/deployment/database-migrations)
- [Realtime 的限制](https://supabase.com/docs/guides/realtime/postgres-changes)
