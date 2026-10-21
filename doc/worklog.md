# Worklog

## 2026-10-21
- 使用者反映畫面「很幼稚、不太日系」:改為低飽和傳統色、霧氣、暖低角度光;抽出共用色票與工具到 `scripts/whitebox.gd`。
- 新增第一章白盒 `scenes/chapter1.tscn` + `scripts/chapter1.gd`,取代原型 main 場景(已刪除)。三處妖氣源(跳石 / 爬高台 / 石板開石籠)→ 石門 → 主殿。修正原型的踏板離開後門又關上的問題(改為永久開啟)。
- 下載 ambientCG 7 組 CC0 材質(約 46 MB)與 Quaternius Stylized Nature MegaKit Standard(99 MB,只取 25 個模型放進專案),套用三向投影貼圖與櫻樹 / 草 / 灌木 / 石頭 / 花瓣。
- 櫻色用白色葉片遮罩染色;淨化時樹冠由灰紫漸變粉色並噴花瓣。
- 踩雷:Godot 預設字型沒有 CJK;SystemFont 指到 `PingFang`(.ttc)載入失敗,改用 `Arial Unicode MS`。
- 以 SceneTree 腳本渲染截圖驗證外觀(headless 看不到畫面)。
- 以 Homebrew 安裝 Godot 4.7.2;headless 匯入與執行皆無腳本錯誤(僅匯入 OBJ 時提示缺 `.mtl`,無影響)。
- 鳥居 OBJ 接進 `main.gd`:原點在頂端、腳底約 y=-7.05,故以 `TORII_FOOT_OFFSET` 抬高;兩個表面(red / black)用程式碼指定顏色。已以 SceneTree 腳本渲染截圖確認外觀。
- 石燈籠需登入 Sketchfab 下載,仍待使用者提供。
- 納入 Godot 產生的 `.uid`、`.import` 檔進版控。
- 逐頁確認素材授權,整理於 `doc/assets.md`;下載 itch.io 鳥居的 `.obj` 至 `assets/models/torii/`(`.fbx`/`.mtl` 被瀏覽器擋下,未取得)。
- 石燈籠(Sketchfab,CC-BY)需使用者登入下載,待取得。
- 決定使用 Godot 4 / PC / low-poly。建立 Godot 專案:`project.godot`、`scenes/main.tscn`、`scripts/main.gd`、`scripts/player.gd`。
- 原型內容:狐狸(膠囊 + 錐形耳 / 尾)、固定視角跟隨鏡頭、踏板開石門、鳥居。場景以程式碼建立,減少手寫 .tscn 出錯。
- 本機尚未安裝 Godot,原型**未經執行驗證**。
- 與使用者討論 3D 日式遊戲方向,5 個提案中選定「神社守護者」(山神的使者)。
- 建立專案骨架:README、doc/plan.md、doc/todo.md、doc/worklog.md。
- 尚未決定引擎與平台。
