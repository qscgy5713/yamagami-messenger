class_name LevelBase
extends Node3D
## 關卡共用邏輯:環境、材質、玩家與鏡頭、HUD、對話、轉場、妖氣源、樹木與植被。
## 子類別實作虛擬函式(_environment_config、_build_level、_start …),_ready 流程由這裡統一。

class Source:
	var orb: Node3D
	var base_y: float
	var leaf_mat: StandardMaterial3D
	var petals: CPUParticles3D
	var checkpoint: Vector3
	var done := false
	var marker: MeshInstance3D  # 嗅覺時顯示的光柱
	var bloom := Color(0, 0, 0, 0)  # 淨化後的葉色;alpha 為 0 時用 _bloom_color()

const CAM_PITCH_DEFAULT := 0.71  ## 約 41°,與舊版固定視角相同
const CAM_DIST_DEFAULT := 9.9
const PARTICLE_DIR := "res://assets/particles/"
const INTERACT_RANGE := 2.5
const FALL_Y := -3.0
const SCATTER_SEED := 20261021
const BOSS_MODEL := "res://assets/models/monsters/Cobra.glb"
const BOSS_SCALE := 0.7
const BOSS_FACING := -PI * 0.5  # 模型的蛇頭朝 +x;轉 -90° 讓它朝 +z,才會面對玩家
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
var boss_orb: Node3D
var boss_model: Node3D
var boss_arms: Array = []  # 每條觸手是一串球體節點
var boss_light: OmniLight3D
var boss_pylons: Array[Dictionary] = []  # {node, cap, lit}
var boss_rings: Array[Dictionary] = []  # {node, r}
var boss_ring_timer := 0.0
var boss_hit_cooldown := 0.0
var water_materials: Array[StandardMaterial3D] = []
var _cam_ready := false
var cam_yaw := 0.0
var cam_pitch := CAM_PITCH_DEFAULT
var cam_dist := CAM_DIST_DEFAULT
var trees: Array[Dictionary] = []  # {meshes, center, radius}:樹冠、鳥居擋住鏡頭時變半透明
var m_plaster: Material
var m_wood_dark: Material
const MUSIC_DIR := "res://assets/audio/"
const MUSIC_BY_LEVEL := {"title": "title", "prologue": "title", "chapter1": "spring", "chapter2": "summer", "chapter3": "autumn", "chapter4": "winter", "finale": "finale"}
const MUSIC_VOLUME_DB := -9.0
var music: AudioStreamPlayer
var music_track := ""
var _music_tween: Tween
var _fade_state: Dictionary = {}  # GeometryInstance3D -> {cur, hold}:遮擋淡出狀態
var swayers: Array[Dictionary] = []  # 隨風輕擺的草花:{node, phase, amp}
var pause_layer: CanvasLayer
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
	music = AudioStreamPlayer.new()
	music.volume_db = -60.0
	add_child(music)
	_play_music(MUSIC_BY_LEVEL.get(get_script().resource_path.get_file().get_basename(), "title"))


func _play_music(track: String) -> void:
	## 配樂為循環的 ogg(tools/make_music.py 合成);換曲時舊曲淡出、新曲淡入。只保留一條淡入淡出 tween,避免互相拉扯音量。
	if track == music_track or not ResourceLoader.exists(MUSIC_DIR + track + ".ogg"):
		return
	music_track = track
	var stream := load(MUSIC_DIR + track + ".ogg") as AudioStreamOggVorbis
	stream.loop = true
	if _music_tween != null:
		_music_tween.kill()
	_music_tween = create_tween()
	if music.playing:
		_music_tween.tween_property(music, "volume_db", -60.0, 0.8)
		_music_tween.tween_callback(func() -> void:
			music.stream = stream
			music.play())
	else:
		music.stream = stream
		music.play()
	_music_tween.tween_property(music, "volume_db", MUSIC_VOLUME_DB, 2.0)


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

	_update_sway()
	_update_quest(delta)
	_update_seek()
	_update_boss(delta)
	_update_sniff()
	_level_process(delta)


# ---------- 鏡頭 ----------

func _update_camera(delta: float) -> void:
	## 可旋轉 / 縮放的第三人稱鏡頭:Z / C 或按住右鍵拖曳轉視角,滾輪縮放;指數趨近平滑跟隨。
	cam_yaw += Input.get_axis("cam_left", "cam_right") * 1.8 * delta
	var horiz := cos(cam_pitch) * cam_dist
	var offset := Vector3(sin(cam_yaw) * horiz, sin(cam_pitch) * cam_dist, cos(cam_yaw) * horiz)
	var target := player.global_position + offset
	if _cam_ready:
		camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-10.0 * delta))
	else:
		camera.global_position = target
		_cam_ready = true
	camera.look_at(player.global_position + Vector3.UP, Vector3.UP)


func _collect_tree_blockers(blocking: Dictionary) -> void:
	var from := camera.global_position
	var to := player.global_position + Vector3.UP
	for t in trees:
		var c: Vector3 = t["center"]
		if Geometry3D.get_closest_point_to_segment(c, from, to).distance_to(c) < float(t["radius"]):
			for m: MeshInstance3D in t["meshes"]:
				blocking[m] = true


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
	_collect_tree_blockers(blocking)
	_apply_fades(blocking, get_process_delta_time())


func _apply_fades(blocking: Dictionary, delta: float) -> void:
	## 擋住鏡頭的物件平滑淡出(約 0.25 秒),不再擋時延遲 0.35 秒才淡回,避免在邊緣來回閃爍。
	for g: GeometryInstance3D in blocking.keys():
		if not _fade_state.has(g):
			_fade_state[g] = {"cur": 0.0, "hold": 0.0}
	for g in _fade_state.keys():
		if not is_instance_valid(g):
			_fade_state.erase(g)
			continue
		var st: Dictionary = _fade_state[g]
		st["hold"] = 0.35 if blocking.has(g) else maxf(float(st["hold"]) - delta, 0.0)
		var goal := 1.0 if float(st["hold"]) > 0.0 else 0.0
		st["cur"] = move_toward(float(st["cur"]), goal, delta / 0.25)
		(g as GeometryInstance3D).transparency = float(st["cur"]) * 0.82
		if goal == 0.0 and float(st["cur"]) == 0.0:
			_fade_state.erase(g)


# ---------- 木靈任務、御守、嗅覺 ----------

func _setup_quest(npc_pos: Vector3, charm_positions: Array[Vector3], lines: Dictionary) -> void:
	## 在關卡中放一隻木靈與數枚御守;子類別在 _build_level 呼叫。lines 需含 intro / waiting / done 三組台詞。
	quest_lines = lines
	kodama_pos = npc_pos
	_build_kodama(npc_pos)
	for p in charm_positions:
		_build_charm(p)


func _spirit_material(light: Color, dark: Color) -> ShaderMaterial:
	## 木靈身體:與妖氣之主共用的煙霧流動貼圖 shader,換成明亮的白綠色,看起來像會呼吸的柔軟精靈。
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/miasma_body.gdshader") as Shader
	mat.set_shader_parameter("smoke", load(PARTICLE_DIR + "smoke_01.png"))
	mat.set_shader_parameter("dark", dark)
	mat.set_shader_parameter("light", light)
	mat.set_shader_parameter("rim", Color("ffffff"))
	return mat


func _build_kodama(pos: Vector3) -> void:
	## 木靈:白色圓潤的小精靈(以基本形狀組成),會輕輕晃動。
	kodama = Node3D.new()
	kodama.position = pos
	var body_mat := _spirit_material(Color("f2f1e6"), Color("c9d6c0"))
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
	## 嗅覺光柱:Kenney 光束貼圖的直立看板(只繞 Y 軸轉向鏡頭),穿透牆壁與霧、只在按住嗅覺時顯示。
	var beam_quad := QuadMesh.new()
	beam_quad.size = Vector2(2.4, 16.0)
	var beam := _beam_material("trace_07_add", Color(color, 0.5))
	var inst := WB.mesh_instance(beam_quad, beam, pos + Vector3(0, 7.0, 0))
	var glow_quad := QuadMesh.new()
	glow_quad.size = Vector2(5.0, 16.0)
	inst.add_child(WB.mesh_instance(glow_quad, _beam_material("trace_05_add", Color(color, 0.22)), Vector3.ZERO))
	var sparks := _sprite_particles("star_04_add", Color(color, 1.0), true, 18, 2.5, Vector2(0.3, 0.6), 0.0, 0.5, 2.5, true, true)
	sparks.position = Vector3(0, -7.0, 0)
	inst.add_child(sparks)
	inst.visible = false
	add_child(inst)
	return inst


func _beam_material(tex_name: String, tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = load(PARTICLE_DIR + tex_name + ".png")
	mat.albedo_color = tint
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.no_depth_test = true
	mat.disable_fog = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


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
		_dress_block(Vector3(p.x, 0.0, p.z), Vector2(4, 4), 1.0, int(p.x))
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
		var mat := _spirit_material(Color("e6f5df"), Color("a9cfa0"))
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
	boss_orb = _build_boss_body()
	boss_orb.position = center
	boss_orb.visible = false
	add_child(boss_orb)
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
	_animate_boss()
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


func _boss_sphere(radius: float, mat: Material, pos: Vector3, squash := Vector3.ONE) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 12
	m.rings = 6
	var inst := WB.mesh_instance(m, mat, pos)
	inst.scale = squash
	return inst


func _boss_cone(radius: float, height: float, mat: Material, pos: Vector3, rot_z_deg: float) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 8
	var inst := WB.mesh_instance(m, mat, pos)
	inst.rotation_degrees.z = rot_z_deg
	return inst


func _build_boss_body() -> Node3D:
	## 妖氣之主:被妖氣侵蝕的大蛇(Poly Pizza「Cobra」by jeremy,CC BY 3.0)。盤踞在庭院地面,頭高高立起;
	## 模型沒有動畫,以呼吸般的縮放與左右擺動代替。boss_model 是放在蛇身中心、腳底貼地的支點。
	var root := Node3D.new()
	boss_model = Node3D.new()
	boss_model.position = Vector3(0, -boss_center.y, 0)
	root.add_child(boss_model)
	var snake := (load(BOSS_MODEL) as PackedScene).instantiate() as Node3D
	snake.scale = Vector3.ONE * BOSS_SCALE
	snake.rotation.y = BOSS_FACING
	boss_model.add_child(snake)
	# 把蛇身的包圍盒中心移到支點上、底面貼地。
	var bb := AABB()
	var first := true
	for mi in snake.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		var rel := Transform3D.IDENTITY  # inst 相對於 snake 根的變換(此時尚未加入場景樹,不能用 global_transform)
		var n: Node = inst
		while n != null and n != snake:
			rel = (n as Node3D).transform * rel
			n = n.get_parent()
		var b := rel * inst.get_aabb()
		bb = b if first else bb.merge(b)
		first = false
	snake.position = -Vector3(bb.get_center().x, bb.position.y, bb.get_center().z) * BOSS_SCALE
	# 材質:身體貼樹皮紋(蛇鱗般粗糙),黑色部分(眼、口)改成發光的紅色。
	var body := StandardMaterial3D.new()
	body.albedo_texture = load("res://assets/textures/Bark014/Bark014_1K-JPG_Color.jpg")
	body.albedo_color = Color(0.55, 0.36, 0.42)
	body.roughness = 0.6
	body.uv1_triplanar = true
	body.uv1_scale = Vector3.ONE * 0.35
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.12, 0.08)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.08, 0.04)
	glow.emission_energy_multiplier = 2.5
	for mi in snake.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		if inst.mesh.get_surface_count() >= 3:
			inst.set_surface_override_material(0, body)
			inst.set_surface_override_material(1, glow)
	boss_arms.clear()
	return root


func _animate_boss() -> void:
	if boss_model != null:
		boss_model.scale = Vector3(1.0, 1.0 + sin(time * 1.8) * 0.025, 1.0)
		boss_model.rotation.y = sin(time * 1.1) * 0.12
	for i in boss_arms.size():
		var a := float(i) * TAU / float(boss_arms.size()) + time * 0.35
		var arm: Array = boss_arms[i]
		for k in arm.size():
			var dist := 1.0 + float(k) * 0.55
			var sway := sin(time * 2.2 + float(k) * 0.9 + float(i)) * 0.3
			(arm[k] as Node3D).position = Vector3(cos(a) * dist, -0.1 - float(k) * 0.28 + sway, sin(a) * dist)
	var to_player := player.global_position - boss_orb.global_position
	boss_orb.rotation.y = lerp_angle(boss_orb.rotation.y, atan2(to_player.x, to_player.z), 0.08)


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
	_play_music("boss")
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
	torus.inner_radius = 0.84
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 6
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("e2c8ff")
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
	_play_music(MUSIC_BY_LEVEL.get(get_script().resource_path.get_file().get_basename(), "title"))
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
		var l := WB.label(box, 30 if i == 0 else 68, 500 if i == 0 else 800, 12 if i == 0 else 22)
		l.text = lines[i]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_constant_override("outline_size", 7)
		if i == 0:
			l.add_theme_color_override("font_color", Color("f1dcae"))
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_property(box, "modulate:a", 1.0, 1.0)
	tw.tween_interval(2.2)
	tw.tween_property(box, "modulate:a", 0.0, 1.2)
	tw.finished.connect(layer.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var motion := event as InputEventMouseMotion
		cam_yaw -= motion.relative.x * 0.005
		cam_pitch = clampf(cam_pitch + motion.relative.y * 0.004, 0.35, 1.2)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var button := (event as InputEventMouseButton).button_index
		if button == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = maxf(cam_dist - 1.0, 5.0)
		elif button == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = minf(cam_dist + 1.0, 16.0)


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
		b.add_theme_font_override("font", WB.serif(700, 4))
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
	m_path = WB.tex("PavingStones138", 0.4, Color("cfc8ba"))
	m_paving = WB.tex("PavingStones138", 0.5)
	m_stone = WB.tex("Rock064", 0.4)
	m_stone_dark = WB.tex("Rock064", 0.3, Color("c2bcaf"))
	m_wood = WB.tex("WoodFloor064", 0.5, Color("c8a58a"))
	m_plaster = WB.tex("Plaster001", 0.35, Color("e2cfa4"))
	m_wood_dark = WB.tex("Wood051", 0.5)
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
			add_child(WB.mesh_instance(peak, WB.tex("Rock064", 0.03, tint), Vector3(x + l[0] * 0.15, l[2] * 0.5 - 2.0, l[0])))


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
	hud_title = WB.label(layer, 28, 700, 3)
	hud_title.position = Vector2(24, 16)
	hud_hint = WB.label(layer, 18)
	hud_hint.position = Vector2(24, 60)
	hud_prompt = WB.label(layer, 24, 700, 3)
	hud_prompt.text = "按 E 淨化"
	hud_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hud_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud_prompt.offset_top = -140.0
	hud_prompt.visible = false
	hud_msg = WB.label(layer, 44, 800, 8)
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
	_register_tree(tree)
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


func _make_path(size: Vector3, pos: Vector3, min_z := -INF) -> void:
	## 參道:石板路面,兩側不規則嵌入小石與草叢,邊緣不再是生硬的直線。min_z 以北(更小的 z)不放裝飾,避開庭院鋪石與主殿。
	add_child(WB.box_visual(size, m_path, pos))
	var rng := RandomNumberGenerator.new()
	rng.seed = SCATTER_SEED + int(pos.z * 7.0) + int(size.z)
	var rocks := ["RockPath_Round_Small_1", "RockPath_Round_Small_2", "RockPath_Round_Small_3"]
	var z := maxf(pos.z - size.z * 0.5, min_z)
	while z < pos.z + size.z * 0.5:
		for side in [-1.0, 1.0]:
			var x: float = pos.x + side * (size.x * 0.5 + rng.randf_range(0.2, 0.7))
			var inst := _load_scene(rocks[rng.randi() % rocks.size()]).instantiate() as Node3D
			inst.position = Vector3(x, _ground_y(Vector3(x, 0, z)), z)
			inst.rotation.y = rng.randf_range(0.0, TAU)
			inst.scale = Vector3.ONE * rng.randf_range(0.9, 1.4)
			add_child(inst)
			if rng.randf() < 0.3:
				var g := _load_scene("Grass_Common_Short").instantiate() as Node3D
				g.position = Vector3(x + side * rng.randf_range(0.2, 0.8), _ground_y(Vector3(x, 0, z)), z + rng.randf_range(-0.4, 0.4))
				g.scale = Vector3.ONE * rng.randf_range(0.9, 1.3)
				add_child(g)
		z += rng.randf_range(1.8, 3.0)


func _make_torii(pos: Vector3, torii_scale := 1.0) -> void:
	## 所有鳥居都走這裡:橫樑會擋住從後方跟拍的鏡頭,所以登記進遮擋半透明清單(中心與半徑隨縮放)。
	var torii := JP.torii(pos, torii_scale)
	add_child(torii)
	var meshes: Array[MeshInstance3D] = []
	for n in torii.find_children("*", "MeshInstance3D", true, false):
		meshes.append(n as MeshInstance3D)
	trees.append({"meshes": meshes, "center": pos + Vector3(0, 5.2 * torii_scale, 0), "radius": 3.2 * torii_scale})


func _register_tree(tree: Node3D) -> void:
	var meshes: Array[MeshInstance3D] = []
	var box := AABB()
	var first := true
	for n in tree.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		meshes.append(mi)
		var a := mi.global_transform * mi.get_aabb()
		box = a if first else box.merge(a)
		first = false
	if meshes.is_empty():
		return
	trees.append({"meshes": meshes, "center": box.get_center(), "radius": maxf(box.size.x, box.size.z) * 0.4})


func _sprite_particles(tex_name: String, tint: Color, additive: bool, amount: int, lifetime: float, scale_range: Vector2, ang_vel: float, radius: float, rise: float, fade := true, no_depth := false) -> CPUParticles3D:
	## 以 Kenney Particle Pack(CC0)貼圖做的看板粒子;additive 用黑底圖加色混合,否則用透明底圖一般混合。
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = load(PARTICLE_DIR + tex_name + ".png")
	mat.albedo_color = tint
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.no_depth_test = no_depth
	mat.disable_fog = no_depth
	quad.material = mat
	var p := CPUParticles3D.new()
	p.mesh = quad
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.local_coords = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = maxf(radius, 0.001)
	p.direction = Vector3.UP
	p.spread = 180.0 if rise <= 0.0 else 25.0
	p.initial_velocity_min = rise * 0.7
	p.initial_velocity_max = rise
	p.gravity = Vector3.ZERO
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -absf(ang_vel)
	p.angular_velocity_max = absf(ang_vel)
	p.scale_amount_min = scale_range.x
	p.scale_amount_max = scale_range.y
	if fade:
		var ramp := Gradient.new()
		ramp.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
		ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		p.color_ramp = ramp
	return p


func _make_miasma(pos: Vector3) -> Node3D:
	## 妖氣源:翻湧的暗紫煙霧、旋轉的光環與符印、向上飄散的星點(皆為 Kenney 粒子貼圖)。
	var root := Node3D.new()
	root.position = pos
	root.add_child(_sprite_particles("smoke_05", Color(0.16, 0.07, 0.24, 0.95), false, 6, 4.0, Vector2(1.5, 2.3), 25.0, 0.2, 0.0))
	root.add_child(_sprite_particles("smoke_01", Color(0.3, 0.12, 0.45, 0.8), false, 4, 3.0, Vector2(1.2, 1.9), 35.0, 0.15, 0.0))
	root.add_child(_sprite_particles("twirl_02_add", Color(0.62, 0.38, 1.0), true, 3, 3.0, Vector2(2.2, 2.8), 90.0, 0.0, 0.0))
	root.add_child(_sprite_particles("magic_01_add", Color(0.7, 0.45, 1.0), true, 2, 6.0, Vector2(2.6, 2.6), 20.0, 0.0, 0.0))
	root.add_child(_sprite_particles("circle_05_add", Color(0.45, 0.2, 0.8), true, 2, 3.0, Vector2(1.2, 1.5), 0.0, 0.0, 0.0))
	root.add_child(_sprite_particles("star_04_add", Color(0.85, 0.65, 1.0), true, 14, 2.2, Vector2(0.25, 0.5), 0.0, 0.6, 0.7))
	return root


func _make_wall(size: Vector3, pos: Vector3) -> StaticBody3D:
	## 土塀:石基座 + 灰泥牆身 + 瓦片壓頂 + 朱漆木柱(沿長邊每 4.5 公尺一根),取代純石頭方塊牆。
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var along_x := size.x >= size.z
	var base_h := minf(0.9, size.y * 0.25)
	var cap_h := 0.4
	var wall_h := size.y - base_h - cap_h
	body.add_child(WB.box_visual(Vector3(size.x + 0.12, base_h, size.z + 0.12), m_stone_dark, Vector3(0, -size.y * 0.5 + base_h * 0.5, 0)))
	body.add_child(WB.box_visual(Vector3(size.x, wall_h, size.z), m_plaster, Vector3(0, -size.y * 0.5 + base_h + wall_h * 0.5, 0)))
	var cap_size := Vector3(size.x + (0.3 if along_x else 0.0), cap_h, size.z + (0.0 if along_x else 0.3))
	cap_size = Vector3(maxf(cap_size.x, size.x + 0.5) if not along_x else cap_size.x, cap_h, maxf(cap_size.z, size.z + 0.5) if along_x else cap_size.z)
	body.add_child(WB.box_visual(cap_size, m_roof, Vector3(0, size.y * 0.5 - cap_h * 0.5, 0)))
	var length := size.x if along_x else size.z
	var posts := int(floor(length / 4.5)) + 1
	for i in posts:
		var t := (float(i) / float(maxi(posts - 1, 1)) - 0.5) * (length - 0.4)
		var post_size := Vector3(0.4, wall_h, size.z + 0.16) if along_x else Vector3(size.x + 0.16, wall_h, 0.4)
		var post_pos := Vector3(t, -size.y * 0.5 + base_h + wall_h * 0.5, 0) if along_x else Vector3(0, -size.y * 0.5 + base_h + wall_h * 0.5, t)
		body.add_child(WB.box_visual(post_size, m_wood_dark, post_pos))
	return body


func _dress_block(center: Vector3, size_xz: Vector2, top_y: float, seed_offset := 0) -> void:
	## 把方塊台座的稜角遮起來:四周底部嵌入大小不一的岩石、頂緣種灌木與草,讓台地看起來像自然的土石坡。
	var rng := RandomNumberGenerator.new()
	rng.seed = SCATTER_SEED + 77 + seed_offset
	var half := size_xz * 0.5
	var rocks := ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"]
	var perimeter := (size_xz.x + size_xz.y) * 2.0
	var n := int(perimeter / 2.2)
	for k in n:
		var t := (float(k) + rng.randf_range(-0.3, 0.3)) / float(n) * perimeter
		var local: Vector2
		if t < size_xz.x:
			local = Vector2(-half.x + t, -half.y)
		elif t < size_xz.x + size_xz.y:
			local = Vector2(half.x, -half.y + (t - size_xz.x))
		elif t < size_xz.x * 2.0 + size_xz.y:
			local = Vector2(half.x - (t - size_xz.x - size_xz.y), half.y)
		else:
			local = Vector2(-half.x, half.y - (t - size_xz.x * 2.0 - size_xz.y))
		var out := local.normalized() if local.length() > 0.01 else Vector2.ZERO
		var rock := _load_scene(rocks[rng.randi() % rocks.size()]).instantiate() as Node3D
		rock.position = Vector3(center.x + local.x + out.x * 0.25, _ground_y(center) - 0.35, center.z + local.y + out.y * 0.25)
		rock.rotation.y = rng.randf_range(0.0, TAU)
		rock.scale = Vector3(rng.randf_range(1.2, 2.2), rng.randf_range(1.0, 2.0), rng.randf_range(1.2, 2.2)) * clampf(top_y * 0.2 + 0.6, 0.8, 1.2)
		add_child(rock)
	# 頂緣的灌木與草。
	var green := WB.leaf_material(Color("6f8a52"))
	for k in int(perimeter / 3.0):
		var tt := rng.randf() * perimeter
		var lp: Vector2
		if tt < size_xz.x:
			lp = Vector2(-half.x + tt, -half.y + 0.4)
		elif tt < size_xz.x + size_xz.y:
			lp = Vector2(half.x - 0.4, -half.y + (tt - size_xz.x))
		elif tt < size_xz.x * 2.0 + size_xz.y:
			lp = Vector2(half.x - (tt - size_xz.x - size_xz.y), half.y - 0.4)
		else:
			lp = Vector2(-half.x + 0.4, half.y - (tt - size_xz.x * 2.0 - size_xz.y))
		var model := "Bush_Common" if rng.randf() < 0.5 else "Grass_Common_Tall"
		var inst := _load_scene(model).instantiate() as Node3D
		inst.position = Vector3(center.x + lp.x, _ground_y(center) + top_y, center.z + lp.y)
		inst.rotation.y = rng.randf_range(0.0, TAU)
		inst.scale = Vector3.ONE * rng.randf_range(0.8, 1.3)
		if model.begins_with("Bush"):
			_swap_leaf_material(inst, green)
		else:
			swayers.append({"node": inst, "phase": rng.randf_range(0.0, TAU), "amp": 0.09})
		add_child(inst)


func _build_shrine_hall() -> StaticBody3D:
	## 神社本殿:碰撞體與牆面在這裡,外觀細部(木柱樑、障子、曲面瓦屋頂、千木鰹木、注連繩)由 JP.hall_details 加。回傳封住正面的木門。
	# 神社本殿不用土壁:牆是風化的素木板。
	var m_board := JP.mat("cedar_board", Color("a08a72"), 0.25, true, 0.9)
	add_child(WB.box_body(Vector3(4, 6, 6), m_board, Vector3(-4, 3, -48)))
	add_child(WB.box_body(Vector3(4, 6, 6), m_board, Vector3(4, 3, -48)))
	add_child(WB.box_body(Vector3(12, 6, 1), m_board, Vector3(0, 3, -51.5)))
	add_child(WB.box_body(Vector3(4, 2, 0.8), m_wood_dark, Vector3(0, 5, -45.4)))
	JP.hall_details(self, m_board)
	var door := WB.box_body(Vector3(4, 4, 0.8), m_wood_dark, Vector3(0, 2, -45.4))
	add_child(door)
	add_child(WB.box_body(Vector3(1.5, 1, 1), m_stone_dark, Vector3(0, 0.5, -49.8)))
	_place_village()
	return door


func _place_village() -> void:
	## 路旁的町家與土藏(自繪貼圖 + 程式產生的曲面屋頂)。位置不空就略過,不影響各章的機關。
	var spots := [
		[Vector3(17, 0, 22), -PI * 0.5, "machiya"], [Vector3(-17, 0, 24), PI * 0.5, "kura"],
		[Vector3(18, 0, 38), -PI * 0.5, "kura"], [Vector3(-18, 0, 40), PI * 0.5, "machiya"]]
	for sp in spots:
		var p: Vector3 = sp[0]
		var ok := true
		for dx in [-5.0, 0.0, 5.0]:
			for dz in [-5.0, 0.0, 5.0]:
				if not _is_free(p + Vector3(dx, 0, dz)):
					ok = false
		if not ok:
			continue
		if sp[2] == "machiya":
			JP.machiya(self, p + Vector3(0, _ground_y(p), 0), sp[1])
			scatter_blocked.append(Rect2(p.x - 8.0, p.z - 7.0, 16.0, 14.0))
		else:
			JP.kura(self, p + Vector3(0, _ground_y(p), 0), sp[1])
			scatter_blocked.append(Rect2(p.x - 6.0, p.z - 6.0, 12.0, 12.0))


func _scatter_is_blocked(p: Vector3) -> bool:
	for r in scatter_blocked:
		if r.has_point(Vector2(p.x, p.z)):
			return true
	return false


func _scatter(model: String, count: int, min_scale: float, max_scale: float, rng: RandomNumberGenerator, leaf_mat: Material = null, clump := 1) -> void:
	## clump > 1:以選到的點為中心成叢生長(草、花不會孤零零一株一株)。草花會登記進 swayers 隨風擺動。
	var scene := _load_scene(model)
	var bounds := _scatter_bounds()
	var sway_amp := 0.0
	if model.begins_with("Grass") or model.begins_with("Fern") or model.begins_with("Clover"):
		sway_amp = 0.09
	elif model.begins_with("Flower"):
		sway_amp = 0.06
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 30:
		tries += 1
		var center := Vector3(
			rng.randf_range(bounds.position.x, bounds.end.x), 0.0,
			rng.randf_range(bounds.position.y, bounds.end.y))
		if not _is_free(center) or _scatter_is_blocked(center):
			continue
		for k in clump:
			var p := center
			if k > 0:
				p += Vector3(rng.randf_range(-1.2, 1.2), 0.0, rng.randf_range(-1.2, 1.2))
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
			if sway_amp > 0.0:
				swayers.append({"node": inst, "phase": rng.randf_range(0.0, TAU), "amp": sway_amp * rng.randf_range(0.6, 1.2)})
			placed += 1


func _update_sway() -> void:
	for sw in swayers:
		var n := sw["node"] as Node3D
		var ph: float = sw["phase"]
		var amp: float = sw["amp"]
		n.rotation.x = sin(time * 1.5 + ph) * amp
		n.rotation.z = cos(time * 1.2 + ph * 1.3) * amp


func _scatter_vegetation(density: float = 1.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SCATTER_SEED + 1
	var green := WB.leaf_material(Color("6f8a52"))
	_scatter("Grass_Common_Tall", int(18 * density), 0.8, 1.4, rng, null, 5)
	_scatter("Grass_Common_Short", int(18 * density), 0.8, 1.4, rng, null, 5)
	_scatter("Bush_Common", int(14 * density), 0.9, 1.5, rng, green)
	_scatter("Bush_Common_Flowers", int(8 * density), 0.9, 1.3, rng)
	_scatter("Fern_1", int(5 * density), 0.8, 1.4, rng, null, 3)
	_scatter("Flower_3_Group", int(5 * density), 0.8, 1.2, rng, null, 3)
	_scatter("Flower_4_Group", int(5 * density), 0.8, 1.2, rng, null, 3)
	_scatter("Clover_1", int(7 * density), 0.8, 1.3, rng, null, 3)
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

	s.orb = _make_miasma(orb_pos)
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
