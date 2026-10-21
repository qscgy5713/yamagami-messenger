class_name JP
extends RefCounted
## 日式建築元件組:程式產生的曲面屋頂(有「反り」翹起的屋簷)、自繪貼圖(tools/make_textures.py)、
## 神社本殿細部、町家、土藏(海鼠壁)、明神鳥居。參考來源與對照見 doc/design-refs.md。

const TEX_DIR := "res://assets/textures/jp/"
static var _cache := {}


static func mat(file: String, tint := Color.WHITE, scale := 1.0, triplanar := false, rough := 0.85, double_sided := false) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s|%s|%s" % [file, tint, scale, triplanar, rough, double_sided]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX_DIR + file + ".png")
	m.albedo_color = tint
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if triplanar:
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * scale
	if double_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = m
	return m


static func lacquer(color: Color, rough := 0.28) -> StandardMaterial3D:
	var key := "lacquer|%s|%s" % [color, rough]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = 0.1
	m.cull_mode = BaseMaterial3D.CULL_DISABLED  # 曲面板的繞向不一,雙面顯示避免破洞
	_cache[key] = m
	return m


# ---------- 幾何 ----------

static func _quad(st: SurfaceTool, p: Array, uv: Array) -> void:
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_uv(uv[idx])
		st.add_vertex(p[idx])


static func slab(prof: Array, dz: float, thick: float, tile: float) -> ArrayMesh:
	## 沿 X 的剖面 prof(Vector2 陣列,由左到右)在 Z 方向擠出 ±dz 的厚板:上面、下面、兩端面、前後面。
	## UV 以 tile 公尺為一個貼圖週期(u 沿 Z、v 沿剖面長度)。
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var run := 0.0
	for i in prof.size() - 1:
		var a: Vector2 = prof[i]
		var b: Vector2 = prof[i + 1]
		var v0 := run / tile
		run += a.distance_to(b)
		var v1 := run / tile
		var u1 := 2.0 * dz / tile
		_quad(st, [Vector3(a.x, a.y, -dz), Vector3(a.x, a.y, dz), Vector3(b.x, b.y, dz), Vector3(b.x, b.y, -dz)],
				[Vector2(0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(0, v1)])
		_quad(st, [Vector3(a.x, a.y - thick, -dz), Vector3(a.x, a.y - thick, dz), Vector3(b.x, b.y - thick, dz), Vector3(b.x, b.y - thick, -dz)],
				[Vector2(0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(0, v1)])
		for z in [-dz, dz]:
			_quad(st, [Vector3(a.x, a.y, z), Vector3(b.x, b.y, z), Vector3(b.x, b.y - thick, z), Vector3(a.x, a.y - thick, z)],
					[Vector2(a.x / tile, a.y / tile), Vector2(b.x / tile, b.y / tile), Vector2(b.x / tile, (b.y - thick) / tile), Vector2(a.x / tile, (a.y - thick) / tile)])
	for end in [prof[0], prof[prof.size() - 1]]:
		var e: Vector2 = end
		_quad(st, [Vector3(e.x, e.y, -dz), Vector3(e.x, e.y, dz), Vector3(e.x, e.y - thick, dz), Vector3(e.x, e.y - thick, -dz)],
				[Vector2(0, 0), Vector2(2.0 * dz / tile, 0), Vector2(2.0 * dz / tile, thick / tile), Vector2(0, thick / tile)])
	st.generate_normals()
	return st.commit()


static func _two_sided(m: StandardMaterial3D) -> StandardMaterial3D:
	## 屋頂底面與山牆端面的三角形繞向不固定,複製一份雙面材質(快取),避免被背面剔除而看穿。
	var key := "2s|%s" % m.get_instance_id()
	if _cache.has(key):
		return _cache[key]
	var c := m.duplicate() as StandardMaterial3D
	c.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = c
	return c


static func attic_fill(w: float, d: float, rise: float, e: float, thick: float, m: Material) -> MeshInstance3D:
	## 牆體範圍內(|x| <= w/2、|z| <= d/2)從牆頂填滿到屋頂下緣:山牆與兩側牆上緣都是實心;屋簷外伸的部分不填。
	var hw := w * 0.5
	var hz := d * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var n := 16
	for i in n:
		var xa := lerpf(-hw, hw, float(i) / n)
		var xb := lerpf(-hw, hw, float(i + 1) / n)
		var ya := maxf(rise * pow(1.0 - absf(xa) / e, 1.12) - thick, 0.0)
		var yb := maxf(rise * pow(1.0 - absf(xb) / e, 1.12) - thick, 0.0)
		for z in [-hz, hz]:
			_quad(st, [Vector3(xa, -0.5, z), Vector3(xb, -0.5, z), Vector3(xb, yb, z), Vector3(xa, ya, z)],
					[Vector2(xa * 0.3, 0.0), Vector2(xb * 0.3, 0.0), Vector2(xb * 0.3, yb * 0.3), Vector2(xa * 0.3, ya * 0.3)])
	for x in [-hw, hw]:
		var y := maxf(rise * pow(1.0 - absf(x) / e, 1.12) - thick, 0.0)
		_quad(st, [Vector3(x, -0.5, -hz), Vector3(x, -0.5, hz), Vector3(x, y, hz), Vector3(x, y, -hz)],
				[Vector2(0, 0), Vector2(d * 0.3, 0), Vector2(d * 0.3, y * 0.3), Vector2(0, y * 0.3)])
	st.generate_normals()
	var inst := MeshInstance3D.new()
	inst.mesh = st.commit()
	inst.material_override = _two_sided(m as StandardMaterial3D)
	return inst


static func _mi(mesh: Mesh, m: Material, pos: Vector3) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = m
	inst.position = pos
	return inst


static func _box(size: Vector3, m: Material, pos: Vector3) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mi(b, m, pos)


static func roof(w: float, d: float, rise: float, over_x: float, over_z: float, pos: Vector3, yaw := 0.0, tile_tint := Color("c9ccd4"), gable: Material = null, body_w := -1.0, body_d := -1.0, tile_mat: Material = null) -> StaticBody3D:
	## 切妻(兩坡)瓦屋頂,棟沿 Z。剖面為「反り」曲線:棟附近陡、往簷下漸平、簷尖微微翹起。
	## 附帶白灰泥棟瓦、兩端鬼瓦,以及簷下一排垂木端。放在 StaticBody 裡,鏡頭被遮住時可被淡出。
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = yaw
	# 一般民家的屋頂:坡度接近直線、只在簷口微微下彎,屋簷出挑小,不翹角(翹角是寺社才有的)。
	over_x = minf(over_x, 0.7)
	over_z = minf(over_z, 0.5)
	var e := w * 0.5 + over_x
	var dz := d * 0.5 + over_z
	var prof: Array = []
	var n := 24
	for i in n + 1:
		var x := lerpf(-e, e, float(i) / n)
		var s := absf(x) / e
		prof.append(Vector2(x, rise * pow(1.0 - s, 1.12)))
	var cover: Material = tile_mat if tile_mat != null else mat("kawara", tile_tint, 1.0, false, 0.55, true)
	body.add_child(_mi(slab(prof, dz, 0.22, 4.0), _two_sided(cover as StandardMaterial3D), Vector3.ZERO))
	body.add_child(attic_fill(body_w if body_w > 0.0 else w, body_d if body_d > 0.0 else d, rise, e, 0.22, gable if gable != null else WB.tex("Wood051", 0.5)))
	# 妻側(山牆面):破風板(沿屋頂斜邊的厚木板,黑漆)、拝み懸魚(頂點下的木雕板)、山牆小格子窗。
	var gable_z := (body_d if body_d > 0.0 else d) * 0.5
	var barge := lacquer(Color("231d19"), 0.5)
	var gegyo_r := clampf(rise * 0.085, 0.16, 0.3)
	var gegyo_wood := WB.tex("Wood051", 0.5, Color("b08a68"))
	for z in [-dz - 0.04, dz + 0.04]:
		body.add_child(_mi(slab(prof, 0.07, 0.55, 4.0), barge, Vector3(0, 0.04, z)))
		var fish := _mi(SphereMesh.new(), gegyo_wood, Vector3(0, rise - 0.75 - gegyo_r, z - signf(z) * 0.02))
		(fish.mesh as SphereMesh).radius = gegyo_r
		(fish.mesh as SphereMesh).height = gegyo_r * 2.0
		fish.scale = Vector3(1.0, 1.15, 0.22)
		body.add_child(fish)
		for sx in [-1.0, 1.0]:
			body.add_child(_box(Vector3(gegyo_r * 0.8, gegyo_r * 0.45, 0.1), gegyo_wood, Vector3(sx * gegyo_r * 1.0, rise - 0.75 - gegyo_r, z - signf(z) * 0.02)))
	var win := Vector2(clampf(rise * 0.55, 0.9, 1.9), clampf(rise * 0.36, 0.6, 1.25))
	koshi_window(body, Vector3(0, rise * 0.40, gable_z), win, 0.0)
	koshi_window(body, Vector3(0, rise * 0.40, -gable_z), win, PI)
	var plaster := mat("namako", Color("e8e6dc"), 1.0, true, 0.9)
	body.add_child(_box(Vector3(0.42, 0.3, dz * 2.0 + 0.2), plaster, Vector3(0, rise + 0.04, 0)))
	for z in [-dz - 0.05, dz + 0.05]:
		body.add_child(_box(Vector3(0.5, 0.7, 0.34), mat("kawara", Color("9aa0ae"), 1.0, true, 0.5), Vector3(0, rise + 0.28, z)))
	var wood := WB.tex("Wood051", 0.5)
	var k := -dz + 0.5
	while k < dz - 0.3:
		for side in [-1.0, 1.0]:
			body.add_child(_box(Vector3(1.0, 0.14, 0.17), wood, Vector3(side * (e - 0.5), rise * pow(0.5 / e, 1.12) - 0.3, k)))
		k += 0.7
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w + 2.0 * over_x, rise * 0.7 + 0.4, d + 2.0 * over_z)
	shape.shape = box
	shape.position = Vector3(0, rise * 0.35, 0)
	body.add_child(shape)
	return body


# ---------- 神社本殿細部 ----------

static func hall_details(parent: Node3D, plaster: Material) -> void:
	## 本殿(以 (0,*,-48) 為中心)的外觀:素木板牆、障子、深色木柱樑、縁側、石基座、
	## 曲面瓦屋頂、鰹木與千木、注連繩。碰撞體由呼叫端建立。
	var wood := WB.tex("Wood051", 0.5)
	var stone := WB.tex("Rock064", 0.3, Color("c2bcaf"))
	for x in [-6.0, -2.0, 2.0, 6.0]:
		parent.add_child(_box(Vector3(0.5, 6.0, 0.5), wood, Vector3(x, 3.0, -44.85)))
	for x in [-6.0, 6.0]:
		parent.add_child(_box(Vector3(0.5, 6.0, 0.5), wood, Vector3(x, 3.0, -51.2)))
	parent.add_child(_box(Vector3(12.6, 0.4, 0.55), wood, Vector3(0, 5.55, -44.85)))
	parent.add_child(_box(Vector3(12.6, 0.3, 0.5), wood, Vector3(0, 0.45, -44.85)))
	for x in [-6.0, 6.0]:
		parent.add_child(_box(Vector3(0.5, 0.4, 6.8), wood, Vector3(x, 5.55, -48)))
	# 障子:每段牆面 3 扇自繪障子(和紙 + 組子)。
	var shoji := mat("shoji", Color.WHITE, 1.0, false, 0.9)
	shoji.emission_enabled = true
	shoji.emission = Color("ffe9c0")
	shoji.emission_energy_multiplier = 0.18
	for cx in [-4.0, 4.0]:
		for k in 3:
			var q := QuadMesh.new()
			q.size = Vector2(1.12, 2.3)
			parent.add_child(_mi(q, shoji, Vector3(cx + (k - 1) * 1.17, 1.55, -44.93)))
	# 日式格子窗:正面障子上方、兩側牆、背面。
	for x in [-4.0, 4.0]:
		koshi_window(parent, Vector3(x, 4.15, -44.6), Vector2(2.6, 1.1), 0.0)
	for sx in [-1.0, 1.0]:
		for z in [-46.4, -49.6]:
			koshi_window(parent, Vector3(sx * 6.0, 3.3, z), Vector2(1.7, 1.9), sx * PI * 0.5)
	koshi_window(parent, Vector3(0, 3.3, -52.0), Vector2(2.4, 1.9), PI)
	# 縁側(木地板迴廊)、石基座、台階。
	parent.add_child(_box(Vector3(14.6, 0.25, 1.8), wood, Vector3(0, 0.12, -44.2)))
	parent.add_child(_box(Vector3(15.4, 0.3, 9.4), stone, Vector3(0, 0.0, -48.2)))
	parent.add_child(_box(Vector3(4.4, 0.2, 1.0), stone, Vector3(0, 0.1, -43.0)))
	# 曲面瓦屋頂(妻入,山牆朝前)。
	var r := roof(12.6, 7.4, 3.3, 1.2, 1.3, Vector3(0, 6.0, -48), 0.0, Color("c9ccd4"), plaster, 12.5, 6.9, WB.tex("ThatchedRoof001A", 0.3, Color("b09a80")))
	parent.add_child(r)
	# 鰹木(屋脊上橫放的圓木)與千木(山牆頂交叉伸出的木條)。
	var light_wood := WB.tex("Wood067", 0.6, Color("d9b58f"))
	for k in 5:
		var log := CylinderMesh.new()
		log.top_radius = 0.22
		log.bottom_radius = 0.22
		log.height = 1.2
		var inst := _mi(log, light_wood, Vector3(0, 3.7, -3.4 + k * 1.7))
		inst.rotation_degrees = Vector3(0, 0, 90)
		r.add_child(inst)
	for zz in [-4.7, 4.7]:
		for ang in [-28.0, 28.0]:
			var chigi := _box(Vector3(0.13, 2.3, 0.13), light_wood, Vector3(0, 4.3, zz))
			chigi.rotation_degrees = Vector3(0, 0, ang)
			r.add_child(chigi)
	# 注連繩與紙垂。
	var rope_mesh := CylinderMesh.new()
	rope_mesh.top_radius = 0.16
	rope_mesh.bottom_radius = 0.16
	rope_mesh.height = 4.4
	var rope := _mi(rope_mesh, WB.tex("ThatchedRoof001A", 0.35, Color("d8cbb0")), Vector3(0, 4.35, -45.1))
	rope.rotation_degrees = Vector3(0, 0, 90)
	parent.add_child(rope)
	var paper := WB.material(Color("f4efe4"))
	for x in [-1.5, 0.0, 1.5]:
		parent.add_child(_box(Vector3(0.35, 0.8, 0.04), paper, Vector3(x, 3.75, -45.1)))
	parent.add_child(_box(Vector3(1.6, 0.9, 0.9), wood, Vector3(0, 0.55, -43.6)))


static func koshi_window(parent: Node3D, pos: Vector3, size: Vector2, yaw: float) -> void:
	## 木格子窗:深色窗框 + 內側暗底 + 直條格子貼圖。pos 是牆面上的位置,yaw 讓窗朝外(預設朝 +Z)。
	var wood := WB.tex("Wood051", 0.5, Color("6e5441"))
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	holder.add_child(_box(Vector3(size.x, size.y, 0.06), WB.material(Color("1d1712")), Vector3(0, 0, 0.03)))
	var q := QuadMesh.new()
	q.size = size
	holder.add_child(_mi(q, mat("koshi", Color.WHITE, 1.0, false, 0.8), Vector3(0, 0, 0.07)))
	for sy in [-1.0, 1.0]:
		holder.add_child(_box(Vector3(size.x + 0.28, 0.14, 0.2), wood, Vector3(0, sy * (size.y * 0.5 + 0.07), 0.08)))
	for sx in [-1.0, 1.0]:
		holder.add_child(_box(Vector3(0.14, size.y + 0.28, 0.2), wood, Vector3(sx * (size.x * 0.5 + 0.07), 0, 0.08)))
	parent.add_child(holder)


# ---------- 町家與土藏 ----------

static func _solid(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)


static func machiya(parent: Node3D, pos: Vector3, yaw: float, w := 9.0, d := 7.0) -> Node3D:
	## 町家:石基座、風化杉板牆、直條格子窗(koshi)、暖簾、一樓上方的小庇、土黃灰泥二樓、灰瓦大屋頂。
	## 正面朝本地 +Z。
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	var cedar := mat("cedar_board", Color("a7876a"), 0.25, true, 0.9)
	var ochre := WB.tex("Plaster001", 0.35, Color("d8bf94"))
	var wood := WB.tex("Wood051", 0.5, Color("8a6a52"))
	var stone := WB.tex("Rock064", 0.3, Color("c2bcaf"))
	var h1 := 3.2
	var h2 := 2.8
	root.add_child(_box(Vector3(w + 0.5, 0.4, d + 0.5), stone, Vector3(0, 0.2, 0)))
	# 一樓:左右杉板牆、中間大門(格子窗 + 暖簾)。
	var door_w := 2.2
	var side_w := (w - door_w) * 0.5
	for sx in [-1.0, 1.0]:
		root.add_child(_box(Vector3(side_w, h1, 0.3), cedar, Vector3(sx * (door_w * 0.5 + side_w * 0.5), 0.4 + h1 * 0.5, d * 0.5)))
		var koshi := QuadMesh.new()
		koshi.size = Vector2(side_w - 0.5, 1.7)
		root.add_child(_mi(koshi, mat("koshi", Color.WHITE, 1.0, false, 0.8), Vector3(sx * (door_w * 0.5 + side_w * 0.5), 0.4 + 1.55, d * 0.5 + 0.22)))
	root.add_child(_box(Vector3(door_w, 0.7, 0.3), wood, Vector3(0, 0.4 + h1 - 0.35, d * 0.5)))
	var noren := QuadMesh.new()
	noren.size = Vector2(1.7, 1.2)
	root.add_child(_mi(noren, mat("noren", Color.WHITE, 1.0, false, 0.95, true), Vector3(0, 0.4 + h1 - 1.3, d * 0.5 + 0.2)))
	for sx in [-1.0, 1.0]:
		root.add_child(_box(Vector3(0.3, h1, 0.3), wood, Vector3(sx * (door_w * 0.5), 0.4 + h1 * 0.5, d * 0.5 + 0.05)))
	for sz in [-1.0, 1.0]:
		root.add_child(_box(Vector3(0.3, h1 + h2, 0.3), wood, Vector3(sz * (w * 0.5), 0.4 + (h1 + h2) * 0.5, d * 0.5)))
	for sx in [-1.0, 1.0]:
		root.add_child(_box(Vector3(0.3, h1, d), cedar, Vector3(sx * w * 0.5, 0.4 + h1 * 0.5, 0)))
	root.add_child(_box(Vector3(w, h1, 0.3), cedar, Vector3(0, 0.4 + h1 * 0.5, -d * 0.5)))
	# 二樓:灰泥牆 + 兩扇格子窗。
	root.add_child(_box(Vector3(w, h2, d), ochre, Vector3(0, 0.4 + h1 + h2 * 0.5, 0)))
	for sx in [-1.0, 1.0]:
		var win := QuadMesh.new()
		win.size = Vector2(2.4, 1.5)
		root.add_child(_mi(win, mat("koshi", Color.WHITE, 1.0, false, 0.8), Vector3(sx * 2.4, 0.4 + h1 + 1.4, d * 0.5 + 0.07)))
	root.add_child(_box(Vector3(w + 0.1, 0.3, d + 0.1), wood, Vector3(0, 0.4 + h1, 0)))
	# 庇(一樓上方的小屋簷)與棟沿街的主屋頂。
	root.add_child(roof(1.4, w - 0.8, 0.3, 0.7, 0.2, Vector3(0, 0.4 + h1 + 0.1, d * 0.5 + 0.55), PI * 0.5))
	root.add_child(roof(d, w, 1.9, 0.8, 0.45, Vector3(0, 0.4 + h1 + h2, 0), PI * 0.5, Color("c9ccd4"), ochre))
	parent.add_child(root)
	_solid(root, Vector3(w, h1 + h2, d), Vector3(0, 0.4 + (h1 + h2) * 0.5, 0))
	return root


static func kura(parent: Node3D, pos: Vector3, yaw: float, s := 6.0) -> Node3D:
	## 土藏:下半海鼠壁、上半白灰泥、對開厚木門、小格窗、厚重屋頂。
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	var namako := mat("namako", Color.WHITE, 0.25, true, 0.55)
	var white := WB.tex("Plaster001", 0.35, Color("f1e6d2"))
	var wood := WB.tex("Wood051", 0.5)
	var stone := WB.tex("Rock064", 0.3, Color("c2bcaf"))
	var h_low := 2.4
	var h_up := 2.4
	root.add_child(_box(Vector3(s + 0.5, 0.5, s + 0.5), stone, Vector3(0, 0.25, 0)))
	root.add_child(_box(Vector3(s, h_low, s), namako, Vector3(0, 0.5 + h_low * 0.5, 0)))
	root.add_child(_box(Vector3(s, h_up, s), white, Vector3(0, 0.5 + h_low + h_up * 0.5, 0)))
	root.add_child(_box(Vector3(2.4, 3.0, 0.3), wood, Vector3(0, 0.5 + 1.5, s * 0.5 + 0.05)))
	root.add_child(_box(Vector3(0.1, 3.0, 0.34), WB.material(Color("1a1512")), Vector3(0, 0.5 + 1.5, s * 0.5 + 0.06)))
	var koshi := QuadMesh.new()
	koshi.size = Vector2(1.0, 0.9)
	for sx in [-1.0, 1.0]:
		root.add_child(_mi(koshi, mat("koshi", Color.WHITE, 1.0, false, 0.8), Vector3(sx * 1.9, 0.5 + h_low + 1.4, s * 0.5 + 0.07)))
	root.add_child(roof(s, s, 1.7, 0.8, 0.8, Vector3(0, 0.5 + h_low + h_up, 0), 0.0, Color("b6bac4"), white))
	parent.add_child(root)
	_solid(root, Vector3(s, h_low + h_up, s), Vector3(0, 0.5 + (h_low + h_up) * 0.5, 0))
	return root


# ---------- 鳥居 ----------

static func torii(pos: Vector3, scale := 1.0) -> Node3D:
	## 明神鳥居(對照嚴島神社、伏見稻荷的照片,見 doc/design-refs.md):
	## 黑色柱腳(龜腹)、朱漆粗圓柱且微微內傾、伸出很長的貫與楔、朱紅島木、厚而兩端強烈翹起的笠木(頂面黑色)、掛神額的額束。
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * scale
	var red := mat("vermilion", Color.WHITE, 1.0, false, 0.38, true)
	var black := lacquer(Color("14110f"))
	for sx in [-1.0, 1.0]:
		var base := CylinderMesh.new()
		base.top_radius = 0.4
		base.bottom_radius = 0.44
		base.height = 0.9
		root.add_child(_mi(base, black, Vector3(sx * 3.1, 0.45, 0)))
		var pillar := CylinderMesh.new()
		pillar.top_radius = 0.31
		pillar.bottom_radius = 0.38
		pillar.height = 6.0
		var p := _mi(pillar, red, Vector3(sx * (3.1 - 0.085), 3.9, 0))
		p.rotation.z = sx * 0.028  # 內傾約 1.6°
		root.add_child(p)
		root.add_child(_box(Vector3(0.24, 0.66, 0.4), red, Vector3(sx * 3.6, 4.75, 0)))  # 楔
	root.add_child(_box(Vector3(8.4, 0.38, 0.32), red, Vector3(0, 4.75, 0)))  # 貫
	root.add_child(_box(Vector3(9.0, 0.42, 0.62), red, Vector3(0, 6.4, 0)))  # 島木
	var prof: Array = []
	var cap: Array = []
	for i in 25:
		var x := lerpf(-5.5, 5.5, float(i) / 24.0)
		var y := 6.7 + 0.8 * pow(absf(x) / 5.5, 3.0)
		prof.append(Vector2(x, y))
		cap.append(Vector2(x, y + 0.13))
	root.add_child(_mi(slab(prof, 0.5, 0.5, 3.0), red, Vector3.ZERO))  # 笠木(朱紅,厚)
	root.add_child(_mi(slab(cap, 0.58, 0.16, 3.0), black, Vector3.ZERO))  # 笠木頂面的黑色蓋
	root.add_child(_box(Vector3(0.5, 1.3, 0.16), red, Vector3(0, 5.55, 0)))  # 額束
	var plaque := QuadMesh.new()
	plaque.size = Vector2(0.4, 0.8)
	var plaque_mat := mat("plaque", Color.WHITE, 1.0, false, 0.5, true)
	root.add_child(_mi(plaque, plaque_mat, Vector3(0, 5.55, 0.1)))
	var back := _mi(plaque, plaque_mat, Vector3(0, 5.55, -0.1))
	back.rotation.y = PI
	root.add_child(back)
	return root
