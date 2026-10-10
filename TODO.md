# omi_app TODO

## 本輪合併與發布（2026-10-10）

- [x] 完成／已驗證／未完成清單更新；PR #3 已合併 master（e14045b）
- [x] TestFlight 1.2.0 (4)：Codemagic 全自動建置、雙 target 簽章與 Apple 上傳成功
- [x] Apple API 確認 VALID、未過期、IN_BETA_TESTING、已在 Omi Internal
- [x] TestFlight 文字／公開隱私政策／iOS manifest 更新；公開 Pages 部署成功
- [x] iOS 發布通知 issue 已留言；本機 Android 1.2.0 (4) APK 已產出
- [ ] 1.2.0 外部 Beta 審查通過（目前 WAITING_FOR_BETA_REVIEW；既有排程持續查驗）
- [ ] 擁有者確認通知信收件及真機安裝

證據：[iOS 發布紀錄](docs/release/ios-release.md)、[Apple 查驗 JSON](docs/release/evidence/1.2.0-4.json)。

## Supabase 後端（2026-10-10）

- [x] 擁有者選定 Supabase 與 Discord 登入；確認使用 `e2755699's Org`
- [x] 建立東京區 `omi-app-dev`，資料表、RLS、群組 RPC、私人照片 bucket
- [x] 本機 51 項資料庫斷言、雲端交易測試與 Security Advisor 驗證
- [x] 登入放在教學最後；可先在本機使用；訪客不顯示其他玩家與假加油
- [x] OAuth 前保存教學草稿，返回或重開仍停在最後一步；首頁保留帳號入口
- [x] Discord 應用條款、秘密與 provider 完成；手機／本機 redirect allow list 已保存
- [x] Chrome 真實 Discord 登入、教學草稿返回、群組建立、打卡／私人心得同步及重新載入保留資料
- [x] 修正一般 Web 啟動誤判登入回呼、返回網址多出 `?#`；37 項 Flutter 測試通過
- [x] Chrome 照片上傳：修正 Web 檔名亂數溢位，確認私人 Storage 與 metadata 建立、重開顯示快取照片
- [x] Android 實機（SM-A1660）Discord 登入：`flutter_web_auth_2` 登入頁自動關閉、狀態切換（記憶體不足被回收時需重按，已接受）
- [ ] iOS 改 `flutter_web_auth_2` 後的真機登入（需 `v` tag 新版 TestFlight）
- [ ] Android／iOS 雙裝置實測
- [x] 帳號／群組隔離的 SQLite 離線佇列、衝突處理、資料匯入與照片同步程式
- [x] 真實隊友、邀請碼與加油介面；切空間關閉舊編輯頁，登出清除隊友
- [x] Web SQLite／IndexedDB 持久儲存 Chrome 實測
- [ ] Discord 登入後雙裝置、斷線、照片跨裝置下載／重試／更換移除與帳號切換端到端實測
- [ ] 雲端小工具背景打卡（目前引導開啟 App）、群組照片牆、照片孤兒檔清理
- [x] 雲端隱私政策與 iOS privacy manifest 更新（1.2.0）
- [ ] 帳號刪除、雲端資料刪除（含 Auth、照片與群組擁有權）

設計與目前驗收：[docs/backend/supabase-plan.md](docs/backend/supabase-plan.md)。
## Android 下載入口（2026-10-10）

- [x] 像素風 `/download/` 頁面：版本、下載、網頁版、安裝教學、資料保存提醒
- [x] Pages 建置加入下載頁存在檢查
- [x] `android-v1.1.0-2` APK 上傳、公開下載驗證（重新下載 SHA-256 一致）
- [x] 下載頁 PR #2 已合併 `master`，Pages run 38014232679 成功（2026-10-10）
- [ ] 乾淨安裝與覆蓋舊版的 Android 真機驗收
- [ ] 後續 APK 自動建置發布：先將固定 Android 簽章納入 secret store

發布方式、限制與證據：[Android 發布](docs/release/android-release.md)。

## 可交接的未完成項目（2026-10-10）

| 工作 | 目前狀態 | 完成條件 |
| --- | --- | --- |
| Android 雲端 Widget | 未實作，雲端模式引導開 App | App 關閉時操作能寫入正確帳號／群組的離線佇列，重連同步，登出後隔離 |
| iOS 雲端 Widget | 未實作，現有 AppIntent 只處理本機 | App Group／背景 engine 與雲端佇列整合；真機冷啟動驗證 |
| App ↔ Widget 更新 | App 可寫入顯示資料，跨裝置背景更新未完成 | 本機／遠端改動與登出切群組後更新，遵守 OS 刷新限制 |
| 自動同步觸發 | 已有編輯、回前景、手動同步 | 補網路恢復監聽／Realtime 訂閱及生命週期 |
| 手機登入 | 程式與 deep link 已配置，未真機驗 | Android／iOS Discord 授權、取消、冷啟動、session 過期 |
| 雙裝置與離線 | 佇列、衝突、帳號隔離有單元測試 | 兩台真機打卡／取消、同時修改、斷網重連、匯入、換帳號端到端測試 |
| 照片同步 | Chrome 上傳與 metadata 實測通過 | 清快取或第二裝置下載、重試、替換、移除與跨組／離組權限驗證 |
| 群組照片牆 | 未實作 | 顯示同組分享照片，移除／離組後權限生效 |
| 孤兒照片清理 | 未實作 | 可恢復的清理流程，避免誤刪正在上傳的檔案 |
| 多人群組 | UI、RPC、RLS 測試已有 | 真人多帳號邀請到期、加入／離組、加油端到端驗證 |
| 帳號與資料刪除 | 未實作 | 刪除 Auth、私人／群組資料、照片及擁有權轉移規則 |
| 商店雲端資訊 | 隱私頁／manifest／測試文字已更新 | ASC 資料收集標籤、支援頁、刪除流程、正式版驗收 |
| Pages 雲端版 | 尚未啟用，公開網頁仍本機 | 確定啟用後才加 callback allow list、CI define 並驗證登入 |
| Android 公開新版 | 下載頁仍 1.1.0 (2) | 固定正式簽章、乾淨安裝／升級驗證，再發布雲端 APK |

1.2.0 本輪只發布已完成的功能；以上未完成項目保持未勾選，不能把建置成功當成功能驗收。

## GitHub Pages 搬家／改自訂網域時要改的網址（2026-10-10 記錄）

擁有者想用自己的網域指向 Pages，之後搬家只換 DNS；目前還沒有網域。屆時對外只公開自訂網域，下列全部換掉。

- Repo 內（`git grep -n "github\.io"` 可重查）：
  - `.github/workflows/pages.yml` 第 34–38 行：自訂網域在根目錄，`--base-href` 要從 `/omi_app/` 改成 `/`，否則整站壞掉
  - `README.md` 第 9、11、80 行：網頁版、APK 下載頁、隱私權政策
  - `docs/release/android-release.md` 第 5–6 行；`docs/release/app-store-listing.md` 第 15 行；`docs/release/ios-release.md` 第 134 行；`docs/session-handoff.md` 第 19 行
  - `tool/release/config.json` 第 14 行 `privacy_policy_url`
  - `supabase/README.md` 第 54 行（allow list 說明）
  - `test/account_controller_test.dart` 第 32–33 行：測試資料用的 Pages 子目錄，改根目錄後同步調整
- Repo 外（擁有者本人或在已登入的後台操作）：
  - GitHub repo Settings → Pages：Custom domain＋Enforce HTTPS（`build_type: workflow`，不需要 `CNAME` 檔）
  - DNS：`CNAME <子網域> → e2755699.github.io`，先 DNS only 讓 GitHub 簽憑證
  - Supabase Auth → URL Configuration：Site URL（目前是 `http://127.0.0.1:5173/`，手機上打不開）與 Redirect URLs 加新網域
  - App Store Connect：隱私權政策網址（及之後的支援網址）
  - 已發到 Discord 社群的下載頁連結：GitHub 會把舊 `github.io/omi_app/` 轉到自訂網域，但離開 GitHub Pages 後舊網址就失效，搬家前要先換成自訂網域

## 之後發想

- **🏅 實體獎章**：達成某種成就就拿到一個實體獎章，可以當裝飾放在家裡、用魔鬼氈貼在包包上，或掛在包包上當吊飾。
  - 有哪些成就？（例如：連續打卡 30 天、某一類能量連續滿格一週、完成 100 天）
  - App 裡怎麼呈現？（像素風徽章牆？解鎖動畫？）
  - 怎麼領取／寄送？跟社群（Discord）怎麼連動？
- **⭐ 願望撲滿＋願望商城**：完成某種成就就收集星星，存進自己的撲滿。願望商城裡放自己想要的獎勵（想買的包包、想吃的大餐），用星星兌換來犒賞自己。
  - 哪些成就給幾顆星？（每日全完成、一週能量滿格、連續 N 天……）
  - 願望是自己新增的嗎？要設定「幾顆星才能換」？
  - 兌換之後要不要分享到「大家的進度」讓隊友一起慶祝？
  - 跟實體獎章怎麼搭配？
- **📤 分享功能**：把自己的進度或成就分享出去（例如產生分享圖卡）。
  - 分享什麼？（每日打卡結果、一週能量、連續天數、達成的成就）
  - 分享到哪裡？（存成圖片、系統分享選單、Discord 貼文）
  - 分享的內容要不要帶隊友的資訊？會不會跟「大家的進度」重疊？
  - 現有的 🧪 Demo Lab 分享圖卡在 `feature/share-flex` 分支（尚未合併），要不要沿用？
- **🧱 每週成就牆**：每週結算一次，把這週的成就掛上牆（像素風格，一週一格，100 天大約 15 格）。
  - 一週的成就怎麼算？（能量全滿、每日全勤、照片有上傳、連續打卡……）
  - 牆上每格要顯示什麼？（週次、達成的成就圖示、沒達成的格子怎麼呈現）
  - 跟實體獎章、願望撲滿是什麼關係？成就牆是不是就是獎章的來源？
  - 牆要不要可以分享？跟上面的分享功能怎麼合在一起？

## 這一批（2026-10-09 擁有者定案，依 docs/PRD.md 第 7 節）

- [x] 結束固定 12/31；開跑日 = 開始用 App 那天，教學可選「從今天」或「從下週一」；「100 天」改成實際天數
- [x] Nourish 至少選 2（可 3）
- [x] 體重保留、不鎖定；輸入後蛋白質和飲水目標都顯示
- [x] 首頁主位「達成 N 天」；🔥 連續 N 天保留但放不顯眼處（結束慶祝牆之後再做）
- [x] 每週只留回顧三題；拿掉「下週計畫」項目；Week 1 計畫放教學
- [x] 每週照片真的能選／拍，本機照片牆（image_picker；iOS 加了相簿／相機權限文字，**下次 iOS 要走 v<版本> 完整發布**）
- [x] 教學照 Mindy 的 Setup 表（決定加入、開跑日、Nourish、要讀什麼書、作息、Week 1 計畫：Move 項目＋最可能的阻礙）
- [x] Reflect 教學：引導寫心得（Jimmy 的例子可點選）＋預覽每週三題
- [x] 教學示範鍵帽可以按；時間選擇器改像素風
- [x] 首頁「本週任務」卡（回顧、照片），不用翻到每日打卡最底下
- [x] 分享只看得到打卡；心得與回顧不給隊友看（隊友頁不再顯示心得）
- [x] 不做：「沒做到」狀態（先寫在心得）

## 還沒決定

- [ ] 提醒通知（每日心得、週日回顧）要不要做
- [x] iOS WidgetKit 已實作並包含於 1.1.0 (3)；本機模式模擬器通過，真機待驗

## 架構討論之後要做

- [x] Supabase 後端與真實群組／加油已實作；真人多人端到端驗收待補
- [ ] 中文也換成像素字型（例如俐方體11號 Cubic 11，OFL 授權）
- [ ] 像素風 App 圖示（上架 App Store 前必須）
- [x] iOS 桌面小工具（WidgetKit，鍵帽可直接打卡；需要發 `v<版本>` 才會進 TestFlight，擁有者要先在 Apple Developer 開好 App Group，見 docs/release/ios-release.md）
- [ ] 正式簽章，上架 Google Play

## iOS 上架（見 docs/release/）

- [x] Codemagic → TestFlight 管線：1.0.0 (1) 已內測可用、已送外部 Beta 審查（2026-10-06）
- [x] Shorebird 已啟用，1.0.0 (2)／1.1.0 (3) 完整發布成功
- [ ] Shorebird patch 真實發布驗收（程式與模擬測試已有）
- [x] Bundle ID `com.jacklope.omiApp`、App Store Connect App、內部群組、Codemagic App（2026-10-06）
- [x] 外部測試自動送審＋審查結果通知、隱私權政策頁（1.1.0 (3) 已全自動實跑）
- [x] TestFlight 測試資訊（含回饋信箱、審查聯絡人）
- [ ] 正式版拿掉 Demo 內容、挑戰日期不要寫死（審查指南 2.2）
- [ ] 支援頁（隱私權政策頁已完成）
- [ ] 價格／付費協議／歐盟 DSA、要不要支援 iPad
- [ ] 截圖（iPhone 6.9 吋，支援 iPad 的話加 13 吋）
- [ ] 送審（擁有者確認後）
