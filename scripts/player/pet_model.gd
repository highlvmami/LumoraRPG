## Blocky pet built from boxes, facing +Z: the bear, fox and unicorn (walk on
## four legs), the frog (hops), the turtle (plods under its shell), the
## minotaur (a bull-headed fighter with an axe), the owl and the baby dragon
## (fly with flapping wings) and the phoenix (a glowing fire bird with a
## trail of sparks).
## `animate` moves legs or wings from the walking speed.
extends Node3D

const Toon := preload("res://scripts/core/toon.gd")

## Pets that fly (the follower keeps them up in the air).
const FLYERS := ["phoenix", "owl", "dragon"]

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
	flies = FLYERS.has(kind_id)
	_visual = Node3D.new()
	add_child(_visual)
	match kind_id:
		"minotaur":
			_build_minotaur()
		"phoenix":
			_build_phoenix()
		"fox":
			_build_fox()
		"frog":
			_build_frog()
		"owl":
			_build_owl()
		"turtle":
			_build_turtle()
		"unicorn":
			_build_unicorn()
		"dragon":
			_build_dragon()
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


func _build_fox() -> void:
	var fur := Color("#e8742a")
	var white := Color("#f6efe4")
	var dark := Color("#2a1d17")
	_box(_visual, Vector3(0.6, 0.5, 1.0), Vector3(0, 0.62, 0), fur)
	_box(_visual, Vector3(0.44, 0.22, 0.7), Vector3(0, 0.44, 0.08), white)
	_box(_visual, Vector3(0.52, 0.46, 0.46), Vector3(0, 0.92, 0.62), fur)
	_box(_visual, Vector3(0.26, 0.2, 0.26), Vector3(0, 0.84, 0.92), white)
	_box(_visual, Vector3(0.1, 0.08, 0.06), Vector3(0, 0.88, 1.06), dark)
	for x in [-0.13, 0.13]:
		_box(_visual, Vector3(0.08, 0.08, 0.03), Vector3(x, 1.0, 0.86), dark)
		var ear := _box(_visual, Vector3(0.16, 0.26, 0.08), Vector3(x * 1.4, 1.26, 0.56), fur)
		_box(ear, Vector3(0.08, 0.14, 0.02), Vector3(0, -0.02, 0.05), dark)
	# A big bushy tail with a white tip.
	var tail := Node3D.new()
	tail.position = Vector3(0, 0.75, -0.5)
	tail.rotation.x = 0.7
	_visual.add_child(tail)
	_box(tail, Vector3(0.3, 0.3, 0.6), Vector3(0, 0, -0.3), fur)
	_box(tail, Vector3(0.26, 0.26, 0.2), Vector3(0, 0, -0.68), white)
	for at: Vector2 in [Vector2(-0.18, 0.32), Vector2(0.18, 0.32), Vector2(-0.18, -0.32), Vector2(0.18, -0.32)]:
		var leg := _limb(Vector3(at.x, 0.42, at.y), Vector3(0.14, 0.42, 0.16), fur.darkened(0.1))
		_box(leg, Vector3(0.15, 0.1, 0.17), Vector3(0, -0.38, 0), dark)
		_legs.append(leg)


func _build_frog() -> void:
	var green := Color("#5cc85a")
	var belly := Color("#d9f0a3")
	_box(_visual, Vector3(0.8, 0.42, 0.8), Vector3(0, 0.38, 0), green)
	_box(_visual, Vector3(0.6, 0.12, 0.6), Vector3(0, 0.2, 0.06), belly)
	_box(_visual, Vector3(0.7, 0.08, 0.06), Vector3(0, 0.36, 0.41), Color("#2b6b2a"))
	for x in [-0.22, 0.22]:
		# Big round eyes on top.
		_box(_visual, Vector3(0.24, 0.22, 0.24), Vector3(x, 0.66, 0.24), green)
		_box(_visual, Vector3(0.2, 0.18, 0.04), Vector3(x, 0.68, 0.37), Color("#ffffff"))
		_box(_visual, Vector3(0.1, 0.12, 0.03), Vector3(x, 0.68, 0.4), Color("#1a1a1a"))
		_box(_visual, Vector3(0.08, 0.04, 0.04), Vector3(x * 1.2, 0.36, 0.42), Color("#ff8fa3"))
	for at: Vector2 in [Vector2(-0.38, 0.25), Vector2(0.38, 0.25), Vector2(-0.4, -0.25), Vector2(0.4, -0.25)]:
		var leg := _limb(Vector3(at.x, 0.28, at.y), Vector3(0.16, 0.28, 0.22), green.darkened(0.15))
		_box(leg, Vector3(0.26, 0.06, 0.3), Vector3(0, -0.26, 0.04), green.darkened(0.25))
		_legs.append(leg)


func _build_owl() -> void:
	var brown := Color("#8b6a4a")
	var cream := Color("#f0dfbf")
	var gold := Color("#ffc533")
	_box(_visual, Vector3(0.6, 0.7, 0.5), Vector3(0, 0, 0), brown)
	_box(_visual, Vector3(0.44, 0.44, 0.06), Vector3(0, -0.08, 0.25), cream)
	_box(_visual, Vector3(0.58, 0.46, 0.5), Vector3(0, 0.52, 0.02), brown)
	for x in [-0.14, 0.14]:
		_box(_visual, Vector3(0.22, 0.22, 0.04), Vector3(x, 0.54, 0.28), cream)
		_glow(_box(_visual, Vector3(0.12, 0.12, 0.03), Vector3(x, 0.54, 0.31), gold), gold, 0.6)
		_box(_visual, Vector3(0.06, 0.06, 0.02), Vector3(x, 0.54, 0.33), Color("#1a1a1a"))
		var tuft := _box(_visual, Vector3(0.1, 0.22, 0.1), Vector3(x * 1.8, 0.84, 0), brown.darkened(0.2))
		tuft.rotation.z = -signf(x) * 0.35
	_box(_visual, Vector3(0.1, 0.12, 0.08), Vector3(0, 0.42, 0.3), Color("#e0a030"))
	for x in [-0.12, 0.12]:
		_box(_visual, Vector3(0.12, 0.08, 0.16), Vector3(x, -0.38, 0.06), Color("#e0a030"))
	for side in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(side * 0.3, 0.12, 0)
		_visual.add_child(wing)
		_box(wing, Vector3(0.6, 0.06, 0.42), Vector3(side * 0.3, 0, -0.02), brown.darkened(0.15))
		_box(wing, Vector3(0.36, 0.05, 0.3), Vector3(side * 0.7, 0, -0.06), cream.darkened(0.2))
		wing.set_meta("side", side)
		_wings.append(wing)


func _build_turtle() -> void:
	var skin := Color("#8bbf5a")
	var shell := Color("#5a7a3a")
	var rim := Color("#c9a86a")
	_box(_visual, Vector3(1.0, 0.18, 1.2), Vector3(0, 0.42, 0), rim)
	_box(_visual, Vector3(0.9, 0.36, 1.06), Vector3(0, 0.66, 0), shell)
	_box(_visual, Vector3(0.6, 0.18, 0.7), Vector3(0, 0.9, 0), shell.lightened(0.12))
	# Shell plates.
	for at: Vector2 in [Vector2(-0.22, 0.25), Vector2(0.22, 0.25), Vector2(-0.22, -0.25), Vector2(0.22, -0.25), Vector2(0, 0)]:
		_box(_visual, Vector3(0.2, 0.04, 0.2), Vector3(at.x, 1.0, at.y), shell.darkened(0.25))
	_box(_visual, Vector3(0.22, 0.14, 0.12), Vector3(0.12, 1.02, -0.3), Color("#4fbf6a"))
	_box(_visual, Vector3(0.38, 0.32, 0.42), Vector3(0, 0.58, 0.74), skin)
	for x in [-0.12, 0.12]:
		_box(_visual, Vector3(0.07, 0.07, 0.03), Vector3(x, 0.66, 0.96), Color("#1a1a1a"))
	_box(_visual, Vector3(0.16, 0.03, 0.03), Vector3(0, 0.52, 0.96), Color("#3a5a2a"))
	for at: Vector2 in [Vector2(-0.4, 0.4), Vector2(0.4, 0.4), Vector2(-0.4, -0.4), Vector2(0.4, -0.4)]:
		_legs.append(_limb(Vector3(at.x, 0.36, at.y), Vector3(0.24, 0.3, 0.24), skin.darkened(0.1)))


func _build_unicorn() -> void:
	var white := Color("#f7f4ff")
	var mane := [Color("#ff8fd0"), Color("#b98cff"), Color("#7fd8ff")]
	_box(_visual, Vector3(0.62, 0.6, 1.1), Vector3(0, 0.95, 0), white)
	var neck := _box(_visual, Vector3(0.36, 0.6, 0.36), Vector3(0, 1.35, 0.5), white)
	neck.rotation.x = 0.35
	_box(_visual, Vector3(0.4, 0.4, 0.6), Vector3(0, 1.62, 0.78), white)
	_box(_visual, Vector3(0.34, 0.2, 0.2), Vector3(0, 1.52, 1.08), Color("#ffd9ec"))
	for x in [-0.12, 0.12]:
		_box(_visual, Vector3(0.07, 0.09, 0.03), Vector3(x, 1.7, 1.05), Color("#3a2a5a"))
		_box(_visual, Vector3(0.1, 0.18, 0.08), Vector3(x, 1.9, 0.62), white.darkened(0.08))
	var horn := _box(_visual, Vector3(0.09, 0.42, 0.09), Vector3(0, 2.0, 0.88), Color("#ffe066"))
	horn.rotation.x = 0.45
	_glow(horn, Color("#ffe066"), 0.9)
	for n in 3:
		_glow(_box(_visual, Vector3(0.1, 0.22, 0.16), Vector3(0, 1.82 - n * 0.2, 0.5 - n * 0.14), mane[n]), mane[n], 0.35)
	var tail := Node3D.new()
	tail.position = Vector3(0, 1.1, -0.56)
	tail.rotation.x = -0.6
	_visual.add_child(tail)
	for n in 3:
		_glow(_box(tail, Vector3(0.14, 0.14, 0.24), Vector3(0, 0, -0.12 - n * 0.2), mane[n]), mane[n], 0.35)
	for at: Vector2 in [Vector2(-0.2, 0.38), Vector2(0.2, 0.38), Vector2(-0.2, -0.38), Vector2(0.2, -0.38)]:
		var leg := _limb(Vector3(at.x, 0.7, at.y), Vector3(0.16, 0.7, 0.18), white.darkened(0.05))
		_box(leg, Vector3(0.18, 0.1, 0.2), Vector3(0, -0.66, 0), Color("#d9b8ff"))
		_legs.append(leg)
	var light := OmniLight3D.new()
	light.light_color = Color("#ffd9ff")
	light.light_energy = 0.4
	light.omni_range = 2.5
	light.position = Vector3(0, 2.0, 0.8)
	_visual.add_child(light)


func _build_dragon() -> void:
	var scale_color := Color("#3fae6a")
	var belly := Color("#ffd27a")
	var horn := Color("#f4f1e6")
	_box(_visual, Vector3(0.5, 0.46, 0.8), Vector3(0, 0, 0), scale_color)
	_box(_visual, Vector3(0.36, 0.3, 0.6), Vector3(0, -0.1, 0.06), belly)
	_box(_visual, Vector3(0.44, 0.4, 0.44), Vector3(0, 0.3, 0.5), scale_color)
	_box(_visual, Vector3(0.3, 0.2, 0.24), Vector3(0, 0.22, 0.8), scale_color.lightened(0.1))
	for x in [-0.1, 0.1]:
		_box(_visual, Vector3(0.05, 0.04, 0.03), Vector3(x, 0.26, 0.93), Color("#1a1a1a"))
		_glow(_box(_visual, Vector3(0.08, 0.08, 0.03), Vector3(x * 1.4, 0.4, 0.72), Color("#ffe14d")), Color("#ffe14d"), 0.6)
		var h := _box(_visual, Vector3(0.07, 0.24, 0.07), Vector3(x * 1.6, 0.56, 0.38), horn)
		h.rotation.x = -0.5
	# Spikes down the back and a tail ending in a spade.
	for n in 3:
		_box(_visual, Vector3(0.06, 0.12, 0.1), Vector3(0, 0.28, 0.2 - n * 0.24), Color("#2a7a4a"))
	var tail := Node3D.new()
	tail.position = Vector3(0, -0.05, -0.38)
	tail.rotation.x = 0.3
	_visual.add_child(tail)
	_box(tail, Vector3(0.18, 0.16, 0.6), Vector3(0, 0, -0.3), scale_color)
	var spade := _box(tail, Vector3(0.26, 0.06, 0.2), Vector3(0, 0, -0.66), Color("#2a7a4a"))
	spade.rotation.y = 0.78
	for side in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(side * 0.22, 0.18, 0)
		_visual.add_child(wing)
		_box(wing, Vector3(0.5, 0.05, 0.4), Vector3(side * 0.26, 0, 0), Color("#2a7a4a"))
		_box(wing, Vector3(0.4, 0.04, 0.32), Vector3(side * 0.66, 0, -0.08), Color("#8fe3a0"))
		wing.set_meta("side", side)
		_wings.append(wing)
	for at: Vector2 in [Vector2(-0.18, 0.22), Vector2(0.18, 0.22), Vector2(-0.18, -0.22), Vector2(0.18, -0.22)]:
		_legs.append(_limb(Vector3(at.x, -0.18, at.y), Vector3(0.12, 0.2, 0.14), scale_color.darkened(0.15)))


## Height of the middle of the pet (for menu framing).
func center_height() -> float:
	match kind:
		"minotaur":
			return 1.3
		"phoenix", "owl", "dragon":
			return 0.1
		"unicorn":
			return 1.2
		"frog":
			return 0.4
		"fox", "turtle":
			return 0.65
		_:
			return 0.8


## How far a camera stands to frame the whole pet.
func view_distance() -> float:
	match kind:
		"minotaur", "unicorn", "dragon":
			return 4.6
		"phoenix":
			return 5.2
		"owl":
			return 3.6
		"frog":
			return 3.0
		_:
			return 3.8


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
	elif kind == "frog":
		_visual.position.y = absf(sin(_phase * 0.5)) * 0.35 * clampf(speed / 4.0, 0.0, 1.0)
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
