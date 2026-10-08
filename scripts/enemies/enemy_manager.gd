## Spawns and moves all enemies. Enemies are plain data in packed arrays and
## are drawn with one MultiMeshInstance3D, so hundreds of them stay cheap.
## They walk on the terrain height map instead of using physics bodies.
extends Node3D

const Config := preload("res://scripts/core/config.gd")
const Toon := preload("res://scripts/core/toon.gd")
const Terrain := preload("res://scripts/world/terrain.gd")

signal enemy_killed(at_position: Vector3, exp_amount: int)

const GRID_CELL := 2.0
const HIT_FLASH_TIME := 0.12

var terrain: Terrain
var player: CharacterBody3D
## Seconds since the run started; drives spawn rate and enemy health.
var run_time := 0.0
var kills := 0
var active := false

var _type: Dictionary
var _spawn: Dictionary
var _rng := RandomNumberGenerator.new()
var _spawn_timer := 0.0
var _bounds := 70.0

var _pos := PackedVector3Array()
var _hp := PackedFloat32Array()
var _flash := PackedFloat32Array()
var _phase := PackedFloat32Array()
var _mm: MultiMesh
var _base_color: Color


func setup(p_terrain: Terrain, p_player: CharacterBody3D, bounds: float) -> void:
	terrain = p_terrain
	player = p_player
	_bounds = bounds
	var cfg := Config.load_json("res://data/enemies.json")
	_type = cfg.slime
	_spawn = cfg.spawn
	_base_color = Color.html(str(_type.color))

	var mesh := SphereMesh.new()
	mesh.radius = _type.radius
	mesh.height = _type.radius * 1.5
	mesh.radial_segments = 8
	mesh.rings = 4
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = mesh
	_mm.instance_count = int(_spawn.maxAlive)
	_mm.visible_instance_count = 0
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = _mm
	instance.material_override = Toon.material(Color.WHITE, true)
	add_child(instance)


func count() -> int:
	return _pos.size()


func clear() -> void:
	_pos.clear()
	_hp.clear()
	_flash.clear()
	_phase.clear()
	_mm.visible_instance_count = 0
	run_time = 0.0
	kills = 0
	_spawn_timer = 0.0


func _physics_process(delta: float) -> void:
	if not active or player == null:
		return
	run_time += delta
	_update_spawning(delta)
	_update_movement(delta)


func _process(_delta: float) -> void:
	_update_render()


func _update_spawning(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	var ramp := clampf(run_time / float(_spawn.rampSeconds), 0.0, 1.0)
	_spawn_timer = lerpf(_spawn.startInterval, _spawn.minInterval, ramp)
	if _pos.size() >= int(_spawn.maxAlive):
		return
	# Spawn on a ring around the player, outside the view of the action.
	var angle := _rng.randf() * TAU
	var dist := _rng.randf_range(_spawn.ringMin, _spawn.ringMax)
	var x := clampf(player.global_position.x + cos(angle) * dist, -_bounds, _bounds)
	var z := clampf(player.global_position.z + sin(angle) * dist, -_bounds, _bounds)
	var minutes := run_time / 60.0
	_pos.append(Vector3(x, terrain.height_at(x, z), z))
	_hp.append(float(_type.hp) * (1.0 + minutes * float(_spawn.hpGrowthPerMinute)))
	_flash.append(0.0)
	_phase.append(_rng.randf() * TAU)


func _update_movement(delta: float) -> void:
	var target := player.global_position
	var speed: float = _type.speed
	var radius: float = _type.radius
	var touch := radius + 0.45

	# Bucket enemies into a grid so each one only checks its neighbours.
	var grid := {}
	for i in _pos.size():
		var key := Vector2i(floori(_pos[i].x / GRID_CELL), floori(_pos[i].z / GRID_CELL))
		if grid.has(key):
			(grid[key] as Array).append(i)
		else:
			grid[key] = [i]

	for i in _pos.size():
		var p := _pos[i]
		var to_player := Vector2(target.x - p.x, target.z - p.z)
		var dist := to_player.length()
		var move := Vector2.ZERO
		if dist > 0.01:
			move = to_player / dist * speed

		# Push away from neighbours so they spread out instead of stacking.
		var push := Vector2.ZERO
		var cell := Vector2i(floori(p.x / GRID_CELL), floori(p.z / GRID_CELL))
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var bucket: Variant = grid.get(cell + Vector2i(dx, dz))
				if bucket == null:
					continue
				for j: int in bucket:
					if j == i:
						continue
					var d := Vector2(p.x - _pos[j].x, p.z - _pos[j].z)
					var l := d.length()
					if l < radius * 2.0 and l > 0.001:
						push += d / l * (radius * 2.0 - l)
		move += push * 6.0

		p.x = clampf(p.x + move.x * delta, -_bounds, _bounds)
		p.z = clampf(p.z + move.y * delta, -_bounds, _bounds)
		p.y = terrain.height_at(p.x, p.z)
		_pos[i] = p
		_flash[i] = maxf(0.0, _flash[i] - delta)
		_phase[i] += delta * 6.0

		if dist < touch and absf(target.y - p.y) < 1.5:
			player.call("take_damage", float(_type.damage))


func _update_render() -> void:
	var n := _pos.size()
	_mm.visible_instance_count = n
	for i in n:
		# Squash-and-stretch bounce reads as a hopping slime.
		var bounce := absf(sin(_phase[i]))
		var squash := Vector3(1.0 + 0.12 * (1.0 - bounce), 0.85 + 0.3 * bounce, 1.0 + 0.12 * (1.0 - bounce))
		var origin := _pos[i] + Vector3.UP * (float(_type.radius) * 0.6 + bounce * 0.35)
		_mm.set_instance_transform(i, Transform3D(Basis.from_scale(squash), origin))
		_mm.set_instance_color(i, Color.WHITE if _flash[i] > 0.0 else _base_color)


## Index of the closest enemy within `max_range` of `from`, or -1.
func nearest(from: Vector3, max_range: float) -> int:
	var best := -1
	var best_d := max_range * max_range
	for i in _pos.size():
		var d := from.distance_squared_to(_pos[i])
		if d < best_d:
			best_d = d
			best = i
	return best


func position_of(index: int) -> Vector3:
	return _pos[index] + Vector3.UP * float(_type.radius) * 0.6


## Index of an enemy overlapping a sphere at `point`, or -1.
func hit_test(point: Vector3, hit_radius: float) -> int:
	var r: float = float(_type.radius) + hit_radius
	for i in _pos.size():
		if position_of(i).distance_squared_to(point) < r * r:
			return i
	return -1


func damage(index: int, amount: float) -> void:
	_hp[index] -= amount
	_flash[index] = HIT_FLASH_TIME
	if _hp[index] <= 0.0:
		var where := position_of(index)
		_remove(index)
		kills += 1
		enemy_killed.emit(where, int(_type.xp))


func _remove(index: int) -> void:
	# Swap with the last enemy so removal is O(1).
	var last := _pos.size() - 1
	_pos[index] = _pos[last]
	_hp[index] = _hp[last]
	_flash[index] = _flash[last]
	_phase[index] = _phase[last]
	_pos.resize(last)
	_hp.resize(last)
	_flash.resize(last)
	_phase.resize(last)
