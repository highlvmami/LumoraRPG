## Every weapon except the archer's bow: the warrior's sword swing and the
## mage's magic orb (class starter weapons) plus the extras picked on level-up.
## Each weapon has a level from 1 to maxLevel (data/weapons.json). They share
## the bow's damage, crit and attack-speed stats, and areas grow with range.
extends Node3D

const Config := preload("res://scripts/core/config.gd")
const Toon := preload("res://scripts/core/toon.gd")
const Terrain := preload("res://scripts/world/terrain.gd")
const EnemyManager := preload("res://scripts/enemies/enemy_manager.gd")
const AutoBow := preload("res://scripts/combat/auto_bow.gd")
const RangeRing := preload("res://scripts/combat/range_ring.gd")

## Same as the bow's signal, for damage numbers.
signal hit_landed(at_position: Vector3, amount: float, crit: bool)
## A starter weapon attacked in this direction (plays the character animation).
signal attacked(direction: Vector3)

const MAX_BLADES := 8
const MAX_FIREBALLS := 32

## Lightning bolt look: height, zigzag pieces and how long each piece takes to appear.
const BOLT_HEIGHT := 14.0
const BOLT_STEPS := 8
const BOLT_STEP_TIME := 0.05
## Height arrows and meteors fall from.
const SKY_HEIGHT := 10.0

var player: CharacterBody3D
var enemies: EnemyManager
var bow: AutoBow
var terrain: Terrain
var active := false
var defs: Array = []
## Weapon evolutions (data/weapons.json "evolutions"): a maxed weapon plus a
## certain boost turns into a super weapon.
var evolutions: Array = []
## Evolved weapons this run: weapon id -> its evolved def (numbers already
## raised, name, icon and color of the evolution).
var evolved := {}
## Weapon slots including the starter weapon (or the bow).
var slots := 4
## True when the bow (outside this node) takes the first slot.
var uses_bow := true
## Class of the character; class-only weapons are offered only to it.
var class_id := ""
## Chance that the class weapon attacks again right away (class boosts).
var double_chance := 0.0
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
## 0 = fireball (explodes), 1 = magic orb (single target).
var _fb_kind := PackedInt32Array()
var _fb_mm: MultiMesh
var _orb_mm: MultiMesh
var _aura_ring: RangeRing
var _rng := RandomNumberGenerator.new()


func setup(p_player: CharacterBody3D, p_enemies: EnemyManager, p_bow: AutoBow, p_terrain: Terrain) -> void:
	player = p_player
	enemies = p_enemies
	bow = p_bow
	terrain = p_terrain
	var cfg := Config.load_json("res://data/weapons.json")
	defs = cfg.extra
	evolutions = cfg.get("evolutions", [])
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
	var orb := SphereMesh.new()
	orb.radius = 0.22
	orb.height = 0.44
	orb.radial_segments = 8
	orb.rings = 4
	_orb_mm = _multimesh(orb, MAX_FIREBALLS, Color("#d8b8ff"), Color("#8a4dff"))

	_aura_ring = RangeRing.new()
	_aura_ring.terrain = terrain
	_aura_ring.target = player
	_aura_ring.color = Color(1.0, 0.82, 0.25, 0.3)
	_aura_ring.width = 0.3
	_aura_ring.visible = false
	add_child(_aura_ring)


func reset() -> void:
	levels.clear()
	evolved.clear()
	damage_dealt.clear()
	_timers.clear()
	_orbit_hits.clear()
	_orbit_count = 0
	_fb_pos.clear()
	_fb_vel.clear()
	_fb_life.clear()
	_fb_kind.clear()
	_aura_ring.visible = false


func def(id: String) -> Dictionary:
	if evolved.has(id):
		return evolved[id]
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
			out.append([def(d.id), level(d.id)])
	return out


## Weapons that can be offered on level-up: new ones while a slot is free,
## and upgrades of owned ones below max level. Class starter weapons are only
## ever upgraded, never offered as new.
func available_choices() -> Array:
	var free_slot := levels.size() + (1 if uses_bow else 0) < slots
	var out: Array = []
	for d: Dictionary in defs:
		if d.has("class") and str(d["class"]) != class_id:
			continue
		var lv := level(d.id)
		var is_new_ok: bool = free_slot and not d.get("starter", false)
		if (lv == 0 and is_new_ok) or (lv > 0 and lv < int(d.maxLevel)):
			out.append(d)
	return out


## Damage of one hit of an owned weapon with the current stats (no crit).
func hit_damage(id: String) -> float:
	return _base_damage(def(id), maxi(level(id), 1)) * bow.damage_multiplier


## Attacks per second of a weapon with the current attack speed.
func attacks_per_second(id: String) -> float:
	return bow.attack_speed_multiplier / float(def(id).cooldown)


## How far a weapon reaches (swing radius or shot range).
func reach(id: String) -> float:
	var d := def(id)
	var lv := maxi(level(id), 1)
	if d.has("radius"):
		return (float(d.radius) + float(d.get("radiusPerLevel", 0.0)) * (lv - 1)) * _area()
	return float(d.get("range", 0.0)) + bow.range_bonus


## Turns weapon `evo.weapon` into its evolution.
func evolve(evo: Dictionary) -> void:
	var id := str(evo.weapon)
	var base: Dictionary = def(id)
	if base.is_empty() or evolved.has(id):
		return
	evolved[id] = evolved_def(base, evo)


## A weapon's numbers after evolution `evo`: more damage, faster attacks,
## a bigger area and more blades or bolts, with the evolution's look.
static func evolved_def(base: Dictionary, evo: Dictionary) -> Dictionary:
	var d := base.duplicate()
	var speed := float(evo.get("speed", 1.0))
	var area := float(evo.get("area", 1.0))
	d.damage = float(base.damage) * float(evo.get("damage", 1.0))
	for key: String in ["cooldown", "tick", "hitCooldown"]:
		if d.has(key):
			d[key] = float(d[key]) / speed
	if d.has("spin"):
		d.spin = float(d.spin) * speed
	for key: String in ["radius", "blast", "arcDegrees"]:
		if d.has(key):
			d[key] = minf(float(d[key]) * area, 330.0) if key == "arcDegrees" else float(d[key]) * area
	for key: String in ["count", "strikes"]:
		if d.has(key):
			d[key] = int(d[key]) + int(evo.get("extraCount", 0))
	for key: String in ["name", "icon", "color", "desc"]:
		d[key] = evo[key]
	d.upgrade = str(evo.desc)
	d.evolved = true
	return d


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
			"slash":
				_update_slash(delta, d, level(id))
			"magic":
				_update_magic(delta, d, level(id))
			"orbit":
				_update_orbit(delta, d, level(id))
			"fireball":
				_update_fireball(delta, d, level(id))
			"lightning":
				_update_lightning(delta, d, level(id))
			"aura":
				_update_aura(delta, d, level(id))
			"arrow_rain", "meteor":
				_update_sky_strike(id, delta, d, level(id))
			"shield_bash":
				_update_shield_bash(delta, d, level(id))
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
	_launch(origin, enemies.position_of(target), float(d.speed), 0)


func _launch(origin: Vector3, at: Vector3, speed: float, kind: int) -> void:
	if _fb_pos.size() >= MAX_FIREBALLS:
		return
	_fb_pos.append(origin)
	_fb_vel.append((at - origin).normalized() * speed)
	_fb_life.append(2.0)
	_fb_kind.append(kind)


## Warrior: a wide swing toward the nearest enemy that hits everything in the arc.
func _update_slash(delta: float, d: Dictionary, lv: int) -> void:
	if not _ready_to_fire("slash", delta, float(d.cooldown)):
		return
	var radius := (float(d.radius) + float(d.radiusPerLevel) * (lv - 1)) * _area()
	var center := player.global_position
	var target := enemies.nearest(center, radius + 0.5)
	if target < 0:
		_timers["slash"] = 0.15
		return
	var dir := enemies.position_of(target) - center
	dir.y = 0.0
	dir = dir.normalized() if dir.length_squared() > 0.0001 else Vector3.BACK
	var min_dot := cos(deg_to_rad(float(d.arcDegrees)) * 0.5)
	var arc := PackedInt32Array()
	for i in enemies.in_range(center, radius):
		var to := enemies.position_of(i) - center
		to.y = 0.0
		if to.length() < 0.9 or to.normalized().dot(dir) >= min_dot:
			arc.append(i)
	_hit_all(arc, _base_damage(d, lv), center, "slash", true)
	attacked.emit(dir)
	if _rng.randf() < double_chance:
		_timers["slash"] = 0.18
	var swoosh := BoxMesh.new()
	swoosh.size = Vector3(radius * 1.7, 0.05, radius)
	var facing := Basis.looking_at(-dir, Vector3.UP)
	_flash(swoosh, center + dir * radius * 0.5 + Vector3.UP * 0.9, Color(1, 1, 1, 0.45), 0.15, facing)


## Mage: magic orbs at the nearest enemies (more orbs at higher levels).
func _update_magic(delta: float, d: Dictionary, lv: int) -> void:
	if not _ready_to_fire("magic", delta, float(d.cooldown)):
		return
	var origin := player.global_position + Vector3.UP * 1.4
	var reach := float(d.range) + bow.range_bonus
	var first := enemies.nearest(origin, reach)
	if first < 0:
		_timers["magic"] = 0.15
		return
	var shots := 1 + int(float(d.shotsPerLevel) * (lv - 1))
	var targets := [first]
	var others := Array(enemies.in_range(player.global_position, reach))
	others.shuffle()
	for i: int in others:
		if targets.size() >= shots:
			break
		if i != first:
			targets.append(i)
	for i: int in targets:
		_launch(origin, enemies.position_of(i), float(d.speed), 1)
	if _rng.randf() < double_chance:
		_timers["magic"] = 0.15
	var aim := enemies.position_of(first) - origin
	aim.y = 0.0
	attacked.emit(aim.normalized())


func _update_fireballs(delta: float) -> void:
	var d := def("fireball")
	var lv := level("fireball")
	var i := 0
	while i < _fb_pos.size():
		_fb_pos[i] += _fb_vel[i] * delta
		_fb_life[i] -= delta
		var hit := enemies.hit_test(_fb_pos[i], 0.3)
		if hit >= 0 and _fb_kind[i] == 1:
			var m := def("magic")
			_hit(hit, _base_damage(m, maxi(level("magic"), 1)), _fb_vel[i].normalized(), "magic")
		elif hit >= 0:
			var blast := (float(d.blast) + float(d.blastPerLevel) * (lv - 1)) * _area()
			var at := _fb_pos[i]
			_hit_all(enemies.in_range(at, blast), _base_damage(d, lv), at, "fireball", true)
			_flash(_sphere_mesh(blast), at, Color(1.0, 0.45, 0.1, 0.55), 0.35)
		if hit >= 0 or _fb_life[i] <= 0.0:
			var last := _fb_pos.size() - 1
			_fb_pos[i] = _fb_pos[last]
			_fb_vel[i] = _fb_vel[last]
			_fb_life[i] = _fb_life[last]
			_fb_kind[i] = _fb_kind[last]
			_fb_pos.resize(last)
			_fb_vel.resize(last)
			_fb_life.resize(last)
			_fb_kind.resize(last)
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
		_bolt(enemies.position_of(i), enemies.uid_of(i), _base_damage(d, lv))


## A thick zigzag bolt that grows down from the sky; the enemy is hit when it
## reaches the ground (if it is still alive by then).
func _bolt(at: Vector3, uid: int, damage: float) -> void:
	var glow := _bolt_material(Color(0.55, 0.85, 1.0, 0.85))
	var core := _bolt_material(Color(0.95, 0.98, 1.0, 1.0))
	var root := Node3D.new()
	add_child(root)
	root.global_position = at
	var points: Array[Vector3] = [Vector3(0, BOLT_HEIGHT, 0)]
	for s in range(1, BOLT_STEPS + 1):
		var p := Vector3(0, BOLT_HEIGHT * (1.0 - float(s) / BOLT_STEPS), 0)
		if s < BOLT_STEPS:
			p += Vector3(randf_range(-0.9, 0.9), 0, randf_range(-0.9, 0.9))
		points.append(p)
	var tween := create_tween()
	for s in BOLT_STEPS:
		var outer := _bolt_segment(points[s], points[s + 1], 0.6, glow)
		var inner := _bolt_segment(points[s], points[s + 1], 0.22, core)
		root.add_child(outer)
		root.add_child(inner)
		tween.tween_callback(_show_nodes.bind([outer, inner]))
		tween.tween_interval(BOLT_STEP_TIME)
	tween.tween_callback(_bolt_impact.bind(at, uid, damage))
	tween.tween_interval(0.12)
	tween.tween_property(glow, "albedo_color:a", 0.0, 0.45)
	tween.parallel().tween_property(core, "albedo_color:a", 0.0, 0.45)
	tween.tween_callback(root.queue_free)


func _bolt_impact(at: Vector3, uid: int, damage: float) -> void:
	_flash(_sphere_mesh(1.3), at + Vector3.UP * 0.3, Color(0.75, 0.92, 1.0, 0.8), 0.5)
	if not active:
		return
	var i := enemies.index_of_uid(uid)
	if i >= 0:
		_hit(i, damage, Vector3.ZERO, "lightning")


func _bolt_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	return mat


func _bolt_segment(a: Vector3, b: Vector3, thickness: float, mat: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = Vector3(thickness, a.distance_to(b) + thickness * 0.5, thickness)
	var seg := MeshInstance3D.new()
	seg.mesh = box
	seg.material_override = mat
	seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	seg.visible = false
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD).normalized()
	seg.transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)
	return seg


func _show_nodes(nodes: Array) -> void:
	for node in nodes:
		if is_instance_valid(node):
			(node as Node3D).visible = true


## Archer's arrow rain and mage's meteor: something falls from the sky onto
## a random enemy in range and hits everything around where it lands.
func _update_sky_strike(id: String, delta: float, d: Dictionary, lv: int) -> void:
	if not _ready_to_fire(id, delta, float(d.cooldown)):
		return
	var near := Array(enemies.in_range(player.global_position, float(d.range) + bow.range_bonus))
	if near.is_empty():
		_timers[id] = 0.2
		return
	var at := enemies.position_of(near[_rng.randi() % near.size()])
	at.y = terrain.height_at(at.x, at.z)
	var radius := (float(d.radius) + float(d.radiusPerLevel) * (lv - 1)) * _area()
	var root := Node3D.new()
	add_child(root)
	root.global_position = at
	var tween := create_tween().set_parallel(true)
	var fall := 0.75 if id == "meteor" else 0.45
	if id == "meteor":
		var rock := MeshInstance3D.new()
		rock.mesh = _sphere_mesh(radius * 0.4)
		rock.material_override = _bolt_material(Color(1.0, 0.45, 0.12, 1.0))
		root.add_child(rock)
		rock.position = Vector3(3.0, SKY_HEIGHT, -2.0)
		tween.tween_property(rock, "position", Vector3(0, radius * 0.2, 0), fall).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	else:
		var mat := _bolt_material(Color(1.0, 0.86, 0.5, 1.0))
		for n in 9:
			var arrow := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.08, 1.0, 0.08)
			arrow.mesh = box
			arrow.material_override = mat
			root.add_child(arrow)
			var spot := Vector3.FORWARD.rotated(Vector3.UP, _rng.randf() * TAU) * _rng.randf() * radius
			arrow.position = spot + Vector3.UP * (SKY_HEIGHT + _rng.randf() * 3.0)
			tween.tween_property(arrow, "position", spot + Vector3.UP * 0.5, fall + _rng.randf() * 0.15).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(_area_hit.bind(at, radius, _base_damage(d, lv), id))
	tween.chain().tween_callback(root.queue_free)


## Warrior's shield bash: hits everything around and throws it far back.
func _update_shield_bash(delta: float, d: Dictionary, lv: int) -> void:
	if not _ready_to_fire("shield_bash", delta, float(d.cooldown)):
		return
	var radius := (float(d.radius) + float(d.radiusPerLevel) * (lv - 1)) * _area()
	var center := player.global_position
	var hits := enemies.in_range(center, radius)
	if hits.is_empty():
		_timers["shield_bash"] = 0.2
		return
	# Face the first target before hitting: a kill can free its slot.
	var dir := enemies.position_of(hits[0]) - center
	dir.y = 0.0
	for n in range(hits.size() - 1, -1, -1):
		var i := hits[n]
		var push := enemies.position_of(i) - center
		push.y = 0.0
		_hit(i, _base_damage(d, lv), push.normalized() * float(d.push), "shield_bash")
	attacked.emit(dir.normalized())
	var ring := CylinderMesh.new()
	ring.top_radius = radius
	ring.bottom_radius = radius
	ring.height = 0.3
	_flash(ring, center + Vector3.UP * 0.4, Color(0.62, 0.76, 1.0, 0.55), 0.3)


func _area_hit(at: Vector3, radius: float, damage: float, id: String) -> void:
	var color := Color(1.0, 0.45, 0.12, 0.6) if id == "meteor" else Color(1.0, 0.9, 0.6, 0.45)
	_flash(_sphere_mesh(radius), at + Vector3.UP * 0.3, color, 0.4)
	if active:
		_hit_all(enemies.in_range(at, radius), damage, at, id, true)


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
	var counts := [0, 0]
	var mms := [_fb_mm, _orb_mm]
	for i in _fb_pos.size():
		var k := _fb_kind[i]
		(mms[k] as MultiMesh).set_instance_transform(counts[k], Transform3D(Basis.IDENTITY, _fb_pos[i]))
		counts[k] += 1
	_fb_mm.visible_instance_count = counts[0]
	_orb_mm.visible_instance_count = counts[1]


## A short-lived glowing shape (explosions, lightning bolts) that fades out.
func _flash(mesh: Mesh, at: Vector3, color: Color, duration: float, facing := Basis.IDENTITY) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	var fx := MeshInstance3D.new()
	fx.mesh = mesh
	fx.material_override = mat
	fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fx)
	fx.global_transform = Transform3D(facing, at)
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
