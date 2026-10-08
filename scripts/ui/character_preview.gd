## A small 3D stage showing a character (with its worn gear) slowly turning,
## for the menus. Renders in its own world at a low resolution (pixel look).
extends SubViewportContainer

const PlayerModel := preload("res://scripts/player/player_model.gd")

var _pivot: Node3D
var _model: PlayerModel
var _time := 0.0


func setup(look: Dictionary, view_size: Vector2, pixel := 2) -> void:
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
	camera.fov = 30.0
	camera.position = Vector3(0, 1.35, 6.2)
	viewport.add_child(camera)
	camera.look_at(Vector3(0, 1.15, 0))

	_pivot = Node3D.new()
	viewport.add_child(_pivot)
	_model = PlayerModel.new()
	_model.build(look)
	_pivot.add_child(_model)
	_pivot.rotation.y = 0.35


func _process(delta: float) -> void:
	if _pivot == null or not is_visible_in_tree():
		return
	_time += delta
	_pivot.rotation.y = 0.35 + sin(_time * 0.6) * 0.6
	_model.animate(delta, 0.0, true)
