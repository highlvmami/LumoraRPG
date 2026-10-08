## Game flow: login → main menu → run → (death) → run again or back to the menu.
## During a run: level-ups pause for a boost choice, Esc opens the pause menu.
## The 3D world lives in a SubViewport rendered at half resolution (pixel look),
## while all UI is drawn at full resolution so text stays sharp.
extends Node

const Config := preload("res://scripts/core/config.gd")
const InputSetup := preload("res://scripts/core/input_setup.gd")
const Terrain := preload("res://scripts/world/terrain.gd")
const Props := preload("res://scripts/world/props.gd")
const Player := preload("res://scripts/player/player.gd")
const CameraRig := preload("res://scripts/player/camera_rig.gd")
const EnemyManager := preload("res://scripts/enemies/enemy_manager.gd")
const AutoBow := preload("res://scripts/combat/auto_bow.gd")
const RangeRing := preload("res://scripts/combat/range_ring.gd")
const ProfileStore := preload("res://scripts/progression/profile_store.gd")
const Progression := preload("res://scripts/progression/progression.gd")
const Shop := preload("res://scripts/progression/shop.gd")
const RunBoosts := preload("res://scripts/progression/run_boosts.gd")
const LoginScreen := preload("res://scripts/ui/login_screen.gd")
const MainMenu := preload("res://scripts/ui/main_menu.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const LevelUpScreen := preload("res://scripts/ui/level_up_screen.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")

## How many screen pixels each 3D pixel covers, per graphics quality.
const PIXEL_SCALES := {"low": 3, "medium": 2, "high": 1}
const DEFAULT_QUALITY := "medium"

var world: Node3D
var terrain: Terrain
var player: Player
var camera_rig: CameraRig
var menu_camera: Camera3D
var enemies: EnemyManager
var bow: AutoBow
var range_ring: RangeRing
var progression: Progression
var shop: Shop
var boosts := RunBoosts.new()
var hud: Hud
var level_up_screen: LevelUpScreen
var pause_menu: PauseMenu
var login_screen: LoginScreen
var main_menu: MainMenu
var store := ProfileStore.new()
var in_run := false

var _world_cfg: Dictionary
var _world_view: SubViewportContainer
var _sun: DirectionalLight3D
## True while the mouse was captured last frame; losing it mid-run pauses
## (browsers swallow Esc and just release the mouse).
var _was_captured := false
var _run_gold := 0
var _menu_angle := 0.0


func _ready() -> void:
	InputSetup.register()
	_world_cfg = Config.load_json("res://data/world.json")
	_build_world_viewport()
	_build_environment()

	terrain = Terrain.new()
	terrain.name = "Terrain"
	terrain.build(_world_cfg)
	world.add_child(terrain)

	var props := Props.new()
	props.name = "Props"
	world.add_child(props)
	props.build(terrain, _world_cfg)

	# A slowly circling camera shows the forest behind the menus.
	menu_camera = Camera3D.new()
	menu_camera.name = "MenuCamera"
	world.add_child(menu_camera)
	menu_camera.current = true
	_update_menu_camera(0.0)

	store.load_from_disk()
	login_screen = LoginScreen.new()
	login_screen.setup(store.last_name())
	login_screen.logged_in.connect(login)
	add_child(login_screen)


func _process(delta: float) -> void:
	if not in_run:
		_update_menu_camera(delta)
		return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _was_captured and not captured:
		pause_menu.open()
	_was_captured = captured


## Logs in (creating the account if new) and opens the main menu.
func login(username: String) -> void:
	var profile := store.login(username)
	progression = Progression.new(store, profile)
	shop = Shop.new(profile, store)

	player = Player.new()
	player.name = "Player"
	player.position = Vector3(0, terrain.height_at(0, 0) + 0.5, 0)
	world.add_child(player)
	player.died.connect(_on_player_died)

	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	camera_rig.target = player
	world.add_child(camera_rig)

	enemies = EnemyManager.new()
	enemies.name = "Enemies"
	world.add_child(enemies)
	enemies.setup(terrain, player, float(_world_cfg.playableHalfSize))
	enemies.enemy_killed.connect(_on_enemy_killed)

	bow = AutoBow.new()
	bow.name = "Bow"
	world.add_child(bow)
	bow.setup(player, enemies)
	bow.fired.connect(player.play_attack)

	range_ring = RangeRing.new()
	range_ring.name = "RangeRing"
	range_ring.terrain = terrain
	range_ring.target = player
	world.add_child(range_ring)

	progression.level_up.connect(_on_level_up)

	hud = Hud.new()
	add_child(hud)
	hud.setup(player, progression, enemies, camera_rig.camera, _world_view.stretch_shrink)
	hud.restart_requested.connect(start_run)
	hud.menu_requested.connect(show_menu)
	bow.hit_landed.connect(hud.show_hit)

	level_up_screen = LevelUpScreen.new()
	add_child(level_up_screen)
	level_up_screen.setup(boosts)
	level_up_screen.chosen.connect(func(_id: String) -> void: _apply_stats())
	level_up_screen.closed.connect(_on_popup_closed)

	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.setup(boosts, str(profile.get("quality", DEFAULT_QUALITY)))
	pause_menu.can_pause = _can_pause
	pause_menu.stats_source = stat_list
	pause_menu.resumed.connect(_on_popup_closed)
	pause_menu.menu_requested.connect(leave_run)
	pause_menu.quality_selected.connect(set_quality)
	set_quality(str(profile.get("quality", DEFAULT_QUALITY)))

	main_menu = MainMenu.new()
	add_child(main_menu)
	main_menu.setup(progression, shop)
	main_menu.play_pressed.connect(start_run)

	show_menu()


## Quits the current run from the pause menu; the run still counts and is saved.
func leave_run() -> void:
	if in_run and not player.dead:
		progression.end_run(enemies.kills)
	show_menu()


func show_menu() -> void:
	in_run = false
	_was_captured = false
	pause_menu.close()
	level_up_screen.close()
	enemies.clear()
	enemies.active = false
	bow.clear()
	bow.active = false
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	range_ring.visible = false
	hud.visible = false
	camera_rig.capture_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_camera.current = true
	main_menu.show_menu()


func start_run() -> void:
	in_run = true
	_was_captured = false
	pause_menu.close()
	level_up_screen.close()
	main_menu.visible = false
	progression.start_run()
	boosts.reset()
	enemies.clear()
	bow.clear()
	_run_gold = 0

	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.visible = true
	player.reset(_max_hp())
	_apply_stats()
	range_ring.visible = true

	enemies.active = true
	bow.active = true
	camera_rig.capture_enabled = true
	camera_rig.camera.current = true
	hud.visible = true
	hud.hide_death()


## Combines base stats, character level, market items and this run's boosts.
func _apply_stats() -> void:
	player.speed_multiplier = 1.0 + shop.bonus("speedBonus") + boosts.total("moveSpeed")
	player.regen = boosts.total("regen")
	player.set_max_hp(_max_hp())
	bow.damage_multiplier = progression.damage_multiplier() + shop.bonus("damageBonus") + boosts.total("damage")
	bow.attack_speed_multiplier = 1.0 + shop.bonus("attackSpeedBonus") + boosts.total("attackSpeed")
	bow.range_bonus = shop.bonus("rangeBonus") + boosts.total("range")
	bow.crit_chance = minf(1.0, bow.base_crit_chance + boosts.total("critChance"))
	bow.crit_multiplier = bow.base_crit_multiplier + boosts.total("critDamage")
	range_ring.radius = bow.attack_range()
	hud.set_stats(stat_list())


## The stats shown in the character panel and the pause menu, as [name, value].
func stat_list() -> Array:
	return [
		["Can", "%d" % int(player.max_hp)],
		["Hasar", "%.1f" % bow.hit_damage()],
		["Kritik Şansı", "%%%d" % roundi(bow.crit_chance * 100.0)],
		["Kritik Hasarı", "x%.2f" % bow.crit_multiplier],
		["Saldırı Hızı", "%.2f/sn" % bow.shots_per_second()],
		["Saldırı Alanı", "%.1f m" % bow.attack_range()],
		["Hareket Hızı", "%.1f" % player.move_speed()],
		["Can Yenileme", "%.1f/sn" % player.regen],
	]


func _max_hp() -> float:
	return float(player.t.maxHp) + progression.max_hp_bonus() + shop.bonus("maxHpBonus") + boosts.total("maxHp")


func _can_pause() -> bool:
	return in_run and not player.dead and not level_up_screen.visible


func _on_popup_closed() -> void:
	# Don't treat the mouse release from the popup as a new "lost focus" pause.
	_was_captured = false
	hud.hide_hint()


## Low quality renders the world at fewer pixels (faster), high at full resolution.
func set_quality(quality: String) -> void:
	if not PIXEL_SCALES.has(quality):
		quality = DEFAULT_QUALITY
	_world_view.stretch_shrink = PIXEL_SCALES[quality]
	_sun.shadow_enabled = quality != "low"
	if hud:
		hud.world_scale = _world_view.stretch_shrink
	if pause_menu:
		pause_menu.set_quality(quality)
	if progression and progression.profile.get("quality", "") != quality:
		progression.profile.quality = quality
		store.save_to_disk()


func _on_enemy_killed(_at: Vector3, exp_amount: int, gold_amount: int) -> void:
	progression.add_exp(exp_amount)
	progression.add_gold(gold_amount)
	_run_gold += gold_amount


func _on_level_up(level: int) -> void:
	_apply_stats()
	if in_run and not player.dead:
		level_up_screen.queue_level_up(level)


func _on_player_died() -> void:
	enemies.active = false
	bow.active = false
	progression.end_run(enemies.kills)
	camera_rig.capture_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_death(progression.level, enemies.kills, _run_gold, enemies.run_time)


func _update_menu_camera(delta: float) -> void:
	_menu_angle += delta * 0.06
	var ground := terrain.height_at(0, 0)
	menu_camera.position = Vector3(sin(_menu_angle) * 30.0, ground + 14.0, cos(_menu_angle) * 30.0)
	menu_camera.look_at(Vector3(0, ground + 2.0, 0))


## 3D renders into a SubViewport at a fraction of the screen resolution (see
## PIXEL_SCALES), scaled up with nearest filtering: pixel world, crisp UI.
func _build_world_viewport() -> void:
	var container := SubViewportContainer.new()
	container.name = "WorldView"
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.stretch_shrink = PIXEL_SCALES[DEFAULT_QUALITY]
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(container)
	_world_view = container

	var viewport := SubViewport.new()
	viewport.name = "WorldViewport"
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.audio_listener_enable_3d = true
	container.add_child(viewport)

	world = Node3D.new()
	world.name = "World"
	viewport.add_child(world)


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
	world.add_child(world_env)

	var sun := DirectionalLight3D.new()
	_sun = sun
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_color = Color("#fff1d6")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	world.add_child(sun)
