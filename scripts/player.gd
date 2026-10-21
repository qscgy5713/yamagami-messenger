class_name Player
extends CharacterBody3D
## 狐狸神使:相對於鏡頭方向移動,支援跳躍。模型為 Quaternius 的低多邊形紅狐(CC0)。

const SPEED := 6.0
const JUMP_VELOCITY := 6.5
const TURN_SPEED := 10.0
const FOX_SCENE := "res://assets/models/fox/Fox.glb"
const FOX_SCALE := 0.45
const BODY_RADIUS := 0.4
const BODY_HEIGHT := 1.0
const FOX_YAW_OFFSET := PI  ## 模型朝 +Z,而遊戲的「前方」是 -Z。
const ANIM_BLEND := 0.15

var camera: Camera3D
## 對話、過場時鎖住操作(仍會受重力影響)。
var controls_locked := false

var _anim: AnimationPlayer
var _current_anim := ""


func _ready() -> void:
	_build_body()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif not controls_locked and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY

	var input := Vector2.ZERO
	if not controls_locked:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis := camera.global_transform.basis if camera else Basis.IDENTITY
	var dir := cam_basis * Vector3(input.x, 0.0, input.y)
	dir.y = 0.0
	dir = dir.normalized()

	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	if dir.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), TURN_SPEED * delta)

	move_and_slide()
	_update_animation(dir.length() > 0.01)


func _update_animation(moving: bool) -> void:
	if _anim == null:
		return
	var wanted := "Idle"
	if not is_on_floor():
		wanted = "Gallop_Jump"
	elif moving:
		wanted = "Gallop"
	if wanted != _current_anim:
		_current_anim = wanted
		_anim.play(wanted, ANIM_BLEND)


func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT
	shape.shape = capsule
	add_child(shape)

	var model := (load(FOX_SCENE) as PackedScene).instantiate() as Node3D
	model.scale = Vector3.ONE * FOX_SCALE
	model.rotation.y = FOX_YAW_OFFSET
	# 模型原點在腳底,碰撞膠囊中心在身體中央,故下移半個膠囊高。
	model.position.y = -BODY_HEIGHT * 0.5
	add_child(model)

	_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim != null:
		# glTF 匯入的動畫預設不循環。
		for anim_name: String in ["Idle", "Walk", "Gallop"]:
			_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		_anim.play("Idle")
		_current_anim = "Idle"
