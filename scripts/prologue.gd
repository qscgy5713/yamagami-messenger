extends LevelBase
## 序章・春夜:教學關。依序教移動 → 跳躍 → 淨化,山頂與白狐長老對話、獲得神使之印,穿過鳥居進入第一章。

const NEXT_SCENE := "res://scenes/chapter1.tscn"
const LEDGE_Z := 2.0  ## z < LEDGE_Z 為較高的上層地面
const UPPER_Y := 1.2
const MOVE_GOAL := Vector3(0.0, 1.0, 8.0)
const ELDER_POS := Vector3(0.0, UPPER_Y, -32.0)
const PORTAL_Z := -46.0
const MOON_POS := Vector3(-50.0, 48.0, -140.0)

const INTRO_LINES := [
	{"who": "", "text": "春夜。山裡的神社,已經很久沒有人點燈了。"},
	{"who": "", "text": "山神沉睡之後,妖氣沿著山徑一點一點滲進來,連櫻花也忘了怎麼綻放。"},
	{"who": "???", "text": "……小小的孩子……你聽得見我嗎……"},
	{"who": "???", "text": "到神社來吧……沿著燈火,往山上走……"},
]
const PURIFY_HINT_LINES := [
	{"who": "???", "text": "那棵樹被妖氣纏住了……靠近它,用你的力量,把它淨化吧。"},
]
const PURIFIED_LINES := [
	{"who": "???", "text": "很好……你果然擁有神使的資質。"},
	{"who": "???", "text": "再往山上走,我在神社等你。"},
]
const ELDER_LINES := [
	{"who": "白狐", "text": "你終於來了,小小的孩子。我是這座神社的守護者,山神大人的使者——或者說,最後一位使者。"},
	{"who": "白狐", "text": "山神大人為了封住山底湧出的妖氣,耗盡了力量,沉沉睡去。妖氣趁機侵蝕山中的神木,四季也跟著停住了。"},
	{"who": "白狐", "text": "只有神使,能用靈光淨化被污染的神木,喚回四季,讓山神大人醒來。"},
	{"who": "白狐", "text": "我已經老了,走不動了。所以,我把這份力量,託付給你。"},
	{"who": "", "text": "白狐額上的光點輕輕飄起,落在你的額前。你獲得了【神使之印】。"},
	{"who": "白狐", "text": "第一處,是山下的櫻之社。春天的神木,就從那裡開始吧。"},
	{"who": "白狐", "text": "鳥居已經打開了。去吧——我會在這裡,等你回來。"},
]

var elder: Node3D
var portal_block: StaticBody3D
var portal_glow: MeshInstance3D
var portal_light: OmniLight3D


# ---------- 基底的覆寫 ----------

func _environment_config() -> Dictionary:
	# 春夜:冷色月光、深藍天空、濃霧;發光物件加 glow。
	return {
		"sky_top": Color("0b1530"),
		"sky_horizon": Color("2c3a5a"),
		"sky_ground": Color("141c2e"),
		"ambient_energy": 0.35,
		"fog_color": Color("1d2840"),
		"fog_density": 0.014,
		"fog_sky_affect": 0.5,
		"sun_color": Color("9db4ff"),
		"sun_energy": 0.55,
		"sun_rotation": Vector3(-38.0, 30.0, 0.0),
		"saturation": 0.85,
		"contrast": 1.12,
		"glow": true,
	}


func _start_position() -> Vector3:
	return Vector3(0.0, 1.0, 38.0)


func _scatter_bounds() -> Rect2:
	return Rect2(-29.0, -57.0, 58.0, 96.0)


func _ground_y(p: Vector3) -> float:
	return UPPER_Y if p.z < LEDGE_Z else 0.0


func _is_free(p: Vector3) -> bool:
	if absf(p.x) < 4.2:
		return false  # 參道
	if absf(p.z - LEDGE_Z) < 2.0:
		return false  # 石階邊緣
	if p.x > -15.0 and p.x < -4.0 and p.z < -29.0 and p.z > -42.0:
		return false  # 小神社
	if absf(p.x) < 9.0 and p.z < -40.0:
		return false  # 鳥居前
	if absf(p.x) < 8.0 and p.z > -35.0 and p.z < -29.0:
		return false  # 長老周圍
	return true


func _build_level() -> void:
	_build_ground()
	_build_path()
	_build_forest()
	_build_shrine()
	_build_portal()
	_build_sky_and_fireflies()
	_scatter_vegetation(0.9)
	_make_source(Vector3(2.0, UPPER_Y + 1.5, -15.0), Vector3(3.2, UPPER_Y, -16.5),
			Vector3(0.0, UPPER_Y + 1.0, -12.0), 0.45, 2)
	_spawn_elder()


func _on_source_purified(_s: LevelBase.Source) -> void:
	pass  # 流程由 _run() 以 _wait_until 等待


func _start() -> void:
	hud_title.text = "序章・春夜"
	hud_hint.text = ""
	var help := WB.label(hud_title.get_parent(), 16)
	help.text = "WASD / 方向鍵 移動    空白 跳躍    E 互動"
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.offset_left = 24.0
	help.offset_top = -40.0
	help.modulate = Color(1, 1, 1, 0.75)
	_run()


# ---------- 教學流程 ----------

func _run() -> void:
	await get_tree().create_timer(1.4).timeout
	await _say(INTRO_LINES)

	# 1. 移動
	_set_objective("用 W A S D 或方向鍵移動,走向前方發光的石燈籠")
	await _wait_until(func() -> bool: return player.global_position.distance_to(MOVE_GOAL) < 3.0)
	_flash("很好")

	# 2. 跳躍
	_set_objective("按 空白鍵 跳上前方的石階")
	await _wait_until(func() -> bool:
		return player.global_position.z < LEDGE_Z - 1.0 and player.global_position.y > UPPER_Y - 0.2 and player.is_on_floor())
	_flash("跳得很好")

	# 3. 淨化
	_set_objective("沿著燈火往山上走,靠近紫色的靈光")
	await _wait_until(func() -> bool: return player.global_position.z < -6.0)
	await _say(PURIFY_HINT_LINES)
	_set_objective("靠近紫色的靈光,按 E 淨化枯樹")
	await _wait_until(func() -> bool: return purified >= 1)
	_flash("枯樹開花了")
	await get_tree().create_timer(1.6).timeout
	await _say(PURIFIED_LINES)

	# 4. 長老
	_set_objective("前往山頂的神社")
	await _wait_until(func() -> bool: return player.global_position.distance_to(ELDER_POS) < 5.5)
	await _say(ELDER_LINES)
	_flash("獲得【神使之印】")
	_open_portal()

	# 5. 前往第一章
	_set_objective("穿過鳥居,前往櫻之社")
	await _wait_until(func() -> bool:
		return absf(player.global_position.x) < 3.5 and player.global_position.z < PORTAL_Z + 0.5)
	player.controls_locked = true
	await _fade(1.0, 1.4)
	get_tree().change_scene_to_file(NEXT_SCENE)


func _set_objective(text: String) -> void:
	hud_hint.text = text


# ---------- 地形與場景 ----------

func _build_ground() -> void:
	# 下層(z 2..40,頂面 y=0)與上層(z -58..2,頂面 y=1.2),中間以石階牆區隔,需要跳上去。
	add_child(WB.box_body(Vector3(60, 1, 38), m_ground, Vector3(0, -0.5, 21)))
	add_child(WB.box_body(Vector3(60, 2.2, 60), m_ground, Vector3(0, UPPER_Y - 1.1, -28)))
	add_child(WB.box_body(Vector3(60, UPPER_Y, 0.6), m_stone, Vector3(0, UPPER_Y * 0.5, LEDGE_Z + 0.3)))
	_build_surroundings(30.0, -58.0, 40.0, WB.tex("Ground037", 0.3, Color("a9ae98")))
	_build_mountains(Color("5a6a8a"))


func _build_path() -> void:
	add_child(WB.box_visual(Vector3(5, 0.06, 38), m_path, Vector3(0, 0.03, 21)))
	add_child(WB.box_visual(Vector3(5, 0.06, 60), m_path, Vector3(0, UPPER_Y + 0.03, -28)))
	add_child(WB.box_visual(Vector3(18, 0.06, 14), m_paving, Vector3(0, UPPER_Y + 0.04, -34)))
	# 沿路點亮的石燈籠(第一對在移動目標旁)。
	for z: float in [30.0, 20.0, 8.0]:
		_add_lantern(Vector3(-3.4, 0.0, z), true)
		_add_lantern(Vector3(3.4, 0.0, z), true)
	for z: float in [-8.0, -20.0, -28.0]:
		_add_lantern(Vector3(-3.4, UPPER_Y, z), true)
		_add_lantern(Vector3(3.4, UPPER_Y, z), true)


func _build_forest() -> void:
	# 兩側的枯樹林(灰紫的葉子,還沒有開花),把參道框成一條小徑。
	var rng := RandomNumberGenerator.new()
	rng.seed = SCATTER_SEED + 7
	var leaves := WB.leaf_material(WB.C_WILTED)
	var z := 36.0
	var i := 0
	while z > -52.0:
		for side: float in [-1.0, 1.0]:
			var x := side * rng.randf_range(8.0, 22.0)
			var pos := Vector3(x, _ground_y(Vector3(x, 0.0, z)), z + rng.randf_range(-2.5, 2.5))
			if _is_free(pos):
				_make_tree(pos, leaves, i, rng.randf_range(0.5, 0.7), rng.randf_range(0.0, TAU))
			i += 1
		z -= rng.randf_range(5.0, 8.0)


func _build_shrine() -> void:
	# 破舊的小神社:石基座 + 朱紅牆 + 瓦屋頂。
	var base_y := UPPER_Y
	add_child(WB.box_body(Vector3(8, 0.5, 6.5), m_stone, Vector3(-10, base_y + 0.25, -36)))
	add_child(WB.box_body(Vector3(5.5, 3.2, 4.2), m_paint_red, Vector3(-10, base_y + 0.5 + 1.6, -36)))
	add_child(WB.box_body(Vector3(7.6, 0.7, 6.0), m_roof, Vector3(-10, base_y + 0.5 + 3.2 + 0.35, -36)))
	add_child(WB.box_visual(Vector3(1.6, 2.2, 0.2), WB.material(WB.C_SUMI), Vector3(-10, base_y + 0.5 + 1.1, -33.85)))
	_add_lantern(Vector3(-5.5, base_y, -33.0), true)
	_add_lantern(Vector3(5.5, base_y, -33.0), true)


func _build_portal() -> void:
	# 通往第一章的鳥居:未開啟時以不可見的牆擋住,長老對話結束後亮起。
	add_child(WB.torii(Vector3(0.0, UPPER_Y, PORTAL_Z), 0.8))
	portal_block = WB.invisible_wall(Vector3(9.0, 8.0, 0.8), Vector3(0.0, UPPER_Y + 4.0, PORTAL_Z))
	add_child(portal_block)

	var quad := QuadMesh.new()
	quad.size = Vector2(5.0, 4.4)
	# 邊緣羽化的放射漸層,避免變成一整塊實心白面。
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([Color(0.7, 0.85, 1.0, 0.55), Color(0.55, 0.75, 1.0, 0.25), Color(0.5, 0.7, 1.0, 0.0)])
	var glow_tex := GradientTexture2D.new()
	glow_tex.gradient = grad
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5)
	glow_tex.fill_to = Vector2(1.0, 0.5)
	glow_tex.width = 128
	glow_tex.height = 128
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = glow_tex
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_fog = true
	mat.albedo_color = Color(1, 1, 1, 0.0)
	portal_glow = WB.mesh_instance(quad, mat, Vector3(0.0, UPPER_Y + 3.0, PORTAL_Z))
	add_child(portal_glow)

	portal_light = OmniLight3D.new()
	portal_light.position = Vector3(0.0, UPPER_Y + 2.5, PORTAL_Z + 1.5)
	portal_light.light_color = Color("a9c8ff")
	portal_light.light_energy = 0.0
	portal_light.omni_range = 12.0
	add_child(portal_light)


func _open_portal() -> void:
	portal_block.get_child(0).set_deferred("disabled", true)
	var mat := portal_glow.material_override as StandardMaterial3D
	var tw := create_tween().set_parallel()
	tw.tween_property(mat, "albedo_color:a", 1.0, 1.6)
	tw.tween_property(portal_light, "light_energy", 2.2, 1.6)


func _spawn_elder() -> void:
	# 白狐長老:同一個狐狸模型,染成銀白並帶一點冷光。
	elder = (load(Player.FOX_SCENE) as PackedScene).instantiate() as Node3D
	elder.position = ELDER_POS
	elder.scale = Vector3.ONE * 0.7  # 朝 +Z(面向從南邊走來的玩家)
	add_child(elder)
	var coat := WB.material(Color("e9e6f2"), true, 0.35)
	var light_coat := WB.material(Color("ffffff"), true, 0.6)
	_recolor_fox(elder, coat, light_coat)
	var ap := elder.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap != null:
		ap.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
		ap.play("Idle")
	var aura := OmniLight3D.new()
	aura.position = ELDER_POS + Vector3(0.0, 1.6, 0.8)
	aura.light_color = Color("b9ccff")
	aura.light_energy = 1.6
	aura.omni_range = 8.0
	add_child(aura)


func _recolor_fox(node: Node, coat: Material, light_coat: Material) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m == null:
				continue
			if m.resource_name == "Main":
				mi.set_surface_override_material(i, coat)
			elif m.resource_name == "Main_Light":
				mi.set_surface_override_material(i, light_coat)
	for c in node.get_children():
		_recolor_fox(c, coat, light_coat)


func _build_sky_and_fireflies() -> void:
	# 月亮(不受霧影響的發光球)與飄浮的螢火蟲。
	var moon := SphereMesh.new()
	moon.radius = 7.0
	moon.height = 14.0
	var moon_mat := StandardMaterial3D.new()
	moon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon_mat.albedo_color = Color("f3efe0")
	moon_mat.disable_fog = true
	add_child(WB.mesh_instance(moon, moon_mat, MOON_POS))

	var fly_mesh := SphereMesh.new()
	fly_mesh.radius = 0.06
	fly_mesh.height = 0.12
	fly_mesh.radial_segments = 6
	fly_mesh.rings = 3
	var fly_mat := WB.material(Color("d8ff9a"), true, 4.0)
	fly_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fly_mesh.material = fly_mat
	var flies := CPUParticles3D.new()
	flies.position = Vector3(0.0, 2.2, -8.0)
	flies.mesh = fly_mesh
	flies.amount = 90
	flies.lifetime = 7.0
	flies.preprocess = 7.0
	flies.direction = Vector3.UP
	flies.spread = 180.0
	flies.initial_velocity_min = 0.2
	flies.initial_velocity_max = 0.7
	flies.gravity = Vector3.ZERO
	flies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flies.emission_box_extents = Vector3(26.0, 1.8, 50.0)
	add_child(flies)
