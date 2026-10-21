# 山神的使者(暫名)

3D 日式風格探索解謎遊戲。玩家扮演剛受封的小狐狸神使,走訪四季山村、淨化神社,讓山神甦醒。目標遊玩時長約 2 小時。

## 技術棧
- 引擎:Godot 4.3+(GDScript)
- 平台:PC(Mac / Windows)
- 美術:low-poly

## 安裝與環境設定
1. 安裝 Godot 4.3 以上(<https://godotengine.org/download>,或 `brew install --cask godot`;已在 4.7.2 驗證可執行)。
2. 用 Godot 開啟本資料夾的 `project.godot`。

## 啟動 / 使用方式
在編輯器按 F5 執行(或 `godot --path .`)。流程:標題 → 序章 → 第一章(春)→ 第二章(夏)→ 第三章(秋)→ 第四章(冬)→ 終章,皆為白盒可玩。
- 移動:WASD / 方向鍵
- 跳躍:空白鍵
- 互動(淨化妖氣源、點燈、推進對話):E
- 衝刺:Shift;嗅覺:按住 Q(顯示妖氣與御守的光柱)
- 每章流程:找木靈收集三枚御守、淨化三處神木、找出藏起來的三隻小木靈 → 在庭院挑戰「妖氣之主」(淨化三根封印柱、跳過擴散的妖氣環)→ 進主殿
- 暫停:Esc(繼續 / 重新開始本章 / 離開)

## 目錄結構
```
yamagami-messenger/
├── project.godot
├── README.md
├── assets/
│   ├── models/           # 鳥居、Quaternius 樹木植被(來源與授權見 doc/assets.md)
│   └── textures/         # ambientCG PBR 材質(CC0)
├── scenes/
│   ├── title.tscn        # 主場景(標題畫面)
│   ├── prologue.tscn     # 序章
│   ├── chapter1.tscn     # 第一章
│   ├── chapter2.tscn     # 第二章
│   ├── chapter3.tscn     # 第三章
│   ├── chapter4.tscn     # 第四章
│   └── finale.tscn       # 終章
├── scripts/
│   ├── title.gd          # 標題畫面
│   ├── level_base.gd     # 關卡基底:環境、玩家、HUD、妖氣源淨化、植被
│   ├── prologue.gd       # 序章:教學、白狐長老對話、傳送門
│   ├── chapter1.gd       # 第一章白盒:地形、機關
│   ├── chapter2.gd       # 第二章白盒:木筏渡河、夏日黃昏
│   ├── chapter3.gd       # 第三章白盒:迷霧、石牆迷宮
│   ├── chapter4.gd       # 第四章白盒:雪夜、點燈、冰牆
│   ├── finale.gd         # 終章:四季神木、山神甦醒、結語
│   ├── dialogue.gd       # 對話框(打字機效果)
│   ├── whitebox.gd       # 共用工具:色票、貼圖材質、方塊、輸入綁定
│   └── player.gd         # 狐狸移動 / 跳躍
└── doc/
    ├── plan.md
    ├── todo.md
    └── worklog.md
```

## 文件索引
- [計畫 plan](doc/plan.md)
- [待辦 todo](doc/todo.md)
- [工作日誌 worklog](doc/worklog.md)
