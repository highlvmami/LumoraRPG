## Builds the M0 test level: forest terrain, props, player, camera and HUD.
## Everything is created in code for now; scenes will be split out as content grows.
extends Node3D

const Config := preload("res://scripts/core/config.gd")
const InputSetup := preload("res://scripts/core/input_setup.gd")
const Terrain := preload("res://scripts/world/terrain.gd")
const Props := preload("res://scripts/world/props.gd")
const Player := preload("res://scripts/player/player.gd")
const CameraRig := preload("res://scripts/player/camera_rig.gd")
const Hud := preload("res://scripts/ui/hud.gd")

var terrain: Terrain
var player: Player
var camera_rig: CameraRig


func _ready() -> void:
	InputSetup.register()
	var world_cfg := Config.load_json("res://data/world.json")

	_build_environment()

	terrain = Terrain.new()
	terrain.name = "Terrain"
	terrain.build(world_cfg)
	add_child(terrain)

	var props := Props.new()
	props.name = "Props"
	add_child(props)
	props.build(terrain, world_cfg)

	player = Player.new()
	player.name = "Player"
	player.position = Vector3(0, terrain.height_at(0, 0) + 0.5, 0)
	add_child(player)

	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	camera_rig.target = player
	add_child(camera_rig)

	var hud := Hud.new()
	hud.player = player
	add_child(hud)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#8fc7e8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b7d3e6")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("#a9d1e8")
	env.fog_density = 0.012
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_color = Color("#fff1d6")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
