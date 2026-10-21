class_name Player
extends CharacterBody3D
## 狐狸神使:相對於鏡頭方向移動,支援跳躍。

const SPEED := 6.0
const JUMP_VELOCITY := 6.5
const TURN_SPEED := 10.0

var camera: Camera3D


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
