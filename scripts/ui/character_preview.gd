## A small 3D stage showing a character (with its worn gear) slowly turning,
## or a pet spinning round, for the menus. Renders in its own world at a low
## resolution (pixel look).
extends SubViewportContainer

const PlayerModel := preload("res://scripts/player/player_model.gd")
const PetModel := preload("res://scripts/player/pet_model.gd")
const MountModel := preload("res://scripts/world/mount_model.gd")

## Full-body framing: the camera looks at this height from this distance
## (the menu uses them to line equipment slots up with the body).
const BODY_CENTER := 1.15
const BODY_DISTANCE := 5.0
const FOV := 30.0

var _pivot: Node3D
var _model: Node3D
var _time := 0.0
## Pets spin all the way round; characters sway.
var _spin := false
## A pet standing still at STILL_ANGLE.
var _still := false
## A mount (rearing, turning a little) with an optional rider.
var _mount: Node3D
var _rider: Node3D
## The pet's turn when it stands still: its face and one side show.
const STILL_ANGLE := 0.6


## `full_body` frames the whole standing character (feet to helmet).
func setup(look: Dictionary, view_size: Vector2, pixel := 2, full_body := false) -> void:
	var eye := Vector3(0, BODY_CENTER, BODY_DISTANCE) if full_body else Vector3(0, 1.35, 6.2)
	var viewport := _build_stage(view_size, pixel, eye, Vector3(0, BODY_CENTER, 0))
	_pivot = Node3D.new()
	viewport.add_child(_pivot)
	var model := PlayerModel.new()
	model.build(look)
	_model = model
	_pivot.add_child(_model)
	_pivot.rotation.y = 0.35


## A pet of `kind_id` on the stage: turning round, or (`spin` false) standing
## still, turned a little to the side (a three-quarter view).
func setup_pet(kind_id: String, view_size: Vector2, pixel := 2, spin := true) -> void:
	var pet := PetModel.new()
	pet.build(kind_id)
	var center := pet.center_height()
	var distance := pet.view_distance()
	var viewport := _build_stage(view_size, pixel, Vector3(0, center + 1.0, distance), Vector3(0, center, 0))
	_pivot = Node3D.new()
	viewport.add_child(_pivot)
	_model = pet
	_pivot.add_child(_model)
	_spin = spin
	_still = not spin
	_pivot.rotation.y = STILL_ANGLE if not spin else 0.0


## A mount (an entry of data/mounts.json) standing on its hind legs, with a
## rider wearing `look` when it is not empty.
func setup_mount(def: Dictionary, look: Dictionary, view_size: Vector2, pixel := 2) -> void:
	var mount := MountModel.new()
	mount.build(def)
	mount.set_rear(true)
	var center := mount.center_height() + 0.3
	var viewport := _build_stage(view_size, pixel, Vector3(0, center + 1.0, mount.view_distance() * 1.1), Vector3(0, center, 0))
	_pivot = Node3D.new()
	viewport.add_child(_pivot)
	_mount = mount
	_model = mount
	_pivot.add_child(mount)
	if not look.is_empty():
		var rider := PlayerModel.new()
		rider.build(look)
		rider.riding = true
		mount.attach_rider(rider)
		_rider = rider
	_pivot.rotation.y = -0.9


func _build_stage(view_size: Vector2, pixel: int, eye: Vector3, look_at: Vector3) -> SubViewport:
	custom_minimum_size = view_size
	stretch = true
	stretch_shrink = pixel
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := make_stage(eye, look_at)
	add_child(viewport)
	return viewport


## A transparent little world with soft light and a camera at `eye` looking
## at `look_at` (no size set: a container stretches it, or set `size`).
static func make_stage(eye: Vector3, look_at: Vector3) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c9d8e6")
	env.ambient_light_energy = 0.7
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 30, 0)
	sun.light_energy = 1.1
	viewport.add_child(sun)

	var camera := Camera3D.new()
	camera.fov = FOV
	camera.transform = Transform3D(Basis.looking_at(look_at - eye), eye)
	viewport.add_child(camera)
	return viewport


## Screen height (pixels from the top) of a body height in a full-body view.
static func body_y(height: float, view_height: float) -> float:
	var half := BODY_DISTANCE * tan(deg_to_rad(FOV * 0.5))
	return view_height * 0.5 - (height - BODY_CENTER) / half * view_height * 0.5


func _process(delta: float) -> void:
	if _pivot == null or not is_visible_in_tree():
		return
	_time += delta
	if _mount != null:
		_pivot.rotation.y = -0.9 + sin(_time * 0.6) * 0.45
		_mount.call("animate", delta, 0.0)
		if _rider != null:
			_rider.call("animate", delta, 0.0, true)
		return
	if _spin:
		_pivot.rotation.y += delta * 0.9
	elif _still:
		_pivot.rotation.y = STILL_ANGLE
	else:
		_pivot.rotation.y = 0.35 + sin(_time * 0.6) * 0.6
	_model.call("animate", delta, 0.0, true)
