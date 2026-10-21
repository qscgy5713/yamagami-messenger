extends LevelBase
## 標題畫面:黎明的參道,鏡頭緩緩繞著狐狸旋轉;按 E 開始序章。

const NEXT_SCENE := "res://scenes/prologue.tscn"

var starting := false


func _environment_config() -> Dictionary:
	return {
		"sky_top": Color("7f93b3"),
		"sky_horizon": Color("f0c9a4"),
		"sky_ground": Color("b9a99a"),
		"fog_color": Color("ecd2b8"),
		"fog_density": 0.009,
		"sun_color": Color("ffd9a8"),
		"sun_rotation": Vector3(-14.0, -25.0, 0.0),
		"glow": true,
	}


func _start_position() -> Vector3:
	return Vector3(0.0, 1.0, 6.0)


func _scatter_bounds() -> Rect2:
	return Rect2(-29.0, -30.0, 58.0, 50.0)


func _is_free(p: Vector3) -> bool:
	return absf(p.x) > 4.0 or p.z > 14.0 or p.z < -24.0


func _build_level() -> void:
	add_child(WB.box_body(Vector3(60, 1, 70), m_ground, Vector3(0, -0.5, -10)))
	_build_surroundings(30.0, -45.0, 25.0, WB.tex("Ground037", 0.3, Color("c4c9b2")))
	_make_path(Vector3(5, 0.06, 60), Vector3(0, 0.03, -10))
	_make_torii(Vector3(0, 0, -6), 1.1)
	_make_torii(Vector3(0, 0, -18), 1.1)
	for z: float in [4.0, -2.0, -10.0, -14.0]:
		_add_lantern(Vector3(-3.6, 0, z), true)
		_add_lantern(Vector3(3.6, 0, z), true)
	var rng := RandomNumberGenerator.new()
	rng.seed = SCATTER_SEED + 6
	for i in 5:
		var bloom := WB.leaf_material(WB.C_SAKURA)
		_make_tree(Vector3(-8.0, 0, 8.0 - i * 7.0), bloom, i, 0.5, rng.randf_range(0.0, TAU))
		_make_tree(Vector3(8.5, 0, 6.0 - i * 7.0), bloom, i + 1, 0.5, rng.randf_range(0.0, TAU))
	_build_mountains(Color("f0dfcb"))
	_scatter_vegetation(0.7)


func _start() -> void:
	player.controls_locked = true
	var layer := CanvasLayer.new()
	add_child(layer)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(box)
	var title := WB.label(box, 96, 800, 28)
	title.text = "山神的使者"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_color", Color("fff4dc"))
	title.add_theme_constant_override("shadow_offset_y", 5)
	# 標題與副標之間一條細金線。
	var rule_row := HBoxContainer.new()
	rule_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(420, 2)
	rule.color = Color(WB.C_GOLD, 0.75)
	rule_row.add_child(rule)
	box.add_child(rule_row)
	var sub := WB.label(box, 24, 500, 10)
	sub.text = "四季之社 ・ 一隻小狐狸的旅程"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color("f1dcae"))
	hud_prompt.text = "按 E 開始"
	hud_prompt.visible = true
	hud_prompt.offset_top = -120.0
	var help := WB.label(layer, 16)
	help.text = "WASD / 方向鍵 移動   空白 跳躍   E 互動   Esc 暫停"
	help.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	help.grow_horizontal = Control.GROW_DIRECTION_BOTH
	help.offset_top = -50.0
	help.modulate.a = 0.8


func _update_camera(_delta: float) -> void:
	var angle := time * 0.12 - 0.4
	camera.global_position = player.global_position + Vector3(sin(angle) * 7.5, 2.2, cos(angle) * 7.5)
	camera.look_at(player.global_position + Vector3(0.0, 1.0, -3.0), Vector3.UP)


func _level_process(_delta: float) -> void:
	hud_prompt.visible = not starting
	if starting or Input.is_action_just_pressed("interact") == false:
		return
	starting = true
	hud_prompt.visible = false
	await _fade(1.0, 1.0)
	get_tree().change_scene_to_file(NEXT_SCENE)
