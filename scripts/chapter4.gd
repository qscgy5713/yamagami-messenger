extends LevelBase
## 第四章・雪之社(冬)白盒場景。
## 流程:雪夜三處妖氣 —— 西側被冰牆封住(點亮兩盞石燈籠融冰)、東邊爬高台、東南角踩石板開石籠 → 石門與主殿開啟。
## 新機關:點燈(靠近未點亮的石燈籠按 E)。

const SOURCES_TOTAL := 3
const KODAMA_LINES := {
	"intro": [
		{"who": "木靈", "text": "雪把我的御守都埋起來了……"},
		{"who": "木靈", "text": "冰牆裡面一枚,高台上一枚,還有一枚在遠遠的石台。"},
		{"who": "木靈", "text": "燈火一亮,御守的光也會跟著亮起來。"},
	],
	"waiting": [{"who": "木靈", "text": "雪還在下,御守還沒回來。"}],
	"done": [{"who": "木靈", "text": "御守都找齊了,雪之社的封印,我來解開。"}],
}
const BOSS_LINES := {
	"start": [
		{"who": "凍結的燈火", "text": "好冷……好安靜……"},
		{"who": "凍結的燈火", "text": "就這樣睡去吧,雪會蓋住一切。"},
	],
	"defeated": [
		{"who": "凍結的燈火", "text": "……燈,亮了。"},
		{"who": "凍結的燈火", "text": "好暖和。謝謝你,小小的神使。"},
	],
}
const OUTRO_LINES := [
	{"who": "", "text": "雪停了,石燈籠一盞一盞亮了起來。"},
	{"who": "白狐", "text": "四季的社都醒了。去山頂吧,他在等你。"},
]
const PURIFY_LINES := ["寒梅在雪裡綻開了", "高台上的老樹醒了", "最後一處的冰雪消融了"]
const NEXT_SCENE := "res://scenes/finale.tscn"
const LANTERN_RANGE := 2.2
## 雪地:草地貼圖乘上超過 1 的色,洗成近白(沒有雪的貼圖,先這樣處理)。
const SNOW_TINT := Color(1.8, 1.9, 2.1)

var gate_door: StaticBody3D
var cage_door: StaticBody3D
var hall_door: StaticBody3D
var ice_wall: StaticBody3D
var plate_latched := false
var completed := false
var gate_open := false
var snow: CPUParticles3D
var lanterns: Array[Dictionary] = []  # {lamp, light, lit}
var ice_melted := false


# ---------- 基底的覆寫 ----------

func _environment_config() -> Dictionary:
	# 雪夜:藍灰天空、冷色霧、微弱月光。
	return {
		"sky_top": Color("2f3a52"),
		"sky_horizon": Color("9aa8ba"),
		"sky_ground": Color("6f7a8c"),
		"ambient_energy": 0.6,
		"fog_color": Color("a9b5c4"),
		"fog_density": 0.012,
		"fog_sky_affect": 0.6,
		"sun_color": Color("c3d3ff"),
		"sun_energy": 0.7,
		"sun_rotation": Vector3(-35.0, -20.0, 0.0),
		"saturation": 0.75,
		"contrast": 1.05,
		"glow": false,
	}


func _bloom_color() -> Color:
	return Color("e8b7c8")  # 淨化後綻開的寒梅


func _chapter_title() -> PackedStringArray:
	return PackedStringArray(["第四章", "雪之社"])


func _purify_line(count: int) -> String:
	return PURIFY_LINES[count - 1] if count >= 1 and count <= PURIFY_LINES.size() else ""


func _start_position() -> Vector3:
	return Vector3(0.0, 1.0, 40.0)


func _burst_scale() -> Vector2:
	return Vector2(1.2, 2.2)


func _start() -> void:
	_update_hud()
	await _say([
		{"who": "", "text": "雪靜靜地落著,山裡聽不見任何聲音。"},
		{"who": "", "text": "石燈籠都熄了。也許點亮它們,凍住的東西就會鬆開。"},
	])


func _build_level() -> void:
	m_ground = WB.tex("Ground037", 0.3, SNOW_TINT)
	_build_ground()
	_build_path()
	_build_ice_enclosure()
	_build_terrace()
	_build_cage_puzzle()
	_build_gate_wall()
	_build_hall()
	_build_scenery()
	_scatter_vegetation(0.6)
	_build_quest()
	_build_snowfall()


func _is_free(p: Vector3) -> bool:
	if absf(p.x) < 4.2 and p.z > -46.0 and p.z < 42.0:
		return false
	if p.x < -9.0 and p.x > -29.0 and p.z > -3.0 and p.z < 19.0:
		return false
	if p.x > 11.0 and p.z > -14.0 and p.z < 9.0:
		return false
	if p.x > 16.0 and p.x < 28.0 and p.z > 22.0 and p.z < 33.0:
		return false
	if Vector2(p.x + 22.0, p.z - 28.0).length() < 3.5:
		return false
	if absf(p.x) < 13.5 and p.z < -24.0 and p.z > -46.0:
		return false
	if absf(p.x) < 8.5 and p.z < -43.0:
		return false
	if absf(p.z + 24.0) < 1.8:
		return false
	return true


func _build_quest() -> void:
	var dash_charm := _build_dash_platforms(Vector3(-27, 0.5, 36))
	var spots: Array[Vector3] = [Vector3(-25.0, 0.8, 5.5), Vector3(25.0, 4.8, -4.0), dash_charm]
	var seek_spots: Array[Vector3] = [Vector3(27, 0.8, 12), Vector3(-27, 0.8, -20), Vector3(28, 0.8, 38)]
	_setup_seek(seek_spots)
	var pylon_spots: Array[Vector3] = [Vector3(-8, 0, -29.5), Vector3(8, 0, -29.5), Vector3(0, 0, -42)]
	_setup_boss(Vector3(0, 3.2, -35), pylon_spots, Rect2(-13, -46, 26, 19), BOSS_LINES)
	_setup_quest(Vector3(2.4, 0.0, 32.0), spots, KODAMA_LINES)


func _on_progress_changed() -> void:
	if _all_ready() and not gate_open:
		gate_open = true
		_move_door(gate_door, -3.2)
		_flash("石門開啟了")
	_update_hud()


func _on_boss_defeated() -> void:
	_move_door(hall_door, -2.2)
	_flash("主殿的門開啟了")


func _on_source_purified(_s: LevelBase.Source) -> void:
	_on_progress_changed()


func _level_process(_delta: float) -> void:
	snow.global_position = player.global_position + Vector3(0.0, 10.0, 0.0)
	if hud_prompt.visible:
		return
	if player.controls_locked or not prompt_enabled:
		return
	var near := _nearest_unlit_lantern()
	if near.is_empty():
		return
	hud_prompt.text = "按 E 點燈"
	hud_prompt.visible = true
	if Input.is_action_just_pressed("interact"):
		_light_lantern(near)


# ---------- 地形 ----------

func _build_ground() -> void:
	add_child(WB.box_body(Vector3(60, 1, 100), m_ground, Vector3(0, -0.5, -5)))
	_build_surroundings(30.0, -55.0, 45.0, WB.tex("Ground037", 0.3, SNOW_TINT * 0.95))


func _build_path() -> void:
	_make_path(Vector3(5, 0.06, 90), Vector3(0, 0.03, -5), -23.0)
	add_child(WB.box_visual(Vector3(26, 0.06, 22), m_paving, Vector3(0, 0.03, -35)))
	_make_torii(Vector3(0, 0, 36))
	for z: float in [30.0, 20.0, 10.0, 0.0, -10.0, -18.0]:
		_add_lantern(Vector3(-3.6, 0, z), true)
		_add_lantern(Vector3(3.6, 0, z), true)


func _build_ice_enclosure() -> void:
	# 西側圍場:三面石牆 + 一面冰牆,妖氣源在裡面。冰牆要點亮兩盞石燈籠才會融化。
	add_child(_make_wall(Vector3(1, 4, 10), Vector3(-27.5, 2, 8)))
	add_child(_make_wall(Vector3(12, 4, 1), Vector3(-22, 2, 13)))
	add_child(_make_wall(Vector3(12, 4, 1), Vector3(-22, 2, 3)))
	var ice := WB.tex("Rock064", 0.35, Color("b9dcec")).duplicate() as StandardMaterial3D
	ice.roughness = 0.1
	ice.metallic = 0.3
	ice.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice.albedo_color.a = 0.6
	ice_wall = WB.box_body(Vector3(1, 4, 10), ice, Vector3(-16.5, 2, 8))
	add_child(ice_wall)
	_make_source(Vector3(-22, 1.2, 8), Vector3(-23.5, 0, 9.5), Vector3(-12, 1.0, 8), 0.4, 0)
	_add_unlit_lantern(Vector3(-12, 0, 17))
	_add_unlit_lantern(Vector3(-12, 0, -1))


func _build_terrace() -> void:
	add_child(WB.box_body(Vector3(14, 4.5, 10), m_stone, Vector3(21, 1.75, -7)))
	add_child(WB.box_body(Vector3(4, 1.8, 4), m_stone_dark, Vector3(21, 0.4, 5.5)))
	add_child(WB.box_body(Vector3(4, 3.1, 4), m_stone_dark, Vector3(21, 1.05, 0)))
	_make_source(Vector3(21, 5.2, -8), Vector3(21, 4, -10.5), Vector3(21, 5.0, -6), 0.45, 1)
	_dress_block(Vector3(21, 0, -7), Vector2(14, 10), 4.0)


func _build_cage_puzzle() -> void:
	add_child(_make_wall(Vector3(6, 3, 0.5), Vector3(22, 1.5, 31)))
	add_child(_make_wall(Vector3(0.5, 3, 6), Vector3(19, 1.5, 28)))
	add_child(_make_wall(Vector3(0.5, 3, 6), Vector3(25, 1.5, 28)))
	cage_door = WB.box_body(Vector3(6, 3, 0.5), m_wood, Vector3(22, 1.5, 25))
	add_child(cage_door)
	_make_source(Vector3(22, 1.2, 28), Vector3(22, 0, 30.0), Vector3(22, 1.0, 22), 0.32, 2)

	var plate := Area3D.new()
	plate.position = Vector3(-22, 0.05, 28)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.5
	mesh.bottom_radius = 1.5
	mesh.height = 0.1
	mesh.radial_segments = 6
	plate.add_child(WB.mesh_instance(mesh, WB.tex("Rock064", 0.6, Color("a9d4e8")), Vector3.ZERO))
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.5
	cyl.height = 1.0
	shape.shape = cyl
	plate.add_child(shape)
	plate.body_entered.connect(_on_plate_entered)
	add_child(plate)


func _build_gate_wall() -> void:
	add_child(_make_wall(Vector3(28, 6, 1), Vector3(-16, 3, -24)))
	add_child(_make_wall(Vector3(28, 6, 1), Vector3(16, 3, -24)))
	gate_door = WB.box_body(Vector3(4, 6, 1), m_wood, Vector3(0, 3, -24))
	add_child(gate_door)


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
	# 參道兩側覆雪的老樹。
	var rng := RandomNumberGenerator.new()
	rng.seed = SCATTER_SEED + 4
	var z_list: Array[float] = [36.0, 28.0, 16.0, 6.0, -4.0, -14.0]
	for i in z_list.size():
		var snowy := WB.leaf_material(Color("e6edf2"))
		_make_tree(Vector3(-8.5, 0, z_list[i]), snowy, i % 4, 0.5, rng.randf_range(0.0, TAU))
		_make_tree(Vector3(9.0, 0, z_list[i] + 3.0), snowy, (i + 2) % 4, 0.5, rng.randf_range(0.0, TAU))
	_build_mountains(Color("e4e9ee"))


func _build_snowfall() -> void:
	var flake := SphereMesh.new()
	flake.radius = 0.04
	flake.height = 0.08
	flake.radial_segments = 6
	flake.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 1, 1)
	flake.material = mat
	snow = CPUParticles3D.new()
	snow.mesh = flake
	snow.amount = 400
	snow.lifetime = 8.0
	snow.preprocess = 8.0
	snow.local_coords = false
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(18.0, 0.5, 18.0)
	snow.direction = Vector3(0.1, -1.0, 0.0)
	snow.spread = 12.0
	snow.initial_velocity_min = 0.2
	snow.initial_velocity_max = 0.8
	snow.gravity = Vector3(0.3, -1.1, 0.1)
	snow.scale_amount_min = 0.6
	snow.scale_amount_max = 1.6
	add_child(snow)


# ---------- 點燈 ----------

func _add_unlit_lantern(pos: Vector3) -> void:
	var lamp := _add_lantern(pos, false)
	var mat := lamp.material_override as StandardMaterial3D
	mat.emission_energy_multiplier = 0.0
	mat.albedo_color = Color("5b5f66")
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, 1.6, 0)
	light.light_color = Color("ffc98a")
	light.light_energy = 0.0
	light.omni_range = 7.5
	add_child(light)
	lanterns.append({"lamp": lamp, "light": light, "lit": false})


func _nearest_unlit_lantern() -> Dictionary:
	for l in lanterns:
		if not l["lit"] and player.global_position.distance_to((l["lamp"] as Node3D).global_position) < LANTERN_RANGE:
			return l
	return {}


func _light_lantern(l: Dictionary) -> void:
	l["lit"] = true
	var mat := (l["lamp"] as MeshInstance3D).material_override as StandardMaterial3D
	mat.albedo_color = WB.C_GOLD
	var tw := create_tween().set_parallel()
	tw.tween_property(mat, "emission_energy_multiplier", 2.5, 0.8)
	tw.tween_property(l["light"], "light_energy", 1.6, 0.8)
	var lit_count := 0
	for x in lanterns:
		if x["lit"]:
			lit_count += 1
	if lit_count == lanterns.size() and not ice_melted:
		ice_melted = true
		_move_door(ice_wall, -4.5)
		_flash("冰牆融化了")
	_update_hud()


# ---------- 機關與流程 ----------

func _on_plate_entered(body: Node3D) -> void:
	if body != player or plate_latched:
		return
	plate_latched = true
	_move_door(cage_door, -1.6)
	_flash("遠處傳來石籠開啟的聲音")


func _on_hall_entered(body: Node3D) -> void:
	if body != player or completed or purified < SOURCES_TOTAL:
		return
	completed = true
	prompt_enabled = false
	msg_serial += 1
	hud_msg.text = "第四章・雪之社 完"
	hud_msg.visible = true
	hud_hint.text = ""
	await get_tree().create_timer(1.8).timeout
	hud_msg.visible = false
	await _say(OUTRO_LINES)
	player.controls_locked = true
	await _fade(1.0, 1.4)
	get_tree().change_scene_to_file(NEXT_SCENE)


func _update_hud() -> void:
	hud_title.text = "第四章・雪之社  淨化 %d / %d" % [purified, SOURCES_TOTAL]
	var hint := "雪夜三處妖氣:西側被冰封(點亮兩盞石燈籠)、東邊高台、東南角石籠"
	if purified >= SOURCES_TOTAL:
		hint = _final_hint()
	elif not ice_melted:
		hint = "西側冰牆需要點亮 %d 盞石燈籠(靠近按 E)" % _unlit_count()
	_set_hint(hint)


func _unlit_count() -> int:
	var n := 0
	for l in lanterns:
		if not l["lit"]:
			n += 1
	return n
