## The hub: Lumora Tavernası, a big wooden tavern everyone online can walk
## around in. It stands far from the game's other maps, so its floor and walls
## are the only things around.
##
## Things to use ("interactables", pressed with E): 24 chairs around six
## tables, 5 bar stools, 2 benches by the fireplace, two swings that swing
## while someone sits on them, a dance floor and the fireplace itself.
## Positions in `interactables` are in the world (not local to the tavern).
extends Node3D

const Toon := preload("res://scripts/core/toon.gd")

## Where the tavern stands in the game world.
const ORIGIN := Vector3(2000, 0, 0)
const HALF := Vector2(15.0, 12.0)
const HEIGHT := 7.0
## A sitter's hips take this much off the standing height.
const SIT_DROP := -0.27
## How far from a thing the player can use it.
const REACH := 2.3
const SWING_LENGTH := 4.9
const SWING_SPEED := 1.5
const SWING_AMPLITUDE := 0.55

## One per usable thing: {kind, label, pos, yaw, radius, swing}.
## kind: "sit", "swing", "dance" or "fire". `pos` is where a sitter's model
## stands (for swings it moves with the swing).
var interactables: Array = []

var _swings: Array = []
var _fire_light: OmniLight3D
var _flames: Array = []
var _fire_boost := 0.0
var _tiles: Array = []
var _time := 0.0
var _lanterns: Array = []


func _init() -> void:
	position = ORIGIN


func build() -> void:
	_floor_and_walls()
	_fireplace()
	_bar()
	_tables()
	_swing_frame()
	_dance_floor()
	_decor()
	_lights()


# --- Using things ---------------------------------------------------------------

## Where to arrive: the n-th spot inside the door.
func spawn_point(n: int) -> Vector3:
	return to_global(Vector3(-6.0 + float(n % 7) * 2.0, 0.3, 9.4 - float(n / 7 % 3) * 1.4))


func facing_of(index: int) -> float:
	return float(interactables[index].yaw)


## Where the model of someone using thing `index` stands now (swings move).
func origin_of(index: int) -> Vector3:
	var d: Dictionary = interactables[index]
	if str(d.kind) == "swing":
		return _swing_origin(int(d.swing))
	return d.pos


## The nearest thing to use from a world position, or -1. Area things (the
## dance floor, the fireplace) lose against a chair or swing within reach.
func nearest(at: Vector3, reach := REACH) -> int:
	var best := -1
	var best_score := INF
	for i in interactables.size():
		var d: Dictionary = interactables[i]
		var pos: Vector3 = origin_of(i)
		var dist := Vector2(pos.x - at.x, pos.z - at.z).length()
		var area := float(d.radius) > 0.0 and str(d.kind) != "swing"
		var limit := float(d.radius) if area else maxf(reach, float(d.radius))
		if dist > limit:
			continue
		var score := dist + (4.0 if area else 0.0)
		if score < best_score:
			best_score = score
			best = i
	return best


## Where the player stands after getting up from thing `index`.
func exit_point(index: int) -> Vector3:
	var d: Dictionary = interactables[index]
	if str(d.kind) == "swing":
		var pivot: Vector3 = (_swings[int(d.swing)].pivot as Node3D).global_position
		return Vector3(pivot.x, ORIGIN.y + 0.3, pivot.z + 1.8)
	var behind := Vector3(0, 0, -0.9).rotated(Vector3.UP, float(d.yaw))
	var at: Vector3 = d.pos
	return Vector3(at.x + behind.x, ORIGIN.y + 0.3, at.z + behind.z)


## A swing swings while someone sits on it.
func set_swing_occupied(swing: int, occupied: bool) -> void:
	_swings[swing].occupied = occupied


## The fireplace flares up for a moment.
func poke_fire() -> void:
	_fire_boost = 1.0


func _swing_origin(swing: int) -> Vector3:
	var s: Dictionary = _swings[swing]
	# The seat plank's top, minus the seat height the model expects.
	return (s.pivot as Node3D).to_global(Vector3(0, -SWING_LENGTH + 0.05 - 0.47, 0))


func _process(delta: float) -> void:
	_time += delta
	_fire_boost = maxf(0.0, _fire_boost - delta * 0.6)
	if _fire_light:
		_fire_light.light_energy = 1.7 + sin(_time * 9.0) * 0.25 + sin(_time * 23.0) * 0.12 + _fire_boost * 1.8
	for i in _flames.size():
		var flame: Node3D = _flames[i]
		flame.scale.y = 1.0 + sin(_time * (8.0 + i * 3.0) + i) * 0.22 + _fire_boost * 0.9
	for s: Dictionary in _swings:
		var target := SWING_AMPLITUDE if bool(s.occupied) else 0.0
		s.amplitude = move_toward(float(s.amplitude), target, delta * (0.5 if target > 0.0 else 0.25))
		s.phase = float(s.phase) + delta * SWING_SPEED
		(s.pivot as Node3D).rotation.x = float(s.amplitude) * sin(float(s.phase))
	for i in _tiles.size():
		var tile: StandardMaterial3D = _tiles[i]
		tile.emission_energy_multiplier = 0.5 + 0.7 * (0.5 + 0.5 * sin(_time * 3.0 + i * 1.7))
	for i in _lanterns.size():
		(_lanterns[i] as Node3D).rotation.z = sin(_time * 0.9 + i) * 0.03


# --- Building -------------------------------------------------------------------

func _floor_and_walls() -> void:
	var wood := Color("#7a5232")
	var planks := int(HALF.x * 2.0 / 1.5)
	for n in planks:
		_box(Vector3(1.5, 0.2, HALF.y * 2.0), Vector3(-HALF.x + 0.75 + n * 1.5, -0.1, 0), wood if n % 2 == 0 else wood.darkened(0.12))
	_collider(Vector3(HALF.x * 2.0 + 6.0, 1.0, HALF.y * 2.0 + 6.0), Vector3(0, -0.5, 0))
	var wall := Color("#5e3f26")
	var dark := Color("#4e321d")
	var thick := 0.4
	# Back, front and side walls with a collider each, and a ceiling.
	_solid(Vector3(HALF.x * 2.0 + thick * 2.0, HEIGHT, thick), Vector3(0, HEIGHT * 0.5, -HALF.y - thick * 0.5), wall)
	_solid(Vector3(HALF.x * 2.0 + thick * 2.0, HEIGHT, thick), Vector3(0, HEIGHT * 0.5, HALF.y + thick * 0.5), wall)
	for side in [-1.0, 1.0]:
		_solid(Vector3(thick, HEIGHT, HALF.y * 2.0), Vector3(side * (HALF.x + thick * 0.5), HEIGHT * 0.5, 0), wall.darkened(0.06))
	_solid(Vector3(HALF.x * 2.0 + 1.0, thick, HALF.y * 2.0 + 1.0), Vector3(0, HEIGHT + thick * 0.5, 0), dark)
	# Beams across the ceiling and along the walls.
	var x := -HALF.x + 2.0
	while x < HALF.x:
		_box(Vector3(0.4, 0.4, HALF.y * 2.0), Vector3(x, HEIGHT - 0.2, 0), dark)
		x += 5.0
	for y in [0.6, 3.8]:
		_box(Vector3(HALF.x * 2.0, 0.18, 0.14), Vector3(0, y, -HALF.y + 0.08), dark)
		_box(Vector3(HALF.x * 2.0, 0.18, 0.14), Vector3(0, y, HALF.y - 0.08), dark)
		for side in [-1.0, 1.0]:
			_box(Vector3(0.14, 0.18, HALF.y * 2.0), Vector3(side * (HALF.x - 0.08), y, 0), dark)
	# The door and windows with a warm glow.
	_box(Vector3(2.0, 3.2, 0.14), Vector3(0, 1.6, HALF.y - 0.1), Color("#2a1a0e"))
	_box(Vector3(1.7, 2.9, 0.1), Vector3(0, 1.5, HALF.y - 0.2), Color("#6b4423"))
	_box(Vector3(0.12, 0.12, 0.1), Vector3(0.6, 1.5, HALF.y - 0.28), Color("#d9a520"))
	for at: Vector3 in [Vector3(-HALF.x + 0.1, 3.0, -4.0), Vector3(-HALF.x + 0.1, 3.0, 2.0), Vector3(HALF.x - 0.1, 3.0, -6.0), Vector3(HALF.x - 0.1, 3.0, 7.0), Vector3(-6.0, 3.0, HALF.y - 0.1), Vector3(6.0, 3.0, HALF.y - 0.1)]:
		var on_side_wall := absf(at.x) > 14.0
		var outward := Vector3(signf(at.x), 0, 0) if on_side_wall else Vector3(0, 0, signf(at.z))
		_box(Vector3(0.1, 1.6, 2.0) if on_side_wall else Vector3(2.0, 1.6, 0.1), at, Color("#ffe29a"), Color("#ffb23f"))
		_box(Vector3(0.14, 1.8, 2.2) if on_side_wall else Vector3(2.2, 1.8, 0.14), at + outward * 0.03, dark)


func _fireplace() -> void:
	var fire := Vector3(-9.0, 0, -HALF.y + 0.9)
	var stone := Color("#7a7470")
	_solid(Vector3(4.4, 3.4, 1.4), fire + Vector3(0, 1.7, 0), stone)
	_box(Vector3(4.8, 0.3, 1.8), fire + Vector3(0, 3.55, 0.1), stone.darkened(0.2))
	_box(Vector3(2.4, 2.0, 0.2), fire + Vector3(0, 1.0, 0.62), Color("#120a06"))
	for n in 3:
		_box(Vector3(1.6 - n * 0.4, 0.22, 0.3), fire + Vector3(0, 0.12 + n * 0.1, 0.78), Color("#5a3a20"))
	for f: Array in [[Vector3(0.5, 0.9, 0.2), Vector3(-0.35, 0.65, 0.78), Color("#ff7a1f")], [Vector3(0.4, 1.2, 0.2), Vector3(0.15, 0.8, 0.8), Color("#ffb23f")], [Vector3(0.3, 0.6, 0.2), Vector3(0.5, 0.45, 0.76), Color("#ffe066")]]:
		var flame := _box(f[0], fire + Vector3(0, 0, 0) + f[1], f[2], f[2])
		_flames.append(flame)
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color("#ff9a4a")
	_fire_light.omni_range = 11.0
	_fire_light.position = fire + Vector3(0, 1.0, 1.6)
	add_child(_fire_light)
	interactables.append({"kind": "fire", "label": "Ateşi canlandır", "pos": to_global(fire + Vector3(0, 0, 2.2)), "yaw": PI, "radius": 3.0})
	# A rug in front of the fire with two benches facing it.
	_box(Vector3(6.0, 0.04, 3.6), Vector3(-9.0, 0.02, -8.4), Color("#8a2f2a"))
	_box(Vector3(5.4, 0.045, 3.0), Vector3(-9.0, 0.025, -8.4), Color("#b8483f"))
	for bx in [-10.5, -7.5]:
		_bench(Vector3(bx, 0, -6.6), PI)


## A bench for two, facing along `yaw`.
func _bench(at: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation.y = yaw
	add_child(root)
	_box(Vector3(2.4, 0.14, 0.7), Vector3(0, 0.45, 0), Color("#6b4423"), Color.BLACK, root)
	_box(Vector3(2.4, 0.7, 0.1), Vector3(0, 0.85, -0.34), Color("#5a381c"), Color.BLACK, root)
	for lx in [-1.0, 1.0]:
		_box(Vector3(0.12, 0.42, 0.6), Vector3(lx, 0.21, 0), Color("#4e321d"), Color.BLACK, root)
	for sx in [-0.55, 0.55]:
		var local := Vector3(sx, 0, 0).rotated(Vector3.UP, yaw)
		_seat(at + local, yaw, "Otur")


func _bar() -> void:
	var z := -HALF.y + 3.4
	_solid(Vector3(11.0, 1.2, 1.1), Vector3(3.5, 0.6, z), Color("#6b4423"))
	_box(Vector3(11.4, 0.14, 1.4), Vector3(3.5, 1.27, z + 0.05), Color("#8d5f38"))
	for n in 5:
		var x := -0.5 + n * 2.3
		_stool(Vector3(x, 0, z + 1.5))
		# A mug on the counter in front of each stool.
		_box(Vector3(0.2, 0.26, 0.2), Vector3(x + 0.3, 1.47, z + 0.2), Color("#a8672e"))
		_box(Vector3(0.21, 0.07, 0.21), Vector3(x + 0.3, 1.64, z + 0.2), Color("#fff6e0"))
	# Shelves with bottles on the wall behind the bar, and kegs.
	for y in [1.9, 2.9]:
		_box(Vector3(10.0, 0.1, 0.5), Vector3(3.5, y, -HALF.y + 0.35), Color("#4e321d"))
		for n in 16:
			var c: Color = [Color("#4fb86a"), Color("#c0504d"), Color("#4f8fd0"), Color("#d9a520")][n % 4]
			_box(Vector3(0.18, 0.4, 0.18), Vector3(-1.2 + n * 0.62, y + 0.25, -HALF.y + 0.35), c, Color(c, 0.0) if n % 3 else c.darkened(0.3))
	for kx in [0.0, 1.4, 2.8]:
		_keg(Vector3(kx, 0, -HALF.y + 1.2))


func _stool(at: Vector3) -> void:
	_box(Vector3(0.62, 0.1, 0.62), Vector3(at.x, 0.78, at.z), Color("#6b4423"))
	_box(Vector3(0.12, 0.72, 0.12), Vector3(at.x, 0.38, at.z), Color("#4e321d"))
	_box(Vector3(0.5, 0.06, 0.5), Vector3(at.x, 0.05, at.z), Color("#4e321d"))
	# The seat is higher than a chair's: the sitter's origin rises with it.
	_seat(at + Vector3(0, 0.36, 0), PI, "Otur")


func _keg(at: Vector3) -> void:
	_solid(Vector3(0.95, 1.2, 0.95), at + Vector3(0, 0.6, 0), Color("#8a5a2b"))
	for y in [0.3, 0.9]:
		_box(Vector3(1.0, 0.08, 1.0), at + Vector3(0, y, 0), Color("#3a3a3a"))


func _tables() -> void:
	for tx in [-5.0, 0.0, 5.0]:
		for tz in [-1.0, 4.5]:
			_table(Vector2(tx, tz))


## A table with four chairs and a candle.
func _table(at: Vector2) -> void:
	var dark := Color("#4e321d")
	_box(Vector3(2.3, 0.14, 1.7), Vector3(at.x, 0.92, at.y), Color("#8d5f38"))
	_collider(Vector3(2.3, 1.0, 1.7), Vector3(at.x, 0.5, at.y))
	for leg: Vector2 in [Vector2(-1.0, -0.7), Vector2(1.0, -0.7), Vector2(-1.0, 0.7), Vector2(1.0, 0.7)]:
		_box(Vector3(0.14, 0.86, 0.14), Vector3(at.x + leg.x, 0.43, at.y + leg.y), dark)
	_box(Vector3(0.12, 0.26, 0.12), Vector3(at.x, 1.1, at.y), Color("#f4ecd6"))
	_box(Vector3(0.06, 0.1, 0.06), Vector3(at.x, 1.28, at.y), Color("#ffd866"), Color("#ffb23f"))
	_box(Vector3(0.22, 0.26, 0.22), Vector3(at.x + 0.6, 1.1, at.y + 0.2), Color("#a8672e"))
	# Chairs on each side, facing the table.
	for c: Array in [[Vector2(0, -1.5), 0.0], [Vector2(0, 1.5), PI], [Vector2(1.75, 0), -PI * 0.5], [Vector2(-1.75, 0), PI * 0.5]]:
		_chair(Vector3(at.x + c[0].x, 0, at.y + c[0].y), c[1])


func _chair(at: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation.y = yaw
	add_child(root)
	_box(Vector3(0.62, 0.1, 0.6), Vector3(0, 0.42, 0), Color("#6b4423"), Color.BLACK, root)
	_box(Vector3(0.62, 0.95, 0.1), Vector3(0, 0.9, -0.34), Color("#5a381c"), Color.BLACK, root)
	for leg: Vector2 in [Vector2(-0.25, -0.24), Vector2(0.25, -0.24), Vector2(-0.25, 0.24), Vector2(0.25, 0.24)]:
		_box(Vector3(0.08, 0.42, 0.08), Vector3(leg.x, 0.21, leg.y), Color("#4e321d"), Color.BLACK, root)
	_seat(at, yaw, "Otur")


func _seat(at: Vector3, yaw: float, label: String) -> void:
	interactables.append({"kind": "sit", "label": label, "pos": to_global(at), "yaw": yaw, "radius": 0.0})


## A wooden frame with two swings.
func _swing_frame() -> void:
	var at := Vector3(-10.0, 0, 5.0)
	var dark := Color("#4e321d")
	var top := 5.6
	for sx in [-2.2, 2.2]:
		_box(Vector3(0.32, top, 0.32), Vector3(at.x + sx, top * 0.5, at.z - 0.9), dark)
		_box(Vector3(0.32, top, 0.32), Vector3(at.x + sx, top * 0.5, at.z + 0.9), dark)
		_box(Vector3(0.22, 0.22, 2.2), Vector3(at.x + sx, top, at.z), dark)
	_box(Vector3(4.8, 0.3, 0.3), Vector3(at.x, top + 0.1, at.z), Color("#5a381c"))
	for k in 2:
		var pivot := Node3D.new()
		pivot.position = Vector3(at.x - 0.9 + k * 1.8, top, at.z)
		add_child(pivot)
		for rx in [-0.4, 0.4]:
			_box(Vector3(0.05, SWING_LENGTH, 0.05), Vector3(rx, -SWING_LENGTH * 0.5, 0), Color("#c9b58a"), Color.BLACK, pivot)
		_box(Vector3(1.0, 0.1, 0.5), Vector3(0, -SWING_LENGTH, 0), Color("#8d5f38"), Color.BLACK, pivot)
		_swings.append({"pivot": pivot, "amplitude": 0.0, "phase": float(k) * 1.3, "occupied": false})
		interactables.append({"kind": "swing", "label": "Salıncağa bin", "pos": Vector3.ZERO, "yaw": 0.0, "radius": 1.6, "swing": k})
	# Grass-green rug under the swings.
	_box(Vector3(5.6, 0.04, 4.6), Vector3(at.x, 0.02, at.z), Color("#3f7d46"))


func _dance_floor() -> void:
	var at := Vector3(10.2, 0.03, 2.0)
	var colors := [Color("#ff5a8a"), Color("#5ad2ff"), Color("#ffd23f"), Color("#9a6bff")]
	for ix in 6:
		for iz in 6:
			var c: Color = colors[(ix + iz) % 4]
			var tile := _box(Vector3(1.0, 0.04, 1.0), at + Vector3((ix - 2.5) * 1.0, 0, (iz - 2.5) * 1.0), c.darkened(0.2), c)
			var mat := tile.material_override as StandardMaterial3D
			_tiles.append(mat)
	interactables.append({"kind": "dance", "label": "Dans et", "pos": to_global(at), "yaw": PI * 0.5, "radius": 3.6})
	# A speaker on each side.
	for sz in [-3.4, 3.4]:
		_box(Vector3(0.8, 1.4, 0.7), Vector3(HALF.x - 0.8, 0.7, at.z + sz), Color("#2a2a32"))
		_box(Vector3(0.5, 0.5, 0.05), Vector3(HALF.x - 1.2, 0.9, at.z + sz), Color("#8a8a99"))


func _decor() -> void:
	# Crates and kegs in the corners, plants by the door.
	for c: Array in [[Vector3(12.8, 0, 9.5), 1.2], [Vector3(12.6, 0, 8.0), 1.0], [Vector3(-12.8, 0, 9.8), 1.1], [Vector3(13.2, 0, -10.0), 1.0]]:
		var at: Vector3 = c[0]
		_solid(Vector3(float(c[1]), float(c[1]), float(c[1])), at + Vector3(0, float(c[1]) * 0.5, 0), Color("#8a6a3a"))
	_solid(Vector3(0.8, 0.8, 0.8), Vector3(12.9, 1.6, 8.8), Color("#9a7a44"))
	for x in [-2.6, 2.6]:
		_box(Vector3(0.5, 0.5, 0.5), Vector3(x, 0.25, HALF.y - 0.6), Color("#7a4a2a"))
		_box(Vector3(0.7, 0.9, 0.7), Vector3(x, 0.95, HALF.y - 0.6), Color("#3f8f46"))
	# Banners on the side walls.
	for z in [-8.0, 0.0, 8.0]:
		_box(Vector3(0.08, 2.0, 1.1), Vector3(-HALF.x + 0.1, 4.6, z), Color("#a83a3a"))
		_box(Vector3(0.08, 0.5, 0.7), Vector3(-HALF.x + 0.14, 4.9, z), Color("#ffd23f"))
	# Antlers over the fireplace.
	_box(Vector3(1.6, 0.14, 0.14), Vector3(-9.0, 5.2, -HALF.y + 0.3), Color("#d8c9a8"))
	for x in [-9.7, -8.3]:
		_box(Vector3(0.12, 0.8, 0.12), Vector3(x, 5.6, -HALF.y + 0.3), Color("#d8c9a8"))


func _lights() -> void:
	for at: Vector3 in [Vector3(-5.0, 0, 1.2), Vector3(5.0, 0, 1.2), Vector3(0.0, 0, 7.0), Vector3(4.0, 0, -5.5)]:
		var lantern := Node3D.new()
		lantern.position = Vector3(at.x, HEIGHT, at.z)
		add_child(lantern)
		_box(Vector3(0.04, 1.3, 0.04), Vector3(0, -0.65, 0), Color("#2a2a2a"), Color.BLACK, lantern)
		_box(Vector3(0.44, 0.5, 0.44), Vector3(0, -1.5, 0), Color("#ffd866"), Color("#ffb23f"), lantern)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color("#ffcf80")
		lamp.light_energy = 1.0
		lamp.omni_range = 11.0
		lamp.position = Vector3(0, -1.6, 0)
		lantern.add_child(lamp)
		_lanterns.append(lantern)
	# Coloured lights over the dance floor.
	for c: Array in [[Vector3(9.0, 4.5, 0.5), Color("#ff5a8a")], [Vector3(11.5, 4.5, 3.5), Color("#5ad2ff")]]:
		var light := OmniLight3D.new()
		light.light_color = c[1]
		light.light_energy = 0.9
		light.omni_range = 7.0
		light.position = c[0]
		add_child(light)


# --- Pieces ---------------------------------------------------------------------

## A box with no collider.
func _box(box_size: Vector3, pos: Vector3, color: Color, glow := Color.BLACK, parent: Node3D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var mat := Toon.material(color)
	if glow != Color.BLACK and glow.a > 0.0:
		mat.emission_enabled = true
		mat.emission = glow
		mat.emission_energy_multiplier = 1.2
	instance.material_override = mat
	instance.position = pos
	(parent if parent else self).add_child(instance)
	return instance


## A box people can't walk through.
func _solid(box_size: Vector3, pos: Vector3, color: Color, glow := Color.BLACK, collide := true) -> void:
	_box(box_size, pos, color, glow)
	if collide:
		_collider(box_size, pos)


func _collider(box_size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	add_child(body)
