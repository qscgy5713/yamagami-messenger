extends Node3D
## 開發用展示場景:把自繪的日式建築排成一排,方便近看。
## 執行:godot --path . scenes/dev_showcase.tscn;左鍵拖曳旋轉、滾輪縮放、WASD 平移、空白切換自動旋轉。

var yaw := 0.35
var pitch := 0.28
var dist := 30.0
var focus := Vector3(0, 3, 0)
var auto := true
var cam: Camera3D


func _ready() -> void:
	WB.setup_input()
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("cfd8e0")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("c9d0d8")
	e.ambient_light_energy = 0.9
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.1
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120, 60)
	ground.mesh = plane
	ground.material_override = WB.tex("Ground037", 0.3, Color("d6dcc6"))
	add_child(ground)
	JP.machiya(self, Vector3(-17, 0, 0), 0.0)
	JP.kura(self, Vector3(-3.5, 0, 0), 0.0)
	var hall := Node3D.new()
	hall.position = Vector3(10, 0, 48)  # 本殿的座標以 (0,*,-48) 為中心,平移到展示位置
	add_child(hall)
	var stone := WB.tex("Rock064", 0.3, Color("c2bcaf"))
	var board := JP.mat("cedar_board", Color("a08a72"), 0.25, true, 0.9)
	JP.hall_details(hall, board)
	for sx in [-4.0, 4.0]:  # 牆面(正式遊戲中由碰撞體方塊提供)
		hall.add_child(WB.box_visual(Vector3(4, 6, 6), board, Vector3(sx, 3, -48)))
	hall.add_child(WB.box_visual(Vector3(12, 6, 1), board, Vector3(0, 3, -51.5)))
	hall.add_child(WB.box_visual(Vector3(4, 4, 0.8), WB.tex("Wood051", 0.5), Vector3(0, 2, -45.4)))
	hall.add_child(WB.box_visual(Vector3(4, 2, 0.8), WB.tex("Wood051", 0.5), Vector3(0, 5, -45.4)))
	add_child(JP.torii(Vector3(27, 0, 3), 1.0))
	cam = Camera3D.new()
	cam.far = 400.0
	add_child(cam)
	_update_cam()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		auto = false
		yaw -= (event as InputEventMouseMotion).relative.x * 0.006
		pitch = clampf(pitch + (event as InputEventMouseMotion).relative.y * 0.005, -0.1, 1.4)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var b := (event as InputEventMouseButton).button_index
		if b == MOUSE_BUTTON_WHEEL_UP:
			dist = maxf(dist - 2.0, 6.0)
		elif b == MOUSE_BUTTON_WHEEL_DOWN:
			dist = minf(dist + 2.0, 90.0)
	elif event.is_action_pressed("jump"):
		auto = not auto


func _process(delta: float) -> void:
	if auto:
		yaw += delta * 0.18
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if move.length() > 0.0:
		var basis := Basis(Vector3.UP, yaw)
		focus += basis * Vector3(move.x, 0, move.y) * delta * 14.0
	_update_cam()


func _update_cam() -> void:
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.global_position = focus + off
	cam.look_at(focus, Vector3.UP)
