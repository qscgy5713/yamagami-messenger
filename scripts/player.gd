class_name Player
extends CharacterBody3D
## 狐狸神使:相對於鏡頭方向移動,支援跳躍。外觀以 low-poly 基本幾何體組成。

const SPEED := 6.0
const JUMP_VELOCITY := 6.5
const TURN_SPEED := 10.0

var camera: Camera3D


func _ready() -> void:
	_build_body()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis := camera.global_transform.basis if camera else Basis.IDENTITY
	var dir := cam_basis * Vector3(input.x, 0.0, input.y)
	dir.y = 0.0
	dir = dir.normalized()

	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	if dir.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), TURN_SPEED * delta)

	move_and_slide()


func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.4
	shape.shape = capsule
	add_child(shape)

	var orange := WB.material(WB.C_FOX)
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.4
	body_mesh.height = 1.4
	body_mesh.radial_segments = 6
	body_mesh.rings = 2
	add_child(WB.mesh_instance(body_mesh, orange, Vector3.ZERO))

	# 耳朵:四角錐,朝前(-Z)的一側。
	for x: float in [-0.22, 0.22]:
		var ear := CylinderMesh.new()
		ear.top_radius = 0.0
		ear.bottom_radius = 0.14
		ear.height = 0.4
		ear.radial_segments = 4
		add_child(WB.mesh_instance(ear, orange, Vector3(x, 0.9, -0.05)))

	# 尾巴:朝後(+Z)。
	var tail := CylinderMesh.new()
	tail.top_radius = 0.0
	tail.bottom_radius = 0.2
	tail.height = 0.7
	tail.radial_segments = 5
	var tail_inst := WB.mesh_instance(tail, WB.material(WB.C_CREAM), Vector3(0.0, 0.0, 0.55))
	tail_inst.rotation_degrees = Vector3(90, 0, 0)
	add_child(tail_inst)
