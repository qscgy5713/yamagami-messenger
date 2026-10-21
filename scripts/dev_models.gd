extends Node3D
## 開發用:逐一檢視 assets/models/_cand 裡的候選模型。左右方向鍵切換、左鍵拖曳旋轉、滾輪縮放。
var files: Array[String] = []
var idx := 0
var current: Node3D
var center := Vector3.ZERO
var radius := 5.0
var yaw := 0.7
var pitch := 0.25
var dist := 8.0
var cam: Camera3D
var label: Label

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("cfd8e0")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("c9d0d8")
	e.ambient_light_energy = 0.9
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	add_child(sun)
	cam = Camera3D.new()
	cam.far = 2000.0
	add_child(cam)
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.position = Vector2(20, 14)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color.BLACK)
	layer.add_child(label)
	for f in DirAccess.open("res://assets/models/_cand").get_files():
		if f.ends_with(".glb"):
			files.append(f)
	files.sort()
	var start := 0
	for a in OS.get_cmdline_user_args():  # godot --path . scenes/dev_models.tscn -- Kaijyu
		for i in files.size():
			if files[i].begins_with(a):
				start = i
	_show(start)

func _show(i: int) -> void:
	idx = posmod(i, files.size())
	if current != null:
		current.queue_free()
	current = (load("res://assets/models/_cand/" + files[idx]) as PackedScene).instantiate()
	add_child(current)
	await get_tree().process_frame
	var bb := AABB()
	var first := true
	for mi in current.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		var b := inst.global_transform * inst.get_aabb()
		bb = b if first else bb.merge(b)
		first = false
	center = bb.get_center()
	dist = maxf(bb.size.length() * 1.0, 0.5)
	label.text = "%d / %d   %s   (← → 切換)" % [idx + 1, files.size(), files[idx].get_basename()]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed:
		match (event as InputEventKey).keycode:
			KEY_RIGHT: _show(idx + 1)
			KEY_LEFT: _show(idx - 1)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		yaw -= (event as InputEventMouseMotion).relative.x * 0.006
		pitch = clampf(pitch + (event as InputEventMouseMotion).relative.y * 0.005, -0.3, 1.4)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var b := (event as InputEventMouseButton).button_index
		if b == MOUSE_BUTTON_WHEEL_UP:
			dist *= 0.88
		elif b == MOUSE_BUTTON_WHEEL_DOWN:
			dist *= 1.14

func _process(delta: float) -> void:
	yaw += delta * 0.25
	cam.global_position = center + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.look_at(center, Vector3.UP)
