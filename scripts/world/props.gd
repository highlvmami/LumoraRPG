## Scatters the forest over the terrain: pine trees, rocks, bushes, grass,
## flower patches, mushrooms, fallen logs, ponds with lily pads and reeds,
## old standing-stone circles with campfires, and fireflies in the air.
## Each kind is drawn with one MultiMeshInstance3D (a single draw call), so
## thousands of small details stay cheap.
extends Node3D

const Toon := preload("res://scripts/core/toon.gd")
const Terrain := preload("res://scripts/world/terrain.gd")

var _rng := RandomNumberGenerator.new()
## Ponds placed so far: (x, z, radius).
var _ponds: Array[Vector3] = []
var _fire_lights: Array = []
var _time := 0.0


func build(terrain: Terrain, cfg: Dictionary) -> void:
	_rng.seed = int(cfg.seed) + 7
	var half: float = cfg.playableHalfSize
	var clear: float = cfg.spawnClearRadius

	var colliders := StaticBody3D.new()
	colliders.name = "Colliders"
	add_child(colliders)

	# Ponds first so nothing grows in the water.
	_build_ponds(terrain, cfg)

	# Trees: trunk + two stacked cones.
	var tree_count := int(cfg.trees)
	var trunks := _multimesh(_cylinder(0.35, 0.45, 2.0), Toon.material(Color("#6b4a2b")), tree_count, false)
	var leaves := _multimesh(_cylinder(0.0, 1.9, 3.2), Toon.material(Color.WHITE, true), tree_count, true)
	var tops := _multimesh(_cylinder(0.0, 1.3, 2.4), Toon.material(Color("#3f9a46")), tree_count, false)
	for i in tree_count:
		var spot := _dry_spot(half, clear)
		var s := _rng.randf_range(0.8, 1.5)
		var ground := terrain.height_at(spot.x, spot.y)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s)
		var base := Vector3(spot.x, ground - 0.1, spot.y)
		trunks.multimesh.set_instance_transform(i, Transform3D(basis, base + Vector3.UP * 1.0 * s))
		leaves.multimesh.set_instance_transform(i, Transform3D(basis, base + Vector3.UP * 3.4 * s))
		tops.multimesh.set_instance_transform(i, Transform3D(basis, base + Vector3.UP * 5.0 * s))
		leaves.multimesh.set_instance_color(i, Color.from_hsv(_rng.randf_range(0.29, 0.36), 0.6, _rng.randf_range(0.42, 0.58)))
		_add_collider(colliders, Vector3(spot.x, ground, spot.y), 0.45 * s, 6.0 * s)

	# Rocks: squashed low-poly blobs you can bump into.
	var rock_count := int(cfg.rocks)
	var rock_mesh := SphereMesh.new()
	rock_mesh.radial_segments = 6
	rock_mesh.rings = 3
	var rocks := _multimesh(rock_mesh, Toon.material(Color("#8d9096")), rock_count, false)
	for i in rock_count:
		var spot := _dry_spot(half, clear * 0.6)
		var s := _rng.randf_range(0.5, 1.6)
		var ground := terrain.height_at(spot.x, spot.y)
		var basis := Basis.from_euler(Vector3(_rng.randf() * 0.4, _rng.randf() * TAU, _rng.randf() * 0.4))
		basis = basis.scaled(Vector3(s * 1.2, s * 0.7, s))
		rocks.multimesh.set_instance_transform(i, Transform3D(basis, Vector3(spot.x, ground + s * 0.15, spot.y)))
		_add_collider(colliders, Vector3(spot.x, ground, spot.y), s * 0.9, s * 1.4)

	_build_ground_cover(terrain, cfg, half, clear)
	_build_logs(terrain, cfg, half, clear, colliders)
	_build_shrines(terrain, cfg, half, clear, colliders)
	_build_fireflies(half)


func _process(delta: float) -> void:
	_time += delta
	# Campfire lights flicker.
	for n in _fire_lights.size():
		var light: OmniLight3D = _fire_lights[n]
		light.light_energy = 1.6 + 0.35 * sin(_time * 9.0 + n * 1.7) + 0.2 * sin(_time * 23.0 + n)


## Ponds sit in flat spots: a see-through water disc a little above the
## ground (the terrain pokes through at the edges), lily pads and reeds.
func _build_ponds(terrain: Terrain, cfg: Dictionary) -> void:
	var count := int(cfg.get("ponds", 0))
	var half: float = cfg.playableHalfSize
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.25, 0.55, 0.85, 0.72)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	water_mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	water_mat.roughness = 0.15
	water_mat.emission_enabled = true
	water_mat.emission = Color(0.1, 0.25, 0.4)
	var pads: Array = []
	var reeds: Array = []
	var tries := 0
	while _ponds.size() < count and tries < 400:
		tries += 1
		var spot := _pick_spot(half * 0.85, float(cfg.spawnClearRadius) + 6.0)
		var r := _rng.randf_range(3.5, 6.0)
		var low := INF
		var high := -INF
		for k in 9:
			var at := spot + (Vector2.from_angle(TAU * k / 8.0) * r if k < 8 else Vector2.ZERO)
			var h := terrain.height_at(at.x, at.y)
			low = minf(low, h)
			high = maxf(high, h)
		if high - low > 0.9 or _near_pond(spot, r + 8.0):
			continue
		_ponds.append(Vector3(spot.x, spot.y, r))
		var level := low + 0.25
		var water := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = r
		disc.bottom_radius = r
		disc.height = 0.05
		disc.radial_segments = 14
		disc.rings = 1
		water.mesh = disc
		water.material_override = water_mat
		water.position = Vector3(spot.x, level, spot.y)
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(water)
		for n in _rng.randi_range(3, 6):
			var at := spot + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.5, r * 0.75)
			pads.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.7, 1.2)), Vector3(at.x, level + 0.04, at.y)))
		for n in _rng.randi_range(10, 16):
			var at := spot + Vector2.from_angle(_rng.randf() * TAU) * r * _rng.randf_range(0.9, 1.1)
			var s := _rng.randf_range(0.7, 1.3)
			reeds.append(Transform3D(Basis.from_euler(Vector3(_rng.randf_range(-0.15, 0.15), 0, _rng.randf_range(-0.15, 0.15))).scaled(Vector3(1, s, 1)), Vector3(at.x, terrain.height_at(at.x, at.y) + 0.6 * s, at.y)))
	var pad_mesh := _cylinder(0.45, 0.45, 0.03)
	var pad_mm := _multimesh(pad_mesh, Toon.material(Color("#4f9c3a")), pads.size(), false)
	for n in pads.size():
		pad_mm.multimesh.set_instance_transform(n, pads[n])
	var reed_mm := _multimesh(_cylinder(0.0, 0.07, 1.2), Toon.material(Color("#7f9a3c")), reeds.size(), false)
	for n in reeds.size():
		reed_mm.multimesh.set_instance_transform(n, reeds[n])


func _near_pond(spot: Vector2, dist: float) -> bool:
	for pond: Vector3 in _ponds:
		if Vector2(pond.x, pond.y).distance_to(spot) < dist + pond.z:
			return true
	return false


## Bushes, grass tufts, flower patches and mushroom rings: small, no collision.
func _build_ground_cover(terrain: Terrain, cfg: Dictionary, half: float, clear: float) -> void:
	# Bushes: squashed round blobs in a few greens.
	var bush_count := int(cfg.get("bushes", 0))
	var bush_mesh := SphereMesh.new()
	bush_mesh.radial_segments = 7
	bush_mesh.rings = 4
	var bushes := _multimesh(bush_mesh, Toon.material(Color.WHITE, true), bush_count, true)
	for i in bush_count:
		var spot := _dry_spot(half, clear * 0.5)
		var s := _rng.randf_range(0.6, 1.2)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s * 1.3, s * 0.8, s * 1.1))
		bushes.multimesh.set_instance_transform(i, Transform3D(basis, Vector3(spot.x, terrain.height_at(spot.x, spot.y) + s * 0.25, spot.y)))
		bushes.multimesh.set_instance_color(i, Color.from_hsv(_rng.randf_range(0.25, 0.34), _rng.randf_range(0.55, 0.75), _rng.randf_range(0.38, 0.55)))

	# Grass tufts: three thin blades each.
	var grass_count := int(cfg.get("grass", 0))
	var grass_mat := Toon.material(Color.WHITE, true)
	grass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var grass := _multimesh(_tuft_mesh(), grass_mat, grass_count, true)
	for i in grass_count:
		var spot := _dry_spot(half, 2.0)
		var s := _rng.randf_range(0.6, 1.3)
		grass.multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(spot.x, terrain.height_at(spot.x, spot.y) - 0.05, spot.y)))
		grass.multimesh.set_instance_color(i, Color.from_hsv(_rng.randf_range(0.22, 0.32), _rng.randf_range(0.5, 0.75), _rng.randf_range(0.5, 0.75)))

	# Flower patches: clusters of one color each.
	var palette := [Color("#fff4e0"), Color("#ffd23f"), Color("#ff7ab8"), Color("#b98cff"), Color("#6cc4ff"), Color("#ff6b4a")]
	var patches := int(cfg.get("flowerPatches", 0))
	var heads: Array = []
	for p in patches:
		var center := _dry_spot(half, 3.0)
		var c: Color = palette[_rng.randi() % palette.size()]
		for n in _rng.randi_range(6, 12):
			var at := center + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.0, 1.8)
			heads.append([at, c.lightened(_rng.randf_range(-0.1, 0.15))])
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.13
	head_mesh.height = 0.2
	head_mesh.radial_segments = 5
	head_mesh.rings = 2
	var flowers := _multimesh(head_mesh, Toon.material(Color.WHITE, true), heads.size(), true)
	var stems := _multimesh(_cylinder(0.025, 0.025, 0.35), Toon.material(Color("#3f8a36")), heads.size(), false)
	for n in heads.size():
		var at: Vector2 = heads[n][0]
		var ground := terrain.height_at(at.x, at.y)
		flowers.multimesh.set_instance_transform(n, Transform3D(Basis.IDENTITY, Vector3(at.x, ground + 0.36, at.y)))
		flowers.multimesh.set_instance_color(n, heads[n][1])
		stems.multimesh.set_instance_transform(n, Transform3D(Basis.IDENTITY, Vector3(at.x, ground + 0.17, at.y)))

	# Mushrooms: red caps with white dots in small rings.
	var rings := int(cfg.get("mushroomRings", 0))
	var spots: Array = []
	for r in rings:
		var center := _dry_spot(half, clear * 0.6)
		var count := _rng.randi_range(4, 8)
		var radius := _rng.randf_range(0.8, 1.6)
		for n in count:
			spots.append([center + Vector2.from_angle(TAU * n / count + _rng.randf() * 0.4) * radius, _rng.randf_range(0.6, 1.3)])
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 0.3
	cap_mesh.height = 0.3
	cap_mesh.is_hemisphere = true
	cap_mesh.radial_segments = 8
	cap_mesh.rings = 3
	var caps := _multimesh(cap_mesh, Toon.material(Color("#e0484f")), spots.size(), false)
	var dots := _multimesh(cap_mesh, Toon.material(Color("#fff4e0")), spots.size(), false)
	var stalks := _multimesh(_cylinder(0.09, 0.12, 0.4), Toon.material(Color("#f1ead6")), spots.size(), false)
	for n in spots.size():
		var at: Vector2 = spots[n][0]
		var s: float = spots[n][1]
		var ground := terrain.height_at(at.x, at.y)
		var yaw := Basis(Vector3.UP, _rng.randf() * TAU)
		stalks.multimesh.set_instance_transform(n, Transform3D(yaw.scaled(Vector3.ONE * s), Vector3(at.x, ground + 0.2 * s, at.y)))
		caps.multimesh.set_instance_transform(n, Transform3D(yaw.scaled(Vector3.ONE * s), Vector3(at.x, ground + 0.38 * s, at.y)))
		# A smaller pale cap peeking out on top reads as white dots.
		dots.multimesh.set_instance_transform(n, Transform3D(yaw.scaled(Vector3(0.45, 0.6, 0.45) * s), Vector3(at.x, ground + 0.5 * s, at.y)))


## Fallen tree trunks lying on the ground (you bump into them).
func _build_logs(terrain: Terrain, cfg: Dictionary, half: float, clear: float, colliders: StaticBody3D) -> void:
	var count := int(cfg.get("logs", 0))
	var bark := _multimesh(_cylinder(0.38, 0.42, 3.4), Toon.material(Color("#6b4a2b")), count, false)
	var ends := _multimesh(_cylinder(0.33, 0.33, 3.45), Toon.material(Color("#c9a26b")), count, false)
	for i in count:
		var spot := _dry_spot(half, clear)
		var yaw := _rng.randf() * TAU
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5)
		var at := Vector3(spot.x, terrain.height_at(spot.x, spot.y) + 0.3, spot.y)
		bark.multimesh.set_instance_transform(i, Transform3D(basis, at))
		ends.multimesh.set_instance_transform(i, Transform3D(basis, at))
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.8, 0.8, 3.4)
		var col := CollisionShape3D.new()
		col.shape = shape
		col.transform = Transform3D(Basis(Vector3.UP, yaw), at)
		colliders.add_child(col)


## Old standing-stone circles, each with a campfire glowing in the middle.
func _build_shrines(terrain: Terrain, cfg: Dictionary, half: float, clear: float, colliders: StaticBody3D) -> void:
	var count := int(cfg.get("shrines", 0))
	var stones_per := 7
	var stone_mm := _multimesh(_box(Vector3(1.0, 2.6, 0.7)), Toon.material(Color("#9a9ca3")), count * stones_per, false)
	var moss_mm := _multimesh(_box(Vector3(1.05, 0.5, 0.75)), Toon.material(Color("#5d8a3a")), count * stones_per, false)
	var ring_mm := _multimesh(_cylinder(0.25, 0.3, 0.25), Toon.material(Color("#6f7279")), count * 9, false)
	var wood_mm := _multimesh(_cylinder(0.12, 0.12, 1.3), Toon.material(Color("#5a3818")), count * 3, false)
	var flame_mat := StandardMaterial3D.new()
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.vertex_color_use_as_albedo = true
	flame_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var flame_quad := QuadMesh.new()
	flame_quad.size = Vector2(0.35, 0.35)
	flame_quad.material = flame_mat
	var flame_colors := Gradient.new()
	flame_colors.set_color(0, Color(1.0, 0.85, 0.3, 1.0))
	flame_colors.set_color(1, Color(0.9, 0.2, 0.05, 0.0))
	for c in count:
		var center := _dry_spot(half * 0.9, clear + 10.0)
		var ground := terrain.height_at(center.x, center.y)
		for n in stones_per:
			var a := TAU * n / stones_per
			var at := center + Vector2.from_angle(a) * 5.0
			var g := terrain.height_at(at.x, at.y)
			var tilt := Basis(Vector3.UP, -a) * Basis(Vector3.FORWARD, _rng.randf_range(-0.12, 0.12))
			var h := _rng.randf_range(0.7, 1.15)
			var idx := c * stones_per + n
			stone_mm.multimesh.set_instance_transform(idx, Transform3D(tilt.scaled(Vector3(1, h, 1)), Vector3(at.x, g + 1.1 * h, at.y)))
			moss_mm.multimesh.set_instance_transform(idx, Transform3D(tilt, Vector3(at.x, g + 0.15, at.y)))
			_add_collider(colliders, Vector3(at.x, g, at.y), 0.55, 2.6)
		for n in 9:
			var at := center + Vector2.from_angle(TAU * n / 9.0) * 0.75
			ring_mm.multimesh.set_instance_transform(c * 9 + n, Transform3D(Basis.IDENTITY, Vector3(at.x, terrain.height_at(at.x, at.y) + 0.1, at.y)))
		for n in 3:
			var wood_basis := Basis(Vector3.UP, TAU * n / 3.0) * Basis(Vector3.RIGHT, 1.2)
			wood_mm.multimesh.set_instance_transform(c * 3 + n, Transform3D(wood_basis, Vector3(center.x, ground + 0.3, center.y)))
		var fire := CPUParticles3D.new()
		fire.mesh = flame_quad
		fire.amount = 24
		fire.lifetime = 0.8
		fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		fire.emission_sphere_radius = 0.25
		fire.direction = Vector3.UP
		fire.spread = 15.0
		fire.gravity = Vector3(0, 1.5, 0)
		fire.initial_velocity_min = 0.6
		fire.initial_velocity_max = 1.4
		fire.scale_amount_min = 0.8
		fire.scale_amount_max = 1.6
		fire.color_ramp = flame_colors
		fire.position = Vector3(center.x, ground + 0.4, center.y)
		add_child(fire)
		var light := OmniLight3D.new()
		light.light_color = Color("#ffa040")
		light.omni_range = 9.0
		light.light_energy = 1.6
		light.position = Vector3(center.x, ground + 1.4, center.y)
		add_child(light)
		_fire_lights.append(light)


## Glowing fireflies drifting over the whole map.
func _build_fireflies(half: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.85, 1.0, 0.45)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.16)
	quad.material = mat
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var flies := CPUParticles3D.new()
	flies.name = "Fireflies"
	flies.mesh = quad
	flies.amount = 500
	flies.lifetime = 7.0
	flies.preprocess = 7.0
	flies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flies.emission_box_extents = Vector3(half, 2.0, half)
	flies.position = Vector3(0, 3.0, 0)
	flies.direction = Vector3.UP
	flies.spread = 180.0
	flies.gravity = Vector3.ZERO
	flies.initial_velocity_min = 0.1
	flies.initial_velocity_max = 0.5
	flies.color_ramp = fade
	flies.visibility_aabb = AABB(Vector3(-half, -10, -half), Vector3(half * 2.0, 30, half * 2.0))
	add_child(flies)


## A random spot outside the clear area that is not in a pond.
func _dry_spot(half: float, min_dist: float) -> Vector2:
	for n in 20:
		var spot := _pick_spot(half, min_dist)
		if not _near_pond(spot, 0.5):
			return spot
	return _pick_spot(half, min_dist)


## Three crossed thin blades.
func _tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for n in 3:
		var a := TAU * n / 3.0
		var side := Vector3(cos(a), 0, sin(a)) * 0.12
		var lean := Vector3(cos(a + 1.2), 0, sin(a + 1.2)) * 0.12
		for tri: Array in [[-side, side, lean + Vector3.UP * 0.55], [side, -side, lean + Vector3.UP * 0.55]]:
			for v: Vector3 in tri:
				st.set_color(Color.WHITE)
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()


func _box(box_size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	return mesh


func _pick_spot(half: float, min_dist: float) -> Vector2:
	while true:
		var p := Vector2(_rng.randf_range(-half, half), _rng.randf_range(-half, half))
		if p.length() > min_dist:
			return p
	return Vector2.ZERO


func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 7
	mesh.rings = 1
	return mesh


func _multimesh(mesh: Mesh, material: Material, count: int, colored: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colored
	mm.mesh = mesh
	mm.instance_count = count
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.material_override = material
	add_child(instance)
	return instance


func _add_collider(body: StaticBody3D, ground_pos: Vector3, radius: float, height: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = ground_pos + Vector3.UP * height * 0.5
	body.add_child(collision)
