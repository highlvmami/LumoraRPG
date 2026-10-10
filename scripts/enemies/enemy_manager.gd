## Spawns and moves all enemies. Enemies are plain data in packed arrays and
## each kind is drawn with one MultiMeshInstance3D, so hundreds stay cheap.
## They walk on the terrain height map instead of using physics bodies.
## New kinds unlock as the run goes on (data/enemies.json) and every enemy
## gets more health, damage and speed the longer the run lasts.
## Bosses fight alone (other enemies leave when one arrives) and use attack
## patterns from their data: each attack first shows a red warning zone on
## the ground, then hits whatever is still inside it. Bosses get angry below
## 2/3 health and enraged below 1/3: each phase (and each later boss in a run)
## unlocks new attack styles, mixes them up and makes them come faster.
## Co-op: the room's host runs everything and enemies chase whichever player
## is closest (`targets`). Partners' games run as a mirror: they show the
## host's enemies from snapshots and send their hits to the host.
extends Node3D

const Config := preload("res://scripts/core/config.gd")
const Toon := preload("res://scripts/core/toon.gd")
const Terrain := preload("res://scripts/world/terrain.gd")
const EnemyMeshes := preload("res://scripts/enemies/enemy_meshes.gd")
const BossAttacks := preload("res://scripts/enemies/boss_attacks.gd")

signal enemy_killed(at_position: Vector3, exp_amount: int, gold_amount: int)
## Emitted the first time a kind can spawn in a run (not for the starting kind).
signal kind_unlocked(kind_name: String)
## A big pack of one kind is rushing in.
signal swarm_started(kind_name: String)
signal boss_spawned(boss_name: String)
signal boss_defeated(boss_name: String)
## A mini boss (a dungeon gate's guardian) was killed.
signal mini_boss_defeated(uid: int)
## The boss got angrier: phase 2 (angry) or 3 (enraged).
signal boss_phase_changed(boss_name: String, phase: int)
## Mirror only: a hit to send to the host (enemy uid, damage, push direction).
signal remote_hit(uid: int, amount: float, push_dir: Vector3)

const GRID_CELL := 2.0
const HIT_FLASH_TIME := 0.12
const KNOCKBACK := 0.7
const MAX_SHOTS := 64
## Instance colors multiply the baked vertex colors; > 1 makes a hit flash.
const FLASH_COLOR := Color(2.6, 2.6, 2.6)

var terrain: Terrain
var player: CharacterBody3D
## Players enemies chase and hurt (this player and co-op partners). Each
## needs `dead`, `visible`, a global position and `take_damage(amount)`.
var targets: Array = []
## Shows the host's enemies instead of running them (co-op partner).
## Night level (0..1) from the weather: enemies hit and run harder in the dark.
var night := 0.0
const DUELIST_UID := 9000001
## World boss fight: this boss id fights alone; `world_damage` is what it took.
var world_fight := ""
var world_damage := 0.0
var _world_spawned := false
const WORLD_BOSS_HP := 40000.0
## Nightmare difficulty multipliers (see data/difficulty.json).
var difficulty := {"hp": 1.0, "damage": 1.0, "reward": 1.0}
var mirror := false
## Seconds since the run started; drives spawn rate, new kinds and toughness.
var run_time := 0.0
var kills := 0
var active := false
## Projectiles thrown by ranged enemies this run.
var shots_fired := 0
## Boss attacks started this run, and how many of them caught the player.
var boss_attacks_started := 0
var boss_attack_hits := 0
## Draws the warning zones of boss attacks.
var attacks: BossAttacks

var _kinds: Array = []
var _spawn: Dictionary
var _rng := RandomNumberGenerator.new()
var _spawn_timer := 0.0
var _swarm_timer := 0.0
var _bounds := 70.0
var _announced := {}
var _next_boss := 0
var _next_uid := 1

var _kind := PackedInt32Array()
## Stable id per enemy (indices change when enemies are removed).
var _uid := PackedInt32Array()
var _max_hp := PackedFloat32Array()
var _pos := PackedVector3Array()
var _hp := PackedFloat32Array()
var _flash := PackedFloat32Array()
var _phase := PackedFloat32Array()
var _yaw := PackedFloat32Array()
## Ranged enemies: seconds until the next throw.
var _cool := PackedFloat32Array()
var _mms: Array[MultiMesh] = []
## Mirror: where each enemy is heading (the last snapshot).
var _goal := PackedVector3Array()
var _goal_yaw := PackedFloat32Array()

## Boss fight state (one boss at a time): seconds until its next attack, how
## long it stands still winding up, which attack comes next, a dash or leap
## it is doing (or will do after the wind-up) and attacks waiting to land.
var _boss_cooldown := 0.0
var _dead_uid := -1
## The run's map id and the kinds its own kinds replace.
var map_id := ""
var _replaced := {}
var _boss_hold := 0.0
var _boss_next := 0
## 1 calm, 2 angry, 3 enraged (by health left).
var _boss_phase := 1
## How many bosses came before this one in the run (later ones are harder).
var _boss_rank := 0
var _bosses_spawned := 0
var _boss_last_type := ""
var _dash := {}
var _pending_dash := {}
var _strikes: Array = []

var _shot_pos := PackedVector3Array()
var _shot_vel := PackedVector3Array()
var _shot_life := PackedFloat32Array()
var _shot_damage := PackedFloat32Array()
var _shot_mm: MultiMesh


func setup(p_terrain: Terrain, p_player: CharacterBody3D, bounds: float) -> void:
	terrain = p_terrain
	player = p_player
	targets = [p_player]
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

	attacks = BossAttacks.new()
	attacks.name = "BossAttacks"
	attacks.terrain = terrain
	add_child(attacks)


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
	world_fight = ""
	world_damage = 0.0
	_world_spawned = false
	_kind.clear()
	_uid.clear()
	_goal.clear()
	_goal_yaw.clear()
	_max_hp.clear()
	_next_boss = 0
	_bosses_spawned = 0
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
	_swarm_timer = float(_spawn.get("swarmStart", 18.0))
	_announced.clear()
	_reset_boss_fight()
	boss_attacks_started = 0
	boss_attack_hits = 0


## Kills every enemy without rewards (developer menu).
func kill_all_silently() -> void:
	var t := run_time
	var k := kills
	var s := shots_fired
	var b := _next_boss
	var spawned := _bosses_spawned
	var started := boss_attacks_started
	clear()
	_next_boss = b
	_bosses_spawned = spawned
	run_time = t
	kills = k
	shots_fired = s
	boss_attacks_started = started
	for kd: Dictionary in _kinds:
		if _unlocked(kd):
			_announced[kd.id] = true


func _physics_process(delta: float) -> void:
	if not active or player == null:
		return
	if mirror:
		_update_mirror(delta)
		return
	run_time += delta
	_update_spawning(delta)
	_update_movement(delta)
	_update_shots(delta)
	_update_strikes(delta)


func _process(_delta: float) -> void:
	_update_render()


## Players that can be chased right now.
func alive_targets() -> Array:
	var out: Array = []
	for t: Node3D in targets:
		if is_instance_valid(t) and t.visible and not bool(t.get("dead")):
			out.append(t)
	return out


func _closest(alive: Array, at: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for t: Node3D in alive:
		var d := Vector2(t.global_position.x - at.x, t.global_position.z - at.z).length_squared()
		if d < best_d:
			best_d = d
			best = t
	return best


## The player closest to `at` (this player when nobody is alive).
func target_near(at: Vector3) -> Node3D:
	var who := _closest(alive_targets(), at)
	return who if who else player


## Multiplier that grows with run time; `per_minute` comes from the spawn config.
func growth(key: String) -> float:
	var scale := 1.0 + run_time / 60.0 * float(_spawn[key])
	if key.begins_with("speed"):
		return scale
	# The first minutes are gentle: enemies start weak and reach full strength.
	var early := clampf(run_time / float(_spawn.get("earlySeconds", 1.0)), 0.0, 1.0)
	return scale * lerpf(float(_spawn.get("earlyScale", 1.0)), 1.0, early)


func _speed_growth() -> float:
	return minf(growth("speedGrowthPerMinute"), 1.0 + float(_spawn.maxSpeedGrowth))


## Kinds of another map never come; a map's own kind takes the place of the
## kind it `replaces` (the snow wolf instead of the wolf).
func _unlocked(k: Dictionary) -> bool:
	if k.has("map") and str(k.map) != map_id:
		return false
	if _replaced.has(str(k.id)):
		return false
	return run_time >= float(k.unlockAt)


## The map of the run (set before it starts): picks the map's own enemies and boss order.
func set_map(id: String) -> void:
	map_id = id
	_replaced.clear()
	for k: Dictionary in _kinds:
		if k.has("replaces") and str(k.get("map", "")) == id:
			_replaced[str(k.replaces)] = true


func _update_spawning(delta: float) -> void:
	if world_fight != "":
		if not _world_spawned and run_time > 1.0:
			_world_spawned = true
			if spawn_boss(world_fight, _spawn_anchor() + Vector3(0, 0, 14.0)):
				var last := _hp.size() - 1
				_hp[last] = WORLD_BOSS_HP
				_max_hp[last] = WORLD_BOSS_HP
		return
	for k: Dictionary in _kinds:
		if _unlocked(k) and not _announced.has(k.id):
			_announced[k.id] = true
			if float(k.unlockAt) > 0.0 and not k.get("boss", false):
				kind_unlocked.emit(str(k.name))

	# Bosses arrive at fixed times, in order (the list repeats).
	var boss_times: Array = _spawn.bossTimes
	if _next_boss < boss_times.size() and run_time >= float(boss_times[_next_boss]):
		var order: Array = (_spawn.get("bossOrderByMap", {}) as Dictionary).get(map_id, _spawn.bossOrder)
		var a := _rng.randf() * TAU
		spawn_boss(str(order[_next_boss % order.size()]), _spawn_anchor() + Vector3(cos(a), 0.0, sin(a)) * 16.0)
		_next_boss += 1

	# Nothing else spawns during a boss fight.
	if boss_index() >= 0:
		return
	_swarm_timer -= delta
	if _swarm_timer <= 0.0:
		_swarm_timer = float(_spawn.get("swarmEvery", 22.0)) * _rng.randf_range(0.8, 1.25)
		_spawn_swarm()
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	var ramp := clampf(run_time / float(_spawn.rampSeconds), 0.0, 1.0)
	# More players, more enemies.
	_spawn_timer = lerpf(_spawn.startInterval, _spawn.minInterval, ramp) / party_scale()
	# Small packs at first, bigger ones later; both stop growing after
	# rampSeconds (and the enemy cap), while enemies keep getting tougher.
	var batch := roundi(lerpf(float(_spawn.get("batchStart", 1)), float(_spawn.get("batchMax", 1)), ramp))
	var anchor := _spawn_anchor()
	var angle := _rng.randf() * TAU
	for n in batch:
		if _pos.size() >= int(_spawn.maxAlive):
			return
		# Spawn on a ring around a player, outside the view of the action.
		var a := angle + _rng.randf_range(-0.35, 0.35)
		var dist := _rng.randf_range(_spawn.ringMin, _spawn.ringMax)
		var at := Vector3(anchor.x + cos(a) * dist, 0.0, anchor.z + sin(a) * dist)
		spawn(str(_kinds[_pick_kind()].id), at)


## A big pack of one ordinary kind rushes in from one side, packed close.
func _spawn_swarm() -> void:
	var picks: Array = []
	for i in _kinds.size():
		var k: Dictionary = _kinds[i]
		if _unlocked(k) and float(k.weight) > 0.0 and not k.has("ranged"):
			picks.append(i)
	if picks.is_empty():
		return
	var kind: Dictionary = _kinds[picks[_rng.randi() % picks.size()]]
	var ramp := clampf(run_time / float(_spawn.rampSeconds), 0.0, 1.0)
	var count := roundi(lerpf(float(_spawn.get("swarmMin", 14)), float(_spawn.get("swarmMax", 40)), ramp) * party_scale())
	var anchor := _spawn_anchor()
	var angle := _rng.randf() * TAU
	var centre := anchor + Vector3(cos(angle), 0.0, sin(angle)) * float(_spawn.ringMax)
	for n in count:
		if _pos.size() >= int(_spawn.maxAlive):
			break
		var offset := Vector3(_rng.randf_range(-4.0, 4.0), 0.0, _rng.randf_range(-4.0, 4.0))
		spawn(str(kind.id), centre + offset)
	swarm_started.emit(str(kind.name))


## A fractional amount rounded down, plus 1 with the chance of the remainder.
func _roll_amount(value: float) -> int:
	var whole := int(value)
	return whole + (1 if _rng.randf() < value - whole else 0)


## A random living player's position to spawn around.
func _spawn_anchor() -> Vector3:
	var alive := alive_targets()
	return (alive[_rng.randi() % alive.size()] as Node3D).global_position if not alive.is_empty() else player.global_position


## 1 alone, +0.5 for every other living player (more spawns, tougher bosses).
func party_scale() -> float:
	return 1.0 + 0.5 * maxi(0, alive_targets().size() - 1)


## Weighted random choice among the kinds unlocked so far.
func _pick_kind() -> int:
	var total := 0.0
	for k: Dictionary in _kinds:
		if _unlocked(k):
			total += float(k.weight)
	if total <= 0.0:
		return 0
	var roll := _rng.randf() * total
	for i in _kinds.size():
		var k: Dictionary = _kinds[i]
		if not _unlocked(k) or float(k.weight) <= 0.0:
			continue
		roll -= float(k.weight)
		if roll <= 0.0:
			return i
	return 0


## Spawns one enemy of kind `id` at `at` (y is snapped to the ground).
## Returns false if the kind is unknown or the enemy cap is reached
## (`force` ignores the cap, used for bosses).
func spawn(id: String, at: Vector3, force := false) -> bool:
	var k := _kind_index(id)
	if k < 0 or (_pos.size() >= int(_spawn.maxAlive) and not force):
		return false
	var x := clampf(at.x, -_bounds, _bounds)
	var z := clampf(at.z, -_bounds, _bounds)
	var hp := float(_kinds[k].hp) * growth("hpGrowthPerMinute") * float(difficulty.hp)
	if _kinds[k].get("boss", false):
		hp *= party_scale()
	_kind.append(k)
	_uid.append(_next_uid)
	_next_uid += 1
	_max_hp.append(hp)
	_pos.append(Vector3(x, terrain.height_at(x, z), z))
	_hp.append(hp)
	_flash.append(0.0)
	_phase.append(_rng.randf() * TAU)
	_yaw.append(0.0)
	_cool.append(_rng.randf_range(0.8, 1.4))
	return true


## Starts a boss fight: every other enemy (and thrown rock) leaves without
## rewards and the boss `id` appears at `at`.
func spawn_boss(id: String, at: Vector3) -> bool:
	for i in range(_pos.size() - 1, -1, -1):
		if not _kinds[_kind[i]].get("boss", false):
			_remove(i)
	_shot_pos.clear()
	_shot_vel.clear()
	_shot_life.clear()
	_shot_damage.clear()
	if not spawn(id, at, true):
		return false
	_reset_boss_fight()
	_boss_rank = _bosses_spawned
	_bosses_spawned += 1
	_boss_cooldown = 2.5
	boss_spawned.emit(str(_kinds[_kind_index(id)].name))
	return true


func _reset_boss_fight() -> void:
	_boss_cooldown = 0.0
	_boss_hold = 0.0
	_boss_next = 0
	_boss_phase = 1
	_boss_rank = 0
	_boss_last_type = ""
	_dash = {}
	_pending_dash = {}
	_strikes.clear()
	if attacks:
		attacks.clear()


func _kind_index(id: String) -> int:
	for i in _kinds.size():
		if _kinds[i].id == id:
			return i
	return -1


func _update_movement(delta: float) -> void:
	var alive := alive_targets()
	if alive.is_empty():
		return
	var speed_scale := _speed_growth() * (1.0 + 0.12 * night)
	var damage_scale := growth("damageGrowthPerMinute") * (1.0 + 0.3 * night) * float(difficulty.damage)

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
		if kd.get("boss", false):
			_update_boss(i, kd, delta, speed_scale, damage_scale, _closest(alive, _pos[i]))
			continue
		var radius := float(kd.radius)
		var p := _pos[i]
		var who: Node3D = _closest(alive, p) if alive.size() > 1 else alive[0]
		var target := who.global_position
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
				var from := p + Vector3.UP * float(r.get("height", 1.3))
				var dmg := float(r.damage) * damage_scale
				var aim := (target + Vector3.UP * 0.9 - from).normalized()
				_throw(from, aim, float(r.projectileSpeed), dmg)
				# Bosses also send a ring of shots in every direction.
				var ring := int(r.get("ring", 0))
				for n in ring:
					var a := TAU * n / ring
					_throw(from, Vector3(cos(a), -0.08, sin(a)), float(r.projectileSpeed), dmg)
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
			who.call("take_damage", float(kd.damage) * damage_scale)


## Boss: walks to the player, and every few seconds winds up one of its
## attacks (in turn), standing still while the warning zone fills.
func _update_boss(i: int, kd: Dictionary, delta: float, speed_scale: float, damage_scale: float, who: Node3D) -> void:
	var p := _pos[i]
	var target := who.global_position
	var to_player := Vector2(target.x - p.x, target.z - p.z)
	var dist := to_player.length()
	var dir: Vector2 = to_player / dist if dist > 0.01 else Vector2.ZERO
	var radius := float(kd.radius)
	_flash[i] = maxf(0.0, _flash[i] - delta)
	_update_boss_phase(i, kd)

	if not _dash.is_empty():
		# Charging or leaping along a fixed path.
		_dash.t = float(_dash.t) + delta
		var f := minf(1.0, float(_dash.t) / float(_dash.duration))
		var flat: Vector2 = (_dash.from as Vector2).lerp(_dash.to, f)
		p = Vector3(flat.x, terrain.height_at(flat.x, flat.y) + sin(f * PI) * float(_dash.arc), flat.y)
		_pos[i] = p
		_phase[i] += delta * 14.0
		if float(_dash.arc) == 0.0 and not bool(_dash.hit):
			for t: Node3D in alive_targets():
				if Vector2(t.global_position.x - p.x, t.global_position.z - p.z).length() < radius + 0.6:
					_dash.hit = true
					t.call("take_damage", float(_dash.damage))
		if f >= 1.0:
			if _dash.has("land"):
				# The leap lands: everything in the warning circle is hit.
				var land: Dictionary = _dash.land
				_damage_if_inside([land], float(_dash.damage))
			var chain := int(_dash.get("chain", 0))
			var chained: Dictionary = _dash.get("attack", {})
			_dash = {}
			if chain > 0 and not chained.is_empty():
				# Enraged: charges again right away at where the player is now.
				_start_charge(i, chained, float(_dash_warn(chained)) * 0.6, float(_dash_damage(chained)), chain - 1)
		return

	if _boss_hold > 0.0:
		_boss_hold -= delta
		if _boss_hold <= 0.0 and not _pending_dash.is_empty():
			_dash = _pending_dash
			_pending_dash = {}
	else:
		if dist > radius + 1.0:
			var step := dir * float(kd.speed) * speed_scale * (1.0 + 0.15 * (_boss_phase - 1)) * delta
			p.x = clampf(p.x + step.x, -_bounds, _bounds)
			p.z = clampf(p.z + step.y, -_bounds, _bounds)
			p.y = terrain.height_at(p.x, p.z)
			_pos[i] = p
			_phase[i] += delta * 5.0
		_boss_cooldown -= delta
		if _boss_cooldown <= 0.0 and dist < 30.0:
			start_boss_attack(i)
	if dist > 0.01:
		_yaw[i] = lerp_angle(_yaw[i], atan2(dir.x, dir.y), minf(1.0, delta * 6.0))
	if dist < radius + 0.45 and absf(target.y - p.y) < 2.0:
		who.call("take_damage", float(kd.damage) * damage_scale)


## 1 calm, 2 angry (below 2/3 health), 3 enraged (below 1/3).
func boss_phase() -> int:
	return _boss_phase


## How much faster boss attacks come (warning time and pauses are divided by
## it): grows with every boss already met this run and every phase.
func boss_tempo() -> float:
	return minf(float(_spawn.get("bossBaseTempo", 1.0)) + float(_spawn.bossTempoPerBoss) * _boss_rank + float(_spawn.bossTempoPerPhase) * (_boss_phase - 1), float(_spawn.bossMaxTempo))


## Attack style level 1-3: which attacks the boss may use and how big they
## get. Later bosses start at a higher level.
func boss_style() -> int:
	return clampi(_boss_phase + _boss_rank, 1, 3)


func _update_boss_phase(i: int, kd: Dictionary) -> void:
	var ratio := _hp[i] / _max_hp[i]
	var limits: Array = _spawn.bossPhases
	var phase := 1
	for limit in limits:
		if ratio <= float(limit):
			phase += 1
	if phase > _boss_phase:
		_boss_phase = phase
		# A roar, then the next attack comes quickly.
		_boss_cooldown = minf(_boss_cooldown, 0.7)
		boss_phase_changed.emit(str(kd.name), phase)


## Attacks the boss may use at its current style level.
func _boss_attack_pool(kd: Dictionary) -> Array:
	var out: Array = []
	for a: Dictionary in kd.attacks:
		if int(a.get("phase", 1)) <= boss_style():
			out.append(a)
	return out


func _dash_warn(a: Dictionary) -> float:
	return maxf(float(a.telegraph) / boss_tempo(), 0.4)


func _dash_damage(a: Dictionary) -> float:
	return float(a.damage) * growth("damageGrowthPerMinute") * float(difficulty.damage)


## Winds up the boss's next attack (or the one of type `only`, for tests).
## The first boss starts by using its attacks in turn; angrier and later
## bosses pick at random (never the same twice in a row) from a bigger set.
func start_boss_attack(i: int, only := "") -> void:
	var kd: Dictionary = _kinds[_kind[i]]
	var pool := _boss_attack_pool(kd)
	var a: Dictionary = pool[_boss_next % pool.size()]
	if only != "":
		for candidate: Dictionary in kd.attacks:
			if candidate.type == only:
				a = candidate
				break
	elif boss_style() > 1 and pool.size() > 1:
		var choices := pool.filter(func(c: Dictionary) -> bool: return str(c.type) != _boss_last_type)
		a = choices[_rng.randi() % choices.size()]
	_boss_last_type = str(a.type)
	_boss_next += 1
	boss_attacks_started += 1
	var tempo := boss_tempo()
	var extra := boss_style() - 1
	var warn := _dash_warn(a)
	_boss_cooldown = float(kd.attackCooldown) / tempo + warn
	var dmg := _dash_damage(a)
	var color := Color(str(a.get("color", "#ff2b2b")))
	var p := _pos[i]
	var me := Vector2(p.x, p.z)
	var aim := target_near(p).global_position
	var target := Vector2(aim.x, aim.z)
	var dir := (target - me).normalized() if me.distance_to(target) > 0.1 else Vector2(0, 1)
	match str(a.type):
		"charge":
			# Rushes forward in a straight line (enraged: twice).
			_start_charge(i, a, warn, dmg, 1 if boss_style() >= 3 else 0)
		"leap":
			# Jumps high and lands on where the player stood.
			var spot := _clamp_flat(target)
			attacks.circle(_ground(spot), float(a.radius), warn + 0.55, color)
			_boss_hold = warn
			_pending_dash = {"from": me, "to": spot, "t": 0.0, "duration": 0.55, "arc": 7.0, "damage": dmg, "hit": false,
				"land": {"type": "circle", "center": spot, "radius": float(a.radius)}}
		"slam":
			# Smashes the ground all around itself (angrier: bigger).
			var r := float(a.radius) * (1.0 + 0.15 * extra)
			attacks.circle(_ground(me), r, warn, color)
			_boss_hold = warn + 0.3
			_strikes.append({"time": warn, "damage": dmg, "shapes": [{"type": "circle", "center": me, "radius": r}]})
		"meteor":
			# Rocks (or eggs) fall from the sky: one on the player, more around.
			var shapes: Array = []
			for n in int(a.count) + extra * 3:
				var spot := target if n == 0 else target + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(2.0, float(a.spread) * (1.0 + 0.2 * extra))
				spot = _clamp_flat(spot)
				shapes.append({"type": "circle", "center": spot, "radius": float(a.radius)})
				attacks.circle(_ground(spot), float(a.radius), warn, color, true)
			_boss_hold = 0.6
			_strikes.append({"time": warn, "damage": dmg, "shapes": shapes})
		"web", "webring":
			# A fan of web lines shoots out towards the player (webring: all around).
			var shapes: Array = []
			var count := int(a.count) + extra * 2
			var around := str(a.type) == "webring"
			var spread := TAU / count if around else deg_to_rad(float(a.spreadDegrees))
			var turn := _rng.randf() * spread if around else 0.0
			for n in count:
				var angle := turn + (n * spread if around else (n - (count - 1) * 0.5) * spread)
				var end := _clamp_flat(me + dir.rotated(angle) * float(a.length))
				shapes.append({"type": "line", "from": me, "to": end, "width": float(a.width)})
				attacks.line(_ground(me), _ground(end), float(a.width), warn, color)
			_boss_hold = warn
			_strikes.append({"time": warn, "damage": dmg, "shapes": shapes})
		"cross":
			# Beams in a + shape (enraged: a star of 8), turned a half step
			# every time so the safe spots move.
			var count := int(a.count) * (2 if boss_style() >= 3 else 1)
			var offset := (PI / count) * (_boss_next % 2) + atan2(dir.y, dir.x)
			var shapes: Array = []
			for n in count:
				var end := _clamp_flat(me + Vector2.from_angle(offset + TAU * n / count) * float(a.length))
				shapes.append({"type": "line", "from": me, "to": end, "width": float(a.width)})
				attacks.line(_ground(me), _ground(end), float(a.width), warn, color)
			_boss_hold = warn
			_strikes.append({"time": warn, "damage": dmg, "shapes": shapes})
		"quake":
			# A crack runs from the boss towards the player, one blast after another.
			var count := int(a.count) + extra * 2
			for n in count:
				var spot := _clamp_flat(me + dir * (float(a.start) + n * float(a.spacing)))
				var t := warn + n * float(a.delay) / tempo
				attacks.circle(_ground(spot), float(a.radius), t, color)
				_strikes.append({"time": t, "damage": dmg, "shapes": [{"type": "circle", "center": spot, "radius": float(a.radius)}]})
			_boss_hold = warn + 0.3
		"nova":
			# Shockwave rings spread out from the boss one after another;
			# stand between them.
			var rings := int(a.count) + extra
			for n in rings:
				var inner := float(a.start) + n * float(a.step)
				var outer := inner + float(a.width)
				var t := warn + n * float(a.delay) / tempo
				attacks.ring(_ground(me), inner, outer, t, color)
				_strikes.append({"time": t, "damage": dmg, "shapes": [{"type": "ring", "center": me, "inner": inner, "outer": outer}]})
			_boss_hold = warn + 0.2


func _start_charge(i: int, a: Dictionary, warn: float, dmg: float, chain: int) -> void:
	var p := _pos[i]
	var me := Vector2(p.x, p.z)
	var aim := target_near(p).global_position
	var target := Vector2(aim.x, aim.z)
	var dir := (target - me).normalized() if me.distance_to(target) > 0.1 else Vector2(0, 1)
	var end := _clamp_flat(me + dir * float(a.length))
	attacks.line(_ground(me), _ground(end), float(a.width), warn, Color(str(a.get("color", "#ff2b2b"))))
	_boss_hold = warn
	_pending_dash = {"from": me, "to": end, "t": 0.0, "duration": me.distance_to(end) / float(a.speed), "arc": 0.0, "damage": dmg, "hit": false,
		"chain": chain, "attack": a}


## Attacks whose warning ran out hit the player if they are still inside.
func _update_strikes(delta: float) -> void:
	var i := 0
	while i < _strikes.size():
		var s: Dictionary = _strikes[i]
		s.time = float(s.time) - delta
		if float(s.time) <= 0.0:
			_damage_if_inside(s.shapes, float(s.damage))
			_strikes.remove_at(i)
		else:
			i += 1


## Hits every player standing in any of the shapes (once each).
func _damage_if_inside(shapes: Array, amount: float) -> bool:
	var any := false
	for t: Node3D in alive_targets():
		if _hit_if_inside(t, shapes, amount):
			any = true
	return any


func _hit_if_inside(t: Node3D, shapes: Array, amount: float) -> bool:
	var at := Vector2(t.global_position.x, t.global_position.z)
	for shape: Dictionary in shapes:
		var inside := false
		if shape.type == "circle":
			inside = at.distance_to(shape.center) <= float(shape.radius) + 0.3
		elif shape.type == "ring":
			var d := at.distance_to(shape.center)
			inside = d >= float(shape.inner) - 0.3 and d <= float(shape.outer) + 0.3
		else:
			var a: Vector2 = shape.from
			var b: Vector2 = shape.to
			var closest := Geometry2D.get_closest_point_to_segment(at, a, b)
			inside = at.distance_to(closest) <= float(shape.width) * 0.5 + 0.3
		if inside:
			boss_attack_hits += 1
			t.call("take_damage", amount)
			return true
	return false


func _ground(flat: Vector2) -> Vector3:
	return Vector3(flat.x, terrain.height_at(flat.x, flat.y), flat.y)


func _clamp_flat(v: Vector2) -> Vector2:
	return Vector2(clampf(v.x, -_bounds, _bounds), clampf(v.y, -_bounds, _bounds))


func _throw(from: Vector3, dir: Vector3, speed: float, dmg: float) -> void:
	if _shot_pos.size() >= MAX_SHOTS:
		return
	_shot_pos.append(from)
	_shot_vel.append(dir.normalized() * speed)
	_shot_life.append(3.0)
	_shot_damage.append(dmg)
	shots_fired += 1


func _update_shots(delta: float) -> void:
	var alive := alive_targets()
	var i := 0
	while i < _shot_pos.size():
		_shot_pos[i] += _shot_vel[i] * delta
		_shot_life[i] -= delta
		var hit := false
		for t: Node3D in alive:
			if _shot_pos[i].distance_squared_to(t.global_position + Vector3.UP * 0.9) < 0.75 * 0.75:
				hit = true
				t.call("take_damage", _shot_damage[i])
				break
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
		if _kinds[k].id in ["slime", "king_slime", "snow_slime"]:
			# Squash-and-stretch bounce reads as a hopping slime.
			scale_v = Vector3(1.0 + 0.12 * (1.0 - bounce), 0.85 + 0.3 * bounce, 1.0 + 0.12 * (1.0 - bounce))
			lift = float(_kinds[k].radius) * 0.6 + bounce * 0.35
		else:
			scale_v = Vector3.ONE * float(_kinds[k].get("scale", 1.0))
			lift = bounce * 0.08
		if _flash[i] > 0.0:
			# Squashed flat for a moment when hit.
			scale_v *= Vector3(1.2, 0.75, 1.2)
		if _kinds[k].get("hidden", false):
			scale_v = Vector3.ONE * 0.001
		var xf_basis := Basis(Vector3.UP, _yaw[i]).scaled(scale_v)
		var slot := counts[k]
		counts[k] = slot + 1
		_mms[k].set_instance_transform(slot, Transform3D(xf_basis, _pos[i] + Vector3.UP * lift))
		var tint := Color.WHITE
		if _boss_phase > 1 and _kinds[k].get("boss", false):
			# Angry bosses glow red, enraged ones pulse.
			var pulse := 0.5 + 0.5 * sin(run_time * 8.0)
			tint = Color(1.25, 0.85, 0.8) if _boss_phase == 2 else Color(1.4 + 0.3 * pulse, 0.6, 0.55)
		_mms[k].set_instance_color(slot, FLASH_COLOR if _flash[i] > 0.0 else tint)
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


## Indices of every enemy within `radius` of `from` (ground distance).
func in_range(from: Vector3, radius: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in _pos.size():
		var d := Vector2(_pos[i].x - from.x, _pos[i].z - from.z)
		var r := radius + float(_kinds[_kind[i]].radius)
		if d.length_squared() < r * r:
			out.append(i)
	return out


func uid_of(index: int) -> int:
	return _uid[index]


## Current index of the enemy with this uid, or -1 if it is gone.
func index_of_uid(uid: int) -> int:
	return _uid.find(uid)


func radius_of(index: int) -> float:
	return float(_kinds[_kind[index]].radius)


## Index of the living boss, or -1.
func boss_index() -> int:
	for i in _kind.size():
		if _kinds[_kind[i]].get("boss", false):
			return i
	return -1


func health_ratio(index: int) -> float:
	return clampf(_hp[index] / _max_hp[index], 0.0, 1.0)


## The data of the enemy's kind (data/enemies.json).
func kind_of(index: int) -> Dictionary:
	return _kinds[_kind[index]]


func kind_name(index: int) -> String:
	return str(_kinds[_kind[index]].name)


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
	if mirror:
		# The host decides; only flash here.
		_flash[index] = HIT_FLASH_TIME
		remote_hit.emit(_uid[index], amount, push_dir)
		return
	if world_fight != "" and _kinds[_kind[index]].get("boss", false):
		world_damage += minf(amount, _hp[index])
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
		_dead_uid = _uid[index]
		_remove(index)
		kills += 1
		# Ordinary enemies are plentiful, so each gives only a share (the
		# remainder is rolled, so small amounts still add up).
		var share := 1.0 if kd.get("boss", false) or kd.get("mini", false) else float(_spawn.get("rewardScale", 1.0))
		share *= float(difficulty.reward)
		enemy_killed.emit(where, _roll_amount(float(kd.xp) * share), _roll_amount(float(kd.get("gold", 0)) * share))
		if kd.get("boss", false):
			boss_defeated.emit(str(kd.name))
		elif kd.get("mini", false):
			mini_boss_defeated.emit(_dead_uid)


## Uid of the enemy spawned last.
func last_uid() -> int:
	return _next_uid - 1


## Takes the enemy with this uid away without rewards.
func remove_uid(uid: int) -> void:
	var i := index_of_uid(uid)
	if i >= 0:
		_remove(i)


## Ordinary enemies within `radius` of `at` leave without rewards.
func clear_near(at: Vector3, radius: float) -> void:
	for i in range(_pos.size() - 1, -1, -1):
		var kd: Dictionary = _kinds[_kind[i]]
		if not kd.get("boss", false) and not kd.get("mini", false) and Vector2(_pos[i].x - at.x, _pos[i].z - at.z).length() < radius:
			_remove(i)


func _remove(index: int) -> void:
	# Swap with the last enemy so removal is O(1).
	var last := _pos.size() - 1
	_kind[index] = _kind[last]
	_uid[index] = _uid[last]
	_max_hp[index] = _max_hp[last]
	_pos[index] = _pos[last]
	_hp[index] = _hp[last]
	_flash[index] = _flash[last]
	_phase[index] = _phase[last]
	_yaw[index] = _yaw[last]
	_cool[index] = _cool[last]
	_kind.resize(last)
	_uid.resize(last)
	_max_hp.resize(last)
	_pos.resize(last)
	_hp.resize(last)
	_flash.resize(last)
	_phase.resize(last)
	_yaw.resize(last)
	_cool.resize(last)


# --- Co-op ------------------------------------------------------------------

## Values per enemy in a snapshot: uid, kind, x, y, z (cm/5), yaw, health ‰, flash.
const SNAP_STRIDE := 8
const SNAP_SCALE := 20.0

## What partners need to show the host's enemies (sent about 10 times a second).
func snapshot() -> Dictionary:
	var e := PackedInt32Array()
	for i in _pos.size():
		e.append_array([_uid[i], _kind[i], roundi(_pos[i].x * SNAP_SCALE), roundi(_pos[i].y * SNAP_SCALE),
			roundi(_pos[i].z * SNAP_SCALE), roundi(wrapf(_yaw[i], -PI, PI) * 100.0),
			roundi(clampf(_hp[i] / _max_hp[i], 0.0, 1.0) * 1000.0), 1 if _flash[i] > 0.0 else 0])
	var shots := PackedInt32Array()
	for i in _shot_pos.size():
		shots.append_array([roundi(_shot_pos[i].x * SNAP_SCALE), roundi(_shot_pos[i].y * SNAP_SCALE), roundi(_shot_pos[i].z * SNAP_SCALE),
			roundi(_shot_vel[i].x * SNAP_SCALE), roundi(_shot_vel[i].y * SNAP_SCALE), roundi(_shot_vel[i].z * SNAP_SCALE)])
	return {"e": Array(e), "s": Array(shots), "t": snappedf(run_time, 0.01), "k": kills, "bp": _boss_phase}


## Mirror: takes the host's latest snapshot. Enemies glide to their new spots.
func apply_snapshot(d: Dictionary) -> void:
	var known := {}
	for i in _uid.size():
		known[_uid[i]] = i
	var e: Array = d.get("e", [])
	var n := e.size() / SNAP_STRIDE
	var kind := PackedInt32Array()
	var uid := PackedInt32Array()
	var pos := PackedVector3Array()
	var goal := PackedVector3Array()
	var hp := PackedFloat32Array()
	var flash := PackedFloat32Array()
	var phase := PackedFloat32Array()
	var yaw := PackedFloat32Array()
	var goal_yaw := PackedFloat32Array()
	for j in n:
		var o := j * SNAP_STRIDE
		var k := int(e[o + 1])
		if k < 0 or k >= _kinds.size():
			continue
		var id := int(e[o])
		var at := Vector3(float(e[o + 2]), float(e[o + 3]), float(e[o + 4])) / SNAP_SCALE
		var old: int = known.get(id, -1)
		kind.append(k)
		uid.append(id)
		goal.append(at)
		goal_yaw.append(float(e[o + 5]) / 100.0)
		hp.append(float(e[o + 6]) / 1000.0)
		if old >= 0:
			pos.append(_pos[old])
			yaw.append(_yaw[old])
			phase.append(_phase[old])
			flash.append(maxf(_flash[old], HIT_FLASH_TIME if int(e[o + 7]) == 1 else 0.0))
		else:
			pos.append(at)
			yaw.append(float(e[o + 5]) / 100.0)
			phase.append(_rng.randf() * TAU)
			flash.append(0.0)
	_kind = kind
	_uid = uid
	_pos = pos
	_goal = goal
	_hp = hp
	_max_hp = PackedFloat32Array()
	_max_hp.resize(hp.size())
	_max_hp.fill(1.0)
	_flash = flash
	_phase = phase
	_yaw = yaw
	_goal_yaw = goal_yaw
	_cool = PackedFloat32Array()
	_cool.resize(hp.size())

	var s: Array = d.get("s", [])
	_shot_pos.clear()
	_shot_vel.clear()
	_shot_life.clear()
	_shot_damage.clear()
	for j in mini(s.size() / 6, MAX_SHOTS):
		var o := j * 6
		_shot_pos.append(Vector3(float(s[o]), float(s[o + 1]), float(s[o + 2])) / SNAP_SCALE)
		_shot_vel.append(Vector3(float(s[o + 3]), float(s[o + 4]), float(s[o + 5])) / SNAP_SCALE)
		_shot_life.append(1.0)
		_shot_damage.append(0.0)
	run_time = float(d.get("t", run_time))
	kills = int(d.get("k", kills))
	_boss_phase = int(d.get("bp", 1))


## Duel: the opponent is one invisible target that follows their character,
## so weapons aim at them like at an enemy (hits go out through `remote_hit`).
func set_duelist(at: Vector3, yaw: float, ratio: float) -> void:
	var kind := -1
	for i in _kinds.size():
		if str(_kinds[i].id) == "duelist":
			kind = i
	if kind < 0:
		return
	apply_snapshot({"e": [DUELIST_UID, kind, roundi(at.x * SNAP_SCALE), roundi(at.y * SNAP_SCALE), roundi(at.z * SNAP_SCALE),
		roundi(wrapf(yaw, -PI, PI) * 100.0), roundi(clampf(ratio, 0.0, 1.0) * 1000.0), 0]})


func _update_mirror(delta: float) -> void:
	run_time += delta
	var follow := minf(1.0, delta * 12.0)
	for i in _pos.size():
		var before := _pos[i]
		_pos[i] = before.lerp(_goal[i], follow)
		_yaw[i] = lerp_angle(_yaw[i], _goal_yaw[i], follow)
		_flash[i] = maxf(0.0, _flash[i] - delta)
		_phase[i] += delta * 6.0 + before.distance_to(_pos[i]) * 1.5
	for i in _shot_pos.size():
		_shot_pos[i] += _shot_vel[i] * delta
