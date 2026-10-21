extends LevelBase
## 終章・山神甦醒。黎明的山頂,四季的神木各占一方;逐一淨化後,封住山神的巨石沉下,山神化為光升起,對話後進入結語。

const SEASONS := [
	{"name": "春", "tree": Vector3(-15, 0, 4), "bloom": Color("e8b3c3")},
	{"name": "夏", "tree": Vector3(15, 0, 4), "bloom": Color("6c9a50")},
	{"name": "秋", "tree": Vector3(-11, 0, -13), "bloom": Color("c4552f")},
	{"name": "冬", "tree": Vector3(11, 0, -13), "bloom": Color("dfe9f2")},
]
const ALTAR_POS := Vector3(0.0, 0.0, -8.0)

var mound: StaticBody3D
var god: MeshInstance3D
var god_light: OmniLight3D
var ending := false


# ---------- 基底的覆寫 ----------

func _environment_config() -> Dictionary:
	# 黎明:粉金色地平線、薄霧、柔和的低角度光。
	return {
		"sky_top": Color("7f93b3"),
		"sky_horizon": Color("f0c9a4"),
		"sky_ground": Color("b9a99a"),
		"ambient_energy": 0.6,
		"fog_color": Color("ecd2b8"),
		"fog_density": 0.008,
		"sun_color": Color("ffd9a8"),
		"sun_energy": 1.0,
		"sun_rotation": Vector3(-14.0, -25.0, 0.0),
		"saturation": 0.95,
		"glow": true,
	}


func _chapter_title() -> PackedStringArray:
	return PackedStringArray(["終章", "山神甦醒"])


func _start_position() -> Vector3:
	return Vector3(0.0, 1.0, 22.0)


func _scatter_bounds() -> Rect2:
	return Rect2(-29.0, -29.0, 58.0, 54.0)


func _is_free(p: Vector3) -> bool:
	if absf(p.x) < 8.0 and p.z > -16.0 and p.z < 0.0:
		return false
	if absf(p.x) < 3.0 and p.z > 0.0:
		return false
	for season in SEASONS:
		var t: Vector3 = season["tree"]
		if Vector2(p.x - t.x, p.z - t.z).length() < 4.5:
			return false
	return true


func _start() -> void:
	_update_hud()
	await _say([
		{"who": "", "text": "山頂的黎明。四棵季節的神木圍著沉睡的山神,各自等待著。"},
		{"who": "", "text": "把四季的力量,一個一個還給山。"},
	])


func _build_level() -> void:
	_build_ground()
	_build_altar()
	_build_seasons()
	_build_scenery()
	_scatter_vegetation(0.8)


func _on_source_purified(_s: LevelBase.Source) -> void:
	_update_hud()
	if purified >= SEASONS.size():
		_awaken()


# ---------- 場景 ----------

func _build_ground() -> void:
	add_child(WB.box_body(Vector3(60, 1, 80), m_ground, Vector3(0, -0.5, -5)))
	_build_surroundings(30.0, -45.0, 35.0, WB.tex("Ground037", 0.3, Color("c4c9b2")))


func _build_altar() -> void:
	_make_path(Vector3(3, 0.06, 36), Vector3(0, 0.03, 10))
	add_child(WB.box_body(Vector3(14, 0.4, 14), m_paving, Vector3(0, 0.2, -8)))
	_make_torii(Vector3(0, 0.4, -17), 1.2)
	for p: Vector3 in [Vector3(-6, 0.4, -1.5), Vector3(6, 0.4, -1.5), Vector3(-6, 0.4, -14), Vector3(6, 0.4, -14)]:
		_add_lantern(p, true)
	# 封住山神的巨石:甦醒時沉入地下。
	mound = WB.box_body(Vector3(6, 3.2, 6), m_stone, ALTAR_POS + Vector3(0, 2.0, 0))
	add_child(mound)
	# 山神的光:一開始藏在巨石裡。
	var orb := SphereMesh.new()
	orb.radius = 1.4
	orb.height = 2.8
	var mat := WB.material(Color("fff1cf"), true, 4.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.9
	god = WB.mesh_instance(orb, mat, ALTAR_POS + Vector3(0, 1.8, 0))
	god.scale = Vector3.ONE * 0.05
	god.visible = false
	add_child(god)
	god_light = OmniLight3D.new()
	god_light.position = ALTAR_POS + Vector3(0, 3.0, 0)
	god_light.light_color = Color("ffe3b0")
	god_light.light_energy = 0.0
	god_light.omni_range = 30.0
	add_child(god_light)


func _build_seasons() -> void:
	for i in SEASONS.size():
		var t: Vector3 = SEASONS[i]["tree"]
		_make_source(t + Vector3(0, 1.2, 2.4), t, t + Vector3(0, 1.0, 4.0), 0.5, i)
		sources[i].bloom = SEASONS[i]["bloom"]


func _build_scenery() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SCATTER_SEED + 5
	var z_list: Array[float] = [20.0, 12.0, 4.0]
	for i in z_list.size():
		var leaves := WB.leaf_material(Color("8fa86a"))
		_make_tree(Vector3(-5.5, 0, z_list[i]), leaves, i, 0.5, rng.randf_range(0.0, TAU))
		_make_tree(Vector3(5.5, 0, z_list[i] + 2.0), leaves, i + 1, 0.5, rng.randf_range(0.0, TAU))
	_build_mountains(Color("f0dfcb"))


# ---------- 甦醒與結語 ----------

func _update_hud() -> void:
	hud_title.text = "終章・山神甦醒  %d / %d" % [purified, SEASONS.size()]
	hud_hint.text = "走向四季的神木,按 E 淨化" if purified < SEASONS.size() else ""


func _awaken() -> void:
	if ending:
		return
	ending = true
	prompt_enabled = false
	player.controls_locked = true
	await get_tree().create_timer(1.6).timeout
	_flash("山在震動……")
	create_tween().tween_property(mound, "position:y", -3.5, 3.0)
	await get_tree().create_timer(2.5).timeout
	god.visible = true
	var tw := create_tween().set_parallel()
	tw.tween_property(god, "scale", Vector3.ONE, 3.0)
	tw.tween_property(god, "position:y", 6.0, 3.0)
	tw.tween_property(god_light, "light_energy", 3.0, 3.0)
	await tw.finished
	await _say([
		{"who": "山神", "text": "……好久,沒有感覺到風了。"},
		{"who": "山神", "text": "是你,一處一處,叫醒了我的社。"},
		{"who": "山神", "text": "春的花、夏的水、秋的葉、冬的燈火,都回到山裡了。"},
		{"who": "", "text": "額間的神使之印微微發亮,小狐狸低下頭。"},
		{"who": "山神", "text": "回去吧,神使。山下的人們,正等著四季再次輪轉。"},
	])
	player.controls_locked = true
	await _show_ending()


func _show_ending() -> void:
	fade_rect.color = Color(1.0, 0.97, 0.92, 0.0)
	await _fade(1.0, 3.0)
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	box.modulate.a = 0.0
	layer.add_child(box)
	var texts := [
		["山神的使者", 56, Color("2b2b2b")],
		["── 完 ──", 28, Color("5a5a5a")],
		["", 16, Color.BLACK],
		["素材:Quaternius(CC0)、ambientCG(CC0)、Noto Sans TC(OFL)", 18, Color("5a5a5a")],
		["感謝遊玩", 24, Color("2b2b2b")],
	]
	for t in texts:
		var l := WB.label(box, t[1])
		l.text = t[0]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color", t[2])
		l.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0))
	create_tween().tween_property(box, "modulate:a", 1.0, 2.0)
