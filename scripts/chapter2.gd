extends LevelBase
## 第二章・水之社(夏)白盒場景。
## 流程:搭木筏渡河 → 淨化池中小島與東邊望樓的神木 → 庭院石門開啟 → 踩石板開石籠、淨化最後一處 → 主殿開門。
## 新機關:木筏(AnimatableBody3D 來回漂流)。

const SOURCES_FOR_GATE := 2
const SOURCES_TOTAL := 3
const KODAMA_LINES := {
	"intro": [
		{"who": "木靈", "text": "神使大人,河水漲起來的時候,御守被沖散了……"},
		{"who": "木靈", "text": "有的漂到了池中的小島,有的在望樓上,還有兩座石台隔著很遠的距離。"},
		{"who": "木靈", "text": "拜託你,找回來吧。"},
	],
	"waiting": [{"who": "木靈", "text": "還沒找齊呢。按住 Q,御守的光會透過牆壁指給你看。"}],
	"done": [{"who": "木靈", "text": "謝謝你!水之社的封印,我來解開。"}],
}
const BOSS_LINES := {
	"start": [
		{"who": "祭典的殘影", "text": "祭典還沒結束……誰也不許離開。"},
		{"who": "祭典的殘影", "text": "水會一直漲,到所有人都留下為止。"},
	],
	"defeated": [
		{"who": "祭典的殘影", "text": "……水,終於流動了。"},
		{"who": "祭典的殘影", "text": "啊,祭典的燈籠,熄了。"},
	],
}
const OUTRO_LINES := [
	{"who": "", "text": "水聲漸漸平息,蟬鳴依舊。夏天的水脈重新流動。"},
	{"who": "白狐", "text": "做得好。接下來是秋天的紅葉之社,那裡的山霧很濃,小心別迷了路。"},
]
const PURIFY_LINES := ["池面泛起了漣漪", "望樓上的老樹抽出新芽", "最後一處的水脈通了"]
const NEXT_SCENE := "res://scenes/chapter3.tscn"
const RIVER_Z_MIN := 10.0
const RIVER_Z_MAX := 22.0
const RAFT_CENTER_Z := 16.0
const RAFT_AMPLITUDE := 5.0

var gate_door: StaticBody3D
var cage_door: StaticBody3D
var hall_door: StaticBody3D
var raft: AnimatableBody3D
var plate_latched := false
var crossed := false
var completed := false
var gate_open := false


# ---------- 基底的覆寫 ----------

func _environment_config() -> Dictionary:
	# 夏日黃昏:偏暖的橙色低角度光、淡藍天空、薄霧。
	return {
		"sky_top": Color("6f86a3"),
		"sky_horizon": Color("e3b98f"),
		"sky_ground": Color("b9a58f"),
		"ambient_energy": 0.55,
		"fog_color": Color("d9bf9f"),
		"fog_density": 0.007,
		"sun_color": Color("ffc58a"),
		"sun_energy": 1.0,
		"sun_rotation": Vector3(-20.0, -50.0, 0.0),
		"saturation": 0.95,
	}


func _bloom_color() -> Color:
	return Color("7fa65c")


func _chapter_title() -> PackedStringArray:
	return PackedStringArray(["第二章", "水之社"])


func _purify_line(count: int) -> String:
	return PURIFY_LINES[count - 1] if count >= 1 and count <= PURIFY_LINES.size() else ""


func _start_position() -> Vector3:
	return Vector3(0.0, 1.0, 40.0)


func _start() -> void:
	_update_hud()
	await _say([
		{"who": "", "text": "蟬聲鋪天蓋地。山腳的河水漲過了橋,水之社在對岸。"},
		{"who": "", "text": "橋斷了,只剩一艘木筏在河面上來回漂著。"},
	])


func _build_level() -> void:
	_build_ground()
	_build_river()
	_build_path()
	_build_pond()
	_build_tower()
	_build_gate_wall()
	_build_cage_puzzle()
	_build_hall()
	_build_scenery()
	_scatter_vegetation()
	_build_quest()


func _is_free(p: Vector3) -> bool:
	if p.z > RIVER_Z_MIN - 2.0 and p.z < RIVER_Z_MAX + 2.0:
		return false
	if p.x < -9.5 and p.z > -19.0 and p.z < 3.0:
		return false
	if absf(p.x) < 4.2 and p.z > -46.0 and p.z < 42.0:
		return false
	if absf(p.x) < 13.5 and p.z < -24.0 and p.z > -46.0:
		return false
	if p.x > 11.0 and p.z > -14.0 and p.z < 9.0:
		return false
	if p.x > 9.5 and p.x < 18.5 and p.z < -29.0 and p.z > -38.5:
		return false
	if Vector2(p.x + 15.0, p.z + 32.0).length() < 3.5:
		return false
	if absf(p.x) < 8.5 and p.z < -43.0:
		return false
	if absf(p.z + 24.0) < 1.8:
		return false
	if absf(p.x) > 7.0 and absf(p.x) < 10.5 and p.z > -20.0 and p.z < 32.0:
		return false
	return true


func _build_quest() -> void:
	var dash_charm := _build_dash_platforms(Vector3(-27, 0.5, 36))
	var spots: Array[Vector3] = [Vector3(-22.0, 0.8, -6.5), Vector3(25.0, 4.8, -4.0), dash_charm]
	var seek_spots: Array[Vector3] = [Vector3(28, 0.8, 40), Vector3(-27, 0.8, -45), Vector3(27, 0.8, -48)]
	_setup_seek(seek_spots)
	var pylon_spots: Array[Vector3] = [Vector3(-8, 0, -29.5), Vector3(8, 0, -29.5), Vector3(0, 0, -42)]
	_setup_boss(Vector3(0, 3.2, -35), pylon_spots, Rect2(-13, -46, 26, 19), BOSS_LINES)
	_setup_quest(Vector3(2.4, 0.0, 32.0), spots, KODAMA_LINES)


func _on_progress_changed() -> void:
	if purified >= SOURCES_FOR_GATE and not gate_open:
		gate_open = true
		_move_door(gate_door, -3.2)
		_flash("庭院的石門開啟了")
	_update_hud()


func _on_boss_defeated() -> void:
	_move_door(hall_door, -2.2)
	_flash("主殿的門開啟了")


func _on_source_purified(_s: LevelBase.Source) -> void:
	_on_progress_changed()


func _level_process(_delta: float) -> void:
	# 過河後把檢查點移到北岸,掉進河裡不必再搭一次木筏。
	if not crossed and player.global_position.z < RIVER_Z_MIN - 1.5:
		crossed = true
		respawn_pos = Vector3(0.0, 1.0, RIVER_Z_MIN - 3.0)
		_update_hud()


func _physics_process(_delta: float) -> void:
	raft.global_position.z = RAFT_CENTER_Z + sin(time * 0.5) * RAFT_AMPLITUDE


# ---------- 地形 ----------

func _build_ground() -> void:
	# 世界範圍 x -30..30、z -55..45;河 z 10..22 與池塘 (x<-10, z -18..2) 留空。
	var pieces := [
		[Vector3(60, 1, 23), Vector3(0, -0.5, 33.5)],
		[Vector3(40, 1, 65), Vector3(10, -0.5, -22.5)],
		[Vector3(20, 1, 37), Vector3(-20, -0.5, -36.5)],
		[Vector3(20, 1, 8), Vector3(-20, -0.5, 6)],
	]
	for p in pieces:
		add_child(WB.box_body(p[0], m_ground, p[1]))
	_build_surroundings(30.0, -55.0, 45.0, WB.tex("Ground037", 0.3, Color("c4c9b2")))
	add_child(WB.box_visual(Vector3(60, 1, 112), WB.tex("Ground037", 0.1, Color("7d8268")), Vector3(0, -4.5, -5)))


func _build_river() -> void:
	var width := RIVER_Z_MAX - RIVER_Z_MIN
	var z_mid := (RIVER_Z_MAX + RIVER_Z_MIN) * 0.5
	add_child(WB.box_visual(Vector3(60, 0.1, width), _water_material(), Vector3(0, -0.8, z_mid)))
	# 木筏:同步物理的移動平台,玩家站上去會跟著走。
	raft = AnimatableBody3D.new()
	raft.sync_to_physics = true
	raft.position = Vector3(0.0, -0.2, RAFT_CENTER_Z)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 0.4, 4.0)
	shape.shape = box
	raft.add_child(shape)
	raft.add_child(WB.box_visual(box.size, m_wood, Vector3.ZERO))
	add_child(raft)


func _build_path() -> void:
	add_child(WB.box_visual(Vector3(5, 0.06, 23), m_path, Vector3(0, 0.03, 33.5)))
	add_child(WB.box_visual(Vector3(5, 0.06, 56), m_path, Vector3(0, 0.03, -18.0)))
	add_child(WB.box_visual(Vector3(26, 0.06, 22), m_paving, Vector3(0, 0.03, -35)))
	add_child(WB.torii(Vector3(0, 0, 36)))
	for z: float in [30.0, 26.0, 6.0, -2.0, -10.0]:
		_add_lantern(Vector3(-3.6, 0, z), true)
		_add_lantern(Vector3(3.6, 0, z), true)


func _build_pond() -> void:
	add_child(WB.box_visual(Vector3(20, 0.1, 20), _water_material(), Vector3(-20, -0.8, -8)))
	add_child(WB.box_body(Vector3(5, 1, 5), m_ground, Vector3(-20, -0.5, -8)))
	for p: Vector3 in [Vector3(-12.8, -0.3, -8.0), Vector3(-15.6, -0.3, -7.2)]:
		add_child(WB.box_body(Vector3(2, 0.6, 2), m_stone, p))
	_dress_block(Vector3(-20, 0, -8), Vector2(5, 5), 0.0, 3)
	_make_source(Vector3(-20, 1.2, -7.2), Vector3(-20, 0, -9.8), Vector3(-20, 1.0, -6.4), 0.4, 0)


func _build_tower() -> void:
	# 東邊望樓:木台階一路爬上去,頂面 y=4。
	add_child(WB.box_body(Vector3(14, 4.5, 10), m_stone, Vector3(21, 1.75, -7)))
	add_child(WB.box_body(Vector3(4, 1.8, 4), m_stone_dark, Vector3(21, 0.4, 5.5)))
	add_child(WB.box_body(Vector3(4, 3.1, 4), m_stone_dark, Vector3(21, 1.05, 0)))
	_make_source(Vector3(21, 5.2, -8), Vector3(21, 4, -10.5), Vector3(21, 5.0, -6), 0.45, 1)
	_dress_block(Vector3(21, 0, -7), Vector2(14, 10), 4.0)


func _build_gate_wall() -> void:
	add_child(_make_wall(Vector3(28, 6, 1), Vector3(-16, 3, -24)))
	add_child(_make_wall(Vector3(28, 6, 1), Vector3(16, 3, -24)))
	gate_door = WB.box_body(Vector3(4, 6, 1), m_wood, Vector3(0, 3, -24))
	add_child(gate_door)


func _build_cage_puzzle() -> void:
	add_child(_make_wall(Vector3(6, 3, 0.5), Vector3(14, 1.5, -37)))
	add_child(_make_wall(Vector3(0.5, 3, 6), Vector3(11, 1.5, -34)))
	add_child(_make_wall(Vector3(0.5, 3, 6), Vector3(17, 1.5, -34)))
	cage_door = WB.box_body(Vector3(6, 3, 0.5), m_wood, Vector3(14, 1.5, -31))
	add_child(cage_door)
	_make_source(Vector3(14, 1.2, -34), Vector3(14, 0, -36.0), Vector3(14, 1.0, -29), 0.32, 2)

	var plate := Area3D.new()
	plate.position = Vector3(-15, 0.05, -32)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.5
	mesh.bottom_radius = 1.5
	mesh.height = 0.1
	mesh.radial_segments = 6
	plate.add_child(WB.mesh_instance(mesh, WB.tex("Rock064", 0.6, Color("8fc0d8")), Vector3.ZERO))
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.5
	cyl.height = 1.0
	shape.shape = cyl
	plate.add_child(shape)
	plate.body_entered.connect(_on_plate_entered)
	add_child(plate)


func _build_hall() -> void:
	hall_door = _build_shrine_hall()

	var trigger := Area3D.new()
	trigger.position = Vector3(0, 1, -48)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 2, 3)
	shape.shape = box
	trigger.add_child(shape)
	trigger.body_entered.connect(_on_hall_entered)
	add_child(trigger)


func _build_scenery() -> void:
	# 參道兩側的夏樹(扭曲樹幹 + 濃綠葉冠)。
	var rng := RandomNumberGenerator.new()
	rng.seed = SCATTER_SEED + 2
	var z_list: Array[float] = [36.0, 30.0, 5.0, -4.0, -12.0, -18.0]
	for i in z_list.size():
		var leaves := WB.leaf_material(Color("5f8a4a"))
		_make_tree(Vector3(-8.5, 0, z_list[i]), leaves, i % 4, 0.5, rng.randf_range(0.0, TAU))
		_make_tree(Vector3(9.0, 0, z_list[i] + 3.0), leaves, (i + 2) % 4, 0.5, rng.randf_range(0.0, TAU))
	_build_mountains(Color("d9cfc0"))


# ---------- 機關與流程 ----------

func _on_plate_entered(body: Node3D) -> void:
	if body != player or plate_latched:
		return
	plate_latched = true
	_move_door(cage_door, -1.6)
	_flash("石籠打開了")


func _on_hall_entered(body: Node3D) -> void:
	if body != player or completed or purified < SOURCES_TOTAL:
		return
	completed = true
	prompt_enabled = false
	msg_serial += 1
	hud_msg.text = "第二章・水之社 完"
	hud_msg.visible = true
	hud_hint.text = ""
	await get_tree().create_timer(1.8).timeout
	hud_msg.visible = false
	await _say(OUTRO_LINES)
	player.controls_locked = true
	await _fade(1.0, 1.4)
	get_tree().change_scene_to_file(NEXT_SCENE)


func _update_hud() -> void:
	hud_title.text = "第二章・水之社  淨化 %d / %d" % [purified, SOURCES_TOTAL]
	var hint := "搭木筏渡河,找出被妖氣污染的神木"
	if purified >= SOURCES_TOTAL:
		hint = _final_hint()
	elif purified >= SOURCES_FOR_GATE:
		hint = "庭院裡還有一處:踩上石板打開石籠"
	elif crossed:
		hint = "找出被妖氣污染的神木:池中的小島、東邊的望樓"
	_set_hint(hint)
