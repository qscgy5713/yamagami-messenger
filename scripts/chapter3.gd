extends LevelBase
## 第三章・紅葉之社(秋)白盒場景。
## 流程:濃霧中的三條支線(西:石牆迷宮、東:爬高台、南:踩石板開石籠)→ 每淨化一處霧就散一些 → 全部淨化後石門與主殿同時開啟。
## 新機關:迷霧(淨化一處降低一次 fog_density)。

const SOURCES_TOTAL := 3
const KODAMA_LINES := {
	"intro": [
		{"who": "木靈", "text": "霧這麼濃,我找不到我的御守了……"},
		{"who": "木靈", "text": "聽說有一枚掉進了石牆迷宮,一枚在東邊高台,另一枚在兩座隔得很遠的石台上。"},
		{"who": "木靈", "text": "神使大人,嗅覺能穿過霧,試試按住 Q。"},
	],
	"waiting": [{"who": "木靈", "text": "霧還沒散盡,御守還在外頭等著呢。"}],
	"done": [{"who": "木靈", "text": "找到了!紅葉之社的封印,現在可以解開了。"}],
}
const BOSS_LINES := {
	"start": [
		{"who": "霧中的回憶", "text": "不要往前走了……前面什麼都沒有。"},
		{"who": "霧中的回憶", "text": "忘記不好嗎?那些事,都忘了吧。"},
	],
	"defeated": [
		{"who": "霧中的回憶", "text": "……霧散了,我想起來了。"},
		{"who": "霧中的回憶", "text": "原來我也曾是這座山的一部分。"},
	],
}
const OUTRO_LINES := [
	{"who": "", "text": "霧散了,楓葉在風裡輕輕搖晃。"},
	{"who": "白狐", "text": "最後的社在雪裡,那裡的燈火都熄了。點亮它們,冰封的東西就會鬆開。"},
]
const PURIFY_LINES := ["霧散了一些", "霧又淡了", "霧完全散去了"]
const NEXT_SCENE := "res://scenes/chapter4.tscn"
const FOG_START := 0.03
const FOG_STEP := 0.008

var gate_door: StaticBody3D
var cage_door: StaticBody3D
var hall_door: StaticBody3D
var plate_latched := false
var leaf_fall: CPUParticles3D
var completed := false
var gate_open := false


# ---------- 基底的覆寫 ----------

func _environment_config() -> Dictionary:
	# 秋日午後的濃霧:灰褐色天空、低飽和暖光,霧很濃、可視距離短。
	return {
		"sky_top": Color("8a8f98"),
		"sky_horizon": Color("d3b99c"),
		"sky_ground": Color("a89a88"),
		"ambient_energy": 0.5,
		"fog_color": Color("c9b09a"),
		"fog_density": FOG_START,
		"fog_sky_affect": 0.8,
		"sun_color": Color("ffd2a0"),
		"sun_energy": 0.8,
		"sun_rotation": Vector3(-28.0, 40.0, 0.0),
		"saturation": 0.9,
	}


func _bloom_color() -> Color:
	return Color("c4552f")


func _chapter_title() -> PackedStringArray:
	return PackedStringArray(["第三章", "紅葉之社"])


func _purify_line(count: int) -> String:
	return PURIFY_LINES[count - 1] if count >= 1 and count <= PURIFY_LINES.size() else ""


func _start_position() -> Vector3:
	return Vector3(0.0, 1.0, 40.0)


func _start() -> void:
	_update_hud()
	await _say([
		{"who": "", "text": "山裡的楓葉紅了,霧卻濃得看不清前路。"},
		{"who": "", "text": "沿著點亮的石燈籠走,霧會隨著神木的淨化慢慢散去。"},
	])


func _build_level() -> void:
	m_ground = WB.tex("Ground037", 0.3, Color("d2bf94"))
	_build_ground()
	_build_path()
	_build_maze()
	_build_terrace()
	_build_cage_puzzle()
	_build_gate_wall()
	_build_hall()
	_build_scenery()
	_scatter_vegetation()
	_build_quest()
	_build_leaf_fall()


func _is_free(p: Vector3) -> bool:
	if absf(p.x) < 4.2 and p.z > -46.0 and p.z < 42.0:
		return false
	if p.x < -7.0 and p.x > -29.0 and p.z > -13.0 and p.z < 10.0:
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


func _burst_scale() -> Vector2:
	return Vector2(0.5, 0.9)


func _petal_mesh() -> Mesh:
	return WB.leaf_mesh(_bloom_color())


func _build_leaf_fall() -> void:
	## 玩家周圍持續飄落的楓葉:紅 / 橙 / 黃隨機、大小不一、邊落邊旋轉。
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color("b5432b"), Color("c9692f"), Color("d4a24a"), Color("8f3a28")])
	leaf_fall = CPUParticles3D.new()
	leaf_fall.mesh = WB.leaf_mesh(Color.WHITE, true)
	leaf_fall.amount = 70
	leaf_fall.lifetime = 8.0
	leaf_fall.preprocess = 8.0
	leaf_fall.local_coords = false
	leaf_fall.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	leaf_fall.emission_box_extents = Vector3(14.0, 0.5, 14.0)
	leaf_fall.direction = Vector3(1.0, -0.2, 0.3)
	leaf_fall.spread = 35.0
	leaf_fall.initial_velocity_min = 0.3
	leaf_fall.initial_velocity_max = 1.2
	leaf_fall.gravity = Vector3(0.3, -0.9, 0.1)
	leaf_fall.damping_min = 0.4
	leaf_fall.damping_max = 1.0
	leaf_fall.angle_min = 0.0
	leaf_fall.angle_max = 360.0
	leaf_fall.angular_velocity_min = -120.0
	leaf_fall.angular_velocity_max = 120.0
	leaf_fall.scale_amount_min = 0.6
	leaf_fall.scale_amount_max = 1.1
	leaf_fall.color_initial_ramp = ramp
	add_child(leaf_fall)


func _level_process(_delta: float) -> void:
	leaf_fall.global_position = player.global_position + Vector3(0.0, 9.0, 0.0)


func _build_quest() -> void:
	var dash_charm := _build_dash_platforms(Vector3(-27, 0.5, 36))
	var spots: Array[Vector3] = [Vector3(-18.0, 0.8, 0.0), Vector3(25.0, 4.8, -4.0), dash_charm]
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
	_set_fog(FOG_START - FOG_STEP * purified)
	_on_progress_changed()


# ---------- 地形 ----------

func _build_ground() -> void:
	add_child(WB.box_body(Vector3(60, 1, 100), m_ground, Vector3(0, -0.5, -5)))
	_build_surroundings(30.0, -55.0, 45.0, WB.tex("Ground037", 0.3, Color("c2b48e")))


func _build_path() -> void:
	_make_path(Vector3(5, 0.06, 90), Vector3(0, 0.03, -5), -23.0)
	add_child(WB.box_visual(Vector3(26, 0.06, 22), m_paving, Vector3(0, 0.03, -35)))
	_make_torii(Vector3(0, 0, 36))
	for z: float in [30.0, 20.0, 10.0, 0.0, -10.0, -18.0]:
		_add_lantern(Vector3(-3.6, 0, z), true)
		_add_lantern(Vector3(3.6, 0, z), true)


func _build_maze() -> void:
	# 西側石牆迷宮:兩道牆缺口錯開(東端 → 西端),妖氣源在最後一格;缺口處點亮石燈籠指路。
	add_child(_make_wall(Vector3(15, 4, 1), Vector3(-20.5, 2, 4)))
	add_child(_make_wall(Vector3(15, 4, 1), Vector3(-15.5, 2, -4)))
	add_child(_make_wall(Vector3(1, 4, 24), Vector3(-28.5, 2, -4)))
	_add_lantern(Vector3(-10.5, 0, 6.0), true)
	_add_lantern(Vector3(-25.5, 0, 0.0), true)
	_add_lantern(Vector3(-12.0, 0, -8.0), true)
	_make_source(Vector3(-18, 1.2, -10), Vector3(-18, 0, -11.5), Vector3(-10.5, 1.0, 8.0), 0.4, 0)


func _build_terrace() -> void:
	add_child(WB.box_body(Vector3(14, 4.5, 10), m_stone, Vector3(21, 1.75, -7)))
	add_child(WB.box_body(Vector3(4, 1.8, 4), m_stone_dark, Vector3(21, 0.4, 5.5)))
	add_child(WB.box_body(Vector3(4, 3.1, 4), m_stone_dark, Vector3(21, 1.05, 0)))
	_make_source(Vector3(21, 5.2, -8), Vector3(21, 4, -10.5), Vector3(21, 5.0, -6), 0.45, 1)
	_dress_block(Vector3(21, 0, -7), Vector2(14, 10), 4.0)


func _build_cage_puzzle() -> void:
	# 東南角的石籠;石板在西南角,霧中得自己找。
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
	plate.add_child(WB.mesh_instance(mesh, WB.tex("Rock064", 0.6, Color("d9a66a")), Vector3.ZERO))
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.5
	cyl.height = 1.0
	shape.shape = cyl
	plate.add_child(shape)
	plate.body_entered.connect(_on_plate_entered)
	add_child(plate)
	_add_lantern(Vector3(-22, 0, 25.0), true)


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
	# 參道兩側的楓樹:紅、橙、黃交錯。
	var rng := RandomNumberGenerator.new()
	rng.seed = SCATTER_SEED + 3
	var tints: Array[Color] = [Color("b5532e"), Color("c98a3a"), Color("a8432b"), Color("d4a24a")]
	var z_list: Array[float] = [36.0, 28.0, 16.0, 6.0, -4.0, -14.0]
	for i in z_list.size():
		_make_tree(Vector3(-8.5, 0, z_list[i]), WB.leaf_material(tints[i % 4]), i % 4, 0.5, rng.randf_range(0.0, TAU))
		_make_tree(Vector3(9.0, 0, z_list[i] + 3.0), WB.leaf_material(tints[(i + 1) % 4]), (i + 2) % 4, 0.5, rng.randf_range(0.0, TAU))
	_build_mountains(Color("cdbfae"))


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
	hud_msg.text = "第三章・紅葉之社 完"
	hud_msg.visible = true
	hud_hint.text = ""
	await get_tree().create_timer(1.8).timeout
	hud_msg.visible = false
	await _say(OUTRO_LINES)
	player.controls_locked = true
	await _fade(1.0, 1.4)
	get_tree().change_scene_to_file(NEXT_SCENE)


func _update_hud() -> void:
	hud_title.text = "第三章・紅葉之社  淨化 %d / %d" % [purified, SOURCES_TOTAL]
	var hint := "霧中有三處妖氣:西邊石牆迷宮、東邊高台、東南角的石籠"
	if purified >= SOURCES_TOTAL:
		hint = _final_hint()
	elif plate_latched:
		hint = "石籠已打開;還有 %d 處妖氣" % (SOURCES_TOTAL - purified)
	elif purified > 0:
		hint = "還有 %d 處妖氣;石籠的石板在西南角" % (SOURCES_TOTAL - purified)
	_set_hint(hint)
