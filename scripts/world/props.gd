## Scatters the map's details over the terrain (data/maps.json "props"):
## - forest: pine trees, rocks, bushes, grass, flower patches, mushrooms,
##   fallen logs, ponds with lily pads and reeds, standing-stone circles
##   with campfires and fireflies;
## - beach: the sea, palm trees, a village of huts, boats, umbrellas,
##   shells and rocks;
## - dungeon: stone pillars with torches, broken walls, bone piles and
##   skulls, barrels, crates, braziers and floating dust.
## Calling build() again clears the old map first.
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


func build(terrain: Terrain, cfg: Dictionary, map := {}) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_ponds.clear()
	_fire_lights.clear()
	_rng.seed = int(map.get("seed", cfg.seed)) + 7
	var colliders := StaticBody3D.new()
	colliders.name = "Colliders"
	add_child(colliders)
	match str(map.get("props", "forest")):
		"beach":
			_build_beach(terrain, cfg, map, colliders)
		"dungeon":
			_build_dungeon(terrain, cfg, colliders)
		_:
			_build_forest(terrain, cfg, colliders)


func _build_forest(terrain: Terrain, cfg: Dictionary, colliders: StaticBody3D) -> void:
	var half: float = cfg.playableHalfSize
	var clear: float = cfg.spawnClearRadius

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
	# Campfire and torch lights flicker.
	for n in _fire_lights.size():
		var light: OmniLight3D = _fire_lights[n]
		var base := float(light.get_meta("base", 1.6))
		light.light_energy = base * (1.0 + 0.22 * sin(_time * 9.0 + n * 1.7) + 0.12 * sin(_time * 23.0 + n))


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
		_add_fire(Vector3(center.x, ground + 0.4, center.y), 0.25, 1.6, 9.0)


## Fire: flame particles rising from `at` and a flickering orange light.
func _add_fire(at: Vector3, flame_radius: float, energy: float, light_range: float) -> void:
	var flame_mat := StandardMaterial3D.new()
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.vertex_color_use_as_albedo = true
	flame_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var flame_quad := QuadMesh.new()
	flame_quad.size = Vector2(0.35, 0.35) * (flame_radius / 0.25)
	flame_quad.material = flame_mat
	var flame_colors := Gradient.new()
	flame_colors.set_color(0, Color(1.0, 0.85, 0.3, 1.0))
	flame_colors.set_color(1, Color(0.9, 0.2, 0.05, 0.0))
	var fire := CPUParticles3D.new()
	fire.mesh = flame_quad
	fire.amount = 20
	fire.lifetime = 0.7
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = flame_radius
	fire.direction = Vector3.UP
	fire.spread = 15.0
	fire.gravity = Vector3(0, 1.5, 0)
	fire.initial_velocity_min = 0.6
	fire.initial_velocity_max = 1.4
	fire.scale_amount_min = 0.8
	fire.scale_amount_max = 1.6
	fire.color_ramp = flame_colors
	fire.position = at
	add_child(fire)
	var light := OmniLight3D.new()
	light.light_color = Color("#ffa040")
	light.omni_range = light_range
	light.light_energy = energy
	light.set_meta("base", energy)
	light.position = at + Vector3.UP
	add_child(light)
	_fire_lights.append(light)


## Glowing fireflies drifting over the whole map.
func _build_fireflies(half: float, tint := Color(0.85, 1.0, 0.45), amount := 500, mote_size := 0.16) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = tint
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var quad := QuadMesh.new()
	quad.size = Vector2(mote_size, mote_size)
	quad.material = mat
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var flies := CPUParticles3D.new()
	flies.name = "Fireflies"
	flies.mesh = quad
	flies.amount = amount
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


# --- Beach -------------------------------------------------------------------

## Sea on the east side, palm trees, a village of huts with roofs, boats on
## the shore, beach umbrellas, shells and rocks.
func _build_beach(terrain: Terrain, cfg: Dictionary, map: Dictionary, colliders: StaticBody3D) -> void:
	var half: float = cfg.playableHalfSize
	var clear: float = cfg.spawnClearRadius
	var sea_level := float(map.get("seaLevel", -0.6))
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.15, 0.6, 0.85, 0.78)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	water_mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	water_mat.roughness = 0.1
	water_mat.emission_enabled = true
	water_mat.emission = Color(0.05, 0.25, 0.35)
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(160, 200)
	sea.mesh = plane
	sea.material_override = water_mat
	sea.position = Vector3(float(map.seaFrom) + 70.0, sea_level, 0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)
	# Foam line along the shore.
	var foam_mat := Toon.material(Color(1, 1, 1, 0.8))
	foam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var foam := MeshInstance3D.new()
	var strip := PlaneMesh.new()
	strip.size = Vector2(1.2, 170)
	foam.mesh = strip
	foam.material_override = foam_mat
	foam.position = Vector3(_shore_x(terrain, sea_level), sea_level + 0.03, 0)
	add_child(foam)

	# Palm trees: a leaning trunk of segments and drooping fronds.
	var palms := int(cfg.trees * 0.35)
	var segs := 4
	var trunk_mm := _multimesh(_cylinder(0.22, 0.3, 1.3), Toon.material(Color("#9a7448")), palms * segs, false)
	var frond_mm := _multimesh(_box(Vector3(0.7, 0.08, 2.6)), Toon.material(Color.WHITE, true), palms * 6, true)
	var nut_mm := _multimesh(_sphere(0.22), Toon.material(Color("#6b4a2b")), palms * 2, false)
	for i in palms:
		var spot := _land_spot(terrain, half, clear, sea_level)
		var ground := terrain.height_at(spot.x, spot.y)
		var lean := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized() * _rng.randf_range(0.15, 0.3)
		var s := _rng.randf_range(0.9, 1.3)
		var at := Vector3(spot.x, ground, spot.y)
		for k in segs:
			var up := (Vector3.UP + lean * (k + 1) * 0.5).normalized()
			var basis := Basis(Vector3.UP.cross(up).normalized() if up != Vector3.UP else Vector3.RIGHT, Vector3.UP.angle_to(up)).scaled(Vector3.ONE * s)
			trunk_mm.multimesh.set_instance_transform(i * segs + k, Transform3D(basis, at + up * 0.62 * s))
			at += up * 1.2 * s
		for f in 6:
			var yaw := TAU * f / 6.0 + _rng.randf() * 0.3
			var frond := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, 0.45)
			frond_mm.multimesh.set_instance_transform(i * 6 + f, Transform3D(frond.scaled(Vector3.ONE * s), at + frond * Vector3(0, 0, 1.1 * s)))
			frond_mm.multimesh.set_instance_color(i * 6 + f, Color.from_hsv(_rng.randf_range(0.25, 0.32), 0.7, _rng.randf_range(0.45, 0.62)))
		for n in 2:
			nut_mm.multimesh.set_instance_transform(i * 2 + n, Transform3D(Basis.IDENTITY, at + Vector3(0.25 - n * 0.5, -0.25, 0.15)))
		_add_collider(colliders, Vector3(spot.x, ground, spot.y), 0.35 * s, 5.0 * s)

	# Village: huts with walls, a pitched roof, a door; on the west, inland.
	var huts := 14
	var wall_mm := _multimesh(_box(Vector3(3.2, 2.2, 3.0)), Toon.material(Color.WHITE, true), huts, true)
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(3.8, 1.6, 3.4)
	var roof_mm := _multimesh(roof_mesh, Toon.material(Color.WHITE, true), huts, true)
	var door_mm := _multimesh(_box(Vector3(0.9, 1.4, 0.1)), Toon.material(Color("#5a3818")), huts, false)
	var walls := [Color("#f1e3c6"), Color("#e8cfa4"), Color("#d9e6ef"), Color("#f2d5c4")]
	var roofs := [Color("#c0523a"), Color("#3a6ea5"), Color("#d18a2b"), Color("#6b8f3a")]
	for i in huts:
		var spot := Vector2(_rng.randf_range(-half * 0.9, -12.0), _rng.randf_range(-half * 0.8, half * 0.8))
		if spot.length() < clear + 4.0:
			spot.x -= clear + 4.0
		var ground := terrain.height_at(spot.x, spot.y)
		var yaw := Basis(Vector3.UP, _rng.randf_range(-0.4, 0.4) + (PI * 0.5 if _rng.randf() < 0.5 else 0.0))
		wall_mm.multimesh.set_instance_transform(i, Transform3D(yaw, Vector3(spot.x, ground + 1.0, spot.y)))
		wall_mm.multimesh.set_instance_color(i, walls[i % walls.size()])
		roof_mm.multimesh.set_instance_transform(i, Transform3D(yaw, Vector3(spot.x, ground + 2.9, spot.y)))
		roof_mm.multimesh.set_instance_color(i, roofs[_rng.randi() % roofs.size()])
		door_mm.multimesh.set_instance_transform(i, Transform3D(yaw, Vector3(spot.x, ground + 0.6, spot.y) + yaw * Vector3(0, 0, 1.52)))
		var box := BoxShape3D.new()
		box.size = Vector3(3.2, 3.5, 3.0)
		var col := CollisionShape3D.new()
		col.shape = box
		col.transform = Transform3D(yaw, Vector3(spot.x, ground + 1.7, spot.y))
		colliders.add_child(col)

	# Boats pulled up on the sand by the waterline.
	var shore := _shore_x(terrain, sea_level)
	var boats := 6
	var hull_mm := _multimesh(_box(Vector3(1.4, 0.6, 3.6)), Toon.material(Color("#8a5a2b")), boats, false)
	var stripe_mm := _multimesh(_box(Vector3(1.45, 0.15, 3.65)), Toon.material(Color.WHITE, true), boats, true)
	for i in boats:
		var z := -half * 0.8 + i * half * 0.32 + _rng.randf_range(-4, 4)
		var x := shore - _rng.randf_range(1.5, 4.0)
		var basis := Basis(Vector3.UP, _rng.randf_range(-0.6, 0.6)) * Basis(Vector3.FORWARD, _rng.randf_range(-0.15, 0.15))
		var at := Vector3(x, terrain.height_at(x, z) + 0.3, z)
		hull_mm.multimesh.set_instance_transform(i, Transform3D(basis, at))
		stripe_mm.multimesh.set_instance_transform(i, Transform3D(basis, at + Vector3.UP * 0.25))
		stripe_mm.multimesh.set_instance_color(i, [Color("#e0484f"), Color("#3a6ea5"), Color("#ffd23f")][i % 3])

	# Beach umbrellas: a pole and a colorful cone.
	var umbrellas := 12
	var pole_mm := _multimesh(_cylinder(0.05, 0.05, 2.2), Toon.material(Color("#f1ead6")), umbrellas, false)
	var shade_mm := _multimesh(_cylinder(0.0, 1.4, 0.6), Toon.material(Color.WHITE, true), umbrellas, true)
	for i in umbrellas:
		var z := _rng.randf_range(-half * 0.8, half * 0.8)
		var x := _rng.randf_range(shore - 14.0, shore - 4.0)
		if Vector2(x, z).length() < clear:
			z += clear * 1.5
		var g := terrain.height_at(x, z)
		pole_mm.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(x, g + 1.1, z)))
		shade_mm.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(x, g + 2.3, z)))
		shade_mm.multimesh.set_instance_color(i, [Color("#ff6b4a"), Color("#4fb8ff"), Color("#ffd23f"), Color("#ff7ab8")][i % 4])

	# Shells and starfish dotting the sand.
	var shells := 260
	var shell_mm := _multimesh(_sphere(0.14), Toon.material(Color.WHITE, true), shells, true)
	for i in shells:
		var spot := _land_spot(terrain, half, 2.0, sea_level)
		shell_mm.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(1, 0.4, 1)), Vector3(spot.x, terrain.height_at(spot.x, spot.y) + 0.03, spot.y)))
		shell_mm.multimesh.set_instance_color(i, [Color("#fff4e0"), Color("#ffb3a0"), Color("#ffd27a"), Color("#e0e6ee")][_rng.randi() % 4])

	# Rocks and grass tufts in the green inland part.
	var rocks := 50
	var rock_mm := _multimesh(_sphere(1.0, 6, 3), Toon.material(Color("#9a8f80")), rocks, false)
	for i in rocks:
		var spot := _land_spot(terrain, half, clear * 0.6, sea_level)
		var s := _rng.randf_range(0.4, 1.2)
		rock_mm.multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s * 1.2, s * 0.6, s)), Vector3(spot.x, terrain.height_at(spot.x, spot.y), spot.y)))
		_add_collider(colliders, Vector3(spot.x, terrain.height_at(spot.x, spot.y), spot.y), s * 0.9, s)
	var grass_count := 900
	var grass_mat := Toon.material(Color.WHITE, true)
	grass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var grass := _multimesh(_tuft_mesh(), grass_mat, grass_count, true)
	for i in grass_count:
		var spot := Vector2(_rng.randf_range(-half, float(map.get("inlandFrom", -30.0)) + 6.0), _rng.randf_range(-half, half))
		grass.multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), Vector3(spot.x, terrain.height_at(spot.x, spot.y) - 0.05, spot.y)))
		grass.multimesh.set_instance_color(i, Color.from_hsv(_rng.randf_range(0.2, 0.3), 0.6, _rng.randf_range(0.5, 0.7)))
	# A couple of evening bonfires in the village.
	for n in 2:
		var at := Vector2(_rng.randf_range(-half * 0.6, -16.0), _rng.randf_range(-half * 0.5, half * 0.5))
		_add_fire(Vector3(at.x, terrain.height_at(at.x, at.y) + 0.3, at.y), 0.3, 1.4, 8.0)


## X where the beach meets the sea (roughly; the sea side is east).
func _shore_x(terrain: Terrain, sea_level: float) -> float:
	var x := 0.0
	while x < 80.0 and terrain.height_at(x, 0.0) > sea_level:
		x += 0.5
	return x


## A spot on dry land (above the sea), away from the start.
func _land_spot(terrain: Terrain, half: float, min_dist: float, sea_level: float) -> Vector2:
	for n in 30:
		var spot := _pick_spot(half, min_dist)
		if terrain.height_at(spot.x, spot.y) > sea_level + 0.3:
			return spot
	return Vector2(-half * 0.5, _rng.randf_range(-half, half))


# --- Dungeon -----------------------------------------------------------------

## Stone pillars with torches, broken wall pieces, bone piles and skulls,
## barrels, crates, braziers with fire, and dust drifting in the dark.
func _build_dungeon(terrain: Terrain, cfg: Dictionary, colliders: StaticBody3D) -> void:
	var half: float = cfg.playableHalfSize
	var clear: float = cfg.spawnClearRadius
	# Pillars on a loose grid, some with a torch.
	var pillar_spots: Array = []
	var step := 14.0
	var gx := -half + step * 0.5
	while gx < half:
		var gz := -half + step * 0.5
		while gz < half:
			var at := Vector2(gx + _rng.randf_range(-2.5, 2.5), gz + _rng.randf_range(-2.5, 2.5))
			if at.length() > clear and _rng.randf() < 0.75:
				pillar_spots.append(at)
			gz += step
		gx += step
	var pillar_mm := _multimesh(_box(Vector3(1.6, 6.0, 1.6)), Toon.material(Color("#5d5866")), pillar_spots.size(), false)
	var cap_mm := _multimesh(_box(Vector3(2.1, 0.5, 2.1)), Toon.material(Color("#45414d")), pillar_spots.size() * 2, false)
	var bracket_mm := _multimesh(_box(Vector3(0.18, 0.7, 0.18)), Toon.material(Color("#3a2a1a")), pillar_spots.size(), false)
	var torches := 0
	for i in pillar_spots.size():
		var at: Vector2 = pillar_spots[i]
		var g := terrain.height_at(at.x, at.y)
		var broken := _rng.randf() < 0.25
		var h := 0.45 if broken else 1.0
		pillar_mm.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(1, h, 1)), Vector3(at.x, g + 3.0 * h, at.y)))
		cap_mm.multimesh.set_instance_transform(i * 2, Transform3D(Basis.IDENTITY, Vector3(at.x, g + 0.25, at.y)))
		cap_mm.multimesh.set_instance_transform(i * 2 + 1, Transform3D(Basis.IDENTITY, Vector3(at.x, g + 6.0 * h, at.y)))
		_add_collider(colliders, Vector3(at.x, g, at.y), 1.0, 6.0 * h)
		var bracket_at := Vector3(at.x, g + 2.6, at.y + 0.9)
		if not broken and torches < 14 and _rng.randf() < 0.55:
			torches += 1
			bracket_mm.multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.RIGHT, -0.4), bracket_at))
			_add_fire(bracket_at + Vector3(0, 0.45, 0.15), 0.12, 2.2, 10.0)
		else:
			bracket_mm.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.001), bracket_at))

	# Broken wall pieces.
	var walls := 26
	var wall_mm := _multimesh(_box(Vector3(5.0, 2.8, 1.0)), Toon.material(Color("#4f4a57")), walls, false)
	for i in walls:
		var spot := _pick_spot(half, clear + 3.0)
		var g := terrain.height_at(spot.x, spot.y)
		var yaw := Basis(Vector3.UP, (PI * 0.5) * (_rng.randi() % 2) + _rng.randf_range(-0.1, 0.1))
		var h := _rng.randf_range(0.35, 1.0)
		wall_mm.multimesh.set_instance_transform(i, Transform3D(yaw.scaled(Vector3(1, h, 1)), Vector3(spot.x, g + 1.4 * h, spot.y)))
		var box := BoxShape3D.new()
		box.size = Vector3(5.0, 2.8 * h, 1.0)
		var col := CollisionShape3D.new()
		col.shape = box
		col.transform = Transform3D(yaw, Vector3(spot.x, g + 1.4 * h, spot.y))
		colliders.add_child(col)

	# Bone piles and skulls.
	var bones := 160
	var bone_mm := _multimesh(_cylinder(0.06, 0.06, 0.8), Toon.material(Color("#e8e0cc")), bones, false)
	var skulls := 60
	var skull_mm := _multimesh(_sphere(0.28), Toon.material(Color("#efe8d6")), skulls, false)
	var eye_mm := _multimesh(_sphere(0.07), Toon.material(Color("#141018")), skulls * 2, false)
	for i in bones:
		var spot := _pick_spot(half, 3.0)
		var basis := Basis.from_euler(Vector3(PI * 0.5, _rng.randf() * TAU, 0))
		bone_mm.multimesh.set_instance_transform(i, Transform3D(basis, Vector3(spot.x, terrain.height_at(spot.x, spot.y) + 0.06, spot.y)))
	for i in skulls:
		var spot := _pick_spot(half, 3.0)
		var g := terrain.height_at(spot.x, spot.y)
		var yaw := Basis(Vector3.UP, _rng.randf() * TAU)
		skull_mm.multimesh.set_instance_transform(i, Transform3D(yaw, Vector3(spot.x, g + 0.22, spot.y)))
		for e in 2:
			eye_mm.multimesh.set_instance_transform(i * 2 + e, Transform3D(yaw, Vector3(spot.x, g + 0.26, spot.y) + yaw * Vector3(0.1 - e * 0.2, 0, 0.24)))

	# Barrels and crates in small heaps.
	var barrels := 40
	var barrel_mm := _multimesh(_cylinder(0.45, 0.45, 1.1), Toon.material(Color("#6b4a2b")), barrels, false)
	var band_mm := _multimesh(_cylinder(0.47, 0.47, 0.12), Toon.material(Color("#3a3640")), barrels * 2, false)
	var crates := 40
	var crate_mm := _multimesh(_box(Vector3(1.0, 1.0, 1.0)), Toon.material(Color("#8a6a3f")), crates, false)
	for i in barrels:
		var spot := _pick_spot(half, clear * 0.7)
		var g := terrain.height_at(spot.x, spot.y)
		barrel_mm.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(spot.x, g + 0.55, spot.y)))
		band_mm.multimesh.set_instance_transform(i * 2, Transform3D(Basis.IDENTITY, Vector3(spot.x, g + 0.25, spot.y)))
		band_mm.multimesh.set_instance_transform(i * 2 + 1, Transform3D(Basis.IDENTITY, Vector3(spot.x, g + 0.85, spot.y)))
		_add_collider(colliders, Vector3(spot.x, g, spot.y), 0.45, 1.1)
		if i < crates:
			var c := spot + Vector2(_rng.randf_range(0.9, 1.4), _rng.randf_range(-0.5, 0.5))
			crate_mm.multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, _rng.randf() * 0.6), Vector3(c.x, terrain.height_at(c.x, c.y) + 0.5, c.y)))

	# Braziers: an iron bowl on legs with a big fire.
	for n in 6:
		var spot := _pick_spot(half * 0.8, clear + 6.0)
		var g := terrain.height_at(spot.x, spot.y)
		var bowl := MeshInstance3D.new()
		bowl.mesh = _cylinder(0.8, 0.45, 0.5)
		bowl.material_override = Toon.material(Color("#2e2a33"))
		bowl.position = Vector3(spot.x, g + 1.1, spot.y)
		add_child(bowl)
		var leg := MeshInstance3D.new()
		leg.mesh = _cylinder(0.12, 0.2, 1.0)
		leg.material_override = Toon.material(Color("#2e2a33"))
		leg.position = Vector3(spot.x, g + 0.5, spot.y)
		add_child(leg)
		_add_collider(colliders, Vector3(spot.x, g, spot.y), 0.8, 1.4)
		_add_fire(Vector3(spot.x, g + 1.45, spot.y), 0.4, 2.6, 12.0)

	# Dust motes drifting in the torchlight.
	_build_fireflies(half, Color(0.85, 0.75, 1.0, 0.7), 400, 0.1)


func _sphere(radius: float, radial := 6, rings := 3) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = radial
	mesh.rings = rings
	return mesh
