## Blocky pet built from boxes, facing +Z: the bear (walks on four legs),
## the minotaur (a bull-headed fighter with an axe) and the phoenix (a
## glowing fire bird that flies with flapping wings and a trail of sparks).
## `animate` moves legs or wings from the walking speed.
extends Node3D

const Toon := preload("res://scripts/core/toon.gd")

## True for pets that fly (the follower keeps them up in the air).
var flies := false
var kind := ""

var _visual: Node3D
var _legs: Array[Node3D] = []
var _wings: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _phase := 0.0
var _time := 0.0


func build(kind_id: String) -> void:
	if _visual:
		_visual.queue_free()
	_legs.clear()
	_wings.clear()
	_arms.clear()
	kind = kind_id
	flies = kind_id == "phoenix"
	_visual = Node3D.new()
	add_child(_visual)
	match kind_id:
		"minotaur":
			_build_minotaur()
		"phoenix":
			_build_phoenix()
		_:
			_build_bear()


func _build_bear() -> void:
	var fur := Color("#7a4f2e")
	var light := Color("#c49a6c")
	_box(_visual, Vector3(0.9, 0.7, 1.3), Vector3(0, 0.75, 0), fur)
	_box(_visual, Vector3(0.7, 0.3, 0.9), Vector3(0, 0.55, 0.05), light)
	_box(_visual, Vector3(0.62, 0.58, 0.55), Vector3(0, 1.05, 0.8), fur)
	_box(_visual, Vector3(0.32, 0.22, 0.2), Vector3(0, 0.95, 1.12), light)
	_box(_visual, Vector3(0.12, 0.09, 0.06), Vector3(0, 1.02, 1.23), Color("#1a1a1a"))
	for x in [-0.15, 0.15]:
		_box(_visual, Vector3(0.08, 0.08, 0.03), Vector3(x, 1.16, 1.08), Color("#1a1a1a"))
		_box(_visual, Vector3(0.16, 0.16, 0.1), Vector3(x * 1.7, 1.38, 0.72), fur.darkened(0.2))
	_box(_visual, Vector3(0.18, 0.16, 0.14), Vector3(0, 0.95, -0.7), fur.darkened(0.1))
	for at: Vector2 in [Vector2(-0.3, 0.45), Vector2(0.3, 0.45), Vector2(-0.3, -0.45), Vector2(0.3, -0.45)]:
		_legs.append(_limb(Vector3(at.x, 0.55, at.y), Vector3(0.28, 0.55, 0.3), fur.darkened(0.15)))


func _build_minotaur() -> void:
	var hide := Color("#8a4a2c")
	var fur := Color("#4a2e1f")
	_box(_visual, Vector3(0.85, 0.8, 0.5), Vector3(0, 1.25, 0), hide)
	_box(_visual, Vector3(0.6, 0.35, 0.06), Vector3(0, 1.35, 0.26), hide.lightened(0.15))
	_box(_visual, Vector3(0.9, 0.16, 0.54), Vector3(0, 0.85, 0), Color("#5a3a20"))
	_box(_visual, Vector3(0.16, 0.12, 0.06), Vector3(0, 0.85, 0.28), Color("#d9a520"))
	# Bull head with a snout, a gold nose ring and long horns.
	_box(_visual, Vector3(0.5, 0.5, 0.5), Vector3(0, 1.92, 0.05), fur)
	_box(_visual, Vector3(0.38, 0.26, 0.26), Vector3(0, 1.8, 0.36), hide.lightened(0.2))
	_glow(_box(_visual, Vector3(0.14, 0.1, 0.04), Vector3(0, 1.7, 0.5), Color("#ffd23f")), Color("#ffd23f"), 0.4)
	for side in [-1.0, 1.0]:
		_box(_visual, Vector3(0.07, 0.07, 0.03), Vector3(side * 0.13, 2.0, 0.31), Color("#ff3b2f"))
		var horn := _box(_visual, Vector3(0.36, 0.1, 0.1), Vector3(side * 0.38, 2.12, 0.05), Color("#f4f1e6"))
		horn.rotation.z = side * 0.35
		var tip := _box(_visual, Vector3(0.1, 0.24, 0.1), Vector3(side * 0.56, 2.3, 0.05), Color("#e6dcc4"))
		tip.rotation.z = -side * 0.3
	_legs.append(_limb(Vector3(-0.2, 0.8, 0), Vector3(0.3, 0.8, 0.32), fur))
	_legs.append(_limb(Vector3(0.2, 0.8, 0), Vector3(0.3, 0.8, 0.32), fur))
	for leg in _legs:
		_box(leg, Vector3(0.32, 0.12, 0.38), Vector3(0, -0.78, 0.04), Color("#2a2a2a"))
	_arms.append(_limb(Vector3(-0.56, 1.6, 0), Vector3(0.26, 0.7, 0.28), hide))
	var arm_r := _limb(Vector3(0.56, 1.6, 0), Vector3(0.26, 0.7, 0.28), hide)
	_arms.append(arm_r)
	# A double-bladed axe in the right hand.
	var axe := Node3D.new()
	axe.position = Vector3(0, -0.66, 0.1)
	axe.rotation.x = -1.2
	arm_r.add_child(axe)
	_box(axe, Vector3(0.08, 1.3, 0.08), Vector3(0, 0.3, 0), Color("#6b4a2b"))
	for side in [-1.0, 1.0]:
		_box(axe, Vector3(0.34, 0.42, 0.05), Vector3(side * 0.2, 0.82, 0), Color("#c9d4e0"))


func _build_phoenix() -> void:
	var flame := Color("#ff7a1f")
	var gold := Color("#ffd23f")
	var red := Color("#e0303a")
	_glow(_box(_visual, Vector3(0.5, 0.5, 0.8), Vector3(0, 0, 0), flame), flame, 0.6)
	_glow(_box(_visual, Vector3(0.36, 0.3, 0.5), Vector3(0, -0.12, 0.1), gold), gold, 0.5)
	_glow(_box(_visual, Vector3(0.36, 0.36, 0.36), Vector3(0, 0.3, 0.48), flame), flame, 0.6)
	_box(_visual, Vector3(0.12, 0.1, 0.22), Vector3(0, 0.26, 0.72), gold.darkened(0.2))
	for x in [-0.13, 0.13]:
		_box(_visual, Vector3(0.07, 0.07, 0.03), Vector3(x, 0.36, 0.66), Color("#1a1a1a"))
	# Crest of three feathers.
	for n in 3:
		var crest := _box(_visual, Vector3(0.06, 0.32, 0.08), Vector3(0, 0.56, 0.4 - n * 0.12), red)
		crest.rotation.x = -0.4 - n * 0.2
		_glow(crest, red, 0.8)
	# Long fanned tail.
	for n in 5:
		var feather := Node3D.new()
		feather.position = Vector3(0, -0.05, -0.38)
		feather.rotation = Vector3(0.35, (n - 2) * 0.28, 0)
		_visual.add_child(feather)
		var c := red if n % 2 == 0 else gold
		_glow(_box(feather, Vector3(0.1, 0.05, 1.1 - absf(n - 2) * 0.15), Vector3(0, 0, -0.5), c), c, 0.9)
	# Wings pivot at the shoulders.
	for side in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(side * 0.24, 0.1, 0.05)
		_visual.add_child(wing)
		_glow(_box(wing, Vector3(0.75, 0.06, 0.5), Vector3(side * 0.4, 0, 0), flame), flame, 0.7)
		_glow(_box(wing, Vector3(0.55, 0.05, 0.35), Vector3(side * 0.95, 0, -0.08), gold), gold, 0.9)
		_glow(_box(wing, Vector3(0.3, 0.04, 0.25), Vector3(side * 1.3, 0, -0.15), red), red, 1.0)
		wing.set_meta("side", side)
		_wings.append(wing)
	var light := OmniLight3D.new()
	light.light_color = Color("#ffb060")
	light.light_energy = 0.8
	light.omni_range = 4.0
	_visual.add_child(light)
	# Sparks drifting off the bird.
	var sparks := CPUParticles3D.new()
	sparks.amount = 24
	sparks.lifetime = 0.9
	sparks.local_coords = false
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 0.35
	sparks.direction = Vector3.UP
	sparks.spread = 50.0
	sparks.gravity = Vector3(0, 1.2, 0)
	sparks.initial_velocity_min = 0.2
	sparks.initial_velocity_max = 0.8
	sparks.scale_amount_min = 0.6
	sparks.scale_amount_max = 1.2
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.1, 0.1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	sparks.mesh = mesh
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 0.4, 1.0))
	ramp.set_color(1, Color(1.0, 0.25, 0.05, 0.0))
	sparks.color_ramp = ramp
	_visual.add_child(sparks)


## Height of the middle of the pet (for menu framing).
func center_height() -> float:
	match kind:
		"minotaur":
			return 1.3
		"phoenix":
			return 0.1
		_:
			return 0.8


func animate(delta: float, speed: float, _grounded := true) -> void:
	_time += delta
	_phase += delta * (2.0 + speed * 1.6)
	var swing := sin(_phase) * clampf(speed / 4.0, 0.0, 1.0) * 0.7
	for n in _legs.size():
		_legs[n].rotation.x = swing * (1.0 if n % 2 == 0 else -1.0) * (1.0 if n < 2 or _legs.size() == 2 else -1.0)
	for n in _arms.size():
		_arms[n].rotation.x = -swing * (1.0 if n == 0 else -0.4) + (-0.2 if n == 1 else 0.0)
	for wing in _wings:
		var side := float(wing.get_meta("side"))
		wing.rotation.z = side * (0.15 + sin(_time * 7.0) * 0.55)
	if flies:
		_visual.position.y = sin(_time * 2.2) * 0.12
	else:
		_visual.position.y = absf(sin(_phase)) * 0.06 * clampf(speed / 4.0, 0.0, 1.0)


func _glow(instance: MeshInstance3D, color: Color, energy: float) -> void:
	var mat := instance.material_override as StandardMaterial3D
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy


func _box(parent: Node3D, box_size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = Toon.material(color)
	instance.position = pos
	parent.add_child(instance)
	return instance


## A limb pivots at its top (hip or shoulder).
func _limb(pivot_pos: Vector3, box_size: Vector3, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_pos
	_visual.add_child(pivot)
	_box(pivot, box_size, Vector3(0, -box_size.y * 0.5, 0), color)
	return pivot
