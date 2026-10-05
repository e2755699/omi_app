# App Store 商店資料與送審準備

> 狀態（2026-10-06）：**草稿，尚未填入 App Store Connect，尚未送審**。送審與公開發布由擁有者確認後才做。
> 發布管線見 [ios-release.md](ios-release.md)。

## 送審前必須先解決（會被退件或無法填寫）

| # | 項目 | 為什麼 | 需要決定／做的事 |
| --- | --- | --- | --- |
| 1 | **Demo 內容** | 審查指南 2.2：demo／beta／試用版不能上 App Store，要用 TestFlight。現在畫面有 `DEMO` 標籤、示範隊友、預設跳到第 30 天、「＊這是 Demo」說明 | 正式版要拿掉 Demo 標示與假隊友（或等後端做好真的隊友），預設日期改用今天 |
| 2 | **挑戰日期寫死** | `lib/models/challenge.dart` 固定 2026-10-09 → 2027-01-16；之後下載的人只會看到「挑戰完成」，也容易被認為功能不完整（4.2） | 改成自己選開始日，或只給社群用 → 考慮「不公開上架（Unlisted）」：只有拿到連結的人能下載，一樣要審查 |
| 3 | **App 圖示** | 目前是 Flutter 預設圖示 | 做像素風圖示（TODO 已列），1024×1024、不透明 |
| 4 | **支援網址**（隱私權政策已完成） | 所有 App 必填 | 隱私權政策：`web/privacy/` → https://e2755699.github.io/omi_app/privacy/（聯絡方式暫用 GitHub Issues）。還缺支援頁。Demo 下架時要保留這些頁面 |
| 5 | **價格與協議** | 要收費須先簽「付費 App 協議」並完成銀行、稅務資料；在歐盟上架要申報 DSA 交易者身分（交易者會公開地址、電話、信箱） | 免費或收費？價格？要不要上歐盟？ |
| 6 | **iPad** | 專案目前支援 iPhone＋iPad → 需要 13 吋 iPad 截圖；上架後一般不能再移除 iPad 支援 | 要不要支援 iPad？不要的話首次上架前改成只支援 iPhone |
| 7 | ~~Bundle ID~~ | ✅ 已定案 `com.jacklope.omiApp`，App 已建立（2026-10-06） | — |

第 1、2 項只擋 App Store 正式上架；TestFlight 外部測試本來就是 demo 的正確管道，審查備註已說明（見下方「TestFlight 測試資訊」）。

## 已經處理好的（在 repo 內）

- `ITSAppUsesNonExemptEncryption = false`（Info.plist）：App 沒有網路連線、沒用加密，每個 build 不用再手動回答出口合規。之後加後端（HTTPS）仍屬豁免，但要重新確認。
- `ios/Runner/PrivacyInfo.xcprivacy`：宣告使用 UserDefaults（理由 CA92.1，只存 App 自己的資料），不追蹤、不收集資料。
- 主畫面名稱 `Omi`（和 Android 一致）。
- 2026-04-28 起必須用 Xcode 26 / iOS 26 SDK 打包：Codemagic 固定 `xcode: '26.6'`（和黃絲帶相同）。

## 商店資料草稿（繁體中文）

**App 名稱**（≤30 字）：`Omi～快樂的 Σίσυφος`

**副標題**（≤30 字）：`100 天好習慣挑戰，每天推一次石頭`

**宣傳文字**（≤170 字，可隨時改、不用送審）：
> 把每天的好習慣變成看得見的能量槽。運動、飲食、閱讀、睡眠、反思——按下鍵帽就是打卡，100 天後回頭看，石頭已經推了好遠。

**描述**（≤4000 字；以下只寫 App 現在真的有的功能，正式版功能變了要一起改）：
```
希臘神話裡，薛西弗斯每天把石頭推上山。Omi 想說的是：每天再推一次，本身就是一種快樂。

Omi 是一個 100 天的好習慣挑戰。五個面向，每天一點點：
・Move 動起來：每週有氧 150 分鐘＋肌力 2 次
・Nourish 好好吃：不喝酒，再從蔬果、蛋白質、喝水三選二
・Learn 學一點：每天閱讀 20 分鐘
・Recover 睡好覺：8 小時睡眠機會、固定作息
・Reflect 回頭看：每天寫下「今天我注意到的事」，每週回顧與計畫

【怎麼玩】
・第一次打開跟著教學一步步設定，三選二和作息時間依自己調整
・首頁的能量槽顯示每一項的進度
・每日打卡是一排機械鍵盤鍵帽，按下去就完成
・幫夥伴集氣加油，完成的人一起慶祝

【隱私】
所有紀錄只存在你的手機裡，不需要註冊帳號，不收集任何資料。
```

**關鍵字**（≤100 字元，逗號分隔，不重複名稱裡的字）：
`習慣,打卡,挑戰,100天,運動,閱讀,睡眠,喝水,反思,自律,健康,日記,像素`

**類別**：主要「健康與健身」，次要「生活風格」

**版權**：`2026 Dustin Liu`

**年齡分級問卷**：都選「無」，除了「酒精、菸草或藥物的使用或提及」——App 提到「不喝酒」的目標，保守選「不頻繁／輕微」（分級可能因此提高一級；選「無」也說得通，由擁有者決定）。

**App 隱私（營養標籤）**：「不收集資料」。依據：沒有網路請求、沒有分析／廣告 SDK、資料只存在裝置（shared_preferences）。**加後端或任何分析工具前必須改這裡和隱私權政策。**

**內容權利**：不含第三方內容。注意：挑戰規則來自 Omi 社群的「The Rules」投影片，請確認有權使用。

**審查備註**（給 Apple 審查員）：
```
不需要登入或帳號。第一次打開會進入設定教學（約 1 分鐘），完成後到首頁，
點「每日打卡」按鍵帽即可打卡。所有資料只存在裝置上，App 不連網。
```

## 截圖

| 裝置 | 尺寸（直式） | 必要？ |
| --- | --- | --- |
| iPhone 6.9 吋 | 1320 × 2868 | 必要（Apple 會自動縮給較小的 iPhone） |
| iPad 13 吋 | 2064 × 2752 | 支援 iPad 才需要 |

每組 1–10 張，PNG／JPEG。建議順序：標題畫面 → 設定教學 → 首頁能量槽 → 鍵帽打卡 → 集氣／慶祝。

## 送審流程（擁有者確認後才做）

1. TestFlight 內測沒問題、上面 1–7 都解決。
2. App Store Connect → App → 1.0 版：填商店資料、截圖、隱私、分級、價格與供應國家、審查備註。
3. 選擇用哪個 TestFlight build → 「新增以供審查」→ 送出。
4. 上架方式建議選「手動發布」，審查通過後再決定公開時間。

CI **不會**自動做第 2–4 步。

## TestFlight 外部測試（擁有者 2026-10-06 已要求）

CI 會在內測可用後自動送外部測試（群組「Omi 夥伴」，開公開連結）。第一個 build 要經 Beta App Review（通常數小時到一天），之後同版本的新 build 通常較快。公開連結在 App Store Connect → TestFlight → 外部測試群組，不貼在公開 repo；要發給 Discord 夥伴時由擁有者貼。

### TestFlight 測試資訊（App Store Connect → TestFlight → 測試資訊）

**Beta 版 App 描述**（測試者看得到）：
```
Omi～快樂的 Σίσυφος 是一個 100 天好習慣挑戰 App：運動、飲食、閱讀、睡眠、反思五個面向，每天按下鍵帽打卡，看能量槽一點一點充滿，也能幫隊友集氣加油。

目前是 Demo 測試版：隊友是示範資料，你的紀錄只存在自己的手機。歡迎試用，並在 TestFlight 裡截圖回饋想法。
```

**隱私權政策 URL**：`https://e2755699.github.io/omi_app/privacy/`

**審查備註**（給 Apple 審查員；照擁有者要求說明目前是 demo、正式上架前會完整做出來）：
```
This build is a demo of our community's 100-day habit challenge app, distributed through TestFlight to collect feedback from participants before we build the full product.

- No login or account is required, and the app works fully offline. All data stays on the device.
- The teammates shown in the app are built-in sample data; the app labels this clearly as DEMO.
- Before any public App Store release we will complete the full app, including the backend and architecture that sync real teammates' progress, and update the privacy policy accordingly.

How to test: on first launch, follow the setup tutorial (about 1 minute). Then tap "每日打卡" (Daily check-in) on the home screen and press the keycap buttons to check in.

（中文）這是社群 100 天好習慣挑戰的 Demo 測試版，透過 TestFlight 先收集參與者回饋。不需登入、可離線使用，資料只存在裝置上；App 中的隊友是內建示範資料（App 內標示 DEMO）。正式上架 App Store 前，我們會把 App 完整做出來，包含同步真實隊友進度的後端與架構，並同步更新隱私權政策。
```

**需要登入**：不勾。

**擁有者本人填**：意見回饋電子郵件地址、審查聯絡人（姓、名、電話、電子郵件）。

## 待確認

- 免費或收費、價格、上架國家（含不含歐盟）
- 支援／聯絡信箱（會公開在支援頁和隱私權政策）
- 要不要支援 iPad
- Demo 內容與寫死日期怎麼處理（正式版範圍）
- 一般公開上架，或不公開上架（只給社群）
