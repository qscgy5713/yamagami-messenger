extends LevelBase
## 第一章・櫻之社(春)白盒場景。
## 流程:淨化池中小島與東邊高台的神木 → 庭院石門開啟 → 踩石板打開石籠、淨化最後一處 → 主殿開門 → 進入神社過關。
## 材質:ambientCG(CC0)PBR 貼圖;樹木與植被:Quaternius Stylized Nature MegaKit(CC0)。

const SOURCES_FOR_GATE := 2
const SOURCES_TOTAL := 3

var gate_door: StaticBody3D
var cage_door: StaticBody3D
var hall_door: StaticBody3D
var plate_latched := false
var completed := false


# ---------- 基底的覆寫 ----------

func _start_position() -> Vector3:
	return Vector3(0.0, 1.0, 40.0)


func _start() -> void:
	_update_hud()


func _build_level() -> void:
	_build_ground()
	_build_path()
	_build_pond()
	_build_terrace()
	_build_gate_wall()
	_build_cage_puzzle()
	_build_hall()
	_build_scenery()
	_scatter_vegetation()


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


func _on_source_purified(_s: LevelBase.Source) -> void:
	if purified == SOURCES_FOR_GATE:
		_move_door(gate_door, -3.2)
		_flash("庭院的石門開啟了")
	if purified >= SOURCES_TOTAL:
		_move_door(hall_door, -2.2)
		_flash("主殿的門開啟了")
	_update_hud()


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
	_build_surroundings(30.0, -55.0, 45.0, WB.tex("Ground037", 0.3, Color("c4c9b2")))
	# 池塘下方的底面,掉下去時看得到底。
	add_child(WB.box_visual(Vector3(60, 1, 112), WB.tex("Ground037", 0.1, Color("7d8268")), Vector3(0, -4.5, -5)))


func _build_path() -> void:
	# 參道與神社庭院(僅視覺,略高於地面)。
	add_child(WB.box_visual(Vector3(5, 0.06, 90), m_path, Vector3(0, 0.03, -5)))
	add_child(WB.box_visual(Vector3(26, 0.06, 22), m_paving, Vector3(0, 0.03, -35)))
	add_child(WB.torii(Vector3(0, 0, 32)))
	for z: float in [36.0, 24.0, 12.0, 0.0, -12.0]:
		_add_lantern(Vector3(-3.6, 0, z))
		_add_lantern(Vector3(3.6, 0, z))


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


func _build_scenery() -> void:
	# 參道兩側盛開的老櫻(扭曲樹幹 + 淡櫻色花冠)。
	var rng := RandomNumberGenerator.new()
	rng.seed = SCATTER_SEED
	var z_list: Array[float] = [28.0, 18.0, 8.0, -2.0, -12.0, -18.0]
	for i in z_list.size():
		var bloom := WB.leaf_material(WB.C_SAKURA)
		_make_tree(Vector3(-8.5, 0, z_list[i]), bloom, i % 4, 0.5, rng.randf_range(0.0, TAU))
		_make_tree(Vector3(9.0, 0, z_list[i] + 3.0), bloom, (i + 2) % 4, 0.5, rng.randf_range(0.0, TAU))
	_build_mountains()
	# 參道上散落的花瓣。
	var petal_scene := _load_scene("Petal_1")
	for i in 22:
		var petal := petal_scene.instantiate() as Node3D
		petal.position = Vector3(rng.randf_range(-2.3, 2.3), 0.07, rng.randf_range(-44.0, 38.0))
		petal.rotation.y = rng.randf_range(0.0, TAU)
		petal.scale = Vector3.ONE * rng.randf_range(0.5, 0.9)
		add_child(petal)


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
	hud_msg.text = "第一章・櫻之社 完"
	hud_msg.visible = true
	hud_hint.text = ""


func _update_hud() -> void:
	hud_title.text = "淨化 %d / %d" % [purified, SOURCES_TOTAL]
	var hint := "找出被妖氣污染的神木:池中的小島、東邊的高台"
	if purified >= SOURCES_TOTAL:
		hint = "前往主殿"
	elif purified >= SOURCES_FOR_GATE:
		hint = "庭院裡還有一處:踩上石板打開石籠"
	hud_hint.text = hint
