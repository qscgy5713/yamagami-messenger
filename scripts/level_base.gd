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
	var marker: MeshInstance3D  # 嗅覺時顯示的光柱
	var bloom := Color(0, 0, 0, 0)  # 淨化後的葉色;alpha 為 0 時用 _bloom_color()

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
## 木靈任務:收集散落的御守交給木靈,才能解開主殿封印。
var charms: Array[Dictionary] = []  # {node, marker, got}
var charms_got := 0
var kodama: Node3D
var kodama_pos := Vector3.ZERO
var quest_lines: Dictionary = {}  # intro / waiting / done
var quest_started := false
var quest_done := false
var talking := false
var scatter_blocked: Array[Rect2] = []
var sniff_tint: ColorRect
## 躲貓貓:藏在地圖各處的小木靈,靠近即找到。
var seek_spirits: Array[Dictionary] = []  # {node, marker, found}
var seek_found := 0
## 關底首領「妖氣之主」:淨化三根封印柱,同時跳過擴散的妖氣環。phase 0 未開始 / 1 戰鬥中 / 2 已淨化。
var boss_phase := 0
var boss_center := Vector3.ZERO
var boss_court := Rect2()
var boss_lines: Dictionary = {}
var boss_orb: MeshInstance3D
var boss_light: OmniLight3D
var boss_pylons: Array[Dictionary] = []  # {node, cap, lit}
var boss_rings: Array[Dictionary] = []  # {node, r}
var boss_ring_timer := 0.0
var boss_hit_cooldown := 0.0
var water_materials: Array[StandardMaterial3D] = []
var _cam_ready := false
var pause_layer: CanvasLayer
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


func _on_progress_changed() -> void:
	## 淨化、任務、躲貓貓完成時呼叫;子類別在這裡處理石門等機關。
	pass


func _on_boss_defeated() -> void:
	pass


func _chapter_title() -> PackedStringArray:
	## 章節標題卡(兩行:章名、地名);空陣列則不顯示。
	return PackedStringArray()


func _purify_line(_count: int) -> String:
	## 第 count 處淨化後顯示的一句短語;空字串則不顯示。
	return ""


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
	_show_title_card()
	_start()


func _process(delta: float) -> void:
	time += delta
	_update_camera(delta)
	_update_occlusion()
	for mat in water_materials:
		mat.uv1_offset = Vector3(time * 0.02, time * 0.012, 0.0)

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
	if can_purify:
		hud_prompt.text = "按 E 淨化"
	if can_purify and Input.is_action_just_pressed("interact"):
		_purify(nearest)

	_update_quest(delta)
	_update_seek()
	_update_boss(delta)
	_update_sniff()
	_level_process(delta)


# ---------- 鏡頭 ----------

func _update_camera(delta: float) -> void:
	## 平滑跟隨玩家(指數趨近),避免鏡頭隨角色的每個小動作抖動。
	var target := player.global_position + CAMERA_OFFSET
	if _cam_ready:
		camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-10.0 * delta))
	else:
		camera.global_position = target
		_cam_ready = true
	camera.look_at(player.global_position + Vector3.UP, Vector3.UP)


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


# ---------- 木靈任務、御守、嗅覺 ----------

func _setup_quest(npc_pos: Vector3, charm_positions: Array[Vector3], lines: Dictionary) -> void:
	## 在關卡中放一隻木靈與數枚御守;子類別在 _build_level 呼叫。lines 需含 intro / waiting / done 三組台詞。
	quest_lines = lines
	kodama_pos = npc_pos
	_build_kodama(npc_pos)
	for p in charm_positions:
		_build_charm(p)


func _build_kodama(pos: Vector3) -> void:
	## 木靈:白色圓潤的小精靈(以基本形狀組成),會輕輕晃動。
	kodama = Node3D.new()
	kodama.position = pos
	var body_mat := WB.material(Color("eeeee2"), true, 0.25)
	var body := SphereMesh.new()
	body.radius = 0.32
	body.height = 0.64
	body.radial_segments = 12
	body.rings = 6
	kodama.add_child(WB.mesh_instance(body, body_mat, Vector3(0, 0.55, 0)))
	var head := SphereMesh.new()
	head.radius = 0.3
	head.height = 0.6
	head.radial_segments = 12
	head.rings = 6
	kodama.add_child(WB.mesh_instance(head, body_mat, Vector3(0, 1.0, 0)))
	var eye := SphereMesh.new()
	eye.radius = 0.045
	eye.height = 0.09
	eye.radial_segments = 6
	eye.rings = 3
	var dark := WB.material(WB.C_SUMI)
	for x: float in [-0.1, 0.1]:
		kodama.add_child(WB.mesh_instance(eye, dark, Vector3(x, 1.04, 0.27)))
	var mouth := SphereMesh.new()
	mouth.radius = 0.04
	mouth.height = 0.06
	mouth.radial_segments = 6
	mouth.rings = 3
	kodama.add_child(WB.mesh_instance(mouth, dark, Vector3(0, 0.93, 0.285)))
	add_child(kodama)
	scatter_blocked.append(Rect2(pos.x - 2.0, pos.z - 2.0, 4.0, 4.0))


func _build_charm(pos: Vector3) -> void:
	## 御守:紅色小護身符 + 金色束繩,緩緩旋轉、上下浮動。
	var node := Node3D.new()
	node.position = pos
	var gold := WB.material(WB.C_GOLD, true, 1.6)
	var red := WB.material(Color("c2453a"), true, 0.4)
	var bag := BoxMesh.new()
	bag.size = Vector3(0.28, 0.46, 0.08)
	node.add_child(WB.mesh_instance(bag, red, Vector3.ZERO))
	var sash := BoxMesh.new()
	sash.size = Vector3(0.3, 0.07, 0.1)
	node.add_child(WB.mesh_instance(sash, gold, Vector3(0, 0.12, 0)))
	var cap := BoxMesh.new()
	cap.size = Vector3(0.12, 0.1, 0.1)
	node.add_child(WB.mesh_instance(cap, gold, Vector3(0, 0.27, 0)))
	var light := OmniLight3D.new()
	light.light_color = Color("ffd98a")
	light.light_energy = 0.6
	light.omni_range = 3.0
	node.add_child(light)
	add_child(node)
	scatter_blocked.append(Rect2(pos.x - 1.5, pos.z - 1.5, 3.0, 3.0))
	charms.append({"node": node, "marker": _make_marker(pos, Color("ffd36b")), "got": false, "base_y": pos.y})


func _make_marker(pos: Vector3, color: Color) -> MeshInstance3D:
	## 嗅覺光柱:穿透牆壁與霧、只在按住嗅覺時顯示。
	var pillar := CylinderMesh.new()
	pillar.top_radius = 0.25
	pillar.bottom_radius = 0.25
	pillar.height = 16.0
	pillar.radial_segments = 8
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.disable_fog = true
	mat.albedo_color = Color(color, 0.5)
	var inst := WB.mesh_instance(pillar, mat, pos + Vector3(0, 7.0, 0))
	inst.visible = false
	add_child(inst)
	return inst


func _update_quest(delta: float) -> void:
	for c in charms:
		if c["got"]:
			continue
		var n := c["node"] as Node3D
		n.position.y = c["base_y"] + sin(time * 2.2 + n.position.x) * 0.12
		n.rotation.y += delta * 1.6
		if player.global_position.distance_to(n.global_position) < 1.4:
			_collect_charm(c)
	if kodama == null:
		return
	kodama.position.y = absf(sin(time * 2.0)) * 0.08
	kodama.rotation.y = lerp_angle(kodama.rotation.y, atan2(player.global_position.x - kodama.global_position.x, player.global_position.z - kodama.global_position.z), delta * 4.0)
	var near := player.global_position.distance_to(kodama.global_position) < 2.6
	if not near or talking or player.controls_locked or not prompt_enabled or hud_prompt.visible:
		return
	hud_prompt.text = "按 E 交談"
	hud_prompt.visible = true
	if Input.is_action_just_pressed("interact"):
		_talk_to_kodama()


func _collect_charm(c: Dictionary) -> void:
	c["got"] = true
	charms_got += 1
	(c["marker"] as Node3D).hide()
	var n := c["node"] as Node3D
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector3.ZERO, 0.3)
	tw.tween_callback(n.queue_free)
	_flash("拾得御守  %d / %d" % [charms_got, charms.size()])
	if has_method("_update_hud"):
		call("_update_hud")


func _talk_to_kodama() -> void:
	talking = true
	if not quest_started:
		quest_started = true
		await _say(quest_lines["intro"])
	elif charms_got < charms.size():
		await _say(quest_lines["waiting"])
	elif not quest_done:
		await _say(quest_lines["done"])
		quest_done = true
		_on_quest_done()
		_on_progress_changed()
		if has_method("_update_hud"):
			call("_update_hud")
	else:
		await _say([{"who": "木靈", "text": "謝謝你,神使。"}])
	talking = false


func _on_quest_done() -> void:
	pass


func _set_hint(hint: String) -> void:
	var q := _quest_hint()
	hud_hint.text = hint if q == "" else hint + "\n" + q


func _build_dash_platforms(a: Vector3, gap: float = 10.5) -> Vector3:
	## 兩座平台相隔 gap 公尺,單靠跳躍過不去,需要衝刺。回傳對岸平台頂面中心(御守放這裡)。
	var b := a + Vector3(4.0 + gap, 0.0, 0.0)
	add_child(WB.box_body(Vector3(4, 1, 4), m_stone_dark, a))
	add_child(WB.box_body(Vector3(4, 1, 4), m_stone, b))
	for p in [a, b]:
		scatter_blocked.append(Rect2(p.x - 3.0, p.z - 3.0, 6.0, 6.0))
	return b + Vector3(0.0, 1.4, 0.0)


func _all_ready() -> bool:
	## 三處妖氣源淨化、御守交齊、小木靈找齊後,才能挑戰妖氣之主。
	return purified >= sources.size() and (charms.is_empty() or quest_done) and (seek_spirits.is_empty() or seek_found >= seek_spirits.size())


func _final_hint() -> String:
	if boss_phase == 2:
		return "前往主殿"
	if _all_ready():
		return "前往庭院深處,面對妖氣之主"
	return "還有未完成的事(見下)"


func _quest_hint() -> String:
	var lines: PackedStringArray = []
	if not quest_done and not charms.is_empty():
		if not quest_started:
			lines.append("山裡有隻木靈在找你,去跟祂說說話")
		elif charms_got < charms.size():
			lines.append("幫木靈找回散落的御守(%d / %d);按住 Q 用嗅覺" % [charms_got, charms.size()])
		else:
			lines.append("御守都找齊了,交給木靈")
	if not seek_spirits.is_empty() and seek_found < seek_spirits.size():
		lines.append("找出躲起來的小木靈(%d / %d)" % [seek_found, seek_spirits.size()])
	if boss_phase == 1:
		var lit := 0
		for pl in boss_pylons:
			if pl["lit"]:
				lit += 1
		lines.append("淨化三根封印柱(%d / 3),跳過擴散的妖氣環!" % lit)
	return "\n".join(lines)


# ---------- 躲貓貓 ----------

func _setup_seek(positions: Array[Vector3]) -> void:
	for pos in positions:
		var spirit := Node3D.new()
		spirit.position = pos
		var mat := WB.material(Color("cfe8c8"), true, 0.4)
		var body := SphereMesh.new()
		body.radius = 0.22
		body.height = 0.44
		body.radial_segments = 10
		body.rings = 5
		spirit.add_child(WB.mesh_instance(body, mat, Vector3(0, 0.25, 0)))
		var eye := SphereMesh.new()
		eye.radius = 0.035
		eye.height = 0.07
		eye.radial_segments = 6
		eye.rings = 3
		var dark := WB.material(WB.C_SUMI)
		for x: float in [-0.07, 0.07]:
			spirit.add_child(WB.mesh_instance(eye, dark, Vector3(x, 0.3, 0.19)))
		add_child(spirit)
		scatter_blocked.append(Rect2(pos.x - 1.2, pos.z - 1.2, 2.4, 2.4))
		seek_spirits.append({"node": spirit, "marker": _make_marker(pos, Color("7be0c8")), "found": false})


func _update_seek() -> void:
	for sp in seek_spirits:
		if sp["found"]:
			continue
		var n := sp["node"] as Node3D
		n.position.y = absf(sin(time * 3.0 + n.position.x)) * 0.05
		if player.global_position.distance_to(n.global_position) < 2.6:
			sp["found"] = true
			seek_found += 1
			(sp["marker"] as Node3D).hide()
			var tw := create_tween()
			tw.tween_property(n, "position:y", 2.5, 0.35)
			tw.parallel().tween_property(n, "scale", Vector3.ZERO, 0.5)
			tw.tween_callback(n.queue_free)
			_flash("找到了!  %d / %d" % [seek_found, seek_spirits.size()])
			_on_progress_changed()


# ---------- 首領:妖氣之主 ----------

func _setup_boss(center: Vector3, pylon_positions: Array[Vector3], court: Rect2, lines: Dictionary) -> void:
	boss_center = center
	boss_court = court
	boss_lines = lines
	var orb := SphereMesh.new()
	orb.radius = 1.6
	orb.height = 3.2
	orb.radial_segments = 16
	orb.rings = 8
	boss_orb = WB.mesh_instance(orb, WB.material(Color("2a1238"), true, 0.9), center)
	boss_orb.visible = false
	add_child(boss_orb)
	# 繚繞的妖氣:暗紫色小球緩緩上升。
	var wisp := SphereMesh.new()
	wisp.radius = 0.12
	wisp.height = 0.24
	wisp.radial_segments = 6
	wisp.rings = 3
	var wisp_mat := StandardMaterial3D.new()
	wisp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wisp_mat.albedo_color = Color("7a4cc0")
	wisp.material = wisp_mat
	var smoke := CPUParticles3D.new()
	smoke.mesh = wisp
	smoke.amount = 60
	smoke.lifetime = 2.2
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 1.7
	smoke.direction = Vector3.UP
	smoke.spread = 40.0
	smoke.initial_velocity_min = 0.6
	smoke.initial_velocity_max = 1.6
	smoke.gravity = Vector3.ZERO
	smoke.scale_amount_min = 0.5
	smoke.scale_amount_max = 1.8
	smoke.scale_amount_curve = _fade_curve()
	boss_orb.add_child(smoke)
	boss_light = OmniLight3D.new()
	boss_light.position = center
	boss_light.light_color = Color("a070ff")
	boss_light.light_energy = 0.0
	boss_light.omni_range = 22.0
	add_child(boss_light)
	for pos in pylon_positions:
		var pillar := Node3D.new()
		pillar.position = pos
		var post := BoxMesh.new()
		post.size = Vector3(0.8, 2.2, 0.8)
		pillar.add_child(WB.mesh_instance(post, m_stone_dark, Vector3(0, 1.1, 0)))
		var cap_mesh := SphereMesh.new()
		cap_mesh.radius = 0.38
		cap_mesh.height = 0.76
		cap_mesh.radial_segments = 8
		cap_mesh.rings = 4
		var cap := WB.mesh_instance(cap_mesh, WB.material(Color("8a55c8"), true, 2.0), Vector3(0, 2.5, 0))
		pillar.add_child(cap)
		pillar.visible = false
		add_child(pillar)
		boss_pylons.append({"node": pillar, "cap": cap, "lit": false})


func _update_boss(delta: float) -> void:
	if boss_orb == null:
		return
	if boss_phase == 0:
		if _all_ready() and not player.controls_locked and boss_court.has_point(Vector2(player.global_position.x, player.global_position.z)):
			_start_boss()
		return
	if boss_phase != 1:
		return
	boss_orb.position.y = boss_center.y + sin(time * 2.0) * 0.25
	boss_hit_cooldown = maxf(boss_hit_cooldown - delta, 0.0)
	if not player.controls_locked:
		boss_ring_timer -= delta
		if boss_ring_timer <= 0.0:
			boss_ring_timer = 2.8 - 0.6 * _pylons_lit()
			_spawn_ring()
		_try_light_pylon()
	for ring in boss_rings.duplicate():
		ring["r"] += delta * 7.0
		var node := ring["node"] as MeshInstance3D
		node.scale = Vector3(ring["r"], 6.0, ring["r"])
		if ring["r"] > 17.0:
			node.queue_free()
			boss_rings.erase(ring)
			continue
		var d := Vector2(player.global_position.x - boss_center.x, player.global_position.z - boss_center.z).length()
		if boss_hit_cooldown <= 0.0 and absf(d - ring["r"]) < 0.7 and player.global_position.y < 1.6:
			_boss_hit()


func _fade_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	return c


func _pylons_lit() -> int:
	var n := 0
	for pl in boss_pylons:
		if pl["lit"]:
			n += 1
	return n


func _start_boss() -> void:
	boss_phase = 1
	boss_orb.visible = true
	boss_orb.scale = Vector3.ONE * 0.05
	create_tween().tween_property(boss_orb, "scale", Vector3.ONE, 1.5)
	create_tween().tween_property(boss_light, "light_energy", 2.5, 1.5)
	for pl in boss_pylons:
		(pl["node"] as Node3D).visible = true
	boss_ring_timer = 3.5
	await _say(boss_lines["start"])
	_flash("淨化三根封印柱!")
	if has_method("_update_hud"):
		call("_update_hud")


func _spawn_ring() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 6
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("b78cff")
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.85
	var node := WB.mesh_instance(torus, mat, Vector3(boss_center.x, 0.3, boss_center.z))
	node.scale = Vector3(1.5, 6.0, 1.5)
	add_child(node)
	boss_rings.append({"node": node, "r": 1.5})


func _boss_hit() -> void:
	boss_hit_cooldown = 1.5
	player.global_position = Vector3(boss_center.x, 1.0, boss_court.end.y - 1.5)
	player.velocity = Vector3.ZERO
	_flash("被妖氣彈開了!在環到腳邊時跳起來")


func _try_light_pylon() -> void:
	if hud_prompt.visible:
		return
	for pl in boss_pylons:
		if pl["lit"]:
			continue
		var node := pl["node"] as Node3D
		if player.global_position.distance_to(node.global_position + Vector3(0, 0.5, 0)) < 2.4:
			hud_prompt.text = "按 E 淨化封印柱"
			hud_prompt.visible = true
			if Input.is_action_just_pressed("interact"):
				_light_pylon(pl)
			return


func _light_pylon(pl: Dictionary) -> void:
	pl["lit"] = true
	var cap_mat := (pl["cap"] as MeshInstance3D).material_override as StandardMaterial3D
	cap_mat.albedo_color = WB.C_GOLD
	cap_mat.emission = WB.C_GOLD
	var lit := _pylons_lit()
	create_tween().tween_property(boss_orb, "scale", Vector3.ONE * (1.0 - 0.3 * lit), 0.8)
	_flash("封印柱亮了  %d / 3" % lit)
	if has_method("_update_hud"):
		call("_update_hud")
	if lit >= boss_pylons.size():
		_end_boss()


func _end_boss() -> void:
	boss_phase = 2
	for ring in boss_rings:
		(ring["node"] as Node).queue_free()
	boss_rings.clear()
	var tw := create_tween().set_parallel()
	tw.tween_property(boss_orb, "scale", Vector3.ZERO, 1.6)
	tw.tween_property(boss_light, "light_energy", 0.0, 1.6)
	await tw.finished
	boss_orb.hide()
	await _say(boss_lines["defeated"])
	_on_boss_defeated()
	if has_method("_update_hud"):
		call("_update_hud")


func _update_sniff() -> void:
	## 按住 Q:嗅覺。附近未完成的妖氣源與御守顯示光柱,畫面微微泛青。
	var sniffing := Input.is_action_pressed("sniff") and not get_tree().paused
	var pulse := 0.5 + 0.2 * sin(time * 5.0)
	var targets: Array[MeshInstance3D] = []
	for s in sources:
		if not s.done:
			targets.append(s.marker)
	for c in charms:
		if not c["got"]:
			targets.append(c["marker"])
	for sp in seek_spirits:
		if not sp["found"]:
			targets.append(sp["marker"])
	for m in targets:
		var near := player.global_position.distance_to(m.global_position - Vector3(0, 7.0, 0)) < 55.0
		m.visible = sniffing and near
		if m.visible:
			var mat := m.material_override as StandardMaterial3D
			mat.albedo_color.a = pulse
	sniff_tint.color.a = lerpf(sniff_tint.color.a, 0.12 if sniffing else 0.0, 0.2)


# ---------- 章節標題卡與暫停選單 ----------

func _show_title_card() -> void:
	var lines := _chapter_title()
	if lines.is_empty():
		return
	var layer := CanvasLayer.new()
	layer.layer = 15
	add_child(layer)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.offset_top = -200.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.modulate.a = 0.0
	layer.add_child(box)
	for i in lines.size():
		var l := WB.label(box, 30 if i == 0 else 64)
		l.text = lines[i]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_constant_override("outline_size", 8)
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_property(box, "modulate:a", 1.0, 1.0)
	tw.tween_interval(2.2)
	tw.tween_property(box, "modulate:a", 0.0, 1.2)
	tw.finished.connect(layer.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()


func _toggle_pause() -> void:
	if pause_layer == null:
		_build_pause_menu()
	var paused := not get_tree().paused
	get_tree().paused = paused
	pause_layer.visible = paused


func _build_pause_menu() -> void:
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 40
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_layer.visible = false
	add_child(pause_layer)
	var dim := ColorRect.new()
	dim.color = Color(WB.C_SUMI, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_layer.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(WB.C_SUMI, 0.92)
	style.border_color = WB.C_GOLD.darkened(0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(28.0)
	panel.add_theme_stylebox_override("panel", style)
	pause_layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var title := WB.label(box, 32)
	title.text = "暫停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var items := [
		["繼續", _toggle_pause],
		["重新開始本章", func() -> void:
			get_tree().paused = false
			get_tree().reload_current_scene()],
		["離開遊戲", func() -> void: get_tree().quit()],
	]
	for it in items:
		var b := Button.new()
		b.text = it[0]
		b.custom_minimum_size = Vector2(260, 48)
		b.add_theme_font_override("font", WB.font())
		b.add_theme_font_size_override("font_size", 22)
		b.add_theme_color_override("font_color", WB.C_CREAM)
		b.add_theme_color_override("font_hover_color", WB.C_GOLD)
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(1, 1, 1, 0.06)
		normal.set_corner_radius_all(3)
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = Color(WB.C_GOLD, 0.22)
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", hover)
		b.add_theme_stylebox_override("focus", hover)
		b.pressed.connect(it[1])
		box.add_child(b)


# ---------- 水面 ----------

func _water_material() -> StandardMaterial3D:
	## 半透明水面 + 緩慢流動的法線(噪聲生成,不需外部貼圖)。
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.03
	var normal_tex := NoiseTexture2D.new()
	normal_tex.noise = noise
	normal_tex.seamless = true
	normal_tex.as_normal_map = true
	normal_tex.bump_strength = 6.0
	normal_tex.width = 256
	normal_tex.height = 256
	var water := WB.material(WB.C_WATER)
	water.roughness = 0.1
	water.metallic = 0.3
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.albedo_color.a = 0.8
	water.normal_enabled = true
	water.normal_texture = normal_tex
	water.normal_scale = 0.6
	water.uv1_scale = Vector3(6.0, 6.0, 1.0)
	water_materials.append(water)
	return water


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
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.6
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
	sun.directional_shadow_max_distance = 70.0
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

	sniff_tint = ColorRect.new()
	sniff_tint.color = Color(0.45, 0.8, 0.9, 0.0)
	sniff_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	sniff_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(sniff_tint)

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


func _scatter_is_blocked(p: Vector3) -> bool:
	for r in scatter_blocked:
		if r.has_point(Vector2(p.x, p.z)):
			return true
	return false


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
		if not _is_free(p) or _scatter_is_blocked(p):
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
	s.marker = _make_marker(orb_pos, Color("b48cff"))

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
	tw.tween_property(s.leaf_mat, "albedo_color", s.bloom if s.bloom.a > 0.0 else _bloom_color(), 1.4)
	tw.chain().tween_callback(s.orb.hide)
	s.petals.emitting = true
	if s.marker:
		s.marker.hide()
	var line := _purify_line(purified)
	if line != "":
		_flash(line)
	_on_source_purified(s)
