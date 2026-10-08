## Extra weapons picked on level-up (the bow is always equipped). Each weapon has
## a level from 1 to maxLevel (data/weapons.json). They share the bow's damage,
## crit and attack-speed stats, and their areas grow with the range stat.
extends Node3D

const Config := preload("res://scripts/core/config.gd")
const Toon := preload("res://scripts/core/toon.gd")
const Terrain := preload("res://scripts/world/terrain.gd")
const EnemyManager := preload("res://scripts/enemies/enemy_manager.gd")
const AutoBow := preload("res://scripts/combat/auto_bow.gd")
const RangeRing := preload("res://scripts/combat/range_ring.gd")

## Same as the bow's signal, for damage numbers.
signal hit_landed(at_position: Vector3, amount: float, crit: bool)

const MAX_BLADES := 8
const MAX_FIREBALLS := 32

var player: CharacterBody3D
var enemies: EnemyManager
var bow: AutoBow
var terrain: Terrain
var active := false
var defs: Array = []
## Weapon slots including the bow.
var slots := 4
## Weapon id -> level (only weapons picked this run).
var levels := {}
## Weapon id -> total damage dealt this run.
var damage_dealt := {}

var _timers := {}
var _orbit_angle := 0.0
var _orbit_count := 0
var _orbit_radius := 0.0
## Enemy uid -> time it was last hit by a blade.
var _orbit_hits := {}
var _time := 0.0
var _blades: MultiMesh
var _fb_pos := PackedVector3Array()
var _fb_vel := PackedVector3Array()
var _fb_life := PackedFloat32Array()
var _fb_mm: MultiMesh
var _aura_ring: RangeRing
var _rng := RandomNumberGenerator.new()


func setup(p_player: CharacterBody3D, p_enemies: EnemyManager, p_bow: AutoBow, p_terrain: Terrain) -> void:
	player = p_player
	enemies = p_enemies
	bow = p_bow
	terrain = p_terrain
	var cfg := Config.load_json("res://data/weapons.json")
	defs = cfg.extra
	slots = int(cfg.slots)

	var blade := BoxMesh.new()
	blade.size = Vector3(1.0, 0.06, 0.16)
	_blades = _multimesh(blade, MAX_BLADES, Color("#dfe8f2"), Color("#9fc3ff"))

	var ball := SphereMesh.new()
	ball.radius = 0.3
	ball.height = 0.6
	ball.radial_segments = 8
	ball.rings = 4
	_fb_mm = _multimesh(ball, MAX_FIREBALLS, Color("#ffb347"), Color("#ff5a1f"))

	_aura_ring = RangeRing.new()
	_aura_ring.terrain = terrain
	_aura_ring.target = player
	_aura_ring.color = Color(1.0, 0.82, 0.25, 0.3)
	_aura_ring.width = 0.3
	_aura_ring.visible = false
	add_child(_aura_ring)


func reset() -> void:
	levels.clear()
	damage_dealt.clear()
	_timers.clear()
	_orbit_hits.clear()
	_orbit_count = 0
	_fb_pos.clear()
	_fb_vel.clear()
	_fb_life.clear()
	_aura_ring.visible = false


func def(id: String) -> Dictionary:
	for d: Dictionary in defs:
		if d.id == id:
			return d
	return {}


func level(id: String) -> int:
	return int(levels.get(id, 0))


## Weapons picked this run as [def, level] pairs.
func owned() -> Array:
	var out: Array = []
	for d: Dictionary in defs:
		if level(d.id) > 0:
			out.append([d, level(d.id)])
	return out


## Weapons that can be offered on level-up: new ones while a slot is free,
## and upgrades of owned ones below max level.
func available_choices() -> Array:
	var free_slot := levels.size() + 1 < slots
	var out: Array = []
	for d: Dictionary in defs:
		var lv := level(d.id)
		if (lv == 0 and free_slot) or (lv > 0 and lv < int(d.maxLevel)):
			out.append(d)
	return out


func add(id: String) -> void:
	if def(id).is_empty():
		return
	levels[id] = level(id) + 1
	_aura_ring.visible = levels.has("aura")


func _physics_process(delta: float) -> void:
	if not active:
		return
	_time += delta
	for id: String in levels:
		var d := def(id)
		match id:
			"orbit":
				_update_orbit(delta, d, level(id))
			"fireball":
				_update_fireball(delta, d, level(id))
			"lightning":
				_update_lightning(delta, d, level(id))
			"aura":
				_update_aura(delta, d, level(id))
	_update_fireballs(delta)


## Damage of one hit of weapon `d` at level `lv`, before stats and crits.
func _base_damage(d: Dictionary, lv: int) -> float:
	return float(d.damage) * (1.0 + float(d.damagePerLevel) * (lv - 1))


func _area() -> float:
	return 1.0 + bow.range_bonus * 0.1


## Counts down the weapon's timer; true when it should fire again.
func _ready_to_fire(id: String, delta: float, cooldown: float) -> bool:
	var t := float(_timers.get(id, 0.0)) - delta
	if t <= 0.0:
		_timers[id] = cooldown / bow.attack_speed_multiplier
		return true
	_timers[id] = t
	return false


func _hit(index: int, base: float, push_dir: Vector3, id: String, show_number := true) -> void:
	var crit := _rng.randf() < bow.crit_chance
	var dmg := base * bow.damage_multiplier * (bow.crit_multiplier if crit else 1.0)
	damage_dealt[id] = float(damage_dealt.get(id, 0.0)) + dmg
	if show_number:
		hit_landed.emit(enemies.position_of(index), dmg, crit)
	enemies.damage(index, dmg, push_dir)


## Hits every enemy in `hits`. Highest index first: a kill swaps the last
## enemy into the freed slot, which never disturbs lower indices.
func _hit_all(hits: PackedInt32Array, base: float, center: Vector3, id: String, show_number: bool) -> void:
	for n in range(hits.size() - 1, -1, -1):
		var i := hits[n]
		var push := enemies.position_of(i) - center
		push.y = 0.0
		_hit(i, base, push.normalized(), id, show_number)


func _update_orbit(delta: float, d: Dictionary, lv: int) -> void:
	_orbit_count = mini(int(d.count) + int(d.countPerLevel) * (lv - 1), MAX_BLADES)
	_orbit_radius = float(d.radius) * _area()
	_orbit_angle = fmod(_orbit_angle + float(d.spin) * bow.attack_speed_multiplier * delta, TAU)
	var center := player.global_position
	var cooldown := float(d.hitCooldown)
	for n in _orbit_count:
		var a := _orbit_angle + TAU * n / _orbit_count
		var tip := center + Vector3(cos(a), 0.0, sin(a)) * _orbit_radius
		# One hit per blade per frame keeps the enemy indices valid.
		for i in enemies.in_range(tip, 0.6):
			var uid := enemies.uid_of(i)
			if _time - float(_orbit_hits.get(uid, -100.0)) < cooldown:
				continue
			_orbit_hits[uid] = _time
			_hit(i, _base_damage(d, lv), Vector3(-sin(a), 0.0, cos(a)), "orbit")
			break
	if _orbit_hits.size() > 200:
		for uid: int in _orbit_hits.keys():
			if _time - float(_orbit_hits[uid]) > cooldown:
				_orbit_hits.erase(uid)


func _update_fireball(delta: float, d: Dictionary, _lv: int) -> void:
	if not _ready_to_fire("fireball", delta, float(d.cooldown)):
		return
	var origin := player.global_position + Vector3.UP * 1.2
	var target := enemies.nearest(origin, float(d.range) + bow.range_bonus)
	if target < 0 or _fb_pos.size() >= MAX_FIREBALLS:
		_timers["fireball"] = 0.2
		return
	_fb_pos.append(origin)
	_fb_vel.append((enemies.position_of(target) - origin).normalized() * float(d.speed))
	_fb_life.append(2.0)


func _update_fireballs(delta: float) -> void:
	var d := def("fireball")
	var lv := level("fireball")
	var i := 0
	while i < _fb_pos.size():
		_fb_pos[i] += _fb_vel[i] * delta
		_fb_life[i] -= delta
		var hit := enemies.hit_test(_fb_pos[i], 0.3)
		if hit >= 0:
			var blast := (float(d.blast) + float(d.blastPerLevel) * (lv - 1)) * _area()
			var at := _fb_pos[i]
			_hit_all(enemies.in_range(at, blast), _base_damage(d, lv), at, "fireball", true)
			_flash(_sphere_mesh(blast), at, Color(1.0, 0.45, 0.1, 0.55), 0.35)
		if hit >= 0 or _fb_life[i] <= 0.0:
			var last := _fb_pos.size() - 1
			_fb_pos[i] = _fb_pos[last]
			_fb_vel[i] = _fb_vel[last]
			_fb_life[i] = _fb_life[last]
			_fb_pos.resize(last)
			_fb_vel.resize(last)
			_fb_life.resize(last)
		else:
			i += 1


func _update_lightning(delta: float, d: Dictionary, lv: int) -> void:
	if not _ready_to_fire("lightning", delta, float(d.cooldown)):
		return
	var near := Array(enemies.in_range(player.global_position, float(d.range) + bow.range_bonus))
	if near.is_empty():
		_timers["lightning"] = 0.2
		return
	near.shuffle()
	var picks := near.slice(0, int(d.strikes) + int(d.strikesPerLevel) * (lv - 1))
	picks.sort()
	picks.reverse()
	for i: int in picks:
		var at := enemies.position_of(i)
		var bolt := BoxMesh.new()
		bolt.size = Vector3(0.25, 14.0, 0.25)
		_flash(bolt, at + Vector3.UP * 7.0, Color(0.7, 0.9, 1.0, 0.9), 0.18)
		_hit(i, _base_damage(d, lv), Vector3.ZERO, "lightning")


func _update_aura(delta: float, d: Dictionary, lv: int) -> void:
	var radius := (float(d.radius) + float(d.radiusPerLevel) * (lv - 1)) * _area()
	_aura_ring.radius = radius
	if not _ready_to_fire("aura", delta, float(d.tick)):
		return
	var center := player.global_position
	_hit_all(enemies.in_range(center, radius), _base_damage(d, lv), center, "aura", false)


func _process(_delta: float) -> void:
	var blades := _orbit_count if active and levels.has("orbit") else 0
	_blades.visible_instance_count = blades
	var center := player.global_position + Vector3.UP * 0.9 if player else Vector3.ZERO
	for n in blades:
		var a := _orbit_angle + TAU * n / blades
		var at := center + Vector3(cos(a), 0.0, sin(a)) * _orbit_radius
		# Long axis points away from the player.
		_blades.set_instance_transform(n, Transform3D(Basis(Vector3.UP, -a), at))
	var balls := _fb_pos.size()
	_fb_mm.visible_instance_count = balls
	for i in balls:
		_fb_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, _fb_pos[i]))


## A short-lived glowing shape (explosions, lightning bolts) that fades out.
func _flash(mesh: Mesh, at: Vector3, color: Color, duration: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	var fx := MeshInstance3D.new()
	fx.mesh = mesh
	fx.material_override = mat
	fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fx)
	fx.global_position = at
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, duration)
	tween.tween_callback(fx.queue_free)


func _sphere_mesh(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 1.2
	m.radial_segments = 12
	m.rings = 6
	return m


func _multimesh(mesh: Mesh, count: int, color: Color, glow: Color) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	var mat := Toon.material(color)
	mat.emission_enabled = true
	mat.emission = glow
	instance.material_override = mat
	add_child(instance)
	return mm
