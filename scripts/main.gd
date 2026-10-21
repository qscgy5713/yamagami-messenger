extends Node3D
## 原型場景:地面、狐狸、踏板 + 石門機關。全部以程式碼建立,之後再換成正式關卡。

const CAMERA_OFFSET := Vector3(0.0, 9.0, 10.0)
const TORII_MESH_PATH := "res://assets/models/torii/shinto-shrine-gate.obj"
const TORII_SCALE := 1.0
const TORII_FOOT_OFFSET := 7.05

var player: Player
var camera: Camera3D
var door: StaticBody3D
var plate_bodies := 0


func _ready() -> void:
	_setup_input()
	_setup_environment()
	_build_ground()
	_build_gate()
	_build_puzzle()
	_build_player()


func _process(_delta: float) -> void:
	camera.global_position = player.global_position + CAMERA_OFFSET
	camera.look_at(player.global_position + Vector3.UP, Vector3.UP)


func _setup_input() -> void:
	var bindings := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
	}
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: Key in bindings[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("f6d5d9")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff1e6")
	env.ambient_light_energy = 0.6
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)

	camera = Camera3D.new()
	add_child(camera)


func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	return mat


func _make_mesh(mesh: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = _make_material(color)
	inst.position = pos
	return inst


func _make_box_body(size: Vector3, color: Color, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var mesh := BoxMesh.new()
	mesh.size = size
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = _make_material(color)
	body.add_child(inst)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	return body


func _build_ground() -> void:
	add_child(_make_box_body(Vector3(40, 1, 40), Color("9bc77d"), Vector3(0, -0.5, 0)))


func _build_gate() -> void:
	## 鳥居:使用 itch.io 的 low-poly 模型,放在石門後方當作目標。
	## 模型原點在頂端、腳底約在 y=-7.05,故需抬高。表面順序為 red、black。
	var inst := MeshInstance3D.new()
	inst.mesh = load(TORII_MESH_PATH) as Mesh
	inst.set_surface_override_material(0, _make_material(Color("c8352b")))
	inst.set_surface_override_material(1, _make_material(Color("2b2b2b")))
	inst.scale = Vector3.ONE * TORII_SCALE
	inst.position = Vector3(0.0, TORII_FOOT_OFFSET * TORII_SCALE, -16.0)
	add_child(inst)


func _build_puzzle() -> void:
	# 石門:擋在鳥居前,踩上踏板後下沉。
	door = _make_box_body(Vector3(6, 4, 1), Color("8a8a8a"), Vector3(0, 2, -10))
	add_child(door)
	# 兩側石牆,避免繞過石門。
	for x: float in [-12.5, 12.5]:
		add_child(_make_box_body(Vector3(19, 4, 1), Color("8a8a8a"), Vector3(x, 2, -10)))

	# 踏板:Area3D 偵測玩家。
	var plate := Area3D.new()
	plate.position = Vector3(-6, 0.05, -4)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.5
	mesh.bottom_radius = 1.5
	mesh.height = 0.1
	mesh.radial_segments = 6
	plate.add_child(_make_mesh(mesh, Color("f2c14e"), Vector3.ZERO))
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.5
	cyl.height = 1.0
	shape.shape = cyl
	plate.add_child(shape)
	plate.body_entered.connect(_on_plate_entered)
	plate.body_exited.connect(_on_plate_exited)
	add_child(plate)


func _on_plate_entered(body: Node3D) -> void:
	if body != player:
		return
	plate_bodies += 1
	_move_door(-4.5)


func _on_plate_exited(body: Node3D) -> void:
	if body != player:
		return
	plate_bodies = maxi(plate_bodies - 1, 0)
	if plate_bodies == 0:
		_move_door(2.0)


func _move_door(target_y: float) -> void:
	var tween := create_tween()
	tween.tween_property(door, "position:y", target_y, 0.8)


func _build_player() -> void:
	player = Player.new()
	player.position = Vector3(0, 1.0, 6)

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.4
	shape.shape = capsule
	player.add_child(shape)

	var orange := Color("e8832a")
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.4
	body_mesh.height = 1.4
	body_mesh.radial_segments = 6
	body_mesh.rings = 2
	player.add_child(_make_mesh(body_mesh, orange, Vector3.ZERO))

	# 耳朵:四角錐,朝前(-Z)的一側。
	for x: float in [-0.22, 0.22]:
		var ear := CylinderMesh.new()
		ear.top_radius = 0.0
		ear.bottom_radius = 0.14
		ear.height = 0.4
		ear.radial_segments = 4
		player.add_child(_make_mesh(ear, orange, Vector3(x, 0.9, -0.05)))

	# 尾巴:朝後(+Z)。
	var tail := CylinderMesh.new()
	tail.top_radius = 0.0
	tail.bottom_radius = 0.2
	tail.height = 0.7
	tail.radial_segments = 5
	var tail_inst := _make_mesh(tail, Color("fff1e6"), Vector3(0, 0.0, 0.55))
	tail_inst.rotation_degrees = Vector3(90, 0, 0)
	player.add_child(tail_inst)

	player.camera = camera
	add_child(player)
