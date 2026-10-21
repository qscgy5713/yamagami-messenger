extends Node3D
## 第一章・櫻之社(春)白盒場景。
## 流程:淨化池中小島與東邊高台的神木 → 庭院石門開啟 → 踩石板打開石籠、淨化最後一處 → 主殿開門 → 進入神社過關。
## 材質:ambientCG(CC0)PBR 貼圖;樹木與植被:Quaternius Stylized Nature MegaKit(CC0)。

const CAMERA_OFFSET := Vector3(0.0, 9.0, 10.0)
const INTERACT_RANGE := 2.5
const FALL_Y := -3.0
const START_POS := Vector3(0.0, 1.0, 40.0)
const SOURCES_FOR_GATE := 2
const SOURCES_TOTAL := 3
const SCATTER_SEED := 20261021

class Source:
	var orb: MeshInstance3D
	var base_y: float
	var leaf_mat: StandardMaterial3D
	var petals: CPUParticles3D
	var checkpoint: Vector3
	var done := false

var player: Player
var camera: Camera3D
var sources: Array[Source] = []
var purified := 0
var respawn_pos := START_POS
var gate_door: StaticBody3D
var cage_door: StaticBody3D
var hall_door: StaticBody3D
var plate_latched := false
var completed := false
var time := 0.0
var msg_serial := 0
var scene_cache := {}

var ui_font: SystemFont
var hud_count: Label
var hud_hint: Label
var hud_prompt: Label
var hud_msg: Label

# 貼圖材質(在 _ready 建立,各處共用)。
var m_ground: Material
var m_path: Material
var m_paving: Material
var m_stone: Material
var m_stone_dark: Material
var m_wood: Material
var m_paint_red: Material
var m_roof: Material


func _ready() -> void:
	WB.setup_input()
	_setup_materials()
	_setup_environment()
	_build_ground()
	_build_path()
	_build_pond()
	_build_terrace()
	_build_gate_wall()
	_build_cage_puzzle()
	_build_hall()
	_build_scenery()
	_scatter_vegetation()
	_build_player()
	_build_hud()
	_update_hud()


func _process(delta: float) -> void:
	time += delta
	camera.global_position = player.global_position + CAMERA_OFFSET
	camera.look_at(player.global_position + Vector3.UP, Vector3.UP)

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
	hud_prompt.visible = nearest != null and not completed
	if nearest != null and Input.is_action_just_pressed("interact"):
		_purify(nearest)


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
	# 晨霧天空:灰藍 → 米白地平線,低飽和。
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("9fb0bd")
	sky_mat.sky_horizon_color = Color("e6dfd2")
	sky_mat.ground_horizon_color = Color("e6dfd2")
	sky_mat.ground_bottom_color = Color("c9c6bb")
	sky_mat.sun_angle_max = 8.0
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.9
	env.adjustment_contrast = 1.1
	# 遠景霧氣:拉開層次、營造山間晨霧(近處保持清晰)。
	env.fog_enabled = true
	env.fog_light_color = Color("cfcdc1")
	env.fog_density = 0.006
	env.fog_sky_affect = 0.4
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# 偏暖、偏低的太陽光。
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32.0, -35.0, 0.0)
	sun.light_color = Color("ffe2bd")
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	add_child(sun)

	camera = Camera3D.new()
	camera.far = 400.0
	add_child(camera)


# ---------- 地形 ----------

func _build_ground() -> void:
	# 世界範圍 x -30..30、z -55..45;池塘區 (x<-10, z -6..14) 留空。
	var pieces := [
		[Vector3(40, 1, 100), Vector3(10, -0.5, -5)],
		[Vector3(20, 1, 31), Vector3(-20, -0.5, 29.5)],
		[Vector3(20, 1, 49), Vector3(-20, -0.5, -30.5)],
	]
	for p in pieces:
		add_child(WB.box_body(p[0], m_ground, p[1]))
	# 遠景地面(僅視覺):世界四周以同材質延伸,看起來不像漂浮的方塊;池塘下方另有底面。
	var outer := WB.tex("Ground037", 0.3, Color("c4c9b2"))
	add_child(WB.box_visual(Vector3(400, 1, 150), outer, Vector3(0, -0.52, 120)))
	add_child(WB.box_visual(Vector3(400, 1, 150), outer, Vector3(0, -0.52, -130)))
	add_child(WB.box_visual(Vector3(150, 1, 112), outer, Vector3(106, -0.52, -5)))
	add_child(WB.box_visual(Vector3(150, 1, 112), outer, Vector3(-106, -0.52, -5)))
	add_child(WB.box_visual(Vector3(60, 1, 112), WB.tex("Ground037", 0.1, Color("7d8268")), Vector3(0, -4.5, -5)))
	# 世界邊界(不可見的牆)。
	add_child(WB.invisible_wall(Vector3(1, 12, 110), Vector3(-30.5, 6, -5)))
	add_child(WB.invisible_wall(Vector3(1, 12, 110), Vector3(30.5, 6, -5)))
	add_child(WB.invisible_wall(Vector3(62, 12, 1), Vector3(0, 6, 45.5)))
	add_child(WB.invisible_wall(Vector3(62, 12, 1), Vector3(0, 6, -55.5)))


func _build_path() -> void:
	# 參道與神社庭院(僅視覺,略高於地面)。
	add_child(WB.box_visual(Vector3(5, 0.06, 90), m_path, Vector3(0, 0.03, -5)))
	add_child(WB.box_visual(Vector3(26, 0.06, 22), m_paving, Vector3(0, 0.03, -35)))
	add_child(WB.torii(Vector3(0, 0, 32)))
	# 參道兩側石燈籠。
	for z: float in [36.0, 24.0, 12.0, 0.0, -12.0]:
		_add_lantern(Vector3(-3.6, 0, z))
		_add_lantern(Vector3(3.6, 0, z))


func _add_lantern(pos: Vector3) -> void:
	## 簡化石燈籠:基座、竿、火袋、笠(石材貼圖,火袋發光)。
	var base := BoxMesh.new()
	base.size = Vector3(0.9, 0.3, 0.9)
	add_child(WB.mesh_instance(base, m_stone, pos + Vector3(0, 0.15, 0)))
	var post := BoxMesh.new()
	post.size = Vector3(0.3, 1.0, 0.3)
	add_child(WB.mesh_instance(post, m_stone, pos + Vector3(0, 0.8, 0)))
	var lamp := BoxMesh.new()
	lamp.size = Vector3(0.7, 0.55, 0.7)
	add_child(WB.mesh_instance(lamp, WB.material(WB.C_GOLD, true), pos + Vector3(0, 1.55, 0)))
	var roof := CylinderMesh.new()
	roof.top_radius = 0.0
	roof.bottom_radius = 0.75
	roof.height = 0.5
	roof.radial_segments = 4
	var roof_inst := WB.mesh_instance(roof, m_stone, pos + Vector3(0, 2.1, 0))
	roof_inst.rotation_degrees.y = 45.0
	add_child(roof_inst)


func _build_pond() -> void:
	# 水面(半透明,僅視覺)、中央小島、兩塊踏石。掉進池裡會回到檢查點。
	var water := WB.material(WB.C_WATER)
	water.roughness = 0.15
	water.metallic = 0.2
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.albedo_color.a = 0.82
	add_child(WB.box_visual(Vector3(20, 0.1, 20), water, Vector3(-20, -0.8, 4)))
	add_child(WB.box_body(Vector3(5, 1, 5), m_ground, Vector3(-20, -0.5, 4)))
	for p: Vector3 in [Vector3(-12.8, -0.3, 4.0), Vector3(-15.6, -0.3, 4.8)]:
		add_child(WB.box_body(Vector3(2, 0.6, 2), m_stone, p))
	_make_source(Vector3(-20, 1.2, 4.8), Vector3(-20, 0, 2.2), Vector3(-20, 1.0, 5.6), 0.4, 0)


func _build_terrace() -> void:
	# 東邊高台:兩階方塊爬上去,頂面 y=4。
	add_child(WB.box_body(Vector3(14, 4.5, 10), m_stone, Vector3(21, 1.75, -7)))
	add_child(WB.box_body(Vector3(4, 1.8, 4), m_stone_dark, Vector3(21, 0.4, 5.5)))
	add_child(WB.box_body(Vector3(4, 3.1, 4), m_stone_dark, Vector3(21, 1.05, 0)))
	_make_source(Vector3(21, 5.2, -8), Vector3(21, 4, -10.5), Vector3(21, 5.0, -6), 0.45, 1)


func _build_gate_wall() -> void:
	# 庭院入口石牆與石門:淨化 2 處後開啟。
	add_child(WB.box_body(Vector3(28, 6, 1), m_stone_dark, Vector3(-16, 3, -24)))
	add_child(WB.box_body(Vector3(28, 6, 1), m_stone_dark, Vector3(16, 3, -24)))
	gate_door = WB.box_body(Vector3(4, 6, 1), m_wood, Vector3(0, 3, -24))
	add_child(gate_door)


func _build_cage_puzzle() -> void:
	# 石籠關住第三處妖氣,踩上石板後永久開啟。
	add_child(WB.box_body(Vector3(6, 3, 0.5), m_stone, Vector3(14, 1.5, -37)))
	add_child(WB.box_body(Vector3(0.5, 3, 6), m_stone, Vector3(11, 1.5, -34)))
	add_child(WB.box_body(Vector3(0.5, 3, 6), m_stone, Vector3(17, 1.5, -34)))
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
	plate.add_child(WB.mesh_instance(mesh, WB.tex("Rock064", 0.6, Color("e0bf70")), Vector3.ZERO))
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.5
	cyl.height = 1.0
	shape.shape = cyl
	plate.add_child(shape)
	plate.body_entered.connect(_on_plate_entered)
	add_child(plate)


func _build_hall() -> void:
	# 主殿:左右牆 + 後牆 + 瓦屋頂,正面以木門封住;內部有觸發區。
	add_child(WB.box_body(Vector3(4, 6, 6), m_paint_red, Vector3(-4, 3, -48)))
	add_child(WB.box_body(Vector3(4, 6, 6), m_paint_red, Vector3(4, 3, -48)))
	add_child(WB.box_body(Vector3(12, 6, 1), m_paint_red, Vector3(0, 3, -51.5)))
	add_child(WB.box_body(Vector3(14, 1, 8), m_roof, Vector3(0, 6.5, -48)))
	hall_door = WB.box_body(Vector3(4, 4, 0.8), m_wood, Vector3(0, 2, -45.4))
	add_child(hall_door)
	add_child(WB.box_body(Vector3(1.5, 1, 1), m_stone_dark, Vector3(0, 0.5, -49.8)))

	var trigger := Area3D.new()
	trigger.position = Vector3(0, 1, -48)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 2, 3)
	shape.shape = box
	trigger.add_child(shape)
	trigger.body_entered.connect(_on_hall_entered)
	add_child(trigger)


# ---------- 景觀:櫻樹、遠山、植被 ----------

func _build_scenery() -> void:
	# 參道兩側盛開的老櫻(扭曲樹幹 + 淡櫻色花冠)。
	var rng := RandomNumberGenerator.new()
	rng.seed = SCATTER_SEED
	var z_list: Array[float] = [28.0, 18.0, 8.0, -2.0, -12.0, -18.0]
	for i in z_list.size():
		var bloom := WB.leaf_material(WB.C_SAKURA)
		_make_tree(Vector3(-8.5, 0, z_list[i]), bloom, i % 4, 0.5, rng.randf_range(0.0, TAU))
		_make_tree(Vector3(9.0, 0, z_list[i] + 3.0), bloom, (i + 2) % 4, 0.5, rng.randf_range(0.0, TAU))
	# 遠山剪影:越遠越淡,營造層次。
	var layers := [[-85.0, 0.0, 34.0], [-120.0, 0.35, 48.0], [-160.0, 0.6, 62.0]]
	for l in layers:
		var tint := WB.C_MOUNTAIN.lerp(Color("e6dfd2"), l[1])
		for x: float in [-90.0, -30.0, 30.0, 90.0]:
			var peak := CylinderMesh.new()
			peak.top_radius = 0.0
			peak.bottom_radius = l[2] * 1.2
			peak.height = l[2]
			peak.radial_segments = 5
			peak.rings = 1
			add_child(WB.mesh_instance(peak, WB.material(tint), Vector3(x + l[0] * 0.15, l[2] * 0.5 - 2.0, l[0])))


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


func _is_free(p: Vector3) -> bool:
	## 植被可放置的位置:避開參道、庭院、高台、石籠、石板、主殿、石牆與池塘。
	if p.x < -10.0 and p.z > -6.0 and p.z < 14.0:
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
		return false  # 路旁櫻樹帶
	return true


func _scatter(model: String, count: int, min_scale: float, max_scale: float, rng: RandomNumberGenerator, leaf_mat: Material = null) -> void:
	var scene := _load_scene(model)
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 30:
		tries += 1
		var p := Vector3(rng.randf_range(-29.0, 29.0), 0.0, rng.randf_range(-54.0, 44.0))
		if not _is_free(p):
			continue
		var inst := scene.instantiate() as Node3D
		inst.position = p
		inst.rotation.y = rng.randf_range(0.0, TAU)
		inst.scale = Vector3.ONE * rng.randf_range(min_scale, max_scale)
		if leaf_mat != null:
			_swap_leaf_material(inst, leaf_mat)
		add_child(inst)
		placed += 1


func _scatter_vegetation() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SCATTER_SEED + 1
	var green := WB.leaf_material(Color("6f8a52"))
	_scatter("Grass_Common_Tall", 60, 0.8, 1.3, rng)
	_scatter("Grass_Common_Short", 60, 0.8, 1.3, rng)
	_scatter("Bush_Common", 14, 0.9, 1.5, rng, green)
	_scatter("Bush_Common_Flowers", 8, 0.9, 1.3, rng)
	_scatter("Fern_1", 12, 0.8, 1.3, rng)
	_scatter("Flower_3_Group", 12, 0.8, 1.2, rng)
	_scatter("Flower_4_Group", 12, 0.8, 1.2, rng)
	_scatter("Clover_1", 18, 0.8, 1.3, rng)
	_scatter("Rock_Medium_1", 4, 0.7, 1.4, rng)
	_scatter("Rock_Medium_2", 4, 0.7, 1.4, rng)
	_scatter("Rock_Medium_3", 4, 0.7, 1.4, rng)
	_scatter("Pebble_Round_1", 14, 1.0, 1.8, rng)
	_scatter("Pebble_Round_2", 14, 1.0, 1.8, rng)
	# 參道上散落的花瓣。
	var petal_scene := _load_scene("Petal_1")
	for i in 22:
		var petal := petal_scene.instantiate() as Node3D
		petal.position = Vector3(rng.randf_range(-2.3, 2.3), 0.07, rng.randf_range(-44.0, 38.0))
		petal.rotation.y = rng.randf_range(0.0, TAU)
		petal.scale = Vector3.ONE * rng.randf_range(0.5, 0.9)
		add_child(petal)


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
	var petal_mesh := QuadMesh.new()
	petal_mesh.size = Vector2(0.22, 0.22)
	var petal_mat := StandardMaterial3D.new()
	petal_mat.albedo_color = WB.C_SAKURA
	petal_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	petal_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	petal_mesh.material = petal_mat
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
	s.petals.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	s.petals.emission_sphere_radius = 1.8
	add_child(s.petals)

	s.checkpoint = checkpoint
	sources.append(s)


func _purify(s: Source) -> void:
	s.done = true
	purified += 1
	respawn_pos = s.checkpoint
	var tw := create_tween().set_parallel()
	tw.tween_property(s.orb, "scale", Vector3.ZERO, 0.6)
	tw.tween_property(s.leaf_mat, "albedo_color", WB.C_SAKURA, 1.4)
	tw.chain().tween_callback(s.orb.hide)
	s.petals.emitting = true

	if purified == SOURCES_FOR_GATE:
		_move_door(gate_door, -3.2)
		_flash("庭院的石門開啟了")
	if purified >= SOURCES_TOTAL:
		_move_door(hall_door, -2.2)
		_flash("主殿的門開啟了")
	_update_hud()


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
	msg_serial += 1
	hud_msg.text = "第一章・櫻之社 完"
	hud_msg.visible = true
	hud_hint.text = ""


func _move_door(door: StaticBody3D, target_y: float) -> void:
	create_tween().tween_property(door, "position:y", target_y, 0.9)


# ---------- 玩家與 HUD ----------

func _build_player() -> void:
	player = Player.new()
	player.position = START_POS
	player.camera = camera
	add_child(player)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud_count = _make_label(layer, 28)
	hud_count.position = Vector2(24, 16)
	hud_hint = _make_label(layer, 18)
	hud_hint.position = Vector2(24, 60)
	hud_prompt = _make_label(layer, 24)
	hud_prompt.text = "按 E 淨化"
	hud_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hud_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud_prompt.offset_top = -140.0
	hud_prompt.visible = false
	hud_msg = _make_label(layer, 44)
	hud_msg.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hud_msg.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud_msg.visible = false


func _make_label(parent: Node, font_size: int) -> Label:
	var label := Label.new()
	if ui_font == null:
		# Godot 預設字型沒有中日文字;依平台挑系統字型(正式版再改為內嵌 CJK 字型)。
		ui_font = SystemFont.new()
		ui_font.font_names = PackedStringArray(["Arial Unicode MS", "Microsoft JhengHei", "Noto Sans CJK TC"])
	label.add_theme_font_override("font", ui_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", WB.C_CREAM)
	label.add_theme_color_override("font_outline_color", WB.C_SUMI)
	label.add_theme_constant_override("outline_size", 6)
	parent.add_child(label)
	return label


func _update_hud() -> void:
	hud_count.text = "淨化 %d / %d" % [purified, SOURCES_TOTAL]
	var hint := "找出被妖氣污染的神木:池中的小島、東邊的高台"
	if purified >= SOURCES_TOTAL:
		hint = "前往主殿"
	elif purified >= SOURCES_FOR_GATE:
		hint = "庭院裡還有一處:踩上石板打開石籠"
	hud_hint.text = hint


func _flash(text: String) -> void:
	msg_serial += 1
	var serial := msg_serial
	hud_msg.text = text
	hud_msg.visible = true
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if serial == msg_serial:
			hud_msg.visible = false)
