## Game flow: login (or the account remembered on this device) → main menu →
## run on a random map (forest, beach, dungeon) → (death) → run again or back
## to the menu.
## During a run: level-ups pause for a boost choice, Esc opens the pause menu.
## The account has up to 3 characters (warrior, archer, mage) sharing one
## backpack of items and chests; the active character's class and gear decide
## its starting weapon, look and stats. Pets in the account's pet slots
## follow the player and add their stats; R casts the class ultimate.
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
const LootOrbs := preload("res://scripts/combat/loot_orbs.gd")
const WeaponSet := preload("res://scripts/combat/weapon_set.gd")
const DungeonGate := preload("res://scripts/combat/dungeon_gate.gd")
const Ultimate := preload("res://scripts/combat/ultimate.gd")
const PetFollowers := preload("res://scripts/player/pet_followers.gd")
const Pets := preload("res://scripts/progression/pets.gd")
const Mounts := preload("res://scripts/progression/mounts.gd")
const Cosmetics := preload("res://scripts/progression/cosmetics.gd")
const ProfileStore := preload("res://scripts/progression/profile_store.gd")
const Progression := preload("res://scripts/progression/progression.gd")
const SkillTree := preload("res://scripts/progression/skill_tree.gd")
const RunBoosts := preload("res://scripts/progression/run_boosts.gd")
const Inventory := preload("res://scripts/progression/inventory.gd")
const Achievements := preload("res://scripts/progression/achievements.gd")
const Food := preload("res://scripts/progression/food.gd")
const Daily := preload("res://scripts/progression/daily.gd")
const Screen := preload("res://scripts/core/screen.gd")
const Hub := preload("res://scripts/world/hub.gd")
const ChestWheel := preload("res://scripts/ui/chest_wheel.gd")
const SoundPlayer := preload("res://scripts/core/sound.gd")
const LoginScreen := preload("res://scripts/ui/login_screen.gd")
const MainMenu := preload("res://scripts/ui/main_menu.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const LevelUpScreen := preload("res://scripts/ui/level_up_screen.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")
const CheatMenu := preload("res://scripts/ui/cheat_menu.gd")
const UiTheme := preload("res://scripts/ui/theme.gd")
const NetClient := preload("res://scripts/net/net_client.gd")
const Coop := preload("res://scripts/net/coop.gd")
const Weather := preload("res://scripts/world/weather.gd")
const TouchControls := preload("res://scripts/ui/touch_controls.gd")

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
var loot_orbs: LootOrbs
var weapons: WeaponSet
var dungeon: DungeonGate
var ultimate: Ultimate
var pets: Pets
var mounts: Mounts
var cosmetics: Cosmetics
var pet_followers: PetFollowers
var progression: Progression
var skill_tree: SkillTree
var boosts := RunBoosts.new()
var inventory: Inventory
var achievements: Achievements
var daily: Daily
var food: Food
var chest_wheel: ChestWheel
var sound: SoundPlayer
var hud: Hud
var level_up_screen: LevelUpScreen
var pause_menu: PauseMenu
var cheat_menu: CheatMenu
var login_screen: LoginScreen
var main_menu: MainMenu
var store := ProfileStore.new()
## Online server connection (rooms, invites) and the live co-op run.
var net: NetClient
var coop: Coop
const HEAL_PULSE_TIME := 6.0
var _pulse_left := HEAL_PULSE_TIME
var healed_pulses := 0
var _world_fight_over := false
var weather: Node
var touch: CanvasLayer
var _pvp_over := false
## The hub tavern (walkable, with everyone online).
var hub: Hub
## Extra gold in runs while in a guild.
const GUILD_GOLD_BONUS := 0.05
var in_run := false

var _world_cfg: Dictionary
var _world_view: SubViewportContainer
var _sun: DirectionalLight3D
## True while the mouse was captured last frame; losing it mid-run pauses
## (browsers swallow Esc and just release the mouse).
var _was_captured := false
var _run_gold := 0
## Names of the items and chests found this run.
var _run_loot := PackedStringArray()
var _bosses_killed := 0
## The character playing the current run.
var _character: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _menu_angle := 0.0
## Maps from data/maps.json and the one the world is built for.
var maps: Dictionary
var map_id := ""
## Map the next run uses instead of a random one (tests).
var forced_map := ""
var _sky_mat: ProceduralSkyMaterial
var _env: Environment
## Last player position, for the steps achievement.
var _last_step_pos := Vector3.ZERO


func _ready() -> void:
	# Sounds and music live in a child node, not an autoload: an updated game
	# pack loaded by the start-up scene cannot add autoloads to an older exe.
	sound = SoundPlayer.new()
	sound.name = "Sound"
	add_child(sound)
	InputSetup.register()
	Screen.restore()
	_world_cfg = Config.load_json("res://data/world.json")
	maps = Config.load_json("res://data/maps.json")
	_build_world_viewport()
	_build_environment()

	terrain = Terrain.new()
	terrain.name = "Terrain"
	world.add_child(terrain)
	var props := Props.new()
	props.name = "Props"
	world.add_child(props)
	load_map("forest")

	# A slowly circling camera shows the forest behind the menus.
	menu_camera = Camera3D.new()
	menu_camera.name = "MenuCamera"
	world.add_child(menu_camera)
	menu_camera.current = true
	_update_menu_camera(0.0)

	net = NetClient.new()
	net.name = "Net"
	add_child(net)
	net.start()

	store.load_from_disk()
	var remembered := store.remembered()
	var token := store.token_for(remembered)
	if remembered != "" and (token != "" or not net.enabled):
		# This device remembers the account: straight to the menu (the
		# online sign-in happens in the background).
		if token != "":
			net.resume(remembered, token)
		login.call_deferred(remembered, true)
		return
	login_screen = LoginScreen.new()
	login_screen.setup(store, net)
	login_screen.logged_in.connect(login)
	add_child(login_screen)


## Builds the world for a map from data/maps.json: ground, details, sky,
## light and fog. Everything that holds the terrain keeps working.
func load_map(id: String) -> void:
	if not maps.has(id):
		id = "forest"
	map_id = id
	var m: Dictionary = maps[id]
	terrain.build(_world_cfg, m)
	(world.get_node("Props") as Props).build(terrain, _world_cfg, m)
	apply_environment(m)
	if enemies:
		enemies.set_map(id)
	if player:
		player.set("_spawn_point", Vector3(0, terrain.height_at(0, 0) + 0.5, 0))


## Sky, ambient light, fog and sun (keys as in data/maps.json).
func apply_environment(m: Dictionary) -> void:
	_sky_mat.sky_top_color = Color(str(m.sky[0]))
	_sky_mat.sky_horizon_color = Color(str(m.sky[1]))
	_sky_mat.ground_horizon_color = Color(str(m.sky[1])).darkened(0.1)
	_sky_mat.ground_bottom_color = Color(str(m.sky[2]))
	_env.ambient_light_color = Color(str(m.ambient))
	_env.ambient_light_energy = float(m.ambientEnergy)
	_env.fog_light_color = Color(str(m.fog))
	_env.fog_density = float(m.fogDensity)
	_sun.light_color = Color(str(m.sun))
	_sun.light_energy = float(m.sunEnergy)
	if weather:
		weather.set_base(m)


func map_name(id := "") -> String:
	return str(maps.get(id if id != "" else map_id, {}).get("name", ""))

func _process(delta: float) -> void:
	if touch:
		var touch_on := (in_run or (hub != null and hub.active)) and not get_tree().paused
		if touch_on != touch.playing:
			touch.set_playing(touch_on)
	if not in_run:
		_update_menu_camera(delta)
		if weather:
			weather.clear()
		return
	_world_fight_tick()
	_healer_pulse(delta)
	if weather:
		weather.update(delta, enemies.run_time)
		enemies.night = weather.night
	if not player.dead and not get_tree().paused:
		var moved := Vector2(player.global_position.x - _last_step_pos.x, player.global_position.z - _last_step_pos.z).length()
		if moved < 5.0:
			achievements.add("steps", moved)
	_last_step_pos = player.global_position
	hud.set_party(coop.party() if coop.partner_count() > 0 else [])
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _was_captured and not captured and not cheat_menu.is_open():
		pause_menu.open()
	_was_captured = captured


## Logs in (creating the account if new) and opens the main menu.
## `remember`: log straight in on this device next time.
func login(username: String, remember := false) -> void:
	var profile := store.login(username)
	if remember:
		store.set_remember(username)
	progression = Progression.new(store, profile)
	skill_tree = SkillTree.new(profile, store)
	inventory = Inventory.new(profile, store)
	pets = Pets.new(profile, store)
	mounts = Mounts.new(profile, store)
	cosmetics = Cosmetics.new(profile, store)
	inventory.cosmetics = cosmetics
	# Account skills (Hazine branch) change the backpack, chests, prices and eggs.
	inventory.gear.bonus = skill_tree.total
	pets.bonus = skill_tree.total
	achievements = Achievements.new(profile, store)
	achievements.reward_gold = progression.add_gold
	achievements.unlocked.connect(_on_achievement)
	daily = Daily.new(profile, achievements)
	daily.grant = grant_reward
	daily.completed.connect(_on_quest_done)
	food = Food.new(profile, achievements)
	food.pay = progression.add_gold
	_rng.randomize()

	player = Player.new()
	player.name = "Player"
	player.position = Vector3(0, terrain.height_at(0, 0) + 0.5, 0)
	world.add_child(player)
	player.died.connect(_on_player_died)

	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	camera_rig.target = player
	world.add_child(camera_rig)
	camera_rig.zoom_changed.connect(func(distance: float) -> void:
		(progression.profile.settings as Dictionary).cameraZoom = distance)

	enemies = EnemyManager.new()
	enemies.name = "Enemies"
	world.add_child(enemies)
	enemies.setup(terrain, player, float(_world_cfg.playableHalfSize))
	enemies.enemy_killed.connect(_on_enemy_killed)
	enemies.boss_defeated.connect(_on_boss_defeated)

	bow = AutoBow.new()
	bow.name = "Bow"
	world.add_child(bow)
	bow.setup(player, enemies)
	bow.fired.connect(player.play_attack)

	weapons = WeaponSet.new()
	weapons.name = "Weapons"
	world.add_child(weapons)
	weapons.setup(player, enemies, bow, terrain)
	weapons.attacked.connect(player.play_attack)

	dungeon = DungeonGate.new()
	dungeon.name = "DungeonGate"
	world.add_child(dungeon)
	dungeon.setup(player, enemies, terrain, float(_world_cfg.playableHalfSize))
	dungeon.opened.connect(func() -> void: hud.toast("ZİNDAN KAPISI AÇILDI! MOR KAPIYA GİR"))
	dungeon.fight_started.connect(func(guardian: String) -> void:
		hud.show_title(UiTheme.upper(guardian), "Zindan muhafızını 60 saniyede yen!"))
	dungeon.cleared.connect(_on_dungeon_cleared)
	dungeon.failed.connect(func() -> void: hud.toast("MUHAFIZ KAÇTI, KAPI KAPANDI"))

	ultimate = Ultimate.new()
	ultimate.name = "Ultimate"
	world.add_child(ultimate)
	ultimate.setup(player, enemies, terrain, bow)
	ultimate.camera_rig = camera_rig

	pet_followers = PetFollowers.new()
	pet_followers.name = "Pets"
	world.add_child(pet_followers)
	pet_followers.setup(player, terrain)

	loot_orbs = LootOrbs.new()
	loot_orbs.name = "LootOrbs"
	world.add_child(loot_orbs)
	loot_orbs.setup(terrain)

	range_ring = RangeRing.new()
	range_ring.name = "RangeRing"
	range_ring.terrain = terrain
	range_ring.target = player
	world.add_child(range_ring)

	progression.level_up.connect(_on_level_up)
	_connect_sounds()

	hud = Hud.new()
	add_child(hud)
	hud.setup(player, progression, enemies, camera_rig.camera, _world_view.stretch_shrink)
	hud.restart_requested.connect(_on_restart)
	hud.menu_requested.connect(show_menu)
	bow.hit_landed.connect(hud.show_hit)
	weapons.hit_landed.connect(hud.show_hit)
	bow.hit_landed.connect(_on_hit_dealt)
	weapons.hit_landed.connect(_on_hit_dealt)
	ultimate.hit_landed.connect(hud.show_hit)
	ultimate.hit_landed.connect(_on_hit_dealt)
	ultimate.hud = hud
	hud.ultimate = ultimate

	level_up_screen = LevelUpScreen.new()
	add_child(level_up_screen)
	level_up_screen.setup(roll_level_up_choices, apply_level_up_choice)
	level_up_screen.closed.connect(_on_popup_closed)

	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.setup(boosts, str(profile.get("quality", DEFAULT_QUALITY)))
	pause_menu.can_pause = _can_pause
	pause_menu.stats_source = stat_list
	pause_menu.weapons_source = weapon_list
	pause_menu.resumed.connect(_on_popup_closed)
	pause_menu.menu_requested.connect(leave_run)
	pause_menu.quality_selected.connect(set_quality)
	set_quality(str(profile.get("quality", DEFAULT_QUALITY)))

	cheat_menu = CheatMenu.new()
	add_child(cheat_menu)
	cheat_menu.setup()
	cheat_menu.changed.connect(_apply_stats)
	cheat_menu.god_mode_toggled.connect(func(on: bool) -> void: player.god_mode = on)
	cheat_menu.action_requested.connect(cheat)

	main_menu = MainMenu.new()
	add_child(main_menu)
	main_menu.setup(progression, skill_tree, inventory)
	main_menu.achievements = achievements
	main_menu.daily = daily
	main_menu.food = food
	main_menu.duel_fighter = duel_fighter
	main_menu.pets = pets
	main_menu.mounts = mounts
	main_menu.cosmetics = cosmetics
	main_menu.play_pressed.connect(start_run)
	main_menu.duel_requested.connect(start_duel)
	main_menu.world_boss_requested.connect(start_world_boss)
	main_menu.chest_open_requested.connect(open_chest)
	main_menu.quality_selected.connect(set_quality)
	main_menu.settings_changed.connect(apply_settings)
	main_menu.logout_requested.connect(logout)
	main_menu.reset_requested.connect(reset_account)
	if daily.login_ready():
		main_menu.notify("Günlük ödülün hazır! Görevler sayfasına bak.")
	main_menu.version_text = _version_text()

	chest_wheel = ChestWheel.new()
	add_child(chest_wheel)
	chest_wheel.setup(inventory.gear)
	chest_wheel.closed.connect(main_menu.refresh)

	touch = TouchControls.new()
	touch.name = "TouchControls"
	add_child(touch)
	touch.camera_rig = camera_rig
	touch.ultimate_pressed.connect(func() -> void: ultimate.try_cast())
	touch.jump_pressed.connect(func() -> void:
		Input.action_press("jump")
		await get_tree().create_timer(0.12).timeout
		Input.action_release("jump"))
	touch.pause_pressed.connect(func() -> void:
		if in_run:
			pause_menu.open())
	weather = Weather.new()
	weather.name = "Weather"
	world.add_child(weather)
	weather.setup(_env, _sky_mat, _sun, player)
	if maps.has(map_id):
		weather.set_base(maps[map_id])
	coop = Coop.new()
	coop.name = "Coop"
	add_child(coop)
	coop.setup(self, net)
	hub = Hub.new()
	hub.name = "Hub"
	add_child(hub)
	hub.setup(self, net)
	main_menu.net = net
	main_menu.hub_requested.connect(enter_hub)
	net.notice.connect(_on_net_notice)
	net.invited.connect(_on_invited)
	net.status_changed.connect(func(_s: String) -> void: main_menu.refresh_online())
	net.room_changed.connect(main_menu.refresh_online)
	net.guild_changed.connect(main_menu.refresh_guild)
	net.guild_list_received.connect(main_menu.refresh_guild)
	net.guild_chat_received.connect(func(_n: String, _t: String) -> void: main_menu.refresh_guild())
	net.guild_changed.connect(func() -> void:
		if hub and hub.tavern:
			hub.tavern.set_guild(net.guild))
	net.trades_changed.connect(main_menu.refresh_trade)
	net.trade_done.connect(_on_trade_done)
	net.guild_reward.connect(_on_guild_reward)
	net.guild_donated.connect(func(gold: int) -> void:
		progression.add_gold(-gold)
		store.save_to_disk()
		_on_net_notice("Lonca kasasına %d altın bağışladın." % gold))
	net.duel_changed.connect(main_menu.refresh_duel)
	net.duel_played.connect(main_menu.show_duel)
	net.game_played.connect(_on_game_played)
	net.game_changed.connect(func() -> void:
		if main_menu.visible and main_menu.section == "games":
			main_menu.open_section("games"))
	net.world_boss_changed.connect(func() -> void:
		if main_menu.visible and main_menu.section == "worldboss":
			main_menu.open_section("worldboss"))
	net.world_boss_reward.connect(func(gold: int) -> void:
		progression.add_gold(gold)
		progression.store.save_to_disk()
		main_menu.notify("Dünya bossu ödülü: +%d altın" % gold))
	net.who_updated.connect(main_menu.update_friend_status)
	net.online_list_updated.connect(main_menu.update_online_list)
	net.leaderboard_received.connect(main_menu.on_leaderboard)
	net.signed_in.connect(_on_signed_in)
	net.sign_in_failed.connect(_on_sign_in_failed)
	net.password_changed.connect(_on_password_changed)
	store.saved.connect(net.save_profile)
	# The server keeps the newest game (an older one there is replaced).
	net.save_profile(profile)

	apply_settings()
	show_menu()


## F11 switches full screen anywhere in the game.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F11:
		Screen.toggle()
		if main_menu and main_menu.visible:
			main_menu.refresh()
		get_viewport().set_input_as_handled()


## Applies the account's settings (camera distance, mouse speed, damage numbers).
func apply_settings() -> void:
	var st: Dictionary = progression.profile.get("settings", {})
	camera_rig.zoom = clampf(float(st.get("cameraZoom", 7.0)), CameraRig.MIN_ZOOM, CameraRig.MAX_ZOOM)
	camera_rig.sensitivity_scale = float(st.get("mouseSpeed", 1.0))
	hud.show_damage_numbers = bool(st.get("damageNumbers", true))
	main_menu.quality = str(progression.profile.get("quality", DEFAULT_QUALITY))
	sound.set_volumes(float(st.get("musicVolume", 0.5)), float(st.get("sfxVolume", 0.7)))
	if touch:
		touch.set_mode("on" if bool(st.get("touchControls", false)) else "auto")


## Signed in online after the menu opened (remembered account, offline
## start, reconnect): a newer game on the server replaces this device's.
func _on_signed_in(account_name: String, token: String, cloud: Dictionary, saved_at: float) -> void:
	if progression == null or account_name.to_lower() != str(progression.profile.name).to_lower():
		return
	account_name = str(progression.profile.name)
	if store.remembered() == account_name:
		store.set_token(account_name, token)
	if not in_run and store.adopt(account_name, cloud, saved_at):
		apply_settings()
		main_menu.selected_item = -1
		main_menu.refresh()
		main_menu.notify("Oyunun sunucudan yüklendi.")
	else:
		net.save_profile(progression.profile)
	main_menu.refresh_online()


func _on_sign_in_failed(code: String, message: String) -> void:
	if progression == null:
		return
	if code == "token":
		# The remembered sign-in no longer works (password changed elsewhere).
		store.set_remember("")
		if not in_run:
			logout()
			return
	_on_net_notice(message if code != "taken" else "Bu isim çevrimiçi başka bir oyuncuya ait. Çevrimiçi oynamak için yeni hesap aç.")


func _on_password_changed(ok: bool, message: String, token: String) -> void:
	if ok and token != "" and store.remembered() == str(progression.profile.name):
		store.set_token(str(progression.profile.name), token)
	main_menu.notify(message)


## Forgets the remembered account and goes back to the login screen.
func logout() -> void:
	store.set_remember("")
	get_tree().reload_current_scene()


## Wipes the account (characters, items, gold, levels, skills, achievements).
func reset_account() -> void:
	store.reset_profile(progression.profile)
	progression.profile.activeCharacter = -1
	main_menu.selected_item = -1
	apply_settings()
	main_menu.open_section("city")
	main_menu.refresh()
	main_menu.notify("Hesap sıfırlandı.")


func _version_text() -> String:
	if not FileAccess.file_exists("res://version.txt"):
		return "geliştirme sürümü"
	var parts := FileAccess.get_file_as_string("res://version.txt").strip_edges().split("|")
	return "Yapı %s  ·  Godot %s" % [parts[0], parts[1] if parts.size() > 1 else "?"]


func _on_hit_dealt(_at: Vector3, amount: float, _crit: bool) -> void:
	achievements.add("damageDealt", amount)


## Quits the current run from the pause menu; the run still counts and is saved.
func leave_run() -> void:
	if in_run and not player.dead:
		_end_run()
	show_menu()


## Walks into the hub tavern (the menu's Taverna page).
func enter_hub() -> void:
	if in_run or hub.active:
		return
	if not net.is_online():
		main_menu.notify("Taverna için çevrimiçi olmalısın.")
		return
	hub.enter()
	sound.music("calm")


## Leaves the hub tavern and shows the menu.
func leave_hub() -> void:
	if hub.active:
		hub.leave()
		show_menu()


func show_menu() -> void:
	sound.music("calm")
	if hub and hub.active:
		hub.leave()
	if coop:
		coop.leave()
	in_run = false
	_was_captured = false
	pause_menu.close()
	level_up_screen.close()
	enemies.clear()
	enemies.active = false
	bow.clear()
	bow.active = false
	weapons.active = false
	dungeon.active = false
	dungeon.reset()
	weapons.reset()
	ultimate.active = false
	ultimate.reset()
	pet_followers.set_pets([])
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	range_ring.visible = false
	loot_orbs.clear()
	hud.visible = false
	cheat_menu.visible = false
	camera_rig.capture_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_camera.current = true
	main_menu.show_menu()


## Starts a run. In a room only the host starts, and the room starts with it;
## `guest_map` is set when the host started one and this game joins it.
func start_run(guest_map := "", pvp := false) -> void:
	var guest := guest_map != ""
	if net and net.in_room() and not net.is_host() and not guest:
		main_menu.notify("Oyunu oda sahibi başlatır. Başlayınca otomatik katılırsın.")
		return
	# Every run picks a random map and shows its name.
	var ids := maps.keys()
	var next := "dungeon" if pvp else guest_map if guest else (forced_map if forced_map != "" else str(ids[_rng.randi() % ids.size()]))
	if next != map_id:
		load_map(next)
	enemies.set_map(next)
	sound.music("run")
	var played: Dictionary = achievements.profile.stats.get("maps", {})
	played[next] = true
	achievements.profile.stats.maps = played
	achievements.profile.stats.mapsPlayed = float(played.size())
	in_run = true
	_was_captured = false
	pause_menu.close()
	level_up_screen.close()
	main_menu.visible = false
	progression.start_run()
	boosts.reset()
	weapons.reset()
	bow.unevolve()
	enemies.clear()
	bow.clear()
	loot_orbs.clear()
	enemies.mirror = guest or pvp
	enemies.difficulty = {"hp": 1.0, "damage": 1.0, "reward": 1.0} if pvp else difficulty_info()
	_pvp_over = false
	enemies.targets = [player]
	_run_gold = 0
	_run_loot.clear()
	_bosses_killed = 0
	cheat_menu.visible = true

	_character = _ensure_character()
	var info := inventory.class_info(class_id())
	var archer := class_id() == "archer"
	weapons.uses_bow = archer
	weapons.class_id = class_id()
	if not archer:
		weapons.add(str(info.weapon))
	hud.character_name = str(_character.name)
	hud.class_name_text = str(info.name)

	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.visible = true
	player.set_look(character_look(_character))
	player.reset(_max_hp())
	if pvp:
		var side := 6.0 if guest else -6.0
		player.global_position = Vector3(side, terrain.height_at(side, 0.0) + 0.5, 0.0)
	_apply_stats()
	range_ring.visible = true

	enemies.active = true
	bow.active = archer
	weapons.active = true
	# Dungeon gates open in solo runs (the host runs the enemies in co-op).
	dungeon.reset()
	dungeon.active = not guest and not pvp and coop.partner_count() == 0
	ultimate.reset()
	ultimate.class_id = class_id()
	ultimate.active = true
	pet_followers.set_pets(pets.active_kinds())
	hud.set_weapons(weapon_list())
	camera_rig.capture_enabled = true
	camera_rig.camera.current = true
	hud.visible = true
	hud.hide_death()
	var subtitle := str(maps[map_id].get("subtitle", ""))
	if net and net.in_room() and net.members().size() > 1:
		subtitle = "Birlikte: " + ", ".join(net.members().map(func(m: Dictionary) -> String: return str(m.name)))
	hud.show_title(UiTheme.upper(map_name()), subtitle)
	_last_step_pos = player.global_position
	# In a room the run is shared live (see Coop); the pause menu can't stop it.
	pause_menu.freezes = not (net and net.in_room())
	if pvp:
		if guest:
			coop.start_duel_as_guest()
		else:
			coop.start_duel_as_host()
		hud.show_title("DÜELLO", " vs ".join(net.members().map(func(m: Dictionary) -> String: return str(m.name))))
	elif net and net.in_room():
		if guest:
			coop.start_as_guest()
		else:
			coop.start_as_host(next)


## The room's host started a run: join it on the same map.
func join_coop_run(map: String, pvp := false) -> void:
	if not maps.has(map):
		map = "forest"
	chest_wheel.visible = false
	main_menu.close_confirm()
	if in_run and not player.dead:
		_end_run()
	start_run(map, pvp)


## The host left the run or the room closed: back to the menu.
func coop_host_ended() -> void:
	if not in_run:
		coop.stop()
		return
	if not player.dead:
		_end_run()
	coop.stop()
	show_menu()
	main_menu.notify("Ev sahibi oyunu bitirdi.")


## A dice / card game finished: the loser pays the bet to the winner.
func _on_game_played(result: Dictionary) -> void:
	var me := str(net.account).to_lower()
	var winner := int(result.winner)
	var mine: bool = str((result.a if winner == 0 else result.b).name).to_lower() == me
	var bet := int(result.bet)
	if mine:
		progression.add_gold(bet)
	else:
		progression.profile.gold = maxi(0, int(progression.profile.gold) - bet)
	achievements.add("gamesWon" if mine else "gamesLost")
	achievements.check()
	progression.store.save_to_disk()
	main_menu.show_game(result)
	main_menu.refresh()


## The weekly world boss: a two minute fight alone with it; the damage done
## counts toward the server's shared health (see server/worldboss.js).
func start_world_boss() -> void:
	var info: Dictionary = net.world_boss
	if in_run or not net.is_online() or net.in_room() or info.is_empty() or bool(info.get("dead", false)):
		return
	start_run()
	enemies.difficulty = {"hp": 1.0, "damage": 1.0, "reward": 1.0}
	enemies.world_fight = str(info.kind)
	enemies.world_damage = 0.0
	_world_fight_over = false
	dungeon.active = false
	hud.show_title(UiTheme.upper(str(info.name)), "Dünya Bossu")


## The healer's pulse: every few seconds heals and shields the healer and the
## partners (their games get a `heal` message).
func _healer_pulse(delta: float) -> void:
	if class_id() != "healer" or player.dead or get_tree().paused:
		return
	_pulse_left -= delta
	if _pulse_left > 0.0:
		return
	_pulse_left = HEAL_PULSE_TIME
	var amount: float = player.max_hp * 0.1
	player.heal(amount)
	player.shield(0.8)
	if coop.running and not coop.pvp:
		for r: Node3D in coop.puppets():
			net.send_game({"k": "heal", "a": snappedf(amount, 0.1)}, int(r.peer_id))
	healed_pulses += 1


func world_fight_running() -> bool:
	return enemies.world_fight != ""


func _world_fight_tick() -> void:
	if enemies.world_fight == "" or _world_fight_over:
		return
	var boss_gone: bool = enemies.run_time > 3.0 and enemies.boss_index() < 0
	if player.dead or boss_gone or enemies.run_time > 120.0:
		_world_fight_over = true
		net.report_world_boss(enemies.world_damage)
		hud.toast("Boss'a %d hasar verdin" % roundi(enemies.world_damage))
		if not player.dead:
			await get_tree().create_timer(3.0).timeout
			if in_run:
				leave_run()


## The room host starts a real-time duel with the other player in the room.
func start_duel() -> void:
	if net and net.in_room() and net.is_host() and net.members().size() == 2 and not in_run:
		chest_wheel.visible = false
		start_run("", true)


## One of the two duellists fell: counts the win or loss and ends the duel.
func pvp_finished(won: bool) -> void:
	if _pvp_over or not coop.pvp:
		return
	_pvp_over = true
	achievements.add("duelsWon" if won else "duelsLost")
	achievements.check()
	progression.store.save_to_disk()
	if won:
		hud.toast("KAZANDIN!")
		await get_tree().create_timer(3.0).timeout
		if in_run and coop.pvp:
			leave_run()


func _on_restart() -> void:
	if coop.pvp:
		show_menu()
		return
	if net.in_room() and not net.is_host():
		show_menu()
	else:
		start_run()


func _on_net_notice(text: String) -> void:
	if in_run:
		hud.toast(UiTheme.upper(text))
	else:
		main_menu.notify(text)


## Sound effects for what happens in a run (see scripts/core/sound.gd).
func _connect_sounds() -> void:
	bow.fired.connect(func(_d: Vector3) -> void: sound.play("shoot"))
	weapons.attacked.connect(func(_d: Vector3) -> void: sound.play("shoot", 0.8))
	for source: Object in [bow, weapons, ultimate]:
		source.hit_landed.connect(func(_at: Vector3, _amount: float, crit: bool) -> void: sound.play("hit", 1.3 if crit else 1.0))
	enemies.enemy_killed.connect(func(_at: Vector3, _e: int, _g: int) -> void: sound.play("kill"))
	enemies.boss_spawned.connect(func(_n: String) -> void: sound.play("boss"))
	enemies.boss_defeated.connect(func(_n: String) -> void: sound.play("chest"))
	progression.level_up.connect(func(_l: int) -> void: sound.play("levelup"))
	progression.exp_gained.connect(func(_a: int) -> void: sound.play("exp"))
	var gold_seen := [progression.gold()]
	progression.gold_changed.connect(func(g: int) -> void:
		if in_run and g > int(gold_seen[0]):
			sound.play("coin")
		gold_seen[0] = g)
	var hp_seen := [INF]
	player.health_changed.connect(func(hp: float, _m: float) -> void:
		if hp < float(hp_seen[0]) - 0.5:
			sound.play("hurt")
		hp_seen[0] = hp)
	ultimate.cast.connect(func(_v: String, _at: Vector3) -> void: sound.play("ult"))
	dungeon.opened.connect(func() -> void: sound.play("gate"))
	dungeon.cleared.connect(func(_g: String, _c: int) -> void: sound.play("chest"))
	daily.completed.connect(func(_d: Dictionary) -> void: sound.play("quest"))


## The server paid out the weekly guild reward.
func _on_guild_reward(gold: int) -> void:
	progression.add_gold(gold)
	store.save_to_disk()
	sound.play("coin")
	_on_net_notice("Lonca ödülü: +%d altın!" % gold)


## A trade went through: the seller hands over the item and gets the gold,
## the buyer pays and gets the item.
func _on_trade_done(info: Dictionary) -> void:
	var me := net.account.to_lower()
	var price := int(info.price)
	var profile: Dictionary = progression.profile
	var item_name := inventory.gear.item_name(info.item) if not inventory.gear.base(str(info.item.get("base", ""))).is_empty() else "eşya"
	if str(info.from).to_lower() == me:
		inventory.take_item(int(info.item.get("uid", -1)))
		profile.gold = int(profile.gold) + price
		_on_net_notice("%s, %s'ı %d altına aldı." % [info.to, item_name, price])
	elif str(info.to).to_lower() == me:
		if inventory.receive_item(info.item).is_empty():
			_on_net_notice("Eşya çantana sığmadı.")
			return
		profile.gold = maxi(0, int(profile.gold) - price)
		_on_net_notice("%s artık senin! (%d altın)" % [item_name, price])
	else:
		return
	achievements.add("trades", 1.0)
	inventory.save()
	_check_achievements()
	sound.play("trade")
	main_menu.refresh_trade()


## A friend invites this player to their room: ask now (menu) or later (run).
func _on_invited(from_name: String, code: String) -> void:
	if in_run:
		hud.toast(UiTheme.upper("%s seni odasına çağırıyor (Arkadaşlar'dan katıl)" % from_name))
		return
	main_menu.ask_invite(from_name, code)


## The active character, creating a default archer if the account has none
## (the menu normally asks for one first).
func _ensure_character() -> Dictionary:
	if inventory.active_character().is_empty():
		if inventory.characters().is_empty():
			var hero := str(progression.profile.name)
			inventory.create_character(hero if hero.length() >= 2 else "Kahraman", "archer")
		else:
			inventory.set_active(int(inventory.characters()[0].id))
	return inventory.active_character()


func class_id() -> String:
	return str(_character["class"]) if not _character.is_empty() else "archer"


## Look of a character for PlayerModel.build (class colors plus worn gear).
func character_look(c: Dictionary) -> Dictionary:
	return inventory.character_look(c)


## Opens a chest from the backpack with the spinning wheel. The item is
## decided (and saved) right away; the wheel only shows it.
func open_chest(uid: int) -> Dictionary:
	var ch := inventory.chest_by_uid(uid)
	if ch.is_empty():
		return {}
	var it := inventory.open_chest(uid)
	if not it.is_empty():
		achievements.add("chestsOpened")
		achievements.check()
	if it.is_empty():
		main_menu.notify("Çanta dolu! Önce eşya sat.")
		return {}
	chest_wheel.spin(int(ch.tier), it)
	sound.play("chest")
	main_menu.refresh()
	return it


## Combines base stats, class, gear, character level, skill tree and boosts.
func _apply_stats() -> void:
	player.speed_multiplier = 1.0 + _extra("moveSpeed")
	player.defense = _extra("defense")
	player.regen = _extra("regen")
	player.set_max_hp(_max_hp())
	weapons.uses_bow = class_id() == "archer"
	bow.damage_multiplier = progression.damage_multiplier() + _extra("damage")
	bow.attack_speed_multiplier = 1.0 + _extra("attackSpeed")
	bow.range_bonus = _extra("range")
	bow.crit_chance = minf(1.0, bow.base_crit_chance + _extra("critChance"))
	bow.double_chance = _extra("doubleChance")
	weapons.double_chance = bow.double_chance
	bow.crit_multiplier = bow.base_crit_multiplier + _extra("critDamage")
	range_ring.radius = _attack_range()
	hud.set_stats(stat_list())


## Level-up cards: random boosts and weapons (new or upgrades), including the
## ones only the character's class can take. When any weapon can be offered,
## at least one card is a weapon.
func roll_level_up_choices() -> Array:
	var boost_cards: Array = []
	for d: Dictionary in boosts.defs:
		if d.has("class") and str(d["class"]) != class_id():
			continue
		if boosts.count(d.id) < int(d.maxStacks):
			boost_cards.append({"id": d.id, "type": "boost", "def": d, "now": boosts.count(d.id), "max": int(d.maxStacks)})
	var weapon_cards: Array = []
	for d: Dictionary in weapons.available_choices():
		weapon_cards.append({"id": d.id, "type": "weapon", "def": d, "now": weapons.level(d.id), "max": int(d.maxLevel)})
	weapon_cards.shuffle()
	var pool: Array = boost_cards + weapon_cards.slice(1)
	pool.shuffle()
	var picks: Array = []
	# A weapon that can evolve is always offered first.
	var evolve_cards := evolution_choices()
	if not evolve_cards.is_empty():
		picks.append(evolve_cards[0])
	if not weapon_cards.is_empty():
		picks.append(weapon_cards[0])
	picks.append_array(pool.slice(0, boosts.choices_per_level - picks.size()))
	picks.shuffle()
	return picks


## Evolutions ready now: the weapon is at its top level (the archer's bow
## just needs to be carried) and the matching boost was picked enough times.
func evolution_choices() -> Array:
	var out: Array = []
	for e: Dictionary in weapons.evolutions:
		var w := str(e.weapon)
		if w == "bow":
			if class_id() != "archer" or bow.is_evolved():
				continue
		elif weapons.evolved.has(w) or weapons.level(w) < int(weapons.def(w).get("maxLevel", 99)):
			continue
		if boosts.count(str(e.boost)) < int(e.get("boostStacks", 1)):
			continue
		out.append({"id": e.id, "type": "evolve", "def": e, "now": 0, "max": 1})
	return out


func apply_level_up_choice(choice: Dictionary) -> void:
	if choice.type == "evolve":
		var e: Dictionary = choice.def
		if str(e.weapon) == "bow":
			bow.evolve(WeaponSet.evolved_def(bow.data(), e))
		else:
			weapons.evolve(e)
		hud.set_weapons(weapon_list())
		hud.toast("SİLAH EVRİMİ: " + UiTheme.upper(str(e.name)))
		achievements.add("evolutions")
	elif choice.type == "weapon":
		weapons.add(str(choice.id))
		hud.set_weapons(weapon_list())
	else:
		boosts.add(str(choice.id))
	_apply_stats()


## Weapons carried this run as [def, level], the class weapon first.
func weapon_list() -> Array:
	if class_id() == "archer":
		return [[bow.data(), 1]] + weapons.owned()
	return weapons.owned()


## Id of the class starter weapon in WeaponSet ("" for the archer's bow).
func _main_weapon() -> String:
	return "" if class_id() == "archer" else str(inventory.class_info(class_id()).weapon)


func _attack_range() -> float:
	var id := _main_weapon()
	return bow.attack_range() if id == "" else weapons.reach(id)


## The stats shown in the character panel and the pause menu, as [name, value].
func stat_list() -> Array:
	return [
		["Can", "%d" % int(player.max_hp)],
		["Hasar", "%.1f" % (bow.hit_damage() if _main_weapon() == "" else weapons.hit_damage(_main_weapon()))],
		["Kritik Şansı", "%%%d" % roundi(bow.crit_chance * 100.0)],
		["Kritik Hasarı", "x%.2f" % bow.crit_multiplier],
		["Saldırı Hızı", "%.2f/sn" % (bow.shots_per_second() if _main_weapon() == "" else weapons.attacks_per_second(_main_weapon()))],
		["Saldırı Alanı", "%.1f m" % _attack_range()],
		["Hareket Hızı", "%.1f" % player.move_speed()],
		["Can Yenileme", "%.1f/sn" % player.regen],
		["Savunma", "%%%d" % roundi(minf(player.defense, Player.MAX_DEFENSE) * 100.0)],
	]


func _max_hp() -> float:
	var base := float(inventory.class_info(class_id()).maxHp) if inventory else float(player.t.maxHp)
	return base + progression.max_hp_bonus() + _extra("maxHp")


## The active character's strength for a duel in the arena (no run boosts):
## class, health, damage per hit, hits per second, crits and defense.
func duel_fighter() -> Dictionary:
	var cls := class_id()
	var info: Dictionary = inventory.class_info(cls)
	var w: Dictionary = bow.data() if cls == "archer" else weapons.def(str(info.weapon))
	var extra := func(stat: String) -> float:
		var sum := (skill_tree.total(stat) if skill_tree else 0.0) + (pets.total(stat) if pets else 0.0)
		if not _character.is_empty():
			sum += float((info.bonus as Dictionary).get(stat, 0.0)) + inventory.gear_total(_character, stat)
		return sum
	return {
		"cls": cls,
		"hp": float(info.maxHp) + progression.max_hp_bonus() + float(extra.call("maxHp")),
		"dmg": float(w.damage) * (progression.damage_multiplier() + float(extra.call("damage"))),
		"aps": (1.0 / float(w.cooldown)) * (1.0 + float(extra.call("attackSpeed"))),
		"crit": 0.05 + float(extra.call("critChance")),
		"critDmg": 1.5 + float(extra.call("critDamage")),
		"defense": minf(float(extra.call("defense")), Player.MAX_DEFENSE),
	}


## Run boosts, skill tree, pets, class bonus, worn gear and the developer cheat bonus for a stat.
func _extra(stat: String) -> float:
	var sum := boosts.total(stat) + (cheat_menu.total(stat) if cheat_menu else 0.0) + (skill_tree.total(stat) if skill_tree else 0.0)
	# Guild members earn a little more gold, and the guild's upgrades add more.
	if net and net.in_guild():
		sum += net.guild_bonus(stat) + (GUILD_GOLD_BONUS if stat == "goldGain" else 0.0)
	sum += pets.total(stat) if pets else 0.0
	if food and in_run:
		sum += food.total(stat)
	if inventory and not _character.is_empty():
		var bonus: Dictionary = inventory.class_info(class_id()).bonus
		sum += float(bonus.get(stat, 0.0)) + inventory.gear_total(_character, stat)
	return sum


## Developer cheat actions from the cheat menu.
func cheat(id: String) -> void:
	match id:
		"item":
			_drop_item(inventory.gear.roll_weighted([30, 25, 20, 13, 8, 4]))
			return
		"chest":
			_drop_chest(_rng.randi() % inventory.gear.chests.size())
			return
		"points":
			progression.profile.bonusSkillPoints = int(progression.profile.get("bonusSkillPoints", 0)) + 10
			_notify("+10 YETENEK PUANI")
			return
		"pet":
			var kinds := pets.kinds()
			var p := pets.add(str(kinds[_rng.randi() % kinds.size()].id))
			if not p.is_empty():
				_notify("PET: " + UiTheme.upper(str(pets.info(p).name)))
			return
		"level10":
			progression.profile.accountLevel = int(progression.profile.accountLevel) + 10
			_notify("HESAP SEVİYESİ %d" % progression.account_level())
			return
	if not in_run:
		return
	var around := func(n: int, kind: String) -> void:
		for i in n:
			var angle := TAU * i / n
			enemies.spawn(kind, player.global_position + Vector3(cos(angle), 0, sin(angle)) * 9.0)
	match id:
		"gold":
			progression.add_gold(100)
		"level":
			progression.add_exp(progression.exp_to_next_level() - progression.level_exp)
		"heal":
			player.hp = player.max_hp
		"clear":
			enemies.kill_all_silently()
		"spawn_wolf":
			around.call(5, "wolf")
		"spawn_spider":
			around.call(3, "spider")
		"spawn_thrower":
			around.call(3, "thrower")
		"time":
			enemies.run_time += 60.0
		"ult":
			ultimate.cooldown_left = 0.0
		"boss", "spider_boss":
			enemies.spawn_boss(id, player.global_position + Vector3(0, 0, 14))
		"weapons":
			for d: Dictionary in weapons.defs:
				if d.get("starter", false) and weapons.level(d.id) == 0:
					continue
				while weapons.level(d.id) < int(d.maxLevel):
					weapons.add(str(d.id))
			hud.set_weapons(weapon_list())


func _notify(text: String) -> void:
	if in_run:
		hud.toast(text)
	else:
		main_menu.notify(text)
		main_menu.refresh()


func _can_pause() -> bool:
	return in_run and not player.dead


func _on_popup_closed() -> void:
	# Don't treat the mouse release from the popup as a new "lost focus" pause.
	_was_captured = false


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
	if main_menu:
		main_menu.quality = quality
	if progression and progression.profile.get("quality", "") != quality:
		progression.profile.quality = quality
		store.save_to_disk()


func _on_enemy_killed(at: Vector3, exp_amount: int, gold_amount: int) -> void:
	loot_orbs.burst(at, exp_amount, gold_amount)
	var exp_gain := roundi(exp_amount * (1.0 + _extra("expGain")))
	var gold_gain := roundi(gold_amount * (1.0 + _extra("goldGain")))
	progression.add_exp(exp_gain)
	progression.add_gold(gold_gain)
	_run_gold += gold_gain
	achievements.add("goldEarned", gold_gain)
	_check_achievements()
	if in_run and _rng.randf() < float(inventory.gear.drops.enemyItemChance) * (1.0 + skill_tree.total("dropChance")):
		_drop_item(inventory.gear.roll_weighted(inventory.gear.drops.enemyOdds))


## Every boss drops a chest; later bosses drop better chests.
## The difficulty picked for runs ({hp, damage, reward, id}); locked ones fall back to normal.
func difficulty_info() -> Dictionary:
	var id := str(progression.profile.get("difficulty", "normal"))
	for d: Dictionary in difficulty_levels():
		if str(d.id) == id and progression.account_level() >= int(d.level):
			return d
	return difficulty_levels()[0]


func difficulty_levels() -> Array:
	return Config.load_json("res://data/difficulty.json").levels


func _on_boss_defeated(_boss_name: String) -> void:
	var odds: Array = inventory.gear.drops.bossChestOdds
	var extra_chests := int(Config.load_json("res://data/difficulty.json").bossChestBonus.get(str(difficulty_info().id), 0)) if not world_fight_running() else 0
	for i in extra_chests:
		_drop_chest(inventory.gear.roll_weighted(odds[mini(_bosses_killed, odds.size() - 1)]))
	_drop_chest(inventory.gear.roll_weighted(odds[mini(_bosses_killed, odds.size() - 1)]))
	_bosses_killed += 1
	var gem_id := inventory.random_gem_id()
	inventory.add_gem(gem_id)
	hud.toast("%s düştü!" % str(inventory.gear.gem(gem_id).name))
	achievements.add("bossKills")
	_check_achievements()


## A dungeon gate's guardian is beaten: gold and a chest (rarer for later gates).
func _on_dungeon_cleared(guardian: String, count: int) -> void:
	var gold_gain := 40 + 30 * count
	progression.add_gold(gold_gain)
	_run_gold += gold_gain
	_drop_chest(1 if count >= 3 or _rng.randf() < 0.3 else 0)
	achievements.add("dungeons")
	hud.toast("%s YENİLDİ! +%d ALTIN" % [UiTheme.upper(guardian), gold_gain])
	_check_achievements()


func _drop_item(rarity_index: int) -> void:
	var it := inventory.add_random_item(rarity_index)
	if it.is_empty():
		hud.toast("ÇANTA DOLU!")
		return
	var text := "%s (%s)" % [inventory.gear.item_name(it), inventory.gear.rarity(rarity_index).name]
	achievements.add("itemsFound")
	_run_loot.append(text)
	hud.toast("EŞYA: " + text.to_upper())


func _drop_chest(tier: int) -> void:
	var ch := inventory.add_chest(tier)
	var text := str(inventory.gear.chest(int(ch.tier)).name)
	_run_loot.append(text)
	hud.toast("KASA DÜŞTÜ: " + text.to_upper())


## Records the run on the account and saves (items found are already in the backpack).
func _end_run() -> void:
	food.clear_meal()
	if not _character.is_empty():
		_character.bestLevel = maxi(int(_character.get("bestLevel", 0)), progression.level)
	_record_history()
	progression.end_run(enemies.kills)
	net.report_guild_kills(enemies.kills)
	achievements.record_best("bestTime", enemies.run_time)
	achievements.live = {}
	achievements.check()
	daily.check()
	inventory.save()


## Adds the finished run to the account's log (newest first, last 50 kept).
func _record_history() -> void:
	var history: Array = progression.profile.get("history", [])
	history.push_front({
		"at": Time.get_datetime_string_from_system(false, true),
		"map": map_name(),
		"character": str(_character.get("name", "")),
		"class": class_id(),
		"level": progression.level,
		"kills": enemies.kills,
		"time": int(enemies.run_time),
		"gold": _run_gold,
		"bosses": _bosses_killed,
		"died": player.dead,
	})
	progression.profile.history = history.slice(0, 50)


## Checks achievements with the numbers of the run in progress.
func _check_achievements() -> void:
	if in_run:
		achievements.live = {"kills": enemies.kills, "level": progression.level, "time": enemies.run_time}
	achievements.check()
	daily.check()


## Gives a daily quest or login reward: {gold?, chest? (tier)}.
func grant_reward(reward: Dictionary) -> void:
	if int(reward.get("gold", 0)) > 0:
		progression.add_gold(int(reward.gold))
	if reward.has("chest") and inventory.add_chest(int(reward.chest)).is_empty():
		# A full backpack gets the chest's price instead.
		progression.add_gold(int(inventory.gear.chest(int(reward.chest)).price))
	inventory.save()


func _on_quest_done(def: Dictionary) -> void:
	if in_run and hud:
		hud.toast("GÖREV TAMAM: " + UiTheme.upper(str(def.name)))
	elif main_menu:
		main_menu.notify("Günlük görev tamamlandı: %s. Ödülünü Görevler sayfasından al." % def.name)


func _on_achievement(def: Dictionary) -> void:
	var text := "BAŞARIM: %s (+%d altın)" % [str(def.name).to_upper(), int(def.reward)]
	if in_run and hud:
		hud.toast(text)
	elif main_menu:
		main_menu.notify("Başarım kazandın: %s (+%d altın)" % [def.name, int(def.reward)])


func _on_level_up(level: int) -> void:
	_check_achievements()
	_apply_stats()
	if in_run and not player.dead:
		level_up_screen.queue_level_up(level)


func _on_player_died() -> void:
	level_up_screen.close()
	# In co-op the others play on (the host keeps running the enemies).
	enemies.active = coop.running
	bow.active = false
	weapons.active = false
	dungeon.active = false
	dungeon.reset()
	ultimate.active = false
	_end_run()
	camera_rig.capture_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var loot := _run_loot.slice(0, 6)
	if _run_loot.size() > 6:
		loot.append("+%d daha" % (_run_loot.size() - 6))
	hud.show_death(progression.level, enemies.kills, _run_gold, enemies.run_time, loot)
	if coop.pvp:
		pvp_finished(false)


func _update_menu_camera(delta: float) -> void:
	_menu_angle += delta * 0.06
	var ground := maxf(terrain.height_at(0, 0), float(maps.get(map_id, {}).get("seaLevel", -100.0)))
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
	# Its own 3D (and physics) world, so two games can share a process (co-op test).
	viewport.own_world_3d = true
	container.add_child(viewport)

	world = Node3D.new()
	world.name = "World"
	viewport.add_child(world)


func _build_environment() -> void:
	var env := Environment.new()
	_env = env
	# A soft sky gradient (colors set per map in load_map).
	var sky_mat := ProceduralSkyMaterial.new()
	_sky_mat = sky_mat
	sky_mat.sky_top_color = Color("#4f97d6")
	sky_mat.sky_horizon_color = Color("#d9ecf2")
	sky_mat.ground_horizon_color = Color("#cfe3d0")
	sky_mat.ground_bottom_color = Color("#4f7a46")
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b7d3e6")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("#a9d1e8")
	env.fog_density = 0.012
	env.fog_sun_scatter = 0.25
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
