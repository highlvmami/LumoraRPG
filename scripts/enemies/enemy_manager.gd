## Spawns and moves all enemies. Enemies are plain data in packed arrays and
## each kind is drawn with one MultiMeshInstance3D, so hundreds stay cheap.
## They walk on the terrain height map instead of using physics bodies.
## New kinds unlock as the run goes on (data/enemies.json) and every enemy
## gets more health, damage and speed the longer the run lasts.
extends Node3D

const Config := preload("res://scripts/core/config.gd")
const Toon := preload("res://scripts/core/toon.gd")
const Terrain := preload("res://scripts/world/terrain.gd")
const EnemyMeshes := preload("res://scripts/enemies/enemy_meshes.gd")

signal enemy_killed(at_position: Vector3, exp_amount: int, gold_amount: int)
## Emitted the first time a kind can spawn in a run (not for the starting kind).
signal kind_unlocked(kind_name: String)

const GRID_CELL := 2.0
const HIT_FLASH_TIME := 0.12
const KNOCKBACK := 0.7
const MAX_SHOTS := 64
## Instance colors multiply the baked vertex colors; > 1 makes a hit flash.
const FLASH_COLOR := Color(2.6, 2.6, 2.6)

var terrain: Terrain
var player: CharacterBody3D
## Seconds since the run started; drives spawn rate, new kinds and toughness.
var run_time := 0.0
var kills := 0
var active := false
## Projectiles thrown by ranged enemies this run.
var shots_fired := 0

var _kinds: Array = []
var _spawn: Dictionary
var _rng := RandomNumberGenerator.new()
var _spawn_timer := 0.0
var _bounds := 70.0
var _announced := {}

var _kind := PackedInt32Array()
var _pos := PackedVector3Array()
var _hp := PackedFloat32Array()
var _flash := PackedFloat32Array()
var _phase := PackedFloat32Array()
var _yaw := PackedFloat32Array()
## Ranged enemies: seconds until the next throw.
var _cool := PackedFloat32Array()
var _mms: Array[MultiMesh] = []

var _shot_pos := PackedVector3Array()
var _shot_vel := PackedVector3Array()
var _shot_life := PackedFloat32Array()
var _shot_damage := PackedFloat32Array()
var _shot_mm: MultiMesh


func setup(p_terrain: Terrain, p_player: CharacterBody3D, bounds: float) -> void:
	terrain = p_terrain
	player = p_player
	_bounds = bounds
	var cfg := Config.load_json("res://data/enemies.json")
	_kinds = cfg.kinds
	_spawn = cfg.spawn

	var mat := Toon.material(Color.WHITE, true)
	for k: Dictionary in _kinds:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = EnemyMeshes.build(str(k.id), float(k.radius))
		mm.instance_count = int(_spawn.maxAlive)
		mm.visible_instance_count = 0
		var instance := MultiMeshInstance3D.new()
		instance.name = str(k.id).capitalize()
		instance.multimesh = mm
		instance.material_override = mat
		add_child(instance)
		_mms.append(mm)

	var orb := SphereMesh.new()
	orb.radius = 0.22
	orb.height = 0.44
	orb.radial_segments = 8
	orb.rings = 4
	_shot_mm = MultiMesh.new()
	_shot_mm.transform_format = MultiMesh.TRANSFORM_3D
	_shot_mm.mesh = orb
	_shot_mm.instance_count = MAX_SHOTS
	_shot_mm.visible_instance_count = 0
	var shots := MultiMeshInstance3D.new()
	shots.name = "Shots"
	shots.multimesh = _shot_mm
	var shot_mat := Toon.material(Color("#b98cff"))
	shot_mat.emission_enabled = true
	shot_mat.emission = Color("#8a4dff")
	shots.material_override = shot_mat
	add_child(shots)


func count() -> int:
	return _pos.size()


## How many enemies of the kind with this id are alive.
func count_kind(id: String) -> int:
	var k := _kind_index(id)
	var n := 0
	for i in _kind.size():
		if _kind[i] == k:
			n += 1
	return n


func clear() -> void:
	_kind.clear()
	_pos.clear()
	_hp.clear()
	_flash.clear()
	_phase.clear()
	_yaw.clear()
	_cool.clear()
	_shot_pos.clear()
	_shot_vel.clear()
	_shot_life.clear()
	_shot_damage.clear()
	for mm in _mms:
		mm.visible_instance_count = 0
	_shot_mm.visible_instance_count = 0
	run_time = 0.0
	kills = 0
	shots_fired = 0
	_spawn_timer = 0.0
	_announced.clear()


## Kills every enemy without rewards (developer menu).
func kill_all_silently() -> void:
	var t := run_time
	var k := kills
	var s := shots_fired
	clear()
	run_time = t
	kills = k
	shots_fired = s
	for kd: Dictionary in _kinds:
		if _unlocked(kd):
			_announced[kd.id] = true


func _physics_process(delta: float) -> void:
	if not active or player == null:
		return
	run_time += delta
	_update_spawning(delta)
	_update_movement(delta)
	_update_shots(delta)


func _process(_delta: float) -> void:
	_update_render()


## Multiplier that grows with run time; `per_minute` comes from the spawn config.
func growth(key: String) -> float:
	return 1.0 + run_time / 60.0 * float(_spawn[key])


func _speed_growth() -> float:
	return minf(growth("speedGrowthPerMinute"), 1.0 + float(_spawn.maxSpeedGrowth))


func _unlocked(k: Dictionary) -> bool:
	return run_time >= float(k.unlockAt)


func _update_spawning(delta: float) -> void:
	for k: Dictionary in _kinds:
		if _unlocked(k) and not _announced.has(k.id):
			_announced[k.id] = true
			if float(k.unlockAt) > 0.0:
				kind_unlocked.emit(str(k.name))

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
	var at := Vector3(player.global_position.x + cos(angle) * dist, 0.0, player.global_position.z + sin(angle) * dist)
	spawn(str(_kinds[_pick_kind()].id), at)


## Weighted random choice among the kinds unlocked so far.
func _pick_kind() -> int:
	var total := 0.0
	for k: Dictionary in _kinds:
		if _unlocked(k):
			total += float(k.weight)
	var roll := _rng.randf() * total
	for i in _kinds.size():
		var k: Dictionary = _kinds[i]
		if not _unlocked(k):
			continue
		roll -= float(k.weight)
		if roll <= 0.0:
			return i
	return 0


## Spawns one enemy of kind `id` at `at` (y is snapped to the ground).
## Returns false if the kind is unknown or the enemy cap is reached.
func spawn(id: String, at: Vector3) -> bool:
	var k := _kind_index(id)
	if k < 0 or _pos.size() >= int(_spawn.maxAlive):
		return false
	var x := clampf(at.x, -_bounds, _bounds)
	var z := clampf(at.z, -_bounds, _bounds)
	_kind.append(k)
	_pos.append(Vector3(x, terrain.height_at(x, z), z))
	_hp.append(float(_kinds[k].hp) * growth("hpGrowthPerMinute"))
	_flash.append(0.0)
	_phase.append(_rng.randf() * TAU)
	_yaw.append(0.0)
	_cool.append(_rng.randf_range(0.8, 1.4))
	return true


func _kind_index(id: String) -> int:
	for i in _kinds.size():
		if _kinds[i].id == id:
			return i
	return -1


func _update_movement(delta: float) -> void:
	var target := player.global_position
	var speed_scale := _speed_growth()
	var damage_scale := growth("damageGrowthPerMinute")

	# Bucket enemies into a grid so each one only checks its neighbours.
	var grid := {}
	for i in _pos.size():
		var key := Vector2i(floori(_pos[i].x / GRID_CELL), floori(_pos[i].z / GRID_CELL))
		if grid.has(key):
			(grid[key] as Array).append(i)
		else:
			grid[key] = [i]

	for i in _pos.size():
		var kd: Dictionary = _kinds[_kind[i]]
		var radius := float(kd.radius)
		var p := _pos[i]
		var to_player := Vector2(target.x - p.x, target.z - p.z)
		var dist := to_player.length()
		var dir: Vector2 = to_player / dist if dist > 0.01 else Vector2.ZERO
		var speed := float(kd.speed) * speed_scale
		var move := dir * speed

		if kd.has("ranged"):
			# Keep a throwing distance, circle a little, throw when in range.
			var r: Dictionary = kd.ranged
			var keep := float(r.keepAway)
			if dist < keep - 1.0:
				move = -dir * speed
			elif dist < keep + 1.0:
				move = Vector2(-dir.y, dir.x) * speed * 0.35
			_cool[i] -= delta
			if _cool[i] <= 0.0 and dist < float(r.range):
				_throw(p + Vector3.UP * 1.3, float(r.projectileSpeed), float(r.damage) * damage_scale)
				_cool[i] = float(r.cooldown) * _rng.randf_range(0.8, 1.2)

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
					var min_gap := radius + float(_kinds[_kind[j]].radius)
					if l < min_gap and l > 0.001:
						push += d / l * (min_gap - l)
		move += push * 6.0

		p.x = clampf(p.x + move.x * delta, -_bounds, _bounds)
		p.z = clampf(p.z + move.y * delta, -_bounds, _bounds)
		p.y = terrain.height_at(p.x, p.z)
		_pos[i] = p
		_flash[i] = maxf(0.0, _flash[i] - delta)
		_phase[i] += delta * (6.0 + speed)
		if dist > 0.01:
			_yaw[i] = lerp_angle(_yaw[i], atan2(dir.x, dir.y), minf(1.0, delta * 10.0))

		if dist < radius + 0.45 and absf(target.y - p.y) < 1.5:
			player.call("take_damage", float(kd.damage) * damage_scale)


func _throw(from: Vector3, speed: float, dmg: float) -> void:
	if _shot_pos.size() >= MAX_SHOTS:
		return
	var aim := player.global_position + Vector3.UP * 0.9
	var vel := (aim - from).normalized() * speed
	_shot_pos.append(from)
	_shot_vel.append(vel)
	_shot_life.append(from.distance_to(aim) / speed + 0.8)
	_shot_damage.append(dmg)
	shots_fired += 1


func _update_shots(delta: float) -> void:
	var chest := player.global_position + Vector3.UP * 0.9
	var i := 0
	while i < _shot_pos.size():
		_shot_pos[i] += _shot_vel[i] * delta
		_shot_life[i] -= delta
		var hit := _shot_pos[i].distance_squared_to(chest) < 0.75 * 0.75
		if hit:
			player.call("take_damage", _shot_damage[i])
		if hit or _shot_life[i] <= 0.0:
			var last := _shot_pos.size() - 1
			_shot_pos[i] = _shot_pos[last]
			_shot_vel[i] = _shot_vel[last]
			_shot_life[i] = _shot_life[last]
			_shot_damage[i] = _shot_damage[last]
			_shot_pos.resize(last)
			_shot_vel.resize(last)
			_shot_life.resize(last)
			_shot_damage.resize(last)
		else:
			i += 1


func _update_render() -> void:
	var counts := PackedInt32Array()
	counts.resize(_mms.size())
	counts.fill(0)
	for i in _pos.size():
		var k := _kind[i]
		var bounce := absf(sin(_phase[i]))
		var scale_v: Vector3
		var lift: float
		if _kinds[k].id == "slime":
			# Squash-and-stretch bounce reads as a hopping slime.
			scale_v = Vector3(1.0 + 0.12 * (1.0 - bounce), 0.85 + 0.3 * bounce, 1.0 + 0.12 * (1.0 - bounce))
			lift = float(_kinds[k].radius) * 0.6 + bounce * 0.35
		else:
			scale_v = Vector3.ONE
			lift = bounce * 0.08
		if _flash[i] > 0.0:
			# Squashed flat for a moment when hit.
			scale_v *= Vector3(1.2, 0.75, 1.2)
		var xf_basis := Basis(Vector3.UP, _yaw[i]).scaled(scale_v)
		var slot := counts[k]
		counts[k] = slot + 1
		_mms[k].set_instance_transform(slot, Transform3D(xf_basis, _pos[i] + Vector3.UP * lift))
		_mms[k].set_instance_color(slot, FLASH_COLOR if _flash[i] > 0.0 else Color.WHITE)
	for k in _mms.size():
		_mms[k].visible_instance_count = counts[k]

	var n := _shot_pos.size()
	_shot_mm.visible_instance_count = n
	for i in n:
		_shot_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, _shot_pos[i]))


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
	return _pos[index] + Vector3.UP * float(_kinds[_kind[index]].center)


## Index of an enemy overlapping a sphere at `point`, or -1.
func hit_test(point: Vector3, hit_radius: float) -> int:
	for i in _pos.size():
		var r := float(_kinds[_kind[i]].radius) + hit_radius
		if position_of(i).distance_squared_to(point) < r * r:
			return i
	return -1


func damage(index: int, amount: float, push_dir := Vector3.ZERO) -> void:
	_hp[index] -= amount
	_flash[index] = HIT_FLASH_TIME
	# Small knockback so hits feel punchy (big enemies barely move).
	var kd: Dictionary = _kinds[_kind[index]]
	var push := KNOCKBACK * 0.6 / float(kd.radius)
	var p := _pos[index]
	p.x = clampf(p.x + push_dir.x * push, -_bounds, _bounds)
	p.z = clampf(p.z + push_dir.z * push, -_bounds, _bounds)
	p.y = terrain.height_at(p.x, p.z)
	_pos[index] = p
	if _hp[index] <= 0.0:
		var where := position_of(index)
		_remove(index)
		kills += 1
		enemy_killed.emit(where, int(kd.xp), int(kd.get("gold", 0)))


func _remove(index: int) -> void:
	# Swap with the last enemy so removal is O(1).
	var last := _pos.size() - 1
	_kind[index] = _kind[last]
	_pos[index] = _pos[last]
	_hp[index] = _hp[last]
	_flash[index] = _flash[last]
	_phase[index] = _phase[last]
	_yaw[index] = _yaw[last]
	_cool[index] = _cool[last]
	_kind.resize(last)
	_pos.resize(last)
	_hp.resize(last)
	_flash.resize(last)
	_phase.resize(last)
	_yaw.resize(last)
	_cool.resize(last)
