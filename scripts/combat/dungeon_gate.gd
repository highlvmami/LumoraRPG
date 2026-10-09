## Dungeon gates: now and then during a run a glowing stone gate opens near
## the player. Walking into it starts a short fight: a ring of rune stones
## closes around the gate (nobody gets out), ordinary monsters inside are
## pushed away and a mini boss with a few minions comes out. Beating it in
## time gives gold and a chest; when time runs out the guardian goes back
## in and the ring opens. A gate left alone closes after a while.
## Mini bosses are the "mini" kinds in data/enemies.json.
extends Node3D

const Toon := preload("res://scripts/core/toon.gd")
const Terrain := preload("res://scripts/world/terrain.gd")
const EnemyManager := preload("res://scripts/enemies/enemy_manager.gd")

## First gate after this many seconds, then one every INTERVAL.
const FIRST := 100.0
const INTERVAL := 150.0
## How long a gate waits for the player, and how long the fight may take.
const GATE_TIME := 40.0
const FIGHT_TIME := 60.0
const ARENA_RADIUS := 10.0
const ENTER_RADIUS := 1.8
const MINIONS := 6
const MINI_BOSSES := ["king_slime", "alpha_wolf", "goblin_chief"]

## The fight started (the guardian's name).
signal fight_started(guardian: String)
## The guardian was beaten: the game gives the reward.
signal cleared(guardian: String, count: int)
## Time ran out.
signal failed
## A gate appeared.
signal opened

var player: Node3D
var enemies: EnemyManager
var terrain: Terrain
var bounds := 60.0
var active := false
## "", "gate" (waiting for the player) or "fight".
var state := ""
var time_left := 0.0
## Gates beaten this run (each one gives a better reward).
var cleared_count := 0

var _next := FIRST
var _center := Vector3.ZERO
var _guardian_uid := -1
var _guardian_name := ""
var _gate: Node3D
var _arena: Node3D
var _walls: StaticBody3D
var _glow: MeshInstance3D
var _tag: Label3D
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func setup(p_player: Node3D, p_enemies: EnemyManager, p_terrain: Terrain, p_bounds: float) -> void:
	player = p_player
	enemies = p_enemies
	terrain = p_terrain
	bounds = p_bounds
	_rng.randomize()
	enemies.mini_boss_defeated.connect(_on_mini_defeated)
	_tag = Label3D.new()
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.fixed_size = true
	_tag.pixel_size = 0.0024
	_tag.font_size = 26
	_tag.outline_size = 8
	_tag.modulate = Color("#e0a8ff")
	_tag.visible = false
	add_child(_tag)


## A new run: no gate, the first one comes after FIRST seconds.
func reset() -> void:
	_close()
	state = ""
	cleared_count = 0
	_next = FIRST


## Opens a gate now (somewhere near the player).
func open_gate() -> void:
	_close()
	var a := _rng.randf() * TAU
	var d := _rng.randf_range(12.0, 16.0)
	var limit := bounds - ARENA_RADIUS - 2.0
	var x := clampf(player.global_position.x + cos(a) * d, -limit, limit)
	var z := clampf(player.global_position.z + sin(a) * d, -limit, limit)
	_center = Vector3(x, terrain.height_at(x, z), z)
	_build_gate()
	state = "gate"
	time_left = GATE_TIME
	opened.emit()


## Where the gate (and its arena) is.
func center() -> Vector3:
	return _center


func guardian_uid() -> int:
	return _guardian_uid


## Walks into the gate: the fight begins.
func start_fight() -> void:
	if state != "gate":
		return
	state = "fight"
	time_left = FIGHT_TIME
	if _gate:
		_gate.queue_free()
		_gate = null
	_build_arena()
	enemies.clear_near(_center, ARENA_RADIUS + 1.0)
	var id: String = MINI_BOSSES[cleared_count % MINI_BOSSES.size()]
	var at := _center + Vector3(0, 0, -3.0)
	if not enemies.spawn(id, at, true):
		_close()
		state = ""
		return
	_guardian_uid = enemies.last_uid()
	var index := enemies.index_of_uid(_guardian_uid)
	_guardian_name = enemies.kind_name(index)
	var minion := str(enemies.kind_of(index).get("minion", "slime"))
	for n in MINIONS:
		var a := TAU * n / MINIONS
		enemies.spawn(minion, _center + Vector3(cos(a), 0, sin(a)) * (ARENA_RADIUS - 2.0), true)
	_tag.text = _guardian_name
	_tag.visible = true
	fight_started.emit(_guardian_name)


func _physics_process(delta: float) -> void:
	_time += delta
	if not active:
		return
	match state:
		"":
			_next -= delta
			# No gate during a boss fight.
			if _next <= 0.0 and enemies.boss_index() < 0:
				_next = INTERVAL
				open_gate()
		"gate":
			time_left -= delta
			if time_left <= 0.0 or enemies.boss_index() >= 0:
				_close()
				state = ""
			elif Vector2(player.global_position.x - _center.x, player.global_position.z - _center.z).length() < ENTER_RADIUS:
				start_fight()
		"fight":
			time_left -= delta
			var index := enemies.index_of_uid(_guardian_uid)
			if index >= 0:
				_tag.global_position = enemies.position_of(index) + Vector3.UP * 2.6
				_tag.text = "%s  ·  %d sn" % [_guardian_name, ceili(time_left)]
			if time_left <= 0.0 or index < 0 or enemies.boss_index() >= 0:
				# Ran out of time (or a boss arrived and sent everyone away).
				enemies.remove_uid(_guardian_uid)
				_close()
				state = ""
				failed.emit()


func _process(_delta: float) -> void:
	if _gate:
		if _glow:
			_glow.scale = Vector3.ONE * (1.0 + sin(_time * 3.0) * 0.06)
			(_glow.material_override as StandardMaterial3D).emission_energy_multiplier = 1.6 + sin(_time * 4.0) * 0.5
	if _arena:
		_arena.rotation.y = _time * 0.15


func _on_mini_defeated(uid: int) -> void:
	if state != "fight" or uid != _guardian_uid:
		return
	cleared_count += 1
	var guardian := _guardian_name
	_close()
	state = ""
	cleared.emit(guardian, cleared_count)


func _close() -> void:
	if _gate:
		_gate.queue_free()
		_gate = null
	if _arena:
		_arena.queue_free()
		_arena = null
	if _walls:
		_walls.queue_free()
		_walls = null
	_glow = null
	_guardian_uid = -1
	if _tag:
		_tag.visible = false


# --- Looks ----------------------------------------------------------------------

## A stone arch with a swirling purple portal and a light.
func _build_gate() -> void:
	_gate = Node3D.new()
	_gate.position = _center
	_gate.rotation.y = atan2(player.global_position.x - _center.x, player.global_position.z - _center.z)
	add_child(_gate)
	var stone := Color("#5a5560")
	for side in [-1.0, 1.0]:
		_box(Vector3(0.8, 3.6, 0.8), Vector3(side * 1.5, 1.8, 0), stone, _gate)
		_box(Vector3(1.0, 0.3, 1.0), Vector3(side * 1.5, 0.15, 0), stone.darkened(0.2), _gate)
	_box(Vector3(4.0, 0.7, 0.9), Vector3(0, 3.85, 0), stone, _gate)
	_box(Vector3(0.6, 0.5, 0.95), Vector3(0, 4.3, 0), Color("#b06ad6"), _gate, Color("#8a3aff"))
	_glow = _box(Vector3(2.2, 3.2, 0.12), Vector3(0, 1.7, 0), Color("#6a2aaa"), _gate, Color("#b06aff"))
	var mat := _glow.material_override as StandardMaterial3D
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.5, 0.2, 0.9, 0.8)
	var light := OmniLight3D.new()
	light.light_color = Color("#b06aff")
	light.light_energy = 2.0
	light.omni_range = 8.0
	light.position = Vector3(0, 2.0, 1.0)
	_gate.add_child(light)
	var sparks := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	spark_mat.albedo_color = Color("#e0a8ff")
	quad.material = spark_mat
	sparks.mesh = quad
	sparks.amount = 24
	sparks.lifetime = 1.6
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sparks.emission_box_extents = Vector3(1.0, 1.5, 0.1)
	sparks.direction = Vector3.UP
	sparks.gravity = Vector3(0, 0.8, 0)
	sparks.initial_velocity_min = 0.2
	sparks.initial_velocity_max = 0.6
	sparks.position = Vector3(0, 1.7, 0)
	_gate.add_child(sparks)


## The ring of rune stones around the fight, with walls nobody can pass.
func _build_arena() -> void:
	_arena = Node3D.new()
	_arena.position = _center
	add_child(_arena)
	var count := 16
	for n in count:
		var a := TAU * n / count
		var at := Vector3(cos(a), 0, sin(a)) * ARENA_RADIUS
		var h := 2.0 + float(n % 3) * 0.5
		var pillar := _box(Vector3(0.7, h, 0.7), at + Vector3(0, h * 0.5 - 0.2, 0), Color("#4a4550"), _arena)
		pillar.rotation.y = -a
		_box(Vector3(0.74, 0.3, 0.74), at + Vector3(0, h * 0.6, 0), Color("#8a3aff"), _arena, Color("#b06aff"))
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = ARENA_RADIUS - 0.25
	torus.outer_radius = ARENA_RADIUS + 0.25
	torus.rings = 48
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.7, 0.4, 1.0, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	ring.scale = Vector3(1, 0.3, 1)
	ring.position = Vector3(0, 0.15, 0)
	_arena.add_child(ring)
	var light := OmniLight3D.new()
	light.light_color = Color("#b06aff")
	light.light_energy = 1.2
	light.omni_range = ARENA_RADIUS + 4.0
	light.position = Vector3(0, 4.0, 0)
	_arena.add_child(light)
	# Walls: a ring of boxes just inside the stones.
	_walls = StaticBody3D.new()
	_walls.position = _center
	add_child(_walls)
	var segs := 32
	for n in segs:
		var a := TAU * (n + 0.5) / segs
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.5, 6.0, TAU * ARENA_RADIUS / segs + 0.3)
		shape.shape = box
		shape.position = Vector3(cos(a), 0, sin(a)) * (ARENA_RADIUS - 0.4) + Vector3(0, 2.0, 0)
		shape.rotation.y = -a
		_walls.add_child(shape)


func _box(box_size: Vector3, pos: Vector3, color: Color, parent: Node3D, glow := Color.BLACK) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var mat := Toon.material(color)
	if glow != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = glow
		mat.emission_energy_multiplier = 1.5
	instance.material_override = mat
	instance.position = pos
	parent.add_child(instance)
	return instance
