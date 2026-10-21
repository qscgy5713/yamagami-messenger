extends Node3D
## 開發用:把首領「鬼」(含妖氣材質)單獨放在乾淨舞台上,可繞行觀看。
## 執行:godot --path . scenes/dev_boss.tscn;左鍵拖曳旋轉、滾輪縮放、空白切換自動旋轉。

var yaw := 0.4
var pitch := 0.12
var dist := 9.0
var auto := true
var cam: Camera3D
var boss: Node3D


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("2a2638")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("8d86a8")
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -30, 0)
	add_child(sun)
	cam = Camera3D.new()
	add_child(cam)
	# 借用關卡裡已經組好的鬼(含材質),取出後丟掉關卡。
	var ch: Node3D = load("res://scenes/chapter1.tscn").instantiate()
	add_child(ch)
	await get_tree().process_frame
	boss = ch.boss_orb
	boss.get_parent().remove_child(boss)
	add_child(boss)
	boss.visible = true
	boss.position = Vector3(0, 3.0, 0)
	ch.queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		auto = false
		yaw -= (event as InputEventMouseMotion).relative.x * 0.006
		pitch = clampf(pitch + (event as InputEventMouseMotion).relative.y * 0.005, -0.3, 1.2)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var b := (event as InputEventMouseButton).button_index
		if b == MOUSE_BUTTON_WHEEL_UP:
			dist = maxf(dist - 1.0, 3.0)
		elif b == MOUSE_BUTTON_WHEEL_DOWN:
			dist = minf(dist + 1.0, 30.0)
	elif event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_SPACE:
		auto = not auto


func _process(delta: float) -> void:
	if auto:
		yaw += delta * 0.4
	cam.global_position = Vector3(0, 3.0, 0) + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.look_at(Vector3(0, 3.0, 0), Vector3.UP)
