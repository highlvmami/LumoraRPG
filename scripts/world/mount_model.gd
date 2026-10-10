## A blocky mount the player rides: a horse, a wolf, a tiger or a winged
## sky horse. It faces +Z like every model, runs on its four legs (`animate`
## takes the walking speed) and can rear up (`set_rear`) for menu previews.
## Dearer mounts are bigger and have more parts: stripes, fangs, wings, a horn.
extends Node3D

const Toon := preload("res://scripts/core/toon.gd")

## Height of the saddle for a mount of scale 1 (the rider sits on it).
const SADDLE := 1.5
## Where the hind hooves are (the mount rears around them).
const HIND_Z := -0.62

var kind := "horse"
var mount_scale := 1.0
var rearing := false

var _frame: Node3D
var _body: Node3D
var _legs: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _tail: Node3D
var _head: Node3D
var _wings: Array[Node3D] = []
var _phase := 0.0
var _time := 0.0
var _rear_amount := 0.0
var _body_color := Color.WHITE
var _mane_color := Color.WHITE
var _accent := Color.WHITE


## `def` is one entry of data/mounts.json (kind, scale, body, mane, accent).
func build(def: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	_legs.clear()
	_knees.clear()
	_wings.clear()
	kind = str(def.get("kind", "horse"))
	mount_scale = float(def.get("scale", 1.0))
	_body_color = Color(str(def.get("body", "#8a5a32")))
	_mane_color = Color(str(def.get("mane", "#2e1d10")))
	_accent = Color(str(def.get("accent", "#b8322a")))
	_frame = Node3D.new()
	_frame.position = Vector3(0, 0, HIND_Z)
	add_child(_frame)
	_body = Node3D.new()
	_body.position = Vector3(0, 0, -HIND_Z)
	_frame.add_child(_body)
	scale = Vector3.ONE * mount_scale
	_build_torso()
	_build_legs()
	_build_neck_and_head()
	_build_tail()
	_build_saddle()
	match kind:
		"wolf":
			_build_wolf_extras()
		"tiger":
			_build_tiger_extras()
		"sky":
			_build_sky_extras()
		_:
			_build_horse_extras()


## Height of the saddle seat in the world (rider's hips sit here).
func seat_height() -> float:
	return SADDLE * mount_scale


## Distance from the middle needed to see the whole mount in a preview.
func view_distance() -> float:
	return 5.2 * mount_scale + 1.5


func center_height() -> float:
	return 1.15 * mount_scale


## Seats a model on the saddle (it moves with the mount, e.g. when rearing).
func attach_rider(rider: Node3D) -> void:
	_body.add_child(rider)
	rider.scale = Vector3.ONE / mount_scale
	rider.position = Vector3(0, SADDLE - 0.3 / mount_scale, 0.0)


func set_rear(on: bool) -> void:
	rearing = on


## Moves the legs from the walking `speed` (0 = standing).
func animate(delta: float, speed: float) -> void:
	_time += delta
	var amount := clampf(speed / 6.0, 0.0, 1.0)
	_phase += delta * (3.0 + speed * 0.9)
	_rear_amount = move_toward(_rear_amount, 1.0 if rearing else 0.0, delta * 2.0)
	var rear := smoothstep(0.0, 1.0, _rear_amount)
	var swing := sin(_phase) * 0.85 * amount
	# Legs 0..3 are front-left, front-right, hind-left, hind-right.
	var sign_of := [1.0, -1.0, -1.0, 1.0]
	for i in _legs.size():
		var front := i < 2
		var walk: float = swing * float(sign_of[i])
		var bend: float = maxf(0.0, -walk) * 1.3
		if front:
			_legs[i].rotation.x = lerpf(walk, -0.9 + sin(_time * 5.0 + i) * 0.12, rear)
			_knees[i].rotation.x = lerpf(bend, 1.5, rear)
		else:
			_legs[i].rotation.x = lerpf(walk, 0.25, rear)
			_knees[i].rotation.x = lerpf(bend, -0.2, rear)
	_frame.rotation.x = -0.62 * rear
	_body.position.y = absf(sin(_phase)) * 0.07 * amount + sin(_time * 1.6) * 0.012
	_body.rotation.x = sin(_phase * 2.0) * 0.025 * amount
	if _tail:
		_tail.rotation.x = 0.35 + sin(_time * 2.0) * 0.12 + amount * 0.4
		_tail.rotation.z = sin(_time * 1.3) * 0.18
	if _head:
		_head.rotation.x = 0.35 + sin(_phase * 2.0) * 0.06 * amount - 0.25 * rear
	for i in _wings.size():
		var flap := sin(_time * (3.0 + amount * 5.0)) * (0.35 + 0.3 * amount)
		_wings[i].rotation.z = (0.85 + flap) * (1.0 if i == 0 else -1.0)


# ---------------------------------------------------------------- parts


func _build_torso() -> void:
	var long := 1.6 if kind != "wolf" else 1.4
	var low := 0.0 if kind != "wolf" else -0.05
	_part(_body, Vector3(0.78, 0.74, long), Vector3(0, 1.12 + low, 0), _body_color)
	# Belly and chest in a lighter shade, rump rounded off.
	_part(_body, Vector3(0.7, 0.2, long - 0.2), Vector3(0, 0.82 + low, 0), _body_color.lightened(0.18))
	_part(_body, Vector3(0.7, 0.62, 0.3), Vector3(0, 1.1 + low, long * 0.5 - 0.05), _body_color.darkened(0.06))
	_part(_body, Vector3(0.7, 0.66, 0.3), Vector3(0, 1.14 + low, -long * 0.5 + 0.02), _body_color.darkened(0.06))


func _build_legs() -> void:
	var thick := 0.2 if kind != "tiger" else 0.27
	for i in 4:
		var front := i < 2
		var x := -0.28 if i % 2 == 0 else 0.28
		var z := 0.58 if front else -0.58
		var hip := Node3D.new()
		hip.position = Vector3(x, 0.92, z)
		_body.add_child(hip)
		_part(hip, Vector3(thick, 0.48, thick), Vector3(0, -0.22, 0), _body_color.darkened(0.12))
		var knee := Node3D.new()
		knee.position = Vector3(0, -0.45, 0)
		hip.add_child(knee)
		_part(knee, Vector3(thick * 0.8, 0.42, thick * 0.8), Vector3(0, -0.2, 0), _body_color.darkened(0.18))
		var hoof_color := _body_color.darkened(0.55) if kind == "horse" else _body_color.lightened(0.1)
		if kind == "sky":
			hoof_color = Color("#e0b030")
		var hoof_size := Vector3(thick * 0.95, 0.1, thick * 1.2) if kind != "tiger" else Vector3(thick * 1.1, 0.12, thick * 1.5)
		_part(knee, Vector3(hoof_size.x, hoof_size.y, hoof_size.z), Vector3(0, -0.43, 0.02), hoof_color)
		_legs.append(hip)
		_knees.append(knee)


func _build_neck_and_head() -> void:
	var lean := 0.65 if kind != "wolf" and kind != "tiger" else 1.0
	var neck_len := 0.78 if kind != "wolf" and kind != "tiger" else 0.5
	var neck := Node3D.new()
	neck.position = Vector3(0, 1.3, 0.72)
	neck.rotation.x = lean
	_body.add_child(neck)
	_part(neck, Vector3(0.38, neck_len, 0.4), Vector3(0, neck_len * 0.5, 0), _body_color)
	_head = Node3D.new()
	_head.position = Vector3(0, neck_len, 0)
	neck.add_child(_head)
	var snout := 0.62 if kind != "wolf" else 0.72
	_part(_head, Vector3(0.34, 0.36, 0.5), Vector3(0, 0.05, 0.2), _body_color)
	_part(_head, Vector3(0.26, 0.26, snout * 0.7), Vector3(0, -0.04, 0.2 + snout * 0.42), _body_color.lightened(0.12))
	# Nose, eyes and ears.
	_part(_head, Vector3(0.28, 0.12, 0.1), Vector3(0, -0.04, 0.2 + snout * 0.78), Color("#1a1210"))
	for sx in [-1.0, 1.0]:
		_part(_head, Vector3(0.05, 0.08, 0.1), Vector3(0.18 * sx, 0.12, 0.28), Color("#101010"))
		var ear_h := 0.2 if kind == "horse" or kind == "sky" else 0.17
		var ear := _part(_head, Vector3(0.09, ear_h, 0.07), Vector3(0.12 * sx, 0.3, 0.0), _body_color.darkened(0.1))
		ear.rotation.z = -0.15 * sx
	# Mane down the neck, a forelock between the ears.
	if kind == "horse" or kind == "sky":
		for i in 4:
			var m := _part(neck, Vector3(0.1, 0.24, 0.1 + 0.02 * i), Vector3(0, 0.12 + i * 0.2, -0.22), _mane_color)
			m.rotation.x = -0.25
		_part(_head, Vector3(0.1, 0.22, 0.1), Vector3(0, 0.3, 0.12), _mane_color)
	if kind == "wolf" or kind == "tiger":
		# Thick ruff round the neck.
		for i in 3:
			_part(neck, Vector3(0.5 + 0.1 * i, 0.22, 0.46), Vector3(0, 0.12 + i * 0.18, 0.0), _mane_color)


func _build_tail() -> void:
	_tail = Node3D.new()
	_tail.position = Vector3(0, 1.3, -0.82)
	_body.add_child(_tail)
	match kind:
		"wolf":
			_part(_tail, Vector3(0.22, 0.2, 0.7), Vector3(0, 0, -0.35), _mane_color)
			_part(_tail, Vector3(0.18, 0.18, 0.3), Vector3(0, 0, -0.8), _body_color.lightened(0.2))
		"tiger":
			for i in 5:
				var c := _mane_color if i % 2 == 1 else _body_color
				_part(_tail, Vector3(0.14, 0.14, 0.24), Vector3(0, 0, -0.14 - i * 0.24), c)
		_:
			for i in 3:
				_part(_tail, Vector3(0.14 - 0.02 * i, 0.3, 0.14), Vector3(0, -0.14 - i * 0.28, -0.05 - i * 0.06), _mane_color)


func _build_saddle() -> void:
	_part(_body, Vector3(0.9, 0.06, 0.8), Vector3(0, 1.5, 0.0), _accent.darkened(0.2))
	_part(_body, Vector3(0.5, 0.1, 0.5), Vector3(0, 1.55, -0.02), Color("#5b3a22"))
	_part(_body, Vector3(0.5, 0.16, 0.08), Vector3(0, 1.62, -0.28), Color("#5b3a22"))
	_part(_body, Vector3(0.5, 0.1, 0.08), Vector3(0, 1.58, 0.24), Color("#5b3a22"))
	# Reins and stirrups.
	for sx in [-1.0, 1.0]:
		_part(_body, Vector3(0.04, 0.34, 0.04), Vector3(0.44 * sx, 1.3, 0.02), Color("#3a2a1a"))
		_part(_body, Vector3(0.1, 0.04, 0.1), Vector3(0.44 * sx, 1.13, 0.02), Color("#9a9a9a"))


func _build_horse_extras() -> void:
	# White blaze and socks.
	_part(_head, Vector3(0.1, 0.4, 0.04), Vector3(0, 0.03, 0.46), Color("#f0ece4"))
	for i in 2:
		_part(_knees[i], Vector3(0.17, 0.16, 0.17), Vector3(0, -0.3, 0), Color("#f0ece4"))
	# Bridle.
	_part(_head, Vector3(0.36, 0.05, 0.05), Vector3(0, 0.1, 0.2), _accent)


func _build_wolf_extras() -> void:
	# Fangs and a lighter chest patch.
	for sx in [-1.0, 1.0]:
		_part(_head, Vector3(0.04, 0.1, 0.04), Vector3(0.07 * sx, -0.14, 0.2 + 0.72 * 0.7), Color("#f4f0e8"))
	_part(_body, Vector3(0.5, 0.45, 0.1), Vector3(0, 1.0, 0.8), _mane_color)
	# A dark saddle stripe along the back.
	_part(_body, Vector3(0.14, 0.04, 1.2), Vector3(0, 1.5, 0), _mane_color.darkened(0.4))
	# Spiky fur along the spine.
	for i in 5:
		_part(_body, Vector3(0.1, 0.14, 0.14), Vector3(0, 1.52, -0.55 + i * 0.28), _mane_color.darkened(0.2))


func _build_tiger_extras() -> void:
	var stripe := _mane_color
	for i in 6:
		var z := -0.62 + i * 0.25
		_part(_body, Vector3(0.8, 0.08, 0.1), Vector3(0, 1.42, z), stripe)
		for sx in [-1.0, 1.0]:
			_part(_body, Vector3(0.05, 0.5, 0.1), Vector3(0.4 * sx, 1.12, z), stripe)
	for leg in _legs:
		_part(leg, Vector3(0.3, 0.06, 0.3), Vector3(0, -0.1, 0), stripe)
	# Fangs, whiskers and a pale muzzle.
	for sx in [-1.0, 1.0]:
		_part(_head, Vector3(0.05, 0.16, 0.05), Vector3(0.08 * sx, -0.16, 0.5), Color("#f4f0e8"))
		_part(_head, Vector3(0.22, 0.02, 0.02), Vector3(0.2 * sx, -0.02, 0.5), Color("#f4f0e8"))
	_part(_head, Vector3(0.3, 0.16, 0.3), Vector3(0, -0.06, 0.45), Color("#f0e6d0"))
	# Head stripes.
	for sx in [-1.0, 1.0]:
		_part(_head, Vector3(0.04, 0.2, 0.06), Vector3(0.14 * sx, 0.14, 0.18), stripe)


func _build_sky_extras() -> void:
	# A glowing horn, a golden collar and big white wings.
	var gold := Color("#e0b030")
	var horn := _part(_head, Vector3(0.07, 0.5, 0.07), Vector3(0, 0.46, 0.2), Color("#fff2c0"))
	horn.rotation.x = 0.2
	_glow(horn, Color("#ffe48a"), 1.3)
	_part(_head, Vector3(0.38, 0.06, 0.06), Vector3(0, 0.12, 0.3), gold)
	_part(_body, Vector3(0.5, 0.1, 0.5), Vector3(0, 1.43, 0.7), gold)
	for part in [_legs[0], _legs[1], _legs[2], _legs[3]]:
		_part(part, Vector3(0.22, 0.07, 0.22), Vector3(0, -0.4, 0), gold)
	# Mane and tail glow like fire.
	_glow(_tail.get_child(0) as MeshInstance3D, _mane_color, 0.9)
	# Wings: three feather rows each.
	for side in 2:
		var sx := 1.0 if side == 0 else -1.0
		var wing := Node3D.new()
		wing.position = Vector3(0.4 * sx, 1.45, 0.15)
		_body.add_child(wing)
		for row in 3:
			var length := 1.7 - row * 0.35
			var feather := _part(wing, Vector3(length, 0.05, 0.42 - row * 0.05), Vector3((length * 0.5 + 0.05) * sx, 0.0, -row * 0.3), Color("#ffffff").darkened(row * 0.05))
			feather.rotation.y = -0.2 * sx * row
		_wings.append(wing)


func _glow(instance: MeshInstance3D, color: Color, energy: float) -> void:
	var mat := instance.material_override as StandardMaterial3D
	if mat == null:
		return
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy


func _part(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.material_override = Toon.material(color)
	m.position = at
	parent.add_child(m)
	return m
