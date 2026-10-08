## A small 3D stage showing a character (with its worn gear) slowly turning,
## for the menus. Renders in its own world at a low resolution (pixel look).
extends SubViewportContainer

const PlayerModel := preload("res://scripts/player/player_model.gd")

## Full-body framing: the camera looks at this height from this distance
## (the menu uses them to line equipment slots up with the body).
const BODY_CENTER := 1.15
const BODY_DISTANCE := 5.0
const FOV := 30.0

var _pivot: Node3D
var _model: PlayerModel
var _time := 0.0


## `full_body` frames the whole standing character (feet to helmet).
func setup(look: Dictionary, view_size: Vector2, pixel := 2, full_body := false) -> void:
	custom_minimum_size = view_size
	stretch = true
	stretch_shrink = pixel
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	add_child(viewport)

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
	var eye := Vector3(0, BODY_CENTER, BODY_DISTANCE) if full_body else Vector3(0, 1.35, 6.2)
	camera.transform = Transform3D(Basis.looking_at(Vector3(0, BODY_CENTER, 0) - eye), eye)
	viewport.add_child(camera)

	_pivot = Node3D.new()
	viewport.add_child(_pivot)
	_model = PlayerModel.new()
	_model.build(look)
	_pivot.add_child(_model)
	_pivot.rotation.y = 0.35


## Screen height (pixels from the top) of a body height in a full-body view.
static func body_y(height: float, view_height: float) -> float:
	var half := BODY_DISTANCE * tan(deg_to_rad(FOV * 0.5))
	return view_height * 0.5 - (height - BODY_CENTER) / half * view_height * 0.5


func _process(delta: float) -> void:
	if _pivot == null or not is_visible_in_tree():
		return
	_time += delta
	_pivot.rotation.y = 0.35 + sin(_time * 0.6) * 0.6
	_model.animate(delta, 0.0, true)
