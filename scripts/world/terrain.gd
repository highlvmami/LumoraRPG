## Heightfield terrain: rolling hills in the middle, a mountain ring at the edge.
## Its look comes from the map (data/maps.json): ground colors, how hilly it
## is, a sea on one side (beach) or stone floor tiles (dungeon). Calling
## build() again replaces the ground in place, so everything holding this
## node keeps working on the new map.
## The collision shape is built from the same triangles that are drawn,
## so the player always stands exactly on what they see.
extends StaticBody3D

const Toon := preload("res://scripts/core/toon.gd")

const GRASS_A := Color("#4f9a3a")
const GRASS_B := Color("#6cb446")
const DIRT := Color("#8a6a3f")
const STONE := Color("#7b7f86")

var size: float
var segments: int
var cell: float
var half: float
var verts: int
var spawn_clear_radius: float
var heights := PackedFloat32Array()
## The map this terrain was built for (see data/maps.json).
var map := {}
var _ground_a := GRASS_A
var _ground_b := GRASS_B
var _slope := DIRT
var _stone := STONE


func build(cfg: Dictionary, p_map := {}) -> void:
	map = p_map
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if map.has("ground"):
		_ground_a = Color(str(map.ground[0]))
		_ground_b = Color(str(map.ground[1]))
		_slope = Color(str(map.get("slope", DIRT.to_html())))
		_stone = Color(str(map.get("stone", STONE.to_html())))
	size = cfg.size
	segments = int(cfg.segments)
	spawn_clear_radius = cfg.spawnClearRadius
	cell = size / segments
	half = size / 2.0
	verts = segments + 1

	var noise := FastNoiseLite.new()
	noise.seed = int(map.get("seed", cfg.seed))
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.018
	noise.fractal_octaves = 4

	heights.resize(verts * verts)
	for iz in verts:
		for ix in verts:
			var x := ix * cell - half
			var z := iz * cell - half
			heights[iz * verts + ix] = _generate_height(noise, x, z)

	var color_noise := FastNoiseLite.new()
	color_noise.seed = int(map.get("seed", cfg.seed)) + 1
	color_noise.frequency = 0.08

	var mesh := _build_mesh(color_noise)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = mesh
	add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = mesh.create_trimesh_shape()
	add_child(collision)


func _generate_height(noise: FastNoiseLite, x: float, z: float) -> float:
	var h := noise.get_noise_2d(x, z) * float(map.get("amplitude", 9.0))

	# Keep the spawn area fairly flat.
	var d := Vector2(x, z).length()
	h *= 0.25 + 0.75 * smoothstep(spawn_clear_radius * 0.5, spawn_clear_radius * 1.6, d)

	# Raise a mountain ring at the border so the map feels enclosed.
	var edge := maxf(absf(x), absf(z)) / half
	var wall := smoothstep(0.84, 1.0, edge)
	if map.has("seaFrom"):
		# The beach slopes down into a shallow sea on the east side (no wall there).
		var sea := smoothstep(float(map.seaFrom), float(map.seaFrom) + 18.0, x)
		h = lerpf(h, -float(map.seaDepth), sea)
		var side_edge := absf(z) / half
		var west_edge := -x / half
		wall = smoothstep(0.84, 1.0, maxf(side_edge, west_edge))
	return h + wall * wall * 26.0


func _vertex(ix: int, iz: int) -> Vector3:
	return Vector3(ix * cell - half, heights[iz * verts + ix], iz * cell - half)


func _build_mesh(color_noise: FastNoiseLite) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in segments:
		for ix in segments:
			var v00 := _vertex(ix, iz)
			var v10 := _vertex(ix + 1, iz)
			var v01 := _vertex(ix, iz + 1)
			var v11 := _vertex(ix + 1, iz + 1)
			# Godot treats clockwise triangles (seen from above here) as front faces.
			_add_triangle(st, color_noise, v00, v10, v01)
			_add_triangle(st, color_noise, v10, v11, v01)
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, Toon.material(Color.WHITE, true))
	return mesh


## Each triangle gets one flat color, which reads as low-poly pixel art.
func _add_triangle(st: SurfaceTool, color_noise: FastNoiseLite, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (c - a).cross(b - a).normalized()
	var center := (a + b + c) / 3.0
	var steep := 1.0 - absf(normal.y)
	var color := _ground_a.lerp(_ground_b, color_noise.get_noise_2d(center.x, center.z) * 0.5 + 0.5)
	if map.get("tiles", false):
		# Stone floor tiles: a checker of slightly different slabs with dark seams.
		var tx := floori((center.x + half) / 2.0)
		var tz := floori((center.z + half) / 2.0)
		color = _ground_a if (tx + tz) % 2 == 0 else _ground_b
		color = color.darkened(0.06 * (color_noise.get_noise_2d(tx * 3.0, tz * 3.0) + 1.0))
	if map.has("inland") and center.x < float(map.inlandFrom) + color_noise.get_noise_2d(center.z, center.x) * 8.0:
		color = Color(str(map.inland)).lerp(_ground_a, 0.15 * (color_noise.get_noise_2d(center.x, center.z) + 1.0))
	if map.has("seaLevel") and center.y < float(map.seaLevel) + 0.5:
		# Wet sand at the waterline.
		color = _ground_a.darkened(0.25)
	if steep > 0.35:
		color = _slope
	if center.y > 12.0 or steep > 0.6:
		color = _stone
	st.set_color(color)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


## Ground height at a world position (bilinear over the height grid).
func height_at(x: float, z: float) -> float:
	var fx := clampf((x + half) / cell, 0.0, verts - 1.001)
	var fz := clampf((z + half) / cell, 0.0, verts - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var h00 := heights[iz * verts + ix]
	var h10 := heights[iz * verts + ix + 1]
	var h01 := heights[(iz + 1) * verts + ix]
	var h11 := heights[(iz + 1) * verts + ix + 1]
	var top := lerpf(h00, h10, tx)
	var bottom := lerpf(h01, h11, tx)
	return lerpf(top, bottom, tz)
