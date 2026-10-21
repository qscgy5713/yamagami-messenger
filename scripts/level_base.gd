class_name LevelBase
extends Node3D
## 關卡共用邏輯:環境、材質、玩家與鏡頭、HUD、對話、轉場、妖氣源、樹木與植被。
## 子類別實作虛擬函式(_environment_config、_build_level、_start …),_ready 流程由這裡統一。

class Source:
	var orb: MeshInstance3D
	var base_y: float
	var leaf_mat: StandardMaterial3D
	var petals: CPUParticles3D
	var checkpoint: Vector3
	var done := false

const CAMERA_OFFSET := Vector3(0.0, 6.5, 7.5)
const INTERACT_RANGE := 2.5
const FALL_Y := -3.0
const SCATTER_SEED := 20261021
const ENV_DEFAULT := {
	"sky_top": Color("9fb0bd"),
	"sky_horizon": Color("e6dfd2"),
	"sky_ground": Color("c9c6bb"),
	"ambient_energy": 0.5,
	"fog_color": Color("cfcdc1"),
	"fog_density": 0.006,
	"fog_sky_affect": 0.4,
	"sun_color": Color("ffe2bd"),
	"sun_energy": 0.9,
	"sun_rotation": Vector3(-32.0, -35.0, 0.0),
	"saturation": 0.9,
	"contrast": 1.1,
	"glow": false,
}

var player: Player
var camera: Camera3D
var dialogue: Dialogue
var sources: Array[Source] = []
var purified := 0
var respawn_pos := Vector3.ZERO
var time := 0.0
var msg_serial := 0
var scene_cache := {}
var world_env: Environment
var _faded: Dictionary = {}  # 目前被鏡頭擋住而半透明的 GeometryInstance3D
var prompt_enabled := true

var hud_title: Label
var hud_hint: Label
var hud_prompt: Label
var hud_msg: Label
var fade_rect: ColorRect

# 貼圖材質(各關卡共用)。
var m_ground: Material
var m_path: Material
var m_paving: Material
var m_stone: Material
var m_stone_dark: Material
var m_wood: Material
var m_paint_red: Material
var m_roof: Material


# ---------- 子類別覆寫 ----------

func _environment_config() -> Dictionary:
	return {}


func _start_position() -> Vector3:
	return Vector3(0.0, 1.0, 0.0)


func _build_level() -> void:
	pass


func _start() -> void:
	pass


func _level_process(_delta: float) -> void:
	pass


func _on_source_purified(_s: Source) -> void:
	pass


func _ground_y(_p: Vector3) -> float:
	return 0.0


func _is_free(_p: Vector3) -> bool:
	return true


func _bloom_color() -> Color:
	## 淨化後神木葉色與花瓣顏色(春:櫻色;夏:新綠)。
	return WB.C_SAKURA


func _scatter_bounds() -> Rect2:
	return Rect2(-29.0, -54.0, 58.0, 98.0)


# ---------- 流程 ----------

func _ready() -> void:
	WB.setup_input()
	_setup_materials()
	_setup_environment()
	_build_level()
	_build_player()
	_build_hud()
	_fade(0.0, 1.2)
	_start()


func _process(delta: float) -> void:
	time += delta
	camera.global_position = player.global_position + CAMERA_OFFSET
	camera.look_at(player.global_position + Vector3.UP, Vector3.UP)
	_update_occlusion()

	if player.global_position.y < FALL_Y:
		player.global_position = respawn_pos
		player.velocity = Vector3.ZERO

	var nearest: Source = null
	for s in sources:
		if s.done:
			continue
		s.orb.position.y = s.base_y + sin(time * 2.0) * 0.15
		if nearest == null and player.global_position.distance_to(s.orb.global_position) < INTERACT_RANGE:
			nearest = s
	var can_purify := nearest != null and prompt_enabled and not player.controls_locked
	hud_prompt.visible = can_purify
	if can_purify and Input.is_action_just_pressed("interact"):
		_purify(nearest)

	_level_process(delta)


# ---------- 鏡頭遮擋 ----------

func _update_occlusion() -> void:
	## 鏡頭到玩家之間若有牆 / 高台等靜態物件擋住,就把它們變半透明,不讓角色被遮住。
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var to := player.global_position + Vector3.UP * 0.8
	var exclude: Array[RID] = [player.get_rid()]
	var blocking: Dictionary = {}
	for _i in 4:
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		var body := hit["collider"] as Node
		exclude.append(hit["rid"])
		if body is StaticBody3D:
			for c in body.get_children():
				if c is GeometryInstance3D:
					blocking[c] = true
	for g: GeometryInstance3D in _faded.keys():
		if is_instance_valid(g) and not blocking.has(g):
			g.transparency = 0.0
	for g: GeometryInstance3D in blocking.keys():
		g.transparency = 0.82
	_faded = blocking


# ---------- 材質與環境 ----------

func _setup_materials() -> void:
	m_ground = WB.tex("Ground037", 0.3, Color("d6dcc6"))
	m_path = WB.tex("Pathway004", 0.4)
	m_paving = WB.tex("PavingStones138", 0.5)
	m_stone = WB.tex("Rock064", 0.4)
	m_stone_dark = WB.tex("Rock064", 0.4, Color("a9a9a9"))
	m_wood = WB.tex("WoodFloor064", 0.5)
	m_paint_red = WB.tex("WoodFloor064", 0.5, Color("e0654a"))
	m_roof = WB.tex("RoofingTiles013A", 0.5, Color("8a8a92"))


func _setup_environment() -> void:
	var cfg: Dictionary = ENV_DEFAULT.merged(_environment_config(), true)

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = cfg["sky_top"]
	sky_mat.sky_horizon_color = cfg["sky_horizon"]
	sky_mat.ground_horizon_color = cfg["sky_horizon"]
	sky_mat.ground_bottom_color = cfg["sky_ground"]
	sky_mat.sun_angle_max = 8.0
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = cfg["ambient_energy"]
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_saturation = cfg["saturation"]
	env.adjustment_contrast = cfg["contrast"]
	env.fog_enabled = true
	env.fog_light_color = cfg["fog_color"]
	env.fog_density = cfg["fog_density"]
	env.fog_sky_affect = cfg["fog_sky_affect"]
	if cfg["glow"]:
		env.glow_enabled = true
		env.glow_intensity = 0.9
		env.glow_hdr_threshold = 0.9
	world_env = env
	var world_env_node := WorldEnvironment.new()
	world_env_node.environment = env
	add_child(world_env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = cfg["sun_rotation"]
	sun.light_color = cfg["sun_color"]
	sun.light_energy = cfg["sun_energy"]
	sun.shadow_enabled = true
	add_child(sun)

	camera = Camera3D.new()
	camera.far = 400.0
	add_child(camera)


func _build_surroundings(x_half: float, z_min: float, z_max: float, outer_mat: Material) -> void:
	## 世界四周以同材質延伸(不像漂浮的方塊),外加不可見的邊界牆。
	var depth := z_max - z_min
	var z_mid := (z_min + z_max) * 0.5
	add_child(WB.box_visual(Vector3(400, 1, 150), outer_mat, Vector3(0, -0.52, z_max + 75.0)))
	add_child(WB.box_visual(Vector3(400, 1, 150), outer_mat, Vector3(0, -0.52, z_min - 75.0)))
	add_child(WB.box_visual(Vector3(150, 1, depth), outer_mat, Vector3(x_half + 75.0, -0.52, z_mid)))
	add_child(WB.box_visual(Vector3(150, 1, depth), outer_mat, Vector3(-x_half - 75.0, -0.52, z_mid)))
	add_child(WB.invisible_wall(Vector3(1, 12, depth + 10.0), Vector3(-x_half - 0.5, 6, z_mid)))
	add_child(WB.invisible_wall(Vector3(1, 12, depth + 10.0), Vector3(x_half + 0.5, 6, z_mid)))
	add_child(WB.invisible_wall(Vector3(x_half * 2.0 + 2.0, 12, 1), Vector3(0, 6, z_max + 0.5)))
	add_child(WB.invisible_wall(Vector3(x_half * 2.0 + 2.0, 12, 1), Vector3(0, 6, z_min - 0.5)))


func _build_mountains(tint_far: Color = Color("e6dfd2")) -> void:
	## 遠山剪影:越遠越淡,營造層次。
	var layers := [[-85.0, 0.0, 34.0], [-120.0, 0.35, 48.0], [-160.0, 0.6, 62.0]]
	for l in layers:
		var tint := WB.C_MOUNTAIN.lerp(tint_far, l[1])
		for x: float in [-90.0, -30.0, 30.0, 90.0]:
			var peak := CylinderMesh.new()
			peak.top_radius = 0.0
			peak.bottom_radius = l[2] * 1.2
			peak.height = l[2]
			peak.radial_segments = 5
			peak.rings = 1
			add_child(WB.mesh_instance(peak, WB.material(tint), Vector3(x + l[0] * 0.15, l[2] * 0.5 - 2.0, l[0])))


# ---------- 玩家、HUD、對話、轉場 ----------

func _build_player() -> void:
	player = Player.new()
	player.position = _start_position()
	player.camera = camera
	respawn_pos = _start_position()
	add_child(player)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud_title = WB.label(layer, 28)
	hud_title.position = Vector2(24, 16)
	hud_hint = WB.label(layer, 18)
	hud_hint.position = Vector2(24, 60)
	hud_prompt = WB.label(layer, 24)
	hud_prompt.text = "按 E 淨化"
	hud_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hud_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud_prompt.offset_top = -140.0
	hud_prompt.visible = false
	hud_msg = WB.label(layer, 44)
	hud_msg.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hud_msg.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud_msg.visible = false

	dialogue = Dialogue.new()
	add_child(dialogue)

	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 20
	add_child(fade_layer)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.02, 0.02, 0.04, 1.0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade_rect)


func _fade(to_alpha: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", to_alpha, duration)
	await tw.finished


func _flash(text: String) -> void:
	msg_serial += 1
	var serial := msg_serial
	hud_msg.text = text
	hud_msg.visible = true
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if serial == msg_serial:
			hud_msg.visible = false)


func _say(lines: Array) -> void:
	## 播放對話並等到結束;期間鎖住玩家操作。
	player.controls_locked = true
	dialogue.play(lines)
	await dialogue.finished
	await get_tree().process_frame  # 避免關閉對話的按鍵同時觸發跳躍
	player.controls_locked = false


func _wait_until(cond: Callable) -> void:
	while not cond.call():
		await get_tree().process_frame


func _set_fog(density: float, duration: float = 1.5) -> void:
	create_tween().tween_property(world_env, "fog_density", density, duration)


func _move_door(door: Node3D, target_y: float) -> void:
	create_tween().tween_property(door, "position:y", target_y, 0.9)


# ---------- 樹木、植被、燈籠 ----------

func _load_scene(model: String) -> PackedScene:
	if not scene_cache.has(model):
		scene_cache[model] = load(WB.NATURE_DIR + model + ".gltf")
	return scene_cache[model]


func _swap_leaf_material(node: Node, leaf_mat: Material) -> void:
	## 把模型上名為 Leaves* 的表面換成自訂(可染色)葉片材質。
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m != null and m.resource_name.begins_with("Leaves"):
				mi.set_surface_override_material(i, leaf_mat)
	for c in node.get_children():
		_swap_leaf_material(c, leaf_mat)


func _make_tree(pos: Vector3, leaf_mat: Material, variant: int, tree_scale: float, rot_y: float) -> void:
	var tree := _load_scene("TwistedTree_%d" % (variant % 4 + 1)).instantiate() as Node3D
	tree.position = pos
	tree.rotation.y = rot_y
	tree.scale = Vector3.ONE * tree_scale
	_swap_leaf_material(tree, leaf_mat)
	add_child(tree)
	# 樹幹碰撞,避免穿過去。
	var trunk := StaticBody3D.new()
	trunk.position = pos + Vector3(0, 1.5, 0)
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.5
	cyl.height = 3.0
	shape.shape = cyl
	trunk.add_child(shape)
	add_child(trunk)


func _scatter(model: String, count: int, min_scale: float, max_scale: float, rng: RandomNumberGenerator, leaf_mat: Material = null) -> void:
	var scene := _load_scene(model)
	var bounds := _scatter_bounds()
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 30:
		tries += 1
		var p := Vector3(
			rng.randf_range(bounds.position.x, bounds.end.x), 0.0,
			rng.randf_range(bounds.position.y, bounds.end.y))
		if not _is_free(p):
			continue
		p.y = _ground_y(p)
		var inst := scene.instantiate() as Node3D
		inst.position = p
		inst.rotation.y = rng.randf_range(0.0, TAU)
		inst.scale = Vector3.ONE * rng.randf_range(min_scale, max_scale)
		if leaf_mat != null:
			_swap_leaf_material(inst, leaf_mat)
		add_child(inst)
		placed += 1


func _scatter_vegetation(density: float = 1.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SCATTER_SEED + 1
	var green := WB.leaf_material(Color("6f8a52"))
	_scatter("Grass_Common_Tall", int(60 * density), 0.8, 1.3, rng)
	_scatter("Grass_Common_Short", int(60 * density), 0.8, 1.3, rng)
	_scatter("Bush_Common", int(14 * density), 0.9, 1.5, rng, green)
	_scatter("Bush_Common_Flowers", int(8 * density), 0.9, 1.3, rng)
	_scatter("Fern_1", int(12 * density), 0.8, 1.3, rng)
	_scatter("Flower_3_Group", int(12 * density), 0.8, 1.2, rng)
	_scatter("Flower_4_Group", int(12 * density), 0.8, 1.2, rng)
	_scatter("Clover_1", int(18 * density), 0.8, 1.3, rng)
	_scatter("Rock_Medium_1", int(4 * density), 0.7, 1.4, rng)
	_scatter("Rock_Medium_2", int(4 * density), 0.7, 1.4, rng)
	_scatter("Rock_Medium_3", int(4 * density), 0.7, 1.4, rng)
	_scatter("Pebble_Round_1", int(14 * density), 1.0, 1.8, rng)
	_scatter("Pebble_Round_2", int(14 * density), 1.0, 1.8, rng)


func _add_lantern(pos: Vector3, lit: bool = false) -> MeshInstance3D:
	## 簡化石燈籠:基座、竿、火袋、笠(石材貼圖,火袋發光)。lit 時加暖色點光源(夜晚用)。
	var base := BoxMesh.new()
	base.size = Vector3(0.9, 0.3, 0.9)
	add_child(WB.mesh_instance(base, m_stone, pos + Vector3(0, 0.15, 0)))
	var post := BoxMesh.new()
	post.size = Vector3(0.3, 1.0, 0.3)
	add_child(WB.mesh_instance(post, m_stone, pos + Vector3(0, 0.8, 0)))
	var lamp := BoxMesh.new()
	lamp.size = Vector3(0.7, 0.55, 0.7)
	var lamp_mat := WB.material(WB.C_GOLD, true, 2.5 if lit else 0.8)
	var lamp_inst := WB.mesh_instance(lamp, lamp_mat, pos + Vector3(0, 1.55, 0))
	add_child(lamp_inst)
	var roof := CylinderMesh.new()
	roof.top_radius = 0.0
	roof.bottom_radius = 0.75
	roof.height = 0.5
	roof.radial_segments = 4
	var roof_inst := WB.mesh_instance(roof, m_stone, pos + Vector3(0, 2.1, 0))
	roof_inst.rotation_degrees.y = 45.0
	add_child(roof_inst)
	if lit:
		var light := OmniLight3D.new()
		light.position = pos + Vector3(0, 1.6, 0)
		light.light_color = Color("ffc98a")
		light.light_energy = 1.4
		light.omni_range = 7.5
		light.shadow_enabled = false
		add_child(light)
	return lamp_inst


# ---------- 神木與妖氣源 ----------

func _make_source(orb_pos: Vector3, tree_pos: Vector3, checkpoint: Vector3, tree_scale: float, variant: int) -> void:
	var s := Source.new()
	s.leaf_mat = WB.leaf_material(WB.C_WILTED)
	_make_tree(tree_pos, s.leaf_mat, variant, tree_scale, float(variant) * 1.7)

	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = 0.6
	orb_mesh.height = 1.2
	orb_mesh.radial_segments = 8
	orb_mesh.rings = 4
	s.orb = WB.mesh_instance(orb_mesh, WB.material(WB.C_MIASMA, true), orb_pos)
	s.base_y = orb_pos.y
	add_child(s.orb)

	# 淨化時從樹冠綻出花瓣。
	var petal_mesh := _petal_mesh()
	s.petals = CPUParticles3D.new()
	s.petals.position = tree_pos + Vector3(0, 4.0, 0)
	s.petals.mesh = petal_mesh
	s.petals.amount = 48
	s.petals.lifetime = 2.4
	s.petals.one_shot = true
	s.petals.explosiveness = 0.85
	s.petals.emitting = false
	s.petals.direction = Vector3.UP
	s.petals.spread = 180.0
	s.petals.initial_velocity_min = 1.5
	s.petals.initial_velocity_max = 3.5
	s.petals.gravity = Vector3(0.4, -1.2, 0.0)
	s.petals.angle_min = 0.0
	s.petals.angle_max = 360.0
	s.petals.angular_velocity_min = -240.0
	s.petals.angular_velocity_max = 240.0
	s.petals.scale_amount_min = _burst_scale().x
	s.petals.scale_amount_max = _burst_scale().y
	s.petals.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	s.petals.emission_sphere_radius = 1.8
	add_child(s.petals)

	s.checkpoint = checkpoint
	sources.append(s)


func _burst_scale() -> Vector2:
	return Vector2(1.2, 2.2)


func _petal_mesh() -> Mesh:
	## 花瓣粒子用 Quaternius 的 Petal 模型網格(帶原本的材質),不是平面方塊。
	var inst := _load_scene("Petal_1").instantiate()
	var mi := (inst if inst is MeshInstance3D else inst.find_children("*", "MeshInstance3D", true, false)[0]) as MeshInstance3D
	var mesh: Mesh = mi.mesh.duplicate()
	inst.free()
	var mat := WB.material(_bloom_color())
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in mesh.get_surface_count():
		mesh.surface_set_material(i, mat)
	return mesh


func _purify(s: Source) -> void:
	s.done = true
	purified += 1
	respawn_pos = s.checkpoint
	var tw := create_tween().set_parallel()
	tw.tween_property(s.orb, "scale", Vector3.ZERO, 0.6)
	tw.tween_property(s.leaf_mat, "albedo_color", _bloom_color(), 1.4)
	tw.chain().tween_callback(s.orb.hide)
	s.petals.emitting = true
	_on_source_purified(s)
