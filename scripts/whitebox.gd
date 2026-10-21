class_name WB
extends RefCounted
## 白盒場景共用工具:材質、方塊、鳥居、輸入綁定。

## 色票:低飽和的日本傳統色(苔色、砂色、鼠色、朱、墨、桜色…),避免糖果色。
const C_MOSS := Color("7b8560")
const C_PATH := Color("c9bb9d")
const C_STONE := Color("8d8c86")
const C_WOOD := Color("5a4535")
const C_VERMILION := Color("a8392a")
const C_SUMI := Color("2b2b2e")
const C_SAKURA := Color("e8b3c3")
const C_WILTED := Color("77707f")
const C_WATER := Color("5f8794")
const C_GOLD := Color("b89a58")
const C_FOX := Color("b9763f")
const C_CREAM := Color("efe6d6")
const C_MIASMA := Color("4b3a63")
const C_MOUNTAIN := Color("8fa0ad")

const UI_FONT_PATH := "res://assets/fonts/NotoSansTC-Regular.otf"
const TEX_DIR := "res://assets/textures/"
const NATURE_DIR := "res://assets/models/nature/"
const LEAF_MASK_PATH := "res://assets/models/nature/Leaves_TwistedTree.png"
const TORII_MESH_PATH :="res://assets/models/torii/shinto-shrine-gate.obj"
## 鳥居模型原點在頂端,腳底約在 y=-7.05。
const TORII_FOOT_OFFSET := 7.05


static func material(color: Color, emissive := false, energy: float = 0.8) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = energy
	return mat


static var _ui_font: FontFile


static func label(parent: Node, font_size: int) -> Label:
	## HUD / 對話共用的 Label:內嵌 Noto Sans TC(Godot 預設字型沒有中日文字)、米白字加墨色描邊。
	if _ui_font == null:
		_ui_font = load(UI_FONT_PATH) as FontFile
	var l := Label.new()
	l.add_theme_font_override("font", _ui_font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", C_CREAM)
	l.add_theme_color_override("font_outline_color", C_SUMI)
	l.add_theme_constant_override("outline_size", 6)
	parent.add_child(l)
	return l


static var _tex_cache := {}


static func tex(id: String, uv_scale: float = 0.5, tint: Color = Color.WHITE) -> StandardMaterial3D:
	## ambientCG PBR 材質(Color / NormalGL / Roughness / AO)。以三向投影貼圖,
	## 方塊不論尺寸都不會被拉伸;uv_scale 是每公尺的貼圖重複次數。
	var key := "%s|%s|%s" % [id, uv_scale, tint]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var base := "%s%s/%s_1K-JPG_" % [TEX_DIR, id, id]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(base + "Color.jpg")
	mat.albedo_color = tint
	mat.normal_enabled = true
	mat.normal_texture = load(base + "NormalGL.jpg")
	mat.roughness = 1.0
	mat.roughness_texture = load(base + "Roughness.jpg")
	if ResourceLoader.exists(base + "AmbientOcclusion.jpg"):
		mat.ao_enabled = true
		mat.ao_texture = load(base + "AmbientOcclusion.jpg")
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * uv_scale
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_tex_cache[key] = mat
	return mat


static func leaf_material(tint: Color) -> StandardMaterial3D:
	## 白色的樹葉遮罩(Quaternius 設計給使用者上色),染成想要的顏色。
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(LEAF_MASK_PATH)
	mat.albedo_color = tint
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	return mat


static func mesh_instance(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	return inst


static func box_visual(size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh_instance(mesh, mat, pos)


static func box_body(size: Vector3, mat: Material, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.add_child(box_visual(size, mat, Vector3.ZERO))
	body.add_child(_box_shape(size))
	return body


static func invisible_wall(size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.add_child(_box_shape(size))
	return body


static func torii(pos: Vector3, scale: float = 1.0) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = load(TORII_MESH_PATH) as Mesh
	# 表面順序:0 = red、1 = black(依 OBJ 的 usemtl 順序)。
	inst.set_surface_override_material(0, material(C_VERMILION))
	inst.set_surface_override_material(1, material(C_SUMI))
	inst.scale = Vector3.ONE * scale
	inst.position = pos + Vector3(0.0, TORII_FOOT_OFFSET * scale, 0.0)
	return inst


static func setup_input() -> void:
	var bindings := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
		"interact": [KEY_E],
	}
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: Key in bindings[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


static func _box_shape(size: Vector3) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	return shape
