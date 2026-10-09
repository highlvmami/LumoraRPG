## The grounds around the hub tavern: a quiet evening meadow under the stars.
## A cobbled path leads from the tavern door to a little square with a
## wishing well; west of it a campfire with log seats, east a pond with a
## fishing dock, ducks and lily pads. Beside the tavern there is a fenced
## vegetable garden with a scarecrow and a woodpile, and trees all around
## keep everyone inside. Fireflies drift over the grass, chimney smoke rises
## and far hills fade into the evening haze.
##
## Built as a child of the HubWorld at its origin, so positions here are the
## same local coordinates as the tavern's (door at z = +12, outside is +z).
extends Node3D

const Toon := preload("res://scripts/core/toon.gd")

## The walkable meadow ends here (invisible walls behind the trees).
const BOUND := 46.0
## The tavern's size (as in HubWorld).
const HALF := Vector2(15.0, 12.0)
const HEIGHT := 7.0
const WELL := Vector3(0, 0, 28)
const CAMPFIRE := Vector3(-17, 0, 26)
const POND := Vector3(19, 0, 25)
const POND_RADIUS := 6.0
const GARDEN := Rect2(-31, -3, 11, 13)

var _hub: Node3D
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _colliders: StaticBody3D
var _fireflies: MultiMesh
var _firefly_base: Array = []
var _campfire_light: OmniLight3D
var _campfire_flames: CPUParticles3D
var _campfire_boost := 0.0
var _ducks: Array = []
var _lamps: Array = []
## Places trees and grass keep out of: Vector3(x, z, radius).
var _clear: Array = []


func build(hub: Node3D) -> void:
	_hub = hub
	_rng.seed = 2024
	_colliders = StaticBody3D.new()
	add_child(_colliders)
	_clear = [Vector3(WELL.x, WELL.z, 5.5), Vector3(CAMPFIRE.x, CAMPFIRE.z, 5.5), Vector3(POND.x, POND.z, POND_RADIUS + 2.5)]
	_ground()
	_roof()
	_front()
	_paths()
	_well()
	_campfire()
	_pond()
	_garden()
	_yard()
	_trees()
	_ground_cover()
	_far_away()
	_build_fireflies()
	_bounds()


## Flares the campfire up for a moment.
func poke_fire() -> void:
	_campfire_boost = 1.0


func _process(delta: float) -> void:
	_time += delta
	_campfire_boost = maxf(0.0, _campfire_boost - delta * 0.6)
	if _campfire_light:
		_campfire_light.light_energy = 1.6 + sin(_time * 7.0) * 0.2 + sin(_time * 17.0) * 0.1 + _campfire_boost * 1.6
		_campfire_flames.scale_amount_max = 1.6 + _campfire_boost * 1.4
	for i in _ducks.size():
		var duck: Node3D = _ducks[i]
		var angle := _time * (0.12 + i * 0.05) + i * 2.4
		var r := 2.4 + i * 1.3
		duck.position = POND + Vector3(cos(angle) * r, 0.05 + sin(_time * 2.0 + i) * 0.02, sin(angle) * r)
		duck.rotation.y = -angle
	for i in _lamps.size():
		(_lamps[i] as OmniLight3D).light_energy = 1.1 + sin(_time * 2.3 + i * 1.7) * 0.05
	if _fireflies:
		for i in _firefly_base.size():
			var b: Vector4 = _firefly_base[i]
			var t := _time * 0.5 + b.w
			var at := Vector3(b.x + sin(t * 1.3) * 1.2, b.y + sin(t * 2.1) * 0.35, b.z + cos(t * 0.9) * 1.2)
			_fireflies.set_instance_transform(i, Transform3D(Basis(), at))
			var glow := 0.4 + 0.6 * maxf(0.0, sin(t * 3.0 + b.w * 5.0))
			_fireflies.set_instance_color(i, Color(0.8 * glow + 0.15, 1.0 * glow + 0.1, 0.35 * glow, 1.0))


# --- Ground ---------------------------------------------------------------------

## Grass in 10 m tiles (the browser renderer lights each mesh with its few
## nearest lamps, so many small tiles catch the lamp light better than one).
func _ground() -> void:
	var greens := [Color("#3d6b35"), Color("#416f38"), Color("#3a6632"), Color("#44733a")]
	var n := int(BOUND / 5.0) + 2
	for ix in range(-n, n):
		for iz in range(-n, n):
			var c: Color = greens[(ix * 7 + iz * 3 + 40) % greens.size()]
			_box(Vector3(10.0, 0.2, 10.0), Vector3(ix * 10.0 + 5.0, -0.11, iz * 10.0 + 5.0), c)
	_hub._collider(Vector3(BOUND * 2.0 + 20.0, 1.0, BOUND * 2.0 + 20.0), Vector3(0, -0.5, 0))


# --- The tavern from outside ----------------------------------------------------

func _roof() -> void:
	var hx: float = HALF.x + 0.4
	var hz: float = HALF.y + 0.4
	var base: float = HEIGHT + 0.4
	var ridge := Vector3(0, base + 4.0, 0)
	var shingles := [Color("#7a3b2e"), Color("#6a3226")]
	for side in [-1.0, 1.0]:
		var eave := Vector3(0, base - 0.25, side * (hz + 1.2))
		var length := ridge.distance_to(eave)
		var angle := atan2(ridge.y - eave.y, absf(eave.z))
		var rows := 7
		for r in rows:
			var t := (r + 0.5) / rows
			var row := _box(Vector3(hx * 2.0 + 1.6, 0.32, length / rows + 0.12), ridge.lerp(eave, t) + Vector3(0, 0.02 * r, 0), shingles[r % 2])
			row.rotation.x = angle * side
	_box(Vector3(hx * 2.0 + 2.0, 0.45, 0.5), ridge + Vector3(0, 0.15, 0), Color("#4e2a1e"))
	# Stepped gable ends with a round glowing window.
	var wall := Color("#5e3f26")
	var steps := 8
	for side in [-1.0, 1.0]:
		for k in steps:
			var w := 2.0 * hz * (1.0 - (k + 0.5) / steps)
			_box(Vector3(0.4, 4.0 / steps + 0.02, w), Vector3(side * (hx - 0.2), base + 4.0 / steps * (k + 0.5), 0), wall)
		_box(Vector3(0.1, 1.0, 1.0), Vector3(side * (hx + 0.02), base + 1.4, 0), Color("#ffe29a"), Color("#ffb23f"))
		_box(Vector3(0.08, 1.2, 1.2), Vector3(side * (hx + 0.0), base + 1.4, 0), Color("#3a2414"))
	# The chimney over the fireplace, with smoke curling up.
	var chimney := Vector3(-9.0, 0, -HALF.y + 0.9)
	var stone := Color("#7a7470")
	_box(Vector3(1.8, 7.0, 1.8), chimney + Vector3(0, base + 2.6, 0), stone)
	_box(Vector3(2.1, 0.35, 2.1), chimney + Vector3(0, base + 6.2, 0), stone.darkened(0.25))
	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mat.vertex_color_use_as_albedo = true
	smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	quad.material = smoke_mat
	var fade := Gradient.new()
	fade.set_color(0, Color(0.55, 0.55, 0.6, 0.45))
	fade.set_color(1, Color(0.4, 0.4, 0.48, 0.0))
	var smoke := CPUParticles3D.new()
	smoke.mesh = quad
	smoke.amount = 18
	smoke.lifetime = 6.0
	smoke.direction = Vector3(0.2, 1, 0)
	smoke.spread = 12.0
	smoke.gravity = Vector3(0.12, 0.15, 0)
	smoke.initial_velocity_min = 0.5
	smoke.initial_velocity_max = 0.8
	smoke.scale_amount_min = 1.0
	smoke.scale_amount_max = 2.6
	smoke.color_ramp = fade
	smoke.position = chimney + Vector3(0, base + 6.5, 0)
	add_child(smoke)


## The front: open double doors, a porch roof on posts, a hanging sign,
## lanterns by the door, glowing windows with shutters and flower boxes.
func _front() -> void:
	var z: float = HALF.y + 0.4
	var dark := Color("#4e321d")
	var wood := Color("#6b4423")
	for side in [-1.0, 1.0]:
		var leaf := _box(Vector3(1.2, 3.2, 0.12), Vector3(side * 1.25, 1.6, z + 0.6), wood)
		leaf.rotation.y = side * PI * 0.5
		leaf.position = Vector3(side * 1.3, 1.6, z + 0.62)
		_box(Vector3(0.06, 0.06, 0.08), Vector3(side * 1.38, 1.5, z + 0.95), Color("#d9a520"))
	# Porch: planks, posts and a sloping roof.
	_box(Vector3(9.0, 0.03, 3.4), Vector3(0, 0.0, z + 1.7), Color("#7a5232"))
	for n in 6:
		_box(Vector3(9.0, 0.032, 0.04), Vector3(0, 0.0, z + 0.3 + n * 0.56), dark)
	for px in [-4.2, 4.2]:
		_solid(Vector3(0.28, 3.9, 0.28), Vector3(px, 1.95, z + 3.2), dark)
	var awning := _box(Vector3(9.6, 0.22, 3.8), Vector3(0, 4.15, z + 1.75), Color("#6a3226"))
	awning.rotation.x = 0.16
	# The sign over the door.
	_box(Vector3(0.08, 0.6, 0.08), Vector3(-1.4, 3.9, z + 0.9), dark)
	_box(Vector3(0.08, 0.6, 0.08), Vector3(1.4, 3.9, z + 0.9), dark)
	_box(Vector3(3.6, 0.9, 0.14), Vector3(0, 3.45, z + 0.9), Color("#8d5f38"))
	_box(Vector3(3.8, 1.05, 0.1), Vector3(0, 3.45, z + 0.86), dark)
	var sign := Label3D.new()
	sign.text = "LUMORA TAVERNASI"
	sign.font_size = 64
	sign.pixel_size = 0.0045
	sign.outline_size = 10
	sign.modulate = Color("#ffd866")
	sign.outline_modulate = Color("#2a1a0e")
	sign.position = Vector3(0, 3.45, z + 0.98)
	add_child(sign)
	# Wall lanterns either side of the door.
	for side in [-1.0, 1.0]:
		_box(Vector3(0.1, 0.1, 0.4), Vector3(side * 2.0, 2.9, z + 0.2), dark)
		_box(Vector3(0.32, 0.42, 0.32), Vector3(side * 2.0, 2.6, z + 0.42), Color("#ffd866"), Color("#ffb23f"))
	_lamp(Vector3(0, 2.6, z + 1.4), 1.0, 9.0)
	# Windows seen from outside.
	for wx in [-6.0, 6.0]:
		_box(Vector3(2.0, 1.6, 0.06), Vector3(wx, 3.0, z + 0.03), Color("#ffe29a"), Color("#ffb23f"))
		_box(Vector3(2.0, 0.08, 0.08), Vector3(wx, 3.0, z + 0.07), dark)
		_box(Vector3(0.08, 1.6, 0.08), Vector3(wx, 3.0, z + 0.07), dark)
		for side in [-1.0, 1.0]:
			_box(Vector3(0.55, 1.75, 0.08), Vector3(wx + side * 1.32, 3.0, z + 0.06), Color("#3f6e5a"))
		_window_box(Vector3(wx, 1.95, z + 0.25))
	for w: Vector2 in [Vector2(-1, -4), Vector2(-1, 2), Vector2(1, -6), Vector2(1, 7)]:
		var x := w.x * (HALF.x + 0.4)
		_box(Vector3(0.06, 1.6, 2.0), Vector3(x + w.x * 0.03, 3.0, w.y), Color("#ffe29a"), Color("#ffb23f"))
		_box(Vector3(0.08, 1.6, 0.08), Vector3(x + w.x * 0.07, 3.0, w.y), dark)
		for side in [-1.0, 1.0]:
			_box(Vector3(0.08, 1.75, 0.55), Vector3(x + w.x * 0.06, 3.0, w.y + side * 1.32), Color("#3f6e5a"))
	# Barrels and a bench on the porch.
	for b: Vector3 in [Vector3(-3.4, 0, z + 0.7), Vector3(-3.6, 0, z + 1.6), Vector3(3.5, 0, z + 0.7)]:
		_solid(Vector3(0.8, 1.0, 0.8), b + Vector3(0, 0.5, 0), Color("#8a5a2b"))
		_box(Vector3(0.84, 0.07, 0.84), b + Vector3(0, 0.75, 0), Color("#3a3a3a"))
	_hub._bench(Vector3(-6.5, 0, z + 1.4), 0.0)
	_hub._bench(Vector3(6.5, 0, z + 1.4), 0.0)


func _window_box(at: Vector3) -> void:
	_box(Vector3(2.1, 0.32, 0.4), at, Color("#6b4423"))
	var colors := [Color("#ff7aa8"), Color("#ffd23f"), Color("#ffffff"), Color("#c07aff")]
	for n in 7:
		_box(Vector3(0.16, 0.2, 0.16), at + Vector3(-0.9 + n * 0.3, 0.28, 0), Color("#3f8f46"))
		_box(Vector3(0.14, 0.14, 0.14), at + Vector3(-0.9 + n * 0.3, 0.42, 0.02), colors[n % colors.size()])


## A street lamp: post, arm and a glowing lantern with a soft light.
func _lamppost(at: Vector3, arm := 1.0) -> void:
	var iron := Color("#2e2e34")
	_solid(Vector3(0.18, 3.2, 0.18), at + Vector3(0, 1.6, 0), iron)
	_box(Vector3(0.36, 0.2, 0.36), at + Vector3(0, 0.1, 0), iron)
	_box(Vector3(0.7, 0.08, 0.08), at + Vector3(arm * 0.3, 3.1, 0), iron)
	_box(Vector3(0.34, 0.44, 0.34), at + Vector3(arm * 0.6, 2.75, 0), Color("#ffd866"), Color("#ffb23f"))
	_box(Vector3(0.42, 0.08, 0.42), at + Vector3(arm * 0.6, 3.0, 0), iron)
	_lamp(at + Vector3(arm * 0.6, 2.6, 0), 1.1, 9.0)


func _lamp(at: Vector3, energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color("#ffc880")
	light.light_energy = energy
	light.omni_range = reach
	light.position = at
	add_child(light)
	_lamps.append(light)


# --- Paths and the square -------------------------------------------------------

func _paths() -> void:
	var door := Vector2(0, HALF.y + 3.6)
	_stones(door, Vector2(WELL.x, WELL.z - 4.0), 2.6)
	_stones(Vector2(WELL.x - 4.0, WELL.z - 1.0), Vector2(CAMPFIRE.x + 3.5, CAMPFIRE.z), 1.8)
	_stones(Vector2(WELL.x + 4.0, WELL.z - 1.0), Vector2(POND.x - POND_RADIUS - 1.0, POND.z), 1.8)
	_stones(Vector2(-3.0, HALF.y + 3.0), Vector2(GARDEN.end.x + 1.0, GARDEN.get_center().y), 1.4)
	# The round square around the well.
	var xforms: Array = []
	var colors: Array = []
	for ring in range(1, 9):
		var r := ring * 0.55
		var count := int(TAU * r / 0.55)
		for k in count:
			var a := TAU * k / count + ring * 0.3
			_stone(Vector2(WELL.x + cos(a) * r, WELL.z + sin(a) * r), xforms, colors)
	_multi(_box_mesh(Vector3(0.48, 0.06, 0.48)), xforms, colors)
	_lamppost(Vector3(-2.4, 0, 17.5), 1.0)
	_lamppost(Vector3(2.4, 0, 22.5), -1.0)
	_lamppost(Vector3(-5.2, 0, 31.5), 1.0)
	_lamppost(Vector3(5.2, 0, 31.5), -1.0)


## Cobblestones from a to b.
func _stones(a: Vector2, b: Vector2, width: float) -> void:
	var xforms: Array = []
	var colors: Array = []
	var dir := (b - a).normalized()
	var across := Vector2(-dir.y, dir.x)
	var length := a.distance_to(b)
	var along := 0.0
	while along < length:
		var w := -width * 0.5 + 0.25
		while w < width * 0.5:
			var at := a + dir * along + across * w + Vector2(_rng.randf_range(-0.08, 0.08), _rng.randf_range(-0.08, 0.08))
			_stone(at, xforms, colors)
			w += 0.55
		along += 0.55
	_multi(_box_mesh(Vector3(0.48, 0.06, 0.48)), xforms, colors)


func _stone(at: Vector2, xforms: Array, colors: Array) -> void:
	var s := _rng.randf_range(0.75, 1.05)
	var basis := Basis(Vector3.UP, _rng.randf_range(-0.3, 0.3)).scaled(Vector3(s, 1.0, s * _rng.randf_range(0.85, 1.1)))
	xforms.append(Transform3D(basis, Vector3(at.x, 0.0, at.y)))
	var g := _rng.randf_range(0.42, 0.58)
	colors.append(Color(g, g * 0.97, g * 0.93))


# --- The wishing well -----------------------------------------------------------

func _well() -> void:
	var stone := Color("#8a8580")
	for k in 10:
		var a := TAU * k / 10.0
		var block := _box(Vector3(0.75, 0.9, 0.42), WELL + Vector3(cos(a) * 1.05, 0.45, sin(a) * 1.05), stone if k % 2 == 0 else stone.darkened(0.12))
		block.rotation.y = -a + PI * 0.5
	_box(Vector3(1.7, 0.05, 1.7), WELL + Vector3(0, 0.6, 0), Color("#1d3a5a"), Color("#1d3a5a"))
	_hub._collider(Vector3(2.5, 1.2, 2.5), WELL + Vector3(0, 0.6, 0))
	var wood := Color("#5a381c")
	for side in [-1.0, 1.0]:
		_box(Vector3(0.2, 2.4, 0.2), WELL + Vector3(side * 1.1, 1.6, 0), wood)
		var roof := _box(Vector3(1.6, 0.12, 2.6), WELL + Vector3(side * 0.62, 2.95, 0), Color("#7a3b2e"))
		roof.rotation.z = -side * 0.6
	_box(Vector3(2.3, 0.1, 0.1), WELL + Vector3(0, 2.2, 0), wood)
	_box(Vector3(0.04, 0.9, 0.04), WELL + Vector3(0, 1.75, 0), Color("#c9b58a"))
	_box(Vector3(0.32, 0.3, 0.32), WELL + Vector3(0, 1.2, 0), Color("#8d5f38"))
	_box(Vector3(0.1, 0.4, 0.06), WELL + Vector3(1.25, 2.0, 0.15), wood)
	_hub.interactables.append({"kind": "well", "label": "Kuyuya dilek tut", "pos": _hub.to_global(WELL), "yaw": 0.0, "radius": 0.0})
	# Flower beds around the square.
	for k in 6:
		var a := TAU * k / 6.0 + 0.5
		var at := WELL + Vector3(cos(a) * 5.3, 0, sin(a) * 5.3)
		if absf(at.x) < 2.0 and at.z < WELL.z:
			continue
		_flower_patch(at, 0.9)


func _flower_patch(at: Vector3, radius: float) -> void:
	var colors := [Color("#ff7aa8"), Color("#ffd23f"), Color("#f4f0ff"), Color("#9a7aff"), Color("#ff9a4a")]
	var c: Color = colors[_rng.randi() % colors.size()]
	for n in 9:
		var p := at + Vector3(_rng.randf_range(-radius, radius), 0, _rng.randf_range(-radius, radius))
		_box(Vector3(0.05, 0.3, 0.05), p + Vector3(0, 0.15, 0), Color("#3f7d36"))
		_box(Vector3(0.16, 0.12, 0.16), p + Vector3(0, 0.34, 0), c)


# --- Campfire -------------------------------------------------------------------

func _campfire() -> void:
	var stone := Color("#7a7470")
	for k in 9:
		var a := TAU * k / 9.0
		_box(Vector3(0.35, 0.25, 0.3), CAMPFIRE + Vector3(cos(a) * 0.75, 0.12, sin(a) * 0.75), stone.darkened(0.1 * (k % 3)))
	for k in 3:
		var log := _box(Vector3(1.1, 0.16, 0.16), CAMPFIRE + Vector3(0, 0.12, 0), Color("#5a3a20"))
		log.rotation = Vector3(0, k * PI / 3.0, 0.15)
	_box(Vector3(0.6, 0.06, 0.6), CAMPFIRE + Vector3(0, 0.05, 0), Color("#ff7a1f"), Color("#ff5a1a"))
	var flame_mat := StandardMaterial3D.new()
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.vertex_color_use_as_albedo = true
	flame_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var quad := QuadMesh.new()
	quad.size = Vector2(0.45, 0.45)
	quad.material = flame_mat
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.3, 1.0))
	ramp.set_color(1, Color(0.9, 0.2, 0.05, 0.0))
	var fire := CPUParticles3D.new()
	fire.mesh = quad
	fire.amount = 26
	fire.lifetime = 0.8
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 0.3
	fire.direction = Vector3.UP
	fire.spread = 15.0
	fire.gravity = Vector3(0, 1.5, 0)
	fire.initial_velocity_min = 0.6
	fire.initial_velocity_max = 1.3
	fire.scale_amount_min = 0.8
	fire.scale_amount_max = 1.6
	fire.color_ramp = ramp
	fire.position = CAMPFIRE + Vector3(0, 0.25, 0)
	add_child(fire)
	_campfire_flames = fire
	_campfire_light = OmniLight3D.new()
	_campfire_light.light_color = Color("#ff9a4a")
	_campfire_light.omni_range = 10.0
	_campfire_light.position = CAMPFIRE + Vector3(0, 1.0, 0)
	add_child(_campfire_light)
	_hub.interactables.append({"kind": "fire", "which": 1, "label": "Ateşe odun at", "pos": _hub.to_global(CAMPFIRE), "yaw": 0.0, "radius": 1.9, "point": true})
	# Four log seats around it, two places each, facing the fire.
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		var at := CAMPFIRE + Vector3(cos(a) * 2.7, 0, sin(a) * 2.7)
		var tangent := Vector3(-sin(a), 0, cos(a))
		var seat := _box(Vector3(2.0, 0.42, 0.5), at + Vector3(0, 0.21, 0), Color("#6b4423"))
		seat.rotation.y = -a + PI * 0.5
		for end in [-1.0, 1.0]:
			var cap := _box(Vector3(0.05, 0.38, 0.44), at + tangent * end * 1.0 + Vector3(0, 0.21, 0), Color("#c9a070"))
			cap.rotation.y = -a + PI * 0.5
		for s in [-0.5, 0.5]:
			var spot: Vector3 = at + tangent * float(s)
			var to_fire: Vector3 = CAMPFIRE - spot
			_hub._seat(spot, atan2(to_fire.x, to_fire.z), "Otur")
	# A pot on a tripod and a stack of firewood.
	for k in 3:
		var leg := _box(Vector3(0.06, 1.7, 0.06), CAMPFIRE + Vector3(cos(TAU * k / 3.0) * 0.45, 0.8, sin(TAU * k / 3.0) * 0.45), Color("#3a3a3a"))
		leg.rotation = Vector3(sin(TAU * k / 3.0) * 0.27, 0, -cos(TAU * k / 3.0) * 0.27)
	_box(Vector3(0.45, 0.35, 0.45), CAMPFIRE + Vector3(0, 0.95, 0), Color("#2e2e34"))
	for n in 5:
		var wood := _box(Vector3(0.9, 0.18, 0.18), CAMPFIRE + Vector3(-3.6, 0.1 + (n / 3) * 0.17, 1.4 + (n % 3) * 0.19 + (n / 3) * 0.1), Color("#7a5232"))
		wood.rotation.y = 0.3


# --- Pond -----------------------------------------------------------------------

func _pond() -> void:
	var water_mesh := CylinderMesh.new()
	water_mesh.top_radius = POND_RADIUS
	water_mesh.bottom_radius = POND_RADIUS
	water_mesh.height = 0.04
	water_mesh.radial_segments = 32
	var water := MeshInstance3D.new()
	water.mesh = water_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.32, 0.45, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.metallic = 0.3
	mat.roughness = 0.15
	mat.emission_enabled = true
	mat.emission = Color("#1a3550")
	mat.emission_energy_multiplier = 0.4
	water.material_override = mat
	water.position = POND + Vector3(0, 0.02, 0)
	add_child(water)
	# Stones and reeds along the edge; colliders keep people out of the
	# water except along the dock, which reaches in from the west.
	var dock_angle := PI
	var xforms: Array = []
	var colors: Array = []
	for k in 40:
		var a := TAU * k / 40.0
		var at := Vector2(POND.x + cos(a) * (POND_RADIUS + 0.15), POND.z + sin(a) * (POND_RADIUS + 0.15))
		_stone(at, xforms, colors)
	_multi(_box_mesh(Vector3(0.55, 0.14, 0.55)), xforms, colors)
	for k in 24:
		var a := TAU * (k + 0.5) / 24.0
		if absf(angle_difference(a, dock_angle)) < 0.2:
			continue
		var seg := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.4, 1.4, TAU * POND_RADIUS / 24.0 + 0.2)
		shape.shape = box
		seg.add_child(shape)
		seg.position = POND + Vector3(cos(a) * POND_RADIUS, 0.7, sin(a) * POND_RADIUS)
		seg.rotation.y = -a
		add_child(seg)
	var reed_xf: Array = []
	var reed_c: Array = []
	for k in 70:
		var a := _rng.randf() * TAU
		if absf(angle_difference(a, dock_angle)) < 0.35:
			continue
		var r := POND_RADIUS + _rng.randf_range(-0.6, 0.3)
		var h := _rng.randf_range(0.6, 1.3)
		reed_xf.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).rotated(Vector3.RIGHT, _rng.randf_range(-0.12, 0.12)).scaled(Vector3(1, h, 1)), POND + Vector3(cos(a) * r, h * 0.5, sin(a) * r)))
		reed_c.append(Color("#5f8a3a").lerp(Color("#8aa04a"), _rng.randf()))
	_multi(_box_mesh(Vector3(0.05, 1.0, 0.05)), reed_xf, reed_c)
	for n in 14:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(1.0, POND_RADIUS - 0.8)
		var pad := _box(Vector3(0.6, 0.02, 0.6), POND + Vector3(cos(a) * r, 0.05, sin(a) * r), Color("#4f8a3a"))
		pad.rotation.y = a
		if n % 3 == 0:
			_box(Vector3(0.16, 0.12, 0.16), pad.position + Vector3(0, 0.07, 0), Color("#ffb3d1"), Color("#ff7aa8"))
	# The dock: planks out over the water with rails so nobody falls in.
	var start := POND.x - POND_RADIUS - 0.6
	var end := POND.x - 1.6
	var mid := (start + end) * 0.5
	var length := end - start
	var wood := Color("#7a5232")
	var n_planks := int(length / 0.42)
	for i in n_planks:
		_box(Vector3(0.38, 0.06, 1.8), Vector3(start + 0.21 + i * 0.42, 0.05, POND.z), wood if i % 2 == 0 else wood.darkened(0.1))
	for side in [-1.0, 1.0]:
		_box(Vector3(length, 0.1, 0.1), Vector3(mid + 0.4, 0.85, POND.z + side * 0.95), Color("#4e321d"))
		_hub._collider(Vector3(length, 1.2, 0.12), Vector3(mid + 0.4, 0.6, POND.z + side * 0.95))
		for i in 4:
			_box(Vector3(0.14, 1.0, 0.14), Vector3(start + 0.8 + i * length / 3.6, 0.4, POND.z + side * 0.95), Color("#3a2414"))
	_box(Vector3(0.1, 0.1, 2.0), Vector3(end + 0.1, 0.85, POND.z), Color("#4e321d"))
	_hub._collider(Vector3(0.12, 1.2, 2.0), Vector3(end + 0.1, 0.6, POND.z))
	# Close the gaps between the rails and the shore.
	for side in [-1.0, 1.0]:
		_hub._collider(Vector3(1.2, 1.4, 0.9), Vector3(POND.x - POND_RADIUS + 0.3, 0.7, POND.z + side * 1.4))
	_lamppost(Vector3(end - 0.3, 0, POND.z - 0.95), 1.0)
	_hub.interactables.append({"kind": "fish", "label": "Balık tut", "pos": _hub.to_global(Vector3(end - 0.5, 0, POND.z)), "yaw": PI * 0.5, "radius": 0.0})
	# A bench on the far shore looking over the water.
	_hub._bench(POND + Vector3(0, 0, POND_RADIUS + 2.2), PI)
	# Ducks paddling slowly around.
	for i in 3:
		var duck := Node3D.new()
		add_child(duck)
		var body := Color("#f4f0e6") if i == 1 else Color("#8a6a4a")
		_box(Vector3(0.36, 0.22, 0.24), Vector3(0, 0.1, 0), body, Color.BLACK, duck)
		_box(Vector3(0.16, 0.18, 0.16), Vector3(0.16, 0.28, 0), Color("#2f6e4a") if i != 1 else body, Color.BLACK, duck)
		_box(Vector3(0.12, 0.05, 0.08), Vector3(0.28, 0.26, 0), Color("#ffb23f"), Color.BLACK, duck)
		_box(Vector3(0.1, 0.1, 0.18), Vector3(-0.2, 0.18, 0), body.darkened(0.15), Color.BLACK, duck)
		_ducks.append(duck)


# --- Garden and yard ------------------------------------------------------------

## A fenced vegetable garden west of the tavern, the gate facing the path.
func _garden() -> void:
	var r := GARDEN
	var fence := Color("#8a6a3a")
	var gate_z := r.get_center().y
	# Fence rails with colliders; a gap on the east side for the gate.
	_fence(Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), fence)
	_fence(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), fence)
	_fence(Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y), fence)
	_fence(Vector2(r.end.x, r.position.y), Vector2(r.end.x, gate_z - 1.0), fence)
	_fence(Vector2(r.end.x, gate_z + 1.0), Vector2(r.end.x, r.end.y), fence)
	# Rows of soil with sprouts, cabbages and pumpkins.
	for row in 4:
		var x := r.position.x + 1.6 + row * 2.0
		_box(Vector3(1.1, 0.08, r.size.y - 2.0), Vector3(x, 0.02, r.get_center().y), Color("#5a3a22"))
		var z := r.position.y + 1.6
		var n := 0
		while z < r.end.y - 1.4:
			match row:
				0:
					_box(Vector3(0.42, 0.32, 0.42), Vector3(x, 0.22, z), Color("#ff8a2a"))
					_box(Vector3(0.06, 0.12, 0.06), Vector3(x, 0.42, z), Color("#3f7d36"))
				1:
					_box(Vector3(0.4, 0.26, 0.4), Vector3(x, 0.18, z), Color("#7ab84a"))
				_:
					_box(Vector3(0.08, 0.36, 0.08), Vector3(x - 0.15, 0.2, z), Color("#4f9a3a"))
					_box(Vector3(0.08, 0.3, 0.08), Vector3(x + 0.15, 0.18, z + 0.1), Color("#4f9a3a"))
			z += 0.9 if row < 2 else 0.6
			n += 1
	# A scarecrow.
	var at := Vector3(r.position.x + 6.6, 0, r.get_center().y - 2.0)
	_box(Vector3(0.12, 2.3, 0.12), at + Vector3(0, 1.15, 0), Color("#5a381c"))
	_box(Vector3(1.6, 0.1, 0.1), at + Vector3(0, 1.8, 0), Color("#5a381c"))
	_box(Vector3(0.6, 0.7, 0.3), at + Vector3(0, 1.6, 0), Color("#8a3a3a"))
	_box(Vector3(0.42, 0.42, 0.42), at + Vector3(0, 2.25, 0), Color("#e8d08a"))
	_box(Vector3(0.7, 0.08, 0.7), at + Vector3(0, 2.48, 0), Color("#a8822e"))
	_box(Vector3(0.36, 0.28, 0.36), at + Vector3(0, 2.64, 0), Color("#a8822e"))
	_box(Vector3(0.24, 0.12, 0.12), at + Vector3(-0.88, 1.8, 0), Color("#e8d08a"))
	_box(Vector3(0.24, 0.12, 0.12), at + Vector3(0.88, 1.8, 0), Color("#e8d08a"))
	_clear.append(Vector3(r.get_center().x, r.get_center().y, 9.0))


func _fence(a: Vector2, b: Vector2, color: Color) -> void:
	var length := a.distance_to(b)
	var mid := (a + b) * 0.5
	var along_x := absf(b.x - a.x) > absf(b.y - a.y)
	var size := Vector3(length, 0.1, 0.08) if along_x else Vector3(0.08, 0.1, length)
	for y in [0.45, 0.85]:
		_box(size, Vector3(mid.x, y, mid.y), color)
	var posts := maxi(1, int(length / 1.4))
	for i in posts + 1:
		var p := a.lerp(b, float(i) / posts)
		_box(Vector3(0.14, 1.1, 0.14), Vector3(p.x, 0.55, p.y), color.darkened(0.2))
	_hub._collider(Vector3(size.x, 1.2, size.z) + Vector3(0.1, 0, 0.1), Vector3(mid.x, 0.6, mid.y))


## East of the tavern: a woodpile, a chopping block with an axe, hay bales
## and a cart.
func _yard() -> void:
	var at := Vector3(HALF.x + 3.2, 0, -5.0)
	var log_c := Color("#7a5232")
	for layer in 4:
		for n in 6 - layer:
			_box(Vector3(0.36, 0.36, 2.2), at + Vector3(-1.0 + n * 0.4 + layer * 0.2, 0.18 + layer * 0.34, 0), log_c if (n + layer) % 2 == 0 else log_c.darkened(0.15))
	_hub._collider(Vector3(2.6, 1.4, 2.4), at + Vector3(0, 0.7, 0))
	_box(Vector3(0.7, 0.6, 0.7), at + Vector3(2.6, 0.3, 2.0), Color("#8d5f38"))
	_box(Vector3(0.06, 0.8, 0.06), at + Vector3(2.6, 0.9, 2.0), Color("#5a381c"))
	_box(Vector3(0.3, 0.2, 0.06), at + Vector3(2.72, 1.25, 2.0), Color("#c9d4e0"))
	for h: Vector3 in [Vector3(1.6, 0, 5.5), Vector3(2.8, 0, 5.8), Vector3(2.2, 0.8, 5.65)]:
		_solid(Vector3(1.2, 0.8, 0.8), at + h + Vector3(0, 0.4, 0), Color("#d9b44a"))
		_box(Vector3(1.22, 0.06, 0.82), at + h + Vector3(0, 0.4, 0), Color("#a8822e"))
	# The cart.
	var cart := at + Vector3(1.5, 0, 10.5)
	_solid(Vector3(1.8, 0.6, 3.0), cart + Vector3(0, 0.9, 0), Color("#8d5f38"))
	for side in [-1.0, 1.0]:
		var wheel := _box(Vector3(0.12, 1.1, 1.1), cart + Vector3(side * 1.0, 0.55, -0.6), Color("#5a381c"))
		wheel.rotation.x = PI * 0.25
		_box(Vector3(0.14, 0.3, 0.3), cart + Vector3(side * 1.04, 0.55, -0.6), Color("#3a3a3a"))
	_box(Vector3(0.1, 0.1, 2.2), cart + Vector3(-0.4, 0.75, 2.4), Color("#5a381c"))
	_box(Vector3(0.1, 0.1, 2.2), cart + Vector3(0.4, 0.75, 2.4), Color("#5a381c"))
	for n in 3:
		_box(Vector3(0.5, 0.5, 0.5), cart + Vector3(-0.4 + n * 0.4, 1.45, -0.6 + n * 0.5), Color("#c0504d") if n == 1 else Color("#7ab84a"))
	_clear.append(Vector3(at.x + 1.5, at.z + 4.0, 8.0))
	# Behind the tavern: stacked crates and barrels by the back wall.
	for c: Vector3 in [Vector3(4.0, 0, -13.6), Vector3(5.1, 0, -13.5), Vector3(4.5, 1.0, -13.55)]:
		_solid(Vector3(1.0, 1.0, 1.0), c + Vector3(0, 0.5, 0), Color("#8a6a3a"))
	for bx in [8.0, 8.9]:
		_solid(Vector3(0.8, 1.0, 0.8), Vector3(bx, 0.5, -13.4), Color("#8a5a2b"))


# --- Trees, grass and flowers ---------------------------------------------------

func _blocked(x: float, z: float, margin: float) -> bool:
	if absf(x) < HALF.x + 4.0 + margin and z > -HALF.y - 4.0 - margin and z < HALF.y + 5.0 + margin:
		return true
	# The path from the door to the square.
	if absf(x) < 2.5 + margin and z > 0.0 and z < WELL.z:
		return true
	if absf(z - WELL.z) < 1.8 + margin and x > CAMPFIRE.x and x < POND.x:
		return true
	for c: Vector3 in _clear:
		if Vector2(x - c.x, z - c.y).length() < c.z + margin:
			return true
	return false


func _trees() -> void:
	var trunk_xf: Array = []
	var trunk_c: Array = []
	var leaf_xf: Array = []
	var leaf_c: Array = []
	var placed := 0
	var tries := 0
	while placed < 170 and tries < 6000:
		tries += 1
		var x := _rng.randf_range(-BOUND + 1.0, BOUND - 1.0)
		var z := _rng.randf_range(-BOUND + 1.0, BOUND - 1.0)
		var edge := maxf(absf(x), absf(z))
		# Dense near the edge, a few here and there in the meadow.
		if edge < 33.0 and _rng.randf() > 0.06:
			continue
		if _blocked(x, z, 1.5):
			continue
		placed += 1
		var s := _rng.randf_range(0.85, 1.4)
		var ground := Vector3(x, 0, z)
		var pine := _rng.randf() < 0.55
		var birch := not pine and _rng.randf() < 0.3
		var trunk_h := (1.6 if pine else 2.4) * s
		trunk_xf.append(Transform3D(Basis().scaled(Vector3(0.45 * s, trunk_h, 0.45 * s)), ground + Vector3(0, trunk_h * 0.5, 0)))
		trunk_c.append(Color("#e8e4d8") if birch else Color("#5a3a22").lerp(Color("#6b4423"), _rng.randf()))
		_add_trunk_collider(ground, 0.35 * s)
		if pine:
			var green := Color("#2f5a35").lerp(Color("#3d6b3a"), _rng.randf())
			for k in 4:
				var w := (2.6 - k * 0.55) * s
				leaf_xf.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(w, 0.9 * s, w)), ground + Vector3(0, trunk_h + (0.45 + k * 0.75) * s, 0)))
				leaf_c.append(green.lightened(k * 0.04))
		else:
			var green := (Color("#7aa040") if birch else Color("#4a7a3a")).lerp(Color("#5a8a40"), _rng.randf())
			leaf_xf.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(2.6 * s, 1.8 * s, 2.6 * s)), ground + Vector3(0, trunk_h + 0.7 * s, 0)))
			leaf_c.append(green)
			leaf_xf.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(1.7 * s, 1.0 * s, 1.7 * s)), ground + Vector3(0, trunk_h + 1.9 * s, 0)))
			leaf_c.append(green.lightened(0.08))
	var cube := _box_mesh(Vector3.ONE)
	_multi(cube, trunk_xf, trunk_c)
	_multi(cube, leaf_xf, leaf_c)
	# A big old oak by the square with a lantern hanging from it.
	var oak := Vector3(-9.0, 0, 37.0)
	_box(Vector3(1.0, 3.6, 1.0), oak + Vector3(0, 1.8, 0), Color("#5a3a22"))
	_add_trunk_collider(oak, 0.6)
	_box(Vector3(5.0, 2.4, 5.0), oak + Vector3(0, 4.4, 0), Color("#3f6e34"))
	_box(Vector3(3.6, 1.4, 3.6), oak + Vector3(0.4, 6.1, 0.2), Color("#4a7a3a"))
	_box(Vector3(2.4, 0.3, 0.3), oak + Vector3(1.6, 3.3, 0), Color("#5a3a22"))
	_box(Vector3(0.04, 0.6, 0.04), oak + Vector3(2.5, 2.9, 0), Color("#2a2a2a"))
	_box(Vector3(0.3, 0.38, 0.3), oak + Vector3(2.5, 2.45, 0), Color("#ffd866"), Color("#ffb23f"))
	_hub._bench(oak + Vector3(0, 0, -2.0), PI)


func _add_trunk_collider(ground: Vector3, radius: float) -> void:
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 3.0
	shape.shape = cyl
	shape.position = ground + Vector3(0, 1.5, 0)
	_colliders.add_child(shape)


func _ground_cover() -> void:
	var tuft_xf: Array = []
	var tuft_c: Array = []
	var flower_xf: Array = []
	var flower_c: Array = []
	var petals := [Color("#ff7aa8"), Color("#ffd23f"), Color("#f4f0ff"), Color("#9a7aff"), Color("#7ac8ff")]
	for i in 1800:
		var x := _rng.randf_range(-BOUND, BOUND)
		var z := _rng.randf_range(-BOUND, BOUND)
		if absf(x) < HALF.x + 0.6 and absf(z) < HALF.y + 0.6:
			continue
		if absf(x) < 1.6 and z > 0.0 and z < WELL.z - 3.0:
			continue
		if Vector2(x - POND.x, z - POND.z).length() < POND_RADIUS + 0.4 or Vector2(x - WELL.x, z - WELL.z).length() < 4.8 or Vector2(x - CAMPFIRE.x, z - CAMPFIRE.z).length() < 3.6:
			continue
		var h := _rng.randf_range(0.18, 0.4)
		tuft_xf.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(1, h, 1)), Vector3(x, h * 0.5, z)))
		tuft_c.append(Color("#4f8a3a").lerp(Color("#7aa848"), _rng.randf()))
		if i % 5 == 0:
			flower_xf.append(Transform3D(Basis(), Vector3(x + 0.2, h + 0.06, z)))
			flower_c.append(petals[_rng.randi() % petals.size()])
	_multi(_box_mesh(Vector3(0.3, 1.0, 0.06)), tuft_xf, tuft_c)
	_multi(_box_mesh(Vector3(0.14, 0.1, 0.14)), flower_xf, flower_c)
	# Mushrooms and stones here and there.
	for n in 24:
		var x := _rng.randf_range(-BOUND + 2.0, BOUND - 2.0)
		var z := _rng.randf_range(-BOUND + 2.0, BOUND - 2.0)
		if _blocked(x, z, 0.5):
			continue
		if n % 2 == 0:
			_box(Vector3(0.08, 0.2, 0.08), Vector3(x, 0.1, z), Color("#f4ecd6"))
			_box(Vector3(0.26, 0.1, 0.26), Vector3(x, 0.24, z), Color("#c0504d"))
		else:
			var rock := _box(Vector3(0.9, 0.5, 0.7) * _rng.randf_range(0.6, 1.3), Vector3(x, 0.15, z), Color("#7a7a7a"))
			rock.rotation.y = _rng.randf() * TAU


# --- Far away -------------------------------------------------------------------

## Hills and mountains past the trees, the moon and stars.
func _far_away() -> void:
	var xf: Array = []
	var colors: Array = []
	for k in 28:
		var a := TAU * k / 28.0 + _rng.randf_range(-0.05, 0.05)
		var r := _rng.randf_range(70.0, 95.0)
		var h := _rng.randf_range(10.0, 26.0)
		var w := _rng.randf_range(24.0, 40.0)
		xf.append(Transform3D(Basis(Vector3.UP, -a).scaled(Vector3(w, h, 14.0)), Vector3(cos(a) * r, h * 0.5 - 1.0, sin(a) * r)))
		colors.append(Color("#24324a").lerp(Color("#2f3f52"), _rng.randf()))
	_multi(_box_mesh(Vector3.ONE), xf, colors)
	var sky_mat := StandardMaterial3D.new()
	sky_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sky_mat.vertex_color_use_as_albedo = true
	sky_mat.disable_fog = true
	var star_xf: Array = []
	var star_c: Array = []
	for i in 360:
		var a := _rng.randf() * TAU
		var up := _rng.randf_range(0.15, 1.0)
		var dir := Vector3(cos(a) * sqrt(1.0 - up * up), up, sin(a) * sqrt(1.0 - up * up))
		var s := _rng.randf_range(0.25, 0.7)
		star_xf.append(Transform3D(Basis().scaled(Vector3(s, s, s)), dir * 190.0))
		star_c.append(Color(1, 1, 1).lerp(Color("#bcd0ff"), _rng.randf()) * _rng.randf_range(0.6, 1.0))
	var stars := _multi(_box_mesh(Vector3.ONE), star_xf, star_c)
	stars.material_override = sky_mat
	stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var moon := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 9.0
	sphere.height = 18.0
	moon.mesh = sphere
	var moon_mat := StandardMaterial3D.new()
	moon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon_mat.albedo_color = Color("#f4ecd0")
	moon_mat.disable_fog = true
	moon.material_override = moon_mat
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	moon.position = Vector3(-90, 95, 130)
	add_child(moon)


func _build_fireflies() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	var xf: Array = []
	var colors: Array = []
	while xf.size() < 110:
		var x := _rng.randf_range(-BOUND + 3.0, BOUND - 3.0)
		var z := _rng.randf_range(-BOUND + 3.0, BOUND - 3.0)
		if absf(x) < HALF.x + 1.5 and absf(z) < HALF.y + 1.5:
			continue
		var base := Vector4(x, _rng.randf_range(0.5, 2.6), z, _rng.randf() * 20.0)
		_firefly_base.append(base)
		xf.append(Transform3D(Basis(), Vector3(base.x, base.y, base.z)))
		colors.append(Color("#d8ff6a"))
	var inst := _multi(_box_mesh(Vector3(0.09, 0.09, 0.09)), xf, colors)
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fireflies = inst.multimesh


func _bounds() -> void:
	for side in [-1.0, 1.0]:
		_hub._collider(Vector3(BOUND * 2.0, 6.0, 1.0), Vector3(0, 3.0, side * BOUND))
		_hub._collider(Vector3(1.0, 6.0, BOUND * 2.0), Vector3(side * BOUND, 3.0, 0))


# --- Pieces ---------------------------------------------------------------------

func _box(box_size: Vector3, pos: Vector3, color: Color, glow := Color.BLACK, parent: Node3D = null) -> MeshInstance3D:
	return _hub._box(box_size, pos, color, glow, parent if parent else self)


func _solid(box_size: Vector3, pos: Vector3, color: Color, glow := Color.BLACK, collide := true) -> void:
	_box(box_size, pos, color, glow)
	if collide:
		_hub._collider(box_size, pos)


func _box_mesh(box_size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	return mesh


## Many copies of one mesh in a single draw call, each with its own color.
func _multi(mesh: Mesh, xforms: Array, colors: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = Toon.material(Color.WHITE, true)
	add_child(inst)
	return inst
