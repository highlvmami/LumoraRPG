## Game flow: build the forest, show the login screen, then run the game.
## A run = character level 1, enemies spawning, until the player dies.
## Account level and stats are kept in the profile across runs.
extends Node3D

const Config := preload("res://scripts/core/config.gd")
const InputSetup := preload("res://scripts/core/input_setup.gd")
const Terrain := preload("res://scripts/world/terrain.gd")
const Props := preload("res://scripts/world/props.gd")
const Player := preload("res://scripts/player/player.gd")
const CameraRig := preload("res://scripts/player/camera_rig.gd")
const EnemyManager := preload("res://scripts/enemies/enemy_manager.gd")
const AutoBow := preload("res://scripts/combat/auto_bow.gd")
const ProfileStore := preload("res://scripts/progression/profile_store.gd")
const Progression := preload("res://scripts/progression/progression.gd")
const LoginScreen := preload("res://scripts/ui/login_screen.gd")
const Hud := preload("res://scripts/ui/hud.gd")

var terrain: Terrain
var player: Player
var camera_rig: CameraRig
var enemies: EnemyManager
var bow: AutoBow
var progression: Progression
var hud: Hud
var login_screen: LoginScreen
var store := ProfileStore.new()

var _world_cfg: Dictionary


func _ready() -> void:
	InputSetup.register()
	_world_cfg = Config.load_json("res://data/world.json")
	_build_environment()

	terrain = Terrain.new()
	terrain.name = "Terrain"
	terrain.build(_world_cfg)
	add_child(terrain)

	var props := Props.new()
	props.name = "Props"
	add_child(props)
	props.build(terrain, _world_cfg)

	# A slowly circling camera shows the forest behind the login screen.
	var menu_cam := Camera3D.new()
	menu_cam.name = "MenuCamera"
	menu_cam.position = Vector3(0, terrain.height_at(0, 0) + 14.0, 26)
	add_child(menu_cam)
	menu_cam.look_at(Vector3(0, terrain.height_at(0, 0), 0))
	menu_cam.current = true

	store.load_from_disk()
	login_screen = LoginScreen.new()
	login_screen.setup(store.last_name())
	login_screen.logged_in.connect(start_game)
	add_child(login_screen)


## Logs in (creating the account if new) and starts the first run.
func start_game(username: String) -> void:
	var profile := store.login(username)
	progression = Progression.new(store, profile)

	player = Player.new()
	player.name = "Player"
	player.position = Vector3(0, terrain.height_at(0, 0) + 0.5, 0)
	add_child(player)
	player.died.connect(_on_player_died)

	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	camera_rig.target = player
	add_child(camera_rig)

	enemies = EnemyManager.new()
	enemies.name = "Enemies"
	add_child(enemies)
	enemies.setup(terrain, player, float(_world_cfg.playableHalfSize))
	enemies.enemy_killed.connect(func(_at: Vector3, amount: int) -> void: progression.add_exp(amount))

	bow = AutoBow.new()
	bow.name = "Bow"
	add_child(bow)
	bow.setup(player, enemies)

	progression.level_up.connect(_on_level_up)

	hud = Hud.new()
	add_child(hud)
	hud.setup(player, progression, enemies, camera_rig.camera)
	hud.restart_requested.connect(start_run)

	start_run()


func start_run() -> void:
	progression.start_run()
	enemies.clear()
	bow.clear()
	player.reset(player.t.maxHp)
	bow.damage_multiplier = progression.damage_multiplier()
	enemies.active = true
	bow.active = true
	camera_rig.capture_enabled = true
	hud.hide_death()


func _on_level_up(_level: int) -> void:
	bow.damage_multiplier = progression.damage_multiplier()
	player.set_max_hp(float(player.t.maxHp) + progression.max_hp_bonus())


func _on_player_died() -> void:
	enemies.active = false
	bow.active = false
	progression.end_run(enemies.kills)
	camera_rig.capture_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_death(progression.level, enemies.kills, enemies.run_time)


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
