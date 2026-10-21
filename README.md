# 山神的使者(暫名)

3D 日式風格探索解謎遊戲。玩家扮演剛受封的小狐狸神使,走訪四季山村、淨化神社,讓山神甦醒。目標遊玩時長約 2 小時。

## 技術棧
- 引擎:Godot 4.3+(GDScript)
- 平台:PC(Mac / Windows)
- 美術:low-poly

## 安裝與環境設定
1. 安裝 Godot 4.3 以上(<https://godotengine.org/download>,或 `brew install --cask godot`)。
2. 用 Godot 開啟本資料夾的 `project.godot`。

## 啟動 / 使用方式
在編輯器按 F5 執行。目前為原型:
- 移動:WASD / 方向鍵
- 跳躍:空白鍵
- 踩上黃色踏板,前方石門會下沉

## 目錄結構
```
yamagami-messenger/
├── project.godot
├── README.md
├── scenes/main.tscn      # 主場景(掛載 main.gd)
├── scripts/
│   ├── main.gd           # 以程式碼建立原型關卡
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
