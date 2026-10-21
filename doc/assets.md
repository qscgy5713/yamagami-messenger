# 素材來源清單

> 下載前務必在各頁面確認授權。本表的授權欄僅為搜尋結果所見,未逐一驗證。

## 已確認為 CC0(搜尋結果有標示)
| 素材 | 用途 | 連結 |
|------|------|------|
| Quaternius LowPoly Nature Pack | 樹、石、草 | https://opengameart.org/content/lowpoly-nature-pack |
| Quaternius Animated Animals(狼、貓、犬…) | 動物動畫參考,可改作狐狸 | https://opengameart.org/content/animated-animales-low-poly |
| Quaternius 5 Low Poly Animals | 小動物 | https://opengameart.org/content/5-low-poly-animals |
| Quaternius LowPoly Animated Monsters | 妖怪原型 | https://opengameart.org/content/lowpoly-animated-monsters |
| Kenney 各類 CC0 包 | 建築、道具、自然 | https://kenney.nl/assets |

## 日式物件(2026-10-21 逐頁確認)
| 素材 | 確認結果 | 連結 |
|------|----------|------|
| Japanese Toro(Sketchfab, André Bernardo) | **CC-BY,可下載**(需在製作名單掛名作者)。約 1.8k 三角面 | https://sketchfab.com/3d-models/japanese-toro-afe883adeab045348b7dc9a038975feb |
| Japanese Torii Low Poly(Sketchfab, 同作者) | 頁面無下載鈕、未顯示授權,**視為不可下載** | https://sketchfab.com/3d-models/japanese-torii-low-poly-ba79bbd7ce454c92aa6c0dd9809093d8 |
| Torii Gate(Gumroad, jsabbott) | 免費(NT$0+),頁面寫「商用與非商用皆可」,**無正式授權名稱**。檔案:Blender / FBX / OBJ | https://jsabbott.gumroad.com/l/torii |
| Torii Gate(itch.io, olde-tinkerer) | 免費(自訂價格),寫「商用與非商用皆可」,**無正式授權名稱**。檔案:Blend / FBX / OBJ | https://olde-tinkerer.itch.io/torii-gate |
| Lantern Set Low Poly Stylized(Sketchfab) | 非日式燈籠(幻想風),無下載鈕、未顯示授權,**不採用** | https://sketchfab.com/3d-models/lantern-set-low-poly-stylized-4f1adf43f2994618b9e95c23446c3ba7 |

結論:石燈籠用 Japanese Toro(CC-BY);鳥居用 Gumroad 或 itch.io 那兩個(口頭宣稱可商用,但無正式授權,建議留下頁面截圖並在製作名單標示),或自建。

## 已下載並使用(2026-10-21)
### ambientCG PBR 材質(CC0,1K-JPG,放在 `assets/textures/<ID>/`)
| ID | 用途 |
|----|------|
| Ground037 | 地面(苔土) |
| PavingStones138 | 參道、庭院 |
| PavingStones138 | 神社庭院 |
| Rock064 | 石牆、高台、石籠、石燈籠 |
| WoodFloor064 | 木門、主殿牆(染朱紅) |
| RoofingTiles013A | 主殿瓦屋頂 |
| Bark014 | 已下載,尚未使用(樹幹改用 Quaternius 模型自帶貼圖) |

### Quaternius Stylized Nature MegaKit — Standard 版(CC0,放在 `assets/models/nature/`)
- 取自 25 個模型:TwistedTree 1–4、CommonTree 1–2、Petal、草、灌木、花、蕨、三葉草、石頭、卵石,共約 29 MB(原 zip 99 MB,其餘未放進專案)。
- 授權檔:`assets/models/nature/License_Standard.txt`(CC0 1.0)。
- 免費版樹葉只有紅 / 綠;櫻花色是用白色葉片遮罩 `Leaves_TwistedTree.png` 在程式裡染色(`WB.leaf_material`)。粉紫櫻色樹屬於付費 Pro 版,未使用。

### 狐狸模型(CC0,`assets/models/fox/Fox.glb`,0.96 MB)
- 來源:[Poly Pizza / Fox by Quaternius](https://poly.pizza/m/Bc97C66HKi),Public Domain (CC0),約 1.8k 三角面。
- 24 組動畫(Idle、Walk、Gallop、Gallop_Jump…),遊戲使用 Idle / Gallop / Gallop_Jump。
- 網頁的 Download 鈕在瀏覽器自動化下無反應,改由頁面原始碼找到的靜態網址(`static.poly.pizza/e18e86df-….glb`)直接下載。

### 字型(OFL,`assets/fonts/NotoSerifTC.ttf`,16.9 MB)
- 來源:Google Fonts 的 Noto Serif TC 可變字重版(已取代先前的 Noto Sans TC,後者已移除)。
- 授權文字:`assets/fonts/OFL.txt`(SIL Open Font License 1.1,可內嵌與商用)。

## 已下載到專案(其他)
| 檔案 | 位置 | 來源 |
|------|------|------|
| `shinto-shrine-gate.obj`(19 kB) | `assets/models/torii/` | itch.io olde-tinkerer / Torii Gate(2026-10-21 下載) |

- 該包的 `.fbx`、`.mtl` 下載時被瀏覽器擋下,尚未取得;`.obj` 內有 `mtllib shinto-shrine-gate.mtl` 參照,缺檔時 Godot 會以預設材質匯入。
- 石燈籠(Sketchfab Japanese Toro)需登入才能下載,尚未取得。

## 怪物模型(首領「妖氣之主」)
- `assets/models/monsters/Ghost.glb`(198.6 KB)— Quaternius「Ghost」,Poly Pizza(https://poly.pizza/m/Iip30bDHmu),CC0,含 8 組動畫(使用 Flying_Idle)。遊戲中放大並以程式乘上暗紫色調。
- 同頁另有 Quaternius「Demon」(https://poly.pizza/m/LnfIziKv4o,CC0)曾下載預覽,風格太卡通(圓眼紅惡魔),未採用,已從專案移除。
- 其他評估但未採用:tt-3D Japanese Yokai 系列(題材最貼近,但授權與格式未確認:Blender / FBX);Quaternius Ultimate Monsters 整包(CC0、50 隻、含 glTF,尚未下載,可作之後的小怪來源)。

## 製作名單(Credits)
- 狐狸模型、樹木與植被、首領(Ghost) — Quaternius(CC0,無須掛名,仍建議列出)。
- PBR 材質 — ambientCG(CC0)。
- 字型 — Noto Sans TC,Google / Adobe(SIL OFL 1.1)。
- Torii Gate — olde-tinkerer(itch.io),作者標示商用與非商用皆可,無正式授權條款。
- Japanese Toro — André Bernardo(Sketchfab),CC-BY 4.0,取得後須於遊戲製作名單標示。

## 付費備選
- Sinto Shrine Essentials(最低 $10.49):https://darkcomdev.itch.io/sinto-shrine-essentials
- CGTrader 低多邊形神社($5):https://www.cgtrader.com/3d-models/exterior/historic-exterior/japanese-shinto-shrine-low-poly-3d-model

## 授權備忘
- CC0:免掛名。CC-BY:製作名單須列作者。避免 NC / ND 以外限制不明者。
- 沒有確認 CC0 的日式神社整包;鳥居、燈籠、神社建築建議自建(基本幾何體即可)。
- `assets/particles/*`(約 0.6 MB)— Kenney「Particle Pack 1.1」,CC0,妖氣源與嗅覺光柱用(授權檔 `KENNEY_LICENSE.txt`)。
- `assets/textures/Plaster001/` — ambientCG Plaster001,CC0,主殿與土塀牆面。
- `assets/textures/{Wood051,Wood067,ThatchedRoof001A}` — ambientCG,CC0

- `assets/audio/*.ogg` — 原創合成(`tools/make_music.py`),無第三方授權。
- `assets/fonts/NotoSerifTC.ttf`(16.9 MB)— Noto Serif TC 可變字重,Google Fonts,SIL OFL 1.1(授權檔 `OFL_NotoSerifTC.txt`),標題與介面文字用。
- `assets/models/monsters/Ogre.glb`(57 KB)— 「Ogre」by joney_lol,Poly Pizza(https://poly.pizza/m/7oO8liwQv6),**CC BY 3.0(需掛名,已列於終章製作名單)**,Boss 用。
- `assets/textures/jp/*.png` — 自繪(`tools/make_textures.py`),參考見 `doc/design-refs.md`。

