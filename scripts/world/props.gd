## Scatters pine trees and rocks over the terrain.
## Each kind is drawn with one MultiMeshInstance3D (a single draw call);
## enemies will use the same technique so hundreds of them stay cheap.
extends Node3D

const Toon := preload("res://scripts/core/toon.gd")
const Terrain := preload("res://scripts/world/terrain.gd")

var _rng := RandomNumberGenerator.new()


func build(terrain: Terrain, cfg: Dictionary) -> void:
	_rng.seed = int(cfg.seed) + 7
	var half: float = cfg.playableHalfSize
	var clear: float = cfg.spawnClearRadius

	var colliders := StaticBody3D.new()
	colliders.name = "Colliders"
	add_child(colliders)

	# Trees: trunk + two stacked cones.
	var tree_count := int(cfg.trees)
	var trunks := _multimesh(_cylinder(0.35, 0.45, 2.0), Toon.material(Color("#6b4a2b")), tree_count, false)
	var leaves := _multimesh(_cylinder(0.0, 1.9, 3.2), Toon.material(Color.WHITE, true), tree_count, true)
	var tops := _multimesh(_cylinder(0.0, 1.3, 2.4), Toon.material(Color("#3f9a46")), tree_count, false)
	for i in tree_count:
		var spot := _pick_spot(half, clear)
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
		var spot := _pick_spot(half, clear * 0.6)
		var s := _rng.randf_range(0.5, 1.6)
		var ground := terrain.height_at(spot.x, spot.y)
		var basis := Basis.from_euler(Vector3(_rng.randf() * 0.4, _rng.randf() * TAU, _rng.randf() * 0.4))
		basis = basis.scaled(Vector3(s * 1.2, s * 0.7, s))
		rocks.multimesh.set_instance_transform(i, Transform3D(basis, Vector3(spot.x, ground + s * 0.15, spot.y)))
		_add_collider(colliders, Vector3(spot.x, ground, spot.y), s * 0.9, s * 1.4)


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
