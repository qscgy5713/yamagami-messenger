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
在編輯器按 F5 執行(或 `godot --path .`)。目前為第一章「櫻之社」白盒:
- 移動:WASD / 方向鍵
- 跳躍:空白鍵
- 淨化:靠近妖氣源按 E
- 目標:淨化 3 處神木(池中小島、東邊高台、庭院石籠),打開主殿並進入

## 目錄結構
```
yamagami-messenger/
├── project.godot
├── README.md
├── assets/
│   ├── models/           # 鳥居、Quaternius 樹木植被(來源與授權見 doc/assets.md)
│   └── textures/         # ambientCG PBR 材質(CC0)
├── scenes/chapter1.tscn  # 主場景(掛載 chapter1.gd)
├── scripts/
│   ├── chapter1.gd       # 第一章白盒:地形、機關、妖氣源、HUD
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
