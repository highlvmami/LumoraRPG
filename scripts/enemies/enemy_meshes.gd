## Builds one low-poly mesh per enemy kind out of boxes and spheres, with the
## colors baked into vertex colors. Meshes face +Z and stand on y = 0
## (the slime is centered on its middle instead, it bounces).
extends RefCounted


static func build(id: String, radius: float) -> ArrayMesh:
	match id:
		"wolf":
			return _wolf()
		"spider":
			return _spider(Color("#3d2c4a"), Color("#2a1f33"), Color("#ff3b3b"), false)
		"thrower":
			return _thrower()
		"boss":
			return _golem()
		"spider_boss":
			return _spider(Color("#4a1f5c"), Color("#2b1236"), Color("#ffdd33"), true)
		_:
			return _slime(radius)


static func _slime(r: float) -> ArrayMesh:
	var body := Color("#7bd65a")
	var eye := Color("#1d2a1a")
	return _compound([
		[_sphere(r, r * 1.5), Vector3.ZERO, body],
		[_box(Vector3(0.1, 0.16, 0.06)), Vector3(-0.17, 0.08, r * 0.92), eye],
		[_box(Vector3(0.1, 0.16, 0.06)), Vector3(0.17, 0.08, r * 0.92), eye],
	])


static func _wolf() -> ArrayMesh:
	var fur := Color("#8d939e")
	var dark := Color("#5c616b")
	var eye := Color("#ffd23f")
	var parts := [
		[_box(Vector3(0.5, 0.45, 1.1)), Vector3(0, 0.6, 0), fur],
		[_box(Vector3(0.42, 0.4, 0.45)), Vector3(0, 0.82, 0.68), fur],
		[_box(Vector3(0.22, 0.18, 0.28)), Vector3(0, 0.72, 0.98), dark],
		[_box(Vector3(0.1, 0.18, 0.08)), Vector3(-0.13, 1.08, 0.6), dark],
		[_box(Vector3(0.1, 0.18, 0.08)), Vector3(0.13, 1.08, 0.6), dark],
		[_box(Vector3(0.07, 0.07, 0.03)), Vector3(-0.11, 0.88, 0.91), eye],
		[_box(Vector3(0.07, 0.07, 0.03)), Vector3(0.11, 0.88, 0.91), eye],
		[_box(Vector3(0.12, 0.12, 0.45)), Vector3(0, 0.78, -0.72), dark],
	]
	for x in [-0.16, 0.16]:
		for z in [-0.38, 0.38]:
			parts.append([_box(Vector3(0.13, 0.4, 0.13)), Vector3(x, 0.2, z), dark])
	return _compound(parts)


## A spider; the queen (boss) gets red markings and a spiky crown.
static func _spider(body: Color, leg: Color, eye: Color, queen: bool) -> ArrayMesh:
	var parts := [
		[_sphere(0.55, 0.85), Vector3(0, 0.6, -0.4), body],
		[_sphere(0.34, 0.5), Vector3(0, 0.5, 0.32), body],
		[_box(Vector3(0.08, 0.08, 0.04)), Vector3(-0.1, 0.58, 0.64), eye],
		[_box(Vector3(0.08, 0.08, 0.04)), Vector3(0.1, 0.58, 0.64), eye],
		[_box(Vector3(0.06, 0.06, 0.04)), Vector3(-0.2, 0.52, 0.6), eye],
		[_box(Vector3(0.06, 0.06, 0.04)), Vector3(0.2, 0.52, 0.6), eye],
	]
	# Four legs per side, angled down and fanned out.
	for side in [-1.0, 1.0]:
		for n in 4:
			var spread := (n - 1.5) * 0.45
			var b := Basis(Vector3.UP, spread * side) * Basis(Vector3.BACK, -0.55 * side)
			var origin := Vector3(side * 0.6, 0.38, 0.15 - n * 0.2)
			parts.append([_box(Vector3(0.95, 0.08, 0.08)), Transform3D(b, origin), leg])
	if queen:
		var mark := Color("#d8263a")
		parts.append([_box(Vector3(0.36, 0.1, 0.36)), Vector3(0, 1.0, -0.42), mark])
		parts.append([_box(Vector3(0.14, 0.08, 0.5)), Vector3(0, 0.96, -0.85), mark])
		for x in [-0.16, 0.0, 0.16]:
			parts.append([_box(Vector3(0.06, 0.16 if x == 0.0 else 0.11, 0.06)), Vector3(x, 0.8, 0.32), eye])
		parts.append([_box(Vector3(0.08, 0.2, 0.08)), Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(-0.12, 0.38, 0.62)), mark])
		parts.append([_box(Vector3(0.08, 0.2, 0.08)), Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(0.12, 0.38, 0.62)), mark])
	return _compound(parts)


static func _thrower() -> ArrayMesh:
	var skin := Color("#8bbf4a")
	var tunic := Color("#7a4e2d")
	var eye := Color("#ffe14d")
	var rock := Color("#b98cff")
	return _compound([
		[_box(Vector3(0.16, 0.42, 0.16)), Vector3(-0.13, 0.21, 0), tunic.darkened(0.3)],
		[_box(Vector3(0.16, 0.42, 0.16)), Vector3(0.13, 0.21, 0), tunic.darkened(0.3)],
		[_box(Vector3(0.52, 0.55, 0.38)), Vector3(0, 0.7, 0), tunic],
		[_box(Vector3(0.44, 0.4, 0.4)), Vector3(0, 1.17, 0), skin],
		[_box(Vector3(0.24, 0.08, 0.08)), Vector3(-0.32, 1.22, 0), skin],
		[_box(Vector3(0.24, 0.08, 0.08)), Vector3(0.32, 1.22, 0), skin],
		[_box(Vector3(0.08, 0.08, 0.03)), Vector3(-0.1, 1.22, 0.21), eye],
		[_box(Vector3(0.08, 0.08, 0.03)), Vector3(0.1, 1.22, 0.21), eye],
		[_box(Vector3(0.13, 0.45, 0.13)), Vector3(0.34, 1.08, 0), skin],
		[_box(Vector3(0.13, 0.4, 0.13)), Vector3(-0.34, 0.66, 0), skin],
		[_sphere(0.15, 0.3), Vector3(0.34, 1.4, 0), rock],
	])


## The forest giant boss: a mossy stone golem about 3.5 units tall.
static func _golem() -> ArrayMesh:
	var stone := Color("#7d7a72")
	var dark := Color("#57544d")
	var moss := Color("#4f9a3a")
	var eye := Color("#7dffb0")
	return _compound([
		[_box(Vector3(0.6, 1.1, 0.6)), Vector3(-0.5, 0.55, 0), dark],
		[_box(Vector3(0.6, 1.1, 0.6)), Vector3(0.5, 0.55, 0), dark],
		[_box(Vector3(1.8, 1.4, 1.1)), Vector3(0, 1.75, 0), stone],
		[_box(Vector3(1.9, 0.25, 1.2)), Vector3(0, 2.5, 0), moss],
		[_box(Vector3(0.9, 0.8, 0.8)), Vector3(0, 2.95, 0.1), stone],
		[_box(Vector3(0.95, 0.18, 0.85)), Vector3(0, 3.42, 0.1), moss],
		[_box(Vector3(0.18, 0.14, 0.05)), Vector3(-0.22, 3.0, 0.52), eye],
		[_box(Vector3(0.18, 0.14, 0.05)), Vector3(0.22, 3.0, 0.52), eye],
		[_box(Vector3(0.55, 1.5, 0.55)), Vector3(-1.2, 1.55, 0.15), stone],
		[_box(Vector3(0.55, 1.5, 0.55)), Vector3(1.2, 1.55, 0.15), stone],
		[_box(Vector3(0.7, 0.5, 0.7)), Vector3(-1.2, 0.6, 0.2), dark],
		[_box(Vector3(0.7, 0.5, 0.7)), Vector3(1.2, 0.6, 0.2), dark],
		[_box(Vector3(0.6, 0.2, 0.6)), Vector3(-1.2, 2.35, 0.15), moss],
		[_box(Vector3(0.6, 0.2, 0.6)), Vector3(1.2, 2.35, 0.15), moss],
	])


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func _sphere(r: float, h: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 8
	m.rings = 4
	return m


## Merges [mesh, offset (Vector3 or Transform3D), color] parts into one mesh.
static func _compound(parts: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part: Array in parts:
		var prim: PrimitiveMesh = part[0]
		var xf: Transform3D
		if part[1] is Transform3D:
			xf = part[1]
		else:
			xf = Transform3D(Basis.IDENTITY, part[1])
		var color: Color = part[2]
		var arrays := prim.get_mesh_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for idx in indices:
			st.set_color(color)
			st.set_normal((xf.basis * normals[idx]).normalized())
			st.add_vertex(xf * verts[idx])
	return st.commit()
