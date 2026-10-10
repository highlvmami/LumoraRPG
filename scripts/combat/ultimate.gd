## Class ultimate (R / Q): a big show that hits every enemy on the map. Each
## cast picks one of the class's two ultimates at random:
## - mage: a giant meteor crashing down, or a storm of lightning bolts;
## - warrior: a quake with shockwaves and rock spikes, or a rain of giant swords;
## - archer: a storm of arrows, or falling golden stars.
## Enemies take damage that grows with the run (bosses take more); the
## damage lands with the effect (on impact, or as the bolt / sword / arrow
## reaching them). In co-op the others see the show (`cast`), and a
## partner's hits go to the host like any other hit.
extends Node3D

const Toon := preload("res://scripts/core/toon.gd")
const EnemyManager := preload("res://scripts/enemies/enemy_manager.gd")
const Terrain := preload("res://scripts/world/terrain.gd")

## Ultimate was cast here (variant id); the game sends it to co-op partners.
signal cast(variant: String, at: Vector3)
## Same as the weapons' signal, for damage numbers.
signal hit_landed(at_position: Vector3, amount: float, crit: bool)

const COOLDOWN := 45.0
## Wait before the first ultimate of a run.
const FIRST_WAIT := 10.0
## Damage to every enemy, times the run's enemy health growth and the
## player's damage multiplier; bosses take BOSS_SCALE times as much.
const BASE_DAMAGE := 70.0
const BOSS_SCALE := 2.5
## Damage numbers shown at most per cast (the rest still take the damage).
const MAX_NUMBERS := 30
const VARIANTS := {
	"mage": ["meteor", "storm"],
	"warrior": ["quake", "blades"],
	"archer": ["arrows", "stars"],
	"rogue": ["blades", "stars"],
	"healer": ["light", "stars"],
}
const NAMES := {
	"meteor": "Göktaşı", "storm": "Şimşek Fırtınası",
	"quake": "Yer Sarsıntısı", "blades": "Kılıç Yağmuru",
	"arrows": "Ok Fırtınası", "stars": "Yıldız Yağmuru", "light": "Şifa Işığı",
}

var player: CharacterBody3D
var enemies: EnemyManager
var terrain: Terrain
## The bow holds the shared damage multiplier.
var bow: Node
## Camera rig (shake) and HUD (screen flash); both optional.
var camera_rig: Node
var hud: Node
var class_id := "archer"
var active := false
var cooldown_left := FIRST_WAIT
var last_variant := ""
## Casts this run (tests).
var casts := 0

## Hits waiting for their moment: [seconds left, enemy uid, damage].
var _pending: Array = []
var _numbers_left := 0
var _rng := RandomNumberGenerator.new()


func setup(p_player: CharacterBody3D, p_enemies: EnemyManager, p_terrain: Terrain, p_bow: Node) -> void:
	player = p_player
	enemies = p_enemies
	terrain = p_terrain
	bow = p_bow
	_rng.randomize()


func reset() -> void:
	cooldown_left = FIRST_WAIT
	_pending.clear()
	casts = 0
	for child in get_children():
		child.queue_free()


func is_ready() -> bool:
	return cooldown_left <= 0.0


## 0 right after a cast, 1 when ready again.
func ratio() -> float:
	return clampf(1.0 - cooldown_left / COOLDOWN, 0.0, 1.0)


func variants() -> Array:
	return VARIANTS.get(class_id, VARIANTS.archer)


## Casts a random one of the class's ultimates (or `only`). Returns false
## while cooling down, outside a run or when dead.
func try_cast(only := "") -> bool:
	if not active or not is_ready() or bool(player.get("dead")):
		return false
	var options := variants()
	var variant := only if only != "" else str(options[_rng.randi() % options.size()])
	cooldown_left = COOLDOWN
	last_variant = variant
	casts += 1
	var at := player.global_position
	play(variant, at, true)
	cast.emit(variant, at)
	return true


func _process(delta: float) -> void:
	if active:
		cooldown_left = maxf(0.0, cooldown_left - delta)
		if Input.is_action_just_pressed("ultimate"):
			try_cast()
	for n in range(_pending.size() - 1, -1, -1):
		var p: Array = _pending[n]
		p[0] = float(p[0]) - delta
		if float(p[0]) <= 0.0:
			_pending.remove_at(n)
			_hit_uid(int(p[1]), float(p[2]))


## Plays an ultimate at `at`. `deal_damage` is false for a partner's cast
## (their game sends its own hits).
func play(variant: String, at: Vector3, deal_damage: bool) -> void:
	_numbers_left = MAX_NUMBERS
	at.y = terrain.height_at(at.x, at.z)
	if hud and hud.has_method("toast"):
		hud.call("toast", ("ULTİ: %s!" % NAMES.get(variant, variant)).replace("i", "İ").to_upper())
	match variant:
		"meteor":
			_meteor(at, deal_damage)
		"storm":
			_storm(at, deal_damage)
		"quake":
			_quake(at, deal_damage)
		"blades":
			_rain(at, deal_damage, "blade")
		"stars":
			_rain(at, deal_damage, "star")
		"light":
			_rain(at, deal_damage, "star")
			# Heals and shields the caster; partners get it when they see the cast.
			if player.has_method("heal"):
				player.call("heal", float(player.get("max_hp")) * 0.4)
				player.call("shield", 3.0)
		_:
			_rain(at, deal_damage, "arrow")


# --- Damage -------------------------------------------------------------------

func _damage_for(index: int) -> float:
	var dmg := BASE_DAMAGE * enemies.growth("hpGrowthPerMinute") * float(bow.get("damage_multiplier"))
	return dmg * (BOSS_SCALE if index == enemies.boss_index() else 1.0)


## Every enemy on the map now (highest index first: kills swap the last in).
func _hit_everyone() -> void:
	for i in range(enemies.count() - 1, -1, -1):
		_hit_index(i, _damage_for(i))


## Every enemy, each at its own moment from `delay(position)` seconds.
func _schedule_everyone(delay: Callable) -> void:
	for i in enemies.count():
		_pending.append([float(delay.call(enemies.position_of(i))), enemies.uid_of(i), _damage_for(i)])


func _hit_uid(uid: int, amount: float) -> void:
	if not active:
		return
	var i := enemies.index_of_uid(uid)
	if i >= 0:
		_hit_index(i, amount)


func _hit_index(i: int, amount: float) -> void:
	var at := enemies.position_of(i)
	if _numbers_left > 0:
		_numbers_left -= 1
		hit_landed.emit(at, amount, true)
	var push := at - player.global_position
	push.y = 0.0
	enemies.damage(i, amount, push.normalized() * 2.0)


# --- Mage -----------------------------------------------------------------------

## A huge burning rock falls from high up and blows up next to the player:
## a white flash, a fireball, shockwave rings, fire pillars and flying rocks.
func _meteor(at: Vector3, deal_damage: bool) -> void:
	var forward := _view_forward()
	var impact := at + forward * 8.0
	impact.y = terrain.height_at(impact.x, impact.z)
	var root := Node3D.new()
	add_child(root)
	root.global_position = impact
	# Warning circle on the ground while it falls.
	var warn := _disc(14.0, Color(1.0, 0.35, 0.1, 0.0))
	root.add_child(warn)
	warn.position.y = 0.15
	var warn_tween := create_tween()
	warn_tween.tween_property(warn.material_override, "albedo_color:a", 0.45, 1.4)
	var rock := Node3D.new()
	root.add_child(rock)
	var core := _shape(_sphere(4.0), Color("#ff6a1f"), 2.4)
	rock.add_child(core)
	var crust := _shape(_sphere(4.3), Color(0.35, 0.12, 0.05, 0.55), 0.0)
	rock.add_child(crust)
	var glow := _shape(_sphere(6.0), Color(1.0, 0.55, 0.1, 0.3), 1.5)
	rock.add_child(glow)
	rock.add_child(_fire_trail(3.5, 160))
	var light := OmniLight3D.new()
	light.light_color = Color("#ff8a3a")
	light.light_energy = 6.0
	light.omni_range = 40.0
	rock.add_child(light)
	# It comes in from far ahead and high up, where the camera looks.
	rock.position = forward * 80.0 + Vector3.UP * 30.0 + forward.cross(Vector3.UP) * 12.0
	var fall := create_tween()
	fall.tween_property(rock, "position", Vector3(0, 2.0, 0), 1.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	fall.parallel().tween_property(rock, "rotation", Vector3(4.0, 2.0, 1.0), 1.6)
	if hud and hud.has_method("screen_flash"):
		hud.call("screen_flash", Color(1.0, 0.45, 0.1), 0.6, 1.0, 0.0, 0.3)
	fall.tween_callback(func() -> void:
		rock.queue_free()
		warn.queue_free()
		_explosion(impact)
		if deal_damage:
			_hit_everyone())
	fall.tween_interval(4.0)
	fall.tween_callback(root.queue_free)


func _explosion(at: Vector3) -> void:
	_shake(1.4, 1.2)
	if hud and hud.has_method("screen_flash"):
		hud.call("screen_flash", Color(1.0, 0.95, 0.8), 0.9, 0.0, 0.9)
	_grow(_sphere(1.0), at + Vector3.UP, Color(1.0, 0.95, 0.7, 1.0), 4.0, 14.0, 0.6, 3.0)
	_grow(_sphere(1.0), at + Vector3.UP, Color(1.0, 0.45, 0.1, 0.85), 6.0, 22.0, 1.1, 2.0)
	_grow(_sphere(1.0), at + Vector3.UP * 3.0, Color(0.25, 0.12, 0.08, 0.6), 8.0, 26.0, 2.2, 0.0)
	for n in 3:
		_ring_wave(at, Color(1.0, 0.6 - n * 0.15, 0.2, 0.8), 45.0 + n * 10.0, 0.9 + n * 0.35, n * 0.15)
	# Fire pillars bursting up around the crater.
	for n in 14:
		var a := TAU * n / 14.0 + _rng.randf() * 0.3
		var d := _rng.randf_range(6.0, 16.0)
		var spot := at + Vector3(cos(a) * d, 0, sin(a) * d)
		spot.y = terrain.height_at(spot.x, spot.z)
		var flame := _shape(_column(0.9, 1.0), Color(1.0, 0.5 + _rng.randf() * 0.3, 0.1, 0.9), 2.0)
		var pillar := _from_base(flame)
		add_child(pillar)
		pillar.global_position = spot
		pillar.scale = Vector3(1, 0.01, 1)
		var t := create_tween()
		t.tween_interval(_rng.randf() * 0.4)
		t.tween_property(pillar, "scale", Vector3(1, _rng.randf_range(6.0, 12.0), 1), 0.25).set_ease(Tween.EASE_OUT)
		t.tween_property(flame.material_override, "albedo_color:a", 0.0, 0.8)
		t.tween_callback(pillar.queue_free)
	# Rocks thrown out of the crater.
	for n in 24:
		var chunk := _shape(_box(Vector3.ONE * _rng.randf_range(0.4, 1.2)), Color("#5a3a28"), 0.0)
		add_child(chunk)
		chunk.global_position = at + Vector3.UP * 1.5
		var dir := Vector3.FORWARD.rotated(Vector3.UP, _rng.randf() * TAU)
		var land := at + dir * _rng.randf_range(10.0, 26.0)
		land.y = terrain.height_at(land.x, land.z)
		var peak := (at + land) * 0.5 + Vector3.UP * _rng.randf_range(8.0, 16.0)
		var t := create_tween()
		t.tween_property(chunk, "global_position", peak, 0.45).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(chunk, "rotation", Vector3(_rng.randf() * 8.0, _rng.randf() * 8.0, 0), 0.9)
		t.tween_property(chunk, "global_position", land, 0.45).set_ease(Tween.EASE_IN)
		t.tween_interval(1.5)
		t.tween_property(chunk, "scale", Vector3.ONE * 0.01, 0.4)
		t.tween_callback(chunk.queue_free)
	var embers := _fire_trail(8.0, 220)
	embers.one_shot = true
	embers.explosiveness = 0.9
	embers.initial_velocity_min = 6.0
	embers.initial_velocity_max = 16.0
	add_child(embers)
	embers.global_position = at + Vector3.UP
	get_tree().create_timer(3.0, false).timeout.connect(embers.queue_free)


## The sky darkens and lightning hammers the whole area for a few seconds;
## every enemy is struck by its own bolt.
func _storm(at: Vector3, deal_damage: bool) -> void:
	const DURATION := 3.2
	if hud and hud.has_method("screen_flash"):
		hud.call("screen_flash", Color(0.05, 0.08, 0.2), 0.4, DURATION, 0.8, 0.55)
	_shake(0.35, DURATION)
	var bolts := 0
	# A bolt for (up to 60) enemies, timed with the damage.
	var order: Array = range(enemies.count())
	order.shuffle()
	for i: int in order:
		var when := _rng.randf_range(0.3, DURATION)
		if deal_damage:
			_pending.append([when + 0.25, enemies.uid_of(i), _damage_for(i)])
		if bolts < 60:
			bolts += 1
			get_tree().create_timer(when, false).timeout.connect(_bolt_at_uid.bind(enemies.uid_of(i), at))
	# And bolts all around the player.
	for n in 36:
		var a := _rng.randf() * TAU
		var spot := at + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(3.0, 32.0)
		get_tree().create_timer(_rng.randf_range(0.2, DURATION), false).timeout.connect(_bolt.bind(spot, _rng.randf() < 0.25))


func _bolt_at_uid(uid: int, fallback: Vector3) -> void:
	var i := enemies.index_of_uid(uid)
	var spot := enemies.position_of(i) if i >= 0 else fallback + Vector3(_rng.randf_range(-20, 20), 0, _rng.randf_range(-20, 20))
	_bolt(spot, false)


## A thick zigzag bolt from the clouds with a bright flash where it lands.
func _bolt(at: Vector3, big: bool) -> void:
	at.y = terrain.height_at(at.x, at.z)
	var height := 26.0
	var steps := 9
	var glow := _unshaded(Color(0.55, 0.8, 1.0, 0.85), 3.0)
	var core := _unshaded(Color(0.97, 0.99, 1.0, 1.0), 4.0)
	var root := Node3D.new()
	add_child(root)
	root.global_position = at
	var points: Array[Vector3] = [Vector3(_rng.randf_range(-3, 3), height, _rng.randf_range(-3, 3))]
	for s in range(1, steps + 1):
		var p := Vector3(0, height * (1.0 - float(s) / steps), 0)
		if s < steps:
			p += Vector3(_rng.randf_range(-1.4, 1.4), 0, _rng.randf_range(-1.4, 1.4))
		points.append(p)
	var thick := 1.6 if big else 1.0
	for s in steps:
		root.add_child(_segment(points[s], points[s + 1], 0.7 * thick, glow))
		root.add_child(_segment(points[s], points[s + 1], 0.25 * thick, core))
		# A side branch now and then.
		if s > 1 and s < steps - 2 and _rng.randf() < 0.35:
			var off := points[s] + Vector3(_rng.randf_range(-3, 3), -_rng.randf_range(1.5, 3.0), _rng.randf_range(-3, 3))
			root.add_child(_segment(points[s], off, 0.2 * thick, glow))
	var light := OmniLight3D.new()
	light.light_color = Color("#9fd8ff")
	light.light_energy = 5.0
	light.omni_range = 14.0
	light.position.y = 3.0
	root.add_child(light)
	_grow(_sphere(1.0), at + Vector3.UP * 0.4, Color(0.8, 0.93, 1.0, 0.9), 1.0, 4.0 * thick, 0.35, 3.0)
	_ring_wave(at, Color(0.6, 0.85, 1.0, 0.7), 7.0 * thick, 0.35, 0.0)
	if big and hud and hud.has_method("screen_flash"):
		hud.call("screen_flash", Color(0.85, 0.92, 1.0), 0.03, 0.0, 0.25, 0.4)
	var t := create_tween()
	t.tween_interval(0.08)
	t.tween_property(glow, "albedo_color:a", 0.0, 0.35)
	t.parallel().tween_property(core, "albedo_color:a", 0.0, 0.35)
	t.parallel().tween_property(light, "light_energy", 0.0, 0.35)
	t.tween_callback(root.queue_free)


# --- Warrior ----------------------------------------------------------------------

## The warrior strikes the ground: shockwaves roll out across the map and
## rock spikes burst up behind them. An enemy is hit when a wave reaches it.
func _quake(at: Vector3, deal_damage: bool) -> void:
	const SPEED := 22.0
	const REACH := 60.0
	_shake(1.0, 2.4)
	if hud and hud.has_method("screen_flash"):
		hud.call("screen_flash", Color(0.9, 0.75, 0.5), 0.05, 0.0, 0.6, 0.5)
	_grow(_sphere(1.0), at + Vector3.UP * 0.5, Color(1.0, 0.85, 0.5, 0.9), 1.0, 6.0, 0.4, 2.0)
	for n in 4:
		_ring_wave(at, Color(0.95, 0.75, 0.45, 0.85), REACH, REACH / SPEED, n * 0.35)
	# Rock spikes in rings, rising as the first wave passes.
	for ring in range(1, 9):
		var dist := ring * 6.5
		var count := 6 + ring * 4
		for n in count:
			var a := TAU * n / count + _rng.randf() * 0.2
			var spot := at + Vector3(cos(a), 0, sin(a)) * (dist + _rng.randf_range(-1.5, 1.5))
			spot.y = terrain.height_at(spot.x, spot.z)
			_spike(spot, dist / SPEED, _rng.randf_range(1.2, 3.2))
	if deal_damage:
		_schedule_everyone(func(p: Vector3) -> float: return Vector2(p.x - at.x, p.z - at.z).length() / SPEED)


func _spike(at: Vector3, delay: float, height: float) -> void:
	var spike := _from_base(_shape(_cone(0.7, 1.0), Color("#8a7a68").darkened(_rng.randf() * 0.3), 0.0))
	add_child(spike)
	spike.global_position = at + Vector3.DOWN * 0.2
	spike.rotation = Vector3(_rng.randf_range(-0.25, 0.25), _rng.randf() * TAU, _rng.randf_range(-0.25, 0.25))
	spike.scale = Vector3(1, 0.01, 1)
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_property(spike, "scale", Vector3(1, height, 1), 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_interval(1.4)
	t.tween_property(spike, "scale", Vector3(1, 0.01, 1), 0.5).set_ease(Tween.EASE_IN)
	t.tween_callback(spike.queue_free)


# --- Rains (warrior swords, archer arrows and stars) --------------------------------

## Things fall from the sky all over the area for a few seconds; each enemy
## gets one aimed straight at it, the rest land around.
func _rain(at: Vector3, deal_damage: bool, kind: String) -> void:
	var duration := 2.8
	var extra := {"blade": 30, "arrow": 260, "star": 40}[kind] as int
	var aimed_max := {"blade": 50, "arrow": 120, "star": 60}[kind] as int
	if kind == "star" and hud and hud.has_method("screen_flash"):
		hud.call("screen_flash", Color(0.1, 0.05, 0.25), 0.4, duration, 0.8, 0.45)
	_shake(0.25, duration)
	var aimed := 0
	var order: Array = range(enemies.count())
	order.shuffle()
	for i: int in order:
		var when := _rng.randf_range(0.0, duration)
		var fall := _fall_time(kind)
		if deal_damage:
			_pending.append([when + fall, enemies.uid_of(i), _damage_for(i)])
		if aimed < aimed_max:
			aimed += 1
			get_tree().create_timer(maxf(0.01, when), false).timeout.connect(_drop_at_uid.bind(enemies.uid_of(i), at, kind, fall))
	for n in extra:
		var a := _rng.randf() * TAU
		var spot := at + Vector3(cos(a), 0, sin(a)) * sqrt(_rng.randf()) * 34.0
		get_tree().create_timer(maxf(0.01, _rng.randf_range(0.0, duration)), false).timeout.connect(_drop.bind(spot, kind, _fall_time(kind)))


func _fall_time(kind: String) -> float:
	return 0.55 if kind == "blade" else (0.4 if kind == "arrow" else 0.7)


func _drop_at_uid(uid: int, fallback: Vector3, kind: String, fall: float) -> void:
	var i := enemies.index_of_uid(uid)
	_drop(enemies.position_of(i) if i >= 0 else fallback, kind, fall)


func _drop(at: Vector3, kind: String, fall: float) -> void:
	at.y = terrain.height_at(at.x, at.z)
	var item := Node3D.new()
	add_child(item)
	var from := Vector3(0, 22.0, 0)
	match kind:
		"blade":
			# A giant glowing sword, point down.
			item.add_child(_at(_shape(_box(Vector3(0.5, 4.2, 0.12)), Color("#dfe8f2"), 0.8), Vector3(0, 2.1, 0)))
			item.add_child(_at(_shape(_box(Vector3(1.6, 0.25, 0.3)), Color("#d9a520"), 0.6), Vector3(0, 4.3, 0)))
			item.add_child(_at(_shape(_box(Vector3(0.22, 1.0, 0.22)), Color("#6b4a2b"), 0.0), Vector3(0, 4.9, 0)))
			item.add_child(_at(_shape(_sphere(0.25), Color("#ff3b2f"), 1.5), Vector3(0, 5.45, 0)))
			item.rotation.y = _rng.randf() * TAU
			item.scale = Vector3.ONE * 1.3
		"star":
			var c := Color("#ffe066").lerp(Color("#ff9ad5"), _rng.randf() * 0.4)
			for axis: Vector3 in [Vector3.RIGHT, Vector3.FORWARD, Vector3.UP]:
				var spike := _shape(_box(Vector3(0.3, 2.2, 0.3)), c, 3.0)
				spike.basis = Basis(axis, PI * 0.25)
				item.add_child(spike)
			item.add_child(_shape(_sphere(0.7), Color(1.0, 0.95, 0.7, 0.6), 3.0))
			item.add_child(_fire_trail(0.4, 30, Color(1.0, 0.95, 0.6), Color(1.0, 0.5, 0.9, 0.0)))
			from = Vector3(_rng.randf_range(-14, 14), 26.0, _rng.randf_range(-14, 14))
		_:
			# An arrow with a glowing tip, leaning the way it flies.
			item.add_child(_at(_shape(_box(Vector3(0.16, 2.4, 0.16)), Color("#ffcf6a"), 1.2), Vector3(0, 1.2, 0)))
			item.add_child(_at(_shape(_box(Vector3(0.32, 0.45, 0.32)), Color("#fff2b0"), 3.0), Vector3(0, 0.0, 0)))
			item.add_child(_at(_shape(_box(Vector3(0.5, 0.45, 0.05)), Color("#f4f1e6"), 0.0), Vector3(0, 2.25, 0)))
			item.add_child(_at(_shape(_box(Vector3(0.05, 0.45, 0.5)), Color("#f4f1e6"), 0.0), Vector3(0, 2.25, 0)))
			from = Vector3(-4.0, 20.0, 3.0)
			item.basis = Basis.looking_at(-from.normalized(), Vector3.UP) * Basis(Vector3.RIGHT, -PI * 0.5)
	item.global_position = at + from
	var t := create_tween()
	t.tween_property(item, "global_position", at + Vector3.UP * (0.2 if kind != "star" else 0.6), fall).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_callback(_impact.bind(at, kind))
	if kind == "star":
		t.tween_callback(item.queue_free)
	else:
		t.tween_interval(0.9 if kind == "blade" else 0.3)
		t.tween_property(item, "scale", Vector3.ONE * 0.01, 0.25)
		t.tween_callback(item.queue_free)


func _impact(at: Vector3, kind: String) -> void:
	match kind:
		"blade":
			_grow(_sphere(1.0), at + Vector3.UP * 0.3, Color(0.85, 0.92, 1.0, 0.8), 0.8, 3.5, 0.3, 2.0)
			_ring_wave(at, Color(0.9, 0.95, 1.0, 0.7), 6.0, 0.35, 0.0)
		"star":
			_grow(_sphere(1.0), at + Vector3.UP * 0.5, Color(1.0, 0.92, 0.5, 0.9), 1.0, 5.0, 0.4, 3.0)
			_ring_wave(at, Color(1.0, 0.85, 0.4, 0.8), 8.0, 0.45, 0.0)
		_:
			_grow(_sphere(1.0), at + Vector3.UP * 0.2, Color(1.0, 0.9, 0.6, 0.7), 0.3, 1.4, 0.25, 1.5)


# --- Effect helpers -------------------------------------------------------------------

## Flat direction the camera looks (the player's facing without a camera).
func _view_forward() -> Vector3:
	if camera_rig:
		return Basis(Vector3.UP, float(camera_rig.get("yaw"))) * Vector3.FORWARD
	return Basis(Vector3.UP, float(player.get("facing"))) * Vector3.BACK


func _shake(strength: float, duration: float) -> void:
	if camera_rig and camera_rig.has_method("shake"):
		camera_rig.call("shake", strength, duration)


## A shape that grows from `from` to `to` (radius) while fading out.
func _grow(mesh: Mesh, at: Vector3, color: Color, from: float, to: float, duration: float, glow: float) -> void:
	var fx := _shape(mesh, color, glow)
	add_child(fx)
	fx.global_position = at
	fx.scale = Vector3.ONE * from
	var t := create_tween().set_parallel(true)
	t.tween_property(fx, "scale", Vector3.ONE * to, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(fx.material_override, "albedo_color:a", 0.0, duration).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(fx.queue_free)


## A flat ring rolling out along the ground.
func _ring_wave(at: Vector3, color: Color, reach: float, duration: float, delay: float) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 6
	var fx := _shape(torus, color, 2.0)
	add_child(fx)
	fx.global_position = at + Vector3.UP * 0.4
	fx.scale = Vector3(0.5, 3.0, 0.5)
	fx.visible = false
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_callback(func() -> void: fx.visible = true)
	t.tween_property(fx, "scale", Vector3(reach, 3.0, reach), duration).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(fx.material_override, "albedo_color:a", 0.0, duration).set_ease(Tween.EASE_IN)
	t.tween_callback(fx.queue_free)


func _fire_trail(radius: float, amount: int, start := Color(1.0, 0.85, 0.3, 1.0), end := Color(0.6, 0.1, 0.02, 0.0)) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 1.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 180.0
	p.gravity = Vector3(0, 2.0, 0)
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 2.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = mat
	p.mesh = quad
	var ramp := Gradient.new()
	ramp.set_color(0, start)
	ramp.set_color(1, end)
	p.color_ramp = ramp
	return p


func _shape(mesh: Mesh, color: Color, glow: float) -> MeshInstance3D:
	var fx := MeshInstance3D.new()
	fx.mesh = mesh
	fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.material_override = _unshaded(color, glow) if glow > 0.0 or color.a < 1.0 else Toon.material(color)
	return fx


func _unshaded(color: Color, glow: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = Color(color, 1.0)
		mat.emission_energy_multiplier = glow
	return mat


func _at(node: Node3D, pos: Vector3) -> Node3D:
	node.position = pos
	return node


func _disc(radius: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.05
	mesh.radial_segments = 40
	return _shape(mesh, color, 0.0)


func _segment(a: Vector3, b: Vector3, thickness: float, mat: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = Vector3(thickness, a.distance_to(b) + thickness * 0.5, thickness)
	var seg := MeshInstance3D.new()
	seg.mesh = box
	seg.material_override = mat
	seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD).normalized()
	seg.transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)
	return seg


func _sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 14
	m.rings = 7
	return m


func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


## A cylinder 1 high (see _from_base).
func _column(top: float, bottom: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = 1.0
	m.radial_segments = 8
	return m


func _cone(bottom: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = 5
	return m


## Godot centers cylinders (height 1 here); the holder grows them from their
## base when its y scale changes.
func _from_base(shape: MeshInstance3D) -> Node3D:
	var holder := Node3D.new()
	shape.position.y = 0.5
	holder.add_child(shape)
	return holder
