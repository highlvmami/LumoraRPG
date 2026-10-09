## The co-op room as a tavern: a warm wooden room with a fireplace, lanterns
## and a long table with 4 chairs. Everyone in the room sits at the table as
## their own character (with their gear) and a name tag above their head.
## When someone joins, their character comes in through the door, walks to a
## free chair and sits down; someone leaving gets up and walks out.
extends Control

const UiTheme := preload("res://scripts/ui/theme.gd")
const Toon := preload("res://scripts/core/toon.gd")
const PlayerModel := preload("res://scripts/player/player_model.gd")

const SEATS := 4
const SEAT_X := [-2.1, -0.7, 0.7, 2.1]
const SEAT_Z := -1.25
## The seat's height takes the character's hips down to the chair.
const SIT_DROP := -0.27
const DOOR := Vector3(4.1, 0, -3.0)
const AISLE_Z := -2.05
const WALK_SPEED := 3.0
const PIXEL := 2

var _viewport: SubViewport
var _camera: Camera3D
var _world: Node3D
var _tags: Control
var _fire_light: OmniLight3D
var _time := 0.0
## Member id -> {model, seat, path, name, tag, leaving, mug}
var _guests := {}


func setup(view_size: Vector2) -> void:
	custom_minimum_size = view_size
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := PanelContainer.new()
	var style := UiTheme.box(Color("#1c120b"), 10, 0)
	style.set_border_width_all(3)
	style.border_color = Color("#8a5a2b")
	frame.add_theme_stylebox_override("panel", style)
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.stretch_shrink = PIXEL
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	container.add_child(_viewport)
	_tags = Control.new()
	_tags.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tags)
	_build_room()


## Who is in the room: [{id, name, look, host, me}]. New people walk in
## (or, with `walk_in` false, are already seated); people gone walk out.
func set_members(members: Array, walk_in := true) -> void:
	var present := {}
	for m: Dictionary in members:
		present[int(m.id)] = true
	for id: int in _guests.keys():
		if not present.has(id) and not bool(_guests[id].leaving):
			_leave(id)
	for m: Dictionary in members:
		var id := int(m.id)
		if _guests.has(id) and not bool(_guests[id].leaving):
			_set_tag(_guests[id], m)
			continue
		var seat := _free_seat()
		if seat < 0:
			continue
		_arrive(id, m, seat, walk_in)


## Ids of the people sitting (or on the way to their chair), by seat.
func seated() -> Array:
	var out: Array = []
	for id: int in _guests:
		if not bool(_guests[id].leaving):
			out.append(id)
	return out


## True while someone is still walking to (or away from) a chair.
func is_busy() -> bool:
	for g: Dictionary in _guests.values():
		if not (g.path as Array).is_empty():
			return true
	return false


func _free_seat() -> int:
	var taken := {}
	for g: Dictionary in _guests.values():
		if not bool(g.leaving):
			taken[int(g.seat)] = true
	for s in SEATS:
		if not taken.has(s):
			return s
	return -1


func _seat_pos(seat: int) -> Vector3:
	return Vector3(float(SEAT_X[seat]), 0, SEAT_Z)


func _arrive(id: int, m: Dictionary, seat: int, walk_in: bool) -> void:
	var model := PlayerModel.new()
	model.build(m.get("look", {}) if m.get("look") is Dictionary else {})
	_world.add_child(model)
	var guest := {"model": model, "seat": seat, "path": [], "leaving": false, "name": str(m.get("name", "?"))}
	var tag := UiTheme.label("", UiTheme.label_settings(14, UiTheme.TEXT, 4))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.size = Vector2(160, 20)
	_tags.add_child(tag)
	guest.tag = tag
	_set_tag(guest, m)
	var mug := _mug(seat)
	mug.visible = not walk_in
	guest.mug = mug
	_guests[id] = guest
	var chair := _seat_pos(seat)
	if walk_in:
		model.position = DOOR
		guest.path = [Vector3(DOOR.x, 0, AISLE_Z), Vector3(chair.x, 0, AISLE_Z), chair]
	else:
		_sit(guest)


func _leave(id: int) -> void:
	var g: Dictionary = _guests[id]
	g.leaving = true
	var model: PlayerModel = g.model
	model.sitting = false
	model.position.y = 0.0
	(g.mug as Node3D).visible = false
	var chair := _seat_pos(int(g.seat))
	g.path = [Vector3(chair.x, 0, AISLE_Z), Vector3(DOOR.x, 0, AISLE_Z), DOOR]


func _sit(g: Dictionary) -> void:
	var model: PlayerModel = g.model
	var chair := _seat_pos(int(g.seat))
	model.position = Vector3(chair.x, SIT_DROP, chair.z)
	model.rotation.y = 0.0
	model.sitting = true
	(g.mug as Node3D).visible = true


func _set_tag(g: Dictionary, m: Dictionary) -> void:
	var text := str(m.get("name", "?"))
	if bool(m.get("host", false)):
		text = "★ " + text
	if bool(m.get("me", false)):
		text += " (sen)"
	var tag: Label = g.tag
	tag.text = text
	tag.label_settings = UiTheme.label_settings(14, UiTheme.ACCENT if bool(m.get("host", false)) else UiTheme.TEXT, 4)


func _process(delta: float) -> void:
	if _viewport == null or not is_visible_in_tree():
		return
	_time += delta
	_fire_light.light_energy = 1.6 + sin(_time * 9.0) * 0.25 + sin(_time * 23.0) * 0.12
	for id: int in _guests.keys():
		var g: Dictionary = _guests[id]
		var model: PlayerModel = g.model
		var path: Array = g.path
		var speed := 0.0
		if not path.is_empty():
			var goal: Vector3 = path[0]
			var to := goal - model.position
			to.y = 0.0
			var step := WALK_SPEED * delta
			if to.length() <= step:
				model.position = Vector3(goal.x, 0, goal.z)
				path.pop_front()
				if path.is_empty():
					if bool(g.leaving):
						_drop(id)
						continue
					_sit(g)
			else:
				model.position += to.normalized() * step
				model.rotation.y = lerp_angle(model.rotation.y, atan2(to.x, to.z), minf(1.0, delta * 12.0))
				speed = 6.0
		model.animate(delta, speed, true)
		# The name tag floats over the head.
		var head := model.global_position + Vector3(0, 2.75 if model.sitting else 3.0, 0)
		var tag: Label = g.tag
		tag.visible = not _camera.is_position_behind(head)
		tag.position = _camera.unproject_position(head) * PIXEL - Vector2(tag.size.x * 0.5, tag.size.y)


func _drop(id: int) -> void:
	var g: Dictionary = _guests[id]
	(g.model as Node).queue_free()
	(g.tag as Node).queue_free()
	(g.mug as Node).queue_free()
	_guests.erase(id)


# --- The room ------------------------------------------------------------------

func _build_room() -> void:
	_world = Node3D.new()
	_viewport.add_child(_world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#140c07")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#ffcf9a")
	env.ambient_light_energy = 0.45
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 20, 0)
	sun.light_energy = 0.55
	sun.light_color = Color("#ffe2b8")
	_viewport.add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 34.0
	var eye := Vector3(0, 2.6, 5.4)
	_camera.transform = Transform3D(Basis.looking_at(Vector3(0, 1.05, -1.1) - eye), eye)
	_viewport.add_child(_camera)

	var wood := Color("#7a5232")
	var dark_wood := Color("#4e321d")
	# Floor planks, back wall with beams, side walls.
	for n in 10:
		_box(Vector3(1.2, 0.2, 7.0), Vector3(-5.4 + n * 1.2, -0.1, -0.5), wood if n % 2 == 0 else wood.darkened(0.12))
	_box(Vector3(12.0, 5.0, 0.2), Vector3(0, 2.5, -3.3), Color("#5e3f26"))
	for y in [0.6, 3.6]:
		_box(Vector3(12.0, 0.18, 0.12), Vector3(0, y, -3.15), dark_wood)
	for x in [-5.0, -1.6, 1.6]:
		_box(Vector3(0.22, 5.0, 0.16), Vector3(x, 2.5, -3.12), dark_wood)
	for side in [-1.0, 1.0]:
		_box(Vector3(0.2, 5.0, 7.0), Vector3(side * 6.0, 2.5, -0.5), Color("#563a23"))

	# Fireplace with a flickering fire.
	var stone := Color("#7a7470")
	_box(Vector3(2.2, 2.4, 0.6), Vector3(-3.4, 1.2, -2.95), stone)
	_box(Vector3(2.5, 0.25, 0.8), Vector3(-3.4, 2.45, -2.9), stone.darkened(0.2))
	_box(Vector3(1.3, 1.1, 0.1), Vector3(-3.4, 0.6, -2.62), Color("#120a06"))
	for n in 3:
		_box(Vector3(0.9 - n * 0.2, 0.14, 0.2), Vector3(-3.4, 0.1 + n * 0.08, -2.6), Color("#5a3a20"), Color.BLACK)
	var flames := [[Vector3(0.3, 0.5, 0.1), Vector3(-3.55, 0.45, -2.5), Color("#ff7a1f")],
		[Vector3(0.24, 0.65, 0.1), Vector3(-3.3, 0.5, -2.52), Color("#ffb23f")],
		[Vector3(0.18, 0.35, 0.1), Vector3(-3.15, 0.38, -2.48), Color("#ffe066")]]
	for f: Array in flames:
		_box(f[0], f[1], f[2], f[2])
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color("#ff9a4a")
	_fire_light.omni_range = 6.0
	_fire_light.position = Vector3(-3.4, 0.9, -2.0)
	_world.add_child(_fire_light)

	# Shelves with bottles, barrels and the door.
	for y in [1.7, 2.6]:
		_box(Vector3(2.4, 0.1, 0.4), Vector3(0.6, y, -3.05), dark_wood)
		for n in 6:
			var c: Color = [Color("#4fb86a"), Color("#c0504d"), Color("#4f8fd0"), Color("#d9a520")][n % 4]
			_box(Vector3(0.16, 0.36, 0.16), Vector3(-0.35 + n * 0.38, y + 0.23, -3.0), c, Color(c, 0.0) if n % 3 else c.darkened(0.3))
	for at: Vector3 in [Vector3(5.1, 0.55, -2.4), Vector3(5.2, 0.55, -1.3), Vector3(5.15, 1.6, -1.9)]:
		_box(Vector3(0.9, 1.1, 0.9), at, Color("#8a5a2b"))
		_box(Vector3(0.95, 0.08, 0.95), at + Vector3(0, 0.3, 0), Color("#3a3a3a"))
		_box(Vector3(0.95, 0.08, 0.95), at - Vector3(0, 0.3, 0), Color("#3a3a3a"))
	_box(Vector3(1.4, 2.6, 0.14), Vector3(DOOR.x, 1.3, -3.2), Color("#2a1a0e"))
	_box(Vector3(1.2, 2.4, 0.1), Vector3(DOOR.x, 1.2, -3.12), Color("#6b4423"))
	_box(Vector3(0.1, 0.1, 0.08), Vector3(DOOR.x + 0.4, 1.2, -3.05), Color("#d9a520"))

	# The long table, its chairs, candles and hanging lanterns.
	_box(Vector3(6.2, 0.14, 1.15), Vector3(0, 0.9, -0.45), Color("#8d5f38"))
	for at: Vector2 in [Vector2(-2.9, -0.9), Vector2(2.9, -0.9), Vector2(-2.9, 0.0), Vector2(2.9, 0.0)]:
		_box(Vector3(0.14, 0.86, 0.14), Vector3(at.x, 0.43, at.y), dark_wood)
	for s in SEATS:
		var x := float(SEAT_X[s])
		_box(Vector3(0.62, 0.1, 0.6), Vector3(x, 0.42, SEAT_Z), Color("#6b4423"))
		_box(Vector3(0.62, 0.95, 0.1), Vector3(x, 0.9, SEAT_Z - 0.34), Color("#5a381c"))
		for leg: Vector2 in [Vector2(-0.25, -0.24), Vector2(0.25, -0.24), Vector2(-0.25, 0.24), Vector2(0.25, 0.24)]:
			_box(Vector3(0.08, 0.42, 0.08), Vector3(x + leg.x, 0.21, SEAT_Z + leg.y), dark_wood)
	for x in [-1.4, 1.4]:
		_box(Vector3(0.12, 0.26, 0.12), Vector3(x, 1.1, -0.3), Color("#f4ecd6"))
		_box(Vector3(0.06, 0.1, 0.06), Vector3(x, 1.28, -0.3), Color("#ffd866"), Color("#ffb23f"))
		var candle := OmniLight3D.new()
		candle.light_color = Color("#ffc070")
		candle.light_energy = 0.8
		candle.omni_range = 2.6
		candle.position = Vector3(x, 1.5, -0.3)
		_world.add_child(candle)
	for x in [-2.6, 0.0, 2.6]:
		_box(Vector3(0.04, 0.8, 0.04), Vector3(x, 4.3, -1.4), Color("#2a2a2a"))
		_box(Vector3(0.36, 0.42, 0.36), Vector3(x, 3.75, -1.4), Color("#ffd866"), Color("#ffb23f"))
		var lamp := OmniLight3D.new()
		lamp.light_color = Color("#ffcf80")
		lamp.light_energy = 0.9
		lamp.omni_range = 4.5
		lamp.position = Vector3(x, 3.4, -1.2)
		_world.add_child(lamp)


## A mug of something foamy in front of a seat.
func _mug(seat: int) -> Node3D:
	var mug := Node3D.new()
	mug.position = Vector3(float(SEAT_X[seat]) + 0.25, 0.97, -0.75)
	_world.add_child(mug)
	_box(Vector3(0.18, 0.24, 0.18), Vector3(0, 0.12, 0), Color("#a8672e"), Color.BLACK, mug)
	_box(Vector3(0.19, 0.06, 0.19), Vector3(0, 0.26, 0), Color("#fff6e0"), Color.BLACK, mug)
	_box(Vector3(0.05, 0.14, 0.08), Vector3(0.12, 0.12, 0), Color("#8a5a2b"), Color.BLACK, mug)
	return mug


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
	(parent if parent else _world).add_child(instance)
	return instance
