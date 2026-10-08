## Game flow: login (or the account remembered on this device) → main menu →
## run on a random map (forest, beach, dungeon) → (death) → run again or back
## to the menu.
## During a run: level-ups pause for a boost choice, Esc opens the pause menu.
## The account has up to 3 characters (warrior, archer, mage) sharing one
## backpack of items and chests; the active character's class and gear decide
## its starting weapon, look and stats.
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
const ProfileStore := preload("res://scripts/progression/profile_store.gd")
const Progression := preload("res://scripts/progression/progression.gd")
const SkillTree := preload("res://scripts/progression/skill_tree.gd")
const RunBoosts := preload("res://scripts/progression/run_boosts.gd")
const Inventory := preload("res://scripts/progression/inventory.gd")
const Achievements := preload("res://scripts/progression/achievements.gd")
const ChestWheel := preload("res://scripts/ui/chest_wheel.gd")
const LoginScreen := preload("res://scripts/ui/login_screen.gd")
const MainMenu := preload("res://scripts/ui/main_menu.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const LevelUpScreen := preload("res://scripts/ui/level_up_screen.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")
const CheatMenu := preload("res://scripts/ui/cheat_menu.gd")
const UiTheme := preload("res://scripts/ui/theme.gd")

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
var progression: Progression
var skill_tree: SkillTree
var boosts := RunBoosts.new()
var inventory: Inventory
var achievements: Achievements
var chest_wheel: ChestWheel
var hud: Hud
var level_up_screen: LevelUpScreen
var pause_menu: PauseMenu
var cheat_menu: CheatMenu
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
	InputSetup.register()
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

	store.load_from_disk()
	var remembered := store.remembered()
	if remembered != "":
		# This device remembers the account: straight to the menu.
		login.call_deferred(remembered, true)
		return
	login_screen = LoginScreen.new()
	login_screen.setup(store)
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
	if player:
		player.set("_spawn_point", Vector3(0, terrain.height_at(0, 0) + 0.5, 0))


func map_name(id := "") -> String:
	return str(maps.get(id if id != "" else map_id, {}).get("name", ""))

func _process(delta: float) -> void:
	if not in_run:
		_update_menu_camera(delta)
		return
	if not player.dead and not get_tree().paused:
		var moved := Vector2(player.global_position.x - _last_step_pos.x, player.global_position.z - _last_step_pos.z).length()
		if moved < 5.0:
			achievements.add("steps", moved)
	_last_step_pos = player.global_position
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
	achievements = Achievements.new(profile, store)
	achievements.reward_gold = progression.add_gold
	achievements.unlocked.connect(_on_achievement)
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

	hud = Hud.new()
	add_child(hud)
	hud.setup(player, progression, enemies, camera_rig.camera, _world_view.stretch_shrink)
	hud.restart_requested.connect(start_run)
	hud.menu_requested.connect(show_menu)
	bow.hit_landed.connect(hud.show_hit)
	weapons.hit_landed.connect(hud.show_hit)
	bow.hit_landed.connect(_on_hit_dealt)
	weapons.hit_landed.connect(_on_hit_dealt)

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
	main_menu.play_pressed.connect(start_run)
	main_menu.chest_open_requested.connect(open_chest)
	main_menu.quality_selected.connect(set_quality)
	main_menu.settings_changed.connect(apply_settings)
	main_menu.logout_requested.connect(logout)
	main_menu.reset_requested.connect(reset_account)
	main_menu.version_text = _version_text()

	chest_wheel = ChestWheel.new()
	add_child(chest_wheel)
	chest_wheel.setup(inventory.gear)
	chest_wheel.closed.connect(main_menu.refresh)

	apply_settings()
	show_menu()


## Applies the account's settings (camera distance, mouse speed, damage numbers).
func apply_settings() -> void:
	var st: Dictionary = progression.profile.get("settings", {})
	camera_rig.zoom = clampf(float(st.get("cameraZoom", 7.0)), CameraRig.MIN_ZOOM, CameraRig.MAX_ZOOM)
	camera_rig.sensitivity_scale = float(st.get("mouseSpeed", 1.0))
	hud.show_damage_numbers = bool(st.get("damageNumbers", true))
	main_menu.quality = str(progression.profile.get("quality", DEFAULT_QUALITY))


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
	main_menu.open_section("characters")
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


func show_menu() -> void:
	in_run = false
	_was_captured = false
	pause_menu.close()
	level_up_screen.close()
	enemies.clear()
	enemies.active = false
	bow.clear()
	bow.active = false
	weapons.active = false
	weapons.reset()
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


func start_run() -> void:
	# Every run picks a random map and shows its name.
	var ids := maps.keys()
	var next := forced_map if forced_map != "" else str(ids[_rng.randi() % ids.size()])
	if next != map_id:
		load_map(next)
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
	enemies.clear()
	bow.clear()
	loot_orbs.clear()
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
	_apply_stats()
	range_ring.visible = true

	enemies.active = true
	bow.active = archer
	weapons.active = true
	hud.set_weapons(weapon_list())
	camera_rig.capture_enabled = true
	camera_rig.camera.current = true
	hud.visible = true
	hud.hide_death()
	hud.show_title(UiTheme.upper(map_name()), str(maps[map_id].get("subtitle", "")))
	_last_step_pos = player.global_position


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
	main_menu.refresh()
	return it


## Combines base stats, class, gear, character level, skill tree and boosts.
func _apply_stats() -> void:
	player.speed_multiplier = 1.0 + _extra("moveSpeed")
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
	if not weapon_cards.is_empty():
		picks.append(weapon_cards[0])
	picks.append_array(pool.slice(0, boosts.choices_per_level - picks.size()))
	picks.shuffle()
	return picks


func apply_level_up_choice(choice: Dictionary) -> void:
	if choice.type == "weapon":
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
	]


func _max_hp() -> float:
	var base := float(inventory.class_info(class_id()).maxHp) if inventory else float(player.t.maxHp)
	return base + progression.max_hp_bonus() + _extra("maxHp")


## Run boosts, skill tree, class bonus, worn gear and the developer cheat bonus for a stat.
func _extra(stat: String) -> float:
	var sum := boosts.total(stat) + (cheat_menu.total(stat) if cheat_menu else 0.0) + (skill_tree.total(stat) if skill_tree else 0.0)
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
		"boss", "spider_boss":
			enemies.spawn_boss(id, player.global_position + Vector3(0, 0, 14))
		"weapons":
			for d: Dictionary in weapons.defs:
				if d.get("starter", false) and weapons.level(d.id) == 0:
					continue
				while weapons.level(d.id) < int(d.maxLevel):
					weapons.add(str(d.id))
			hud.set_weapons(weapon_list())


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
	if in_run and _rng.randf() < float(inventory.gear.drops.enemyItemChance):
		_drop_item(inventory.gear.roll_weighted(inventory.gear.drops.enemyOdds))


## Every boss drops a chest; later bosses drop better chests.
func _on_boss_defeated(_boss_name: String) -> void:
	var odds: Array = inventory.gear.drops.bossChestOdds
	_drop_chest(inventory.gear.roll_weighted(odds[mini(_bosses_killed, odds.size() - 1)]))
	_bosses_killed += 1
	achievements.add("bossKills")
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
	if not _character.is_empty():
		_character.bestLevel = maxi(int(_character.get("bestLevel", 0)), progression.level)
	_record_history()
	progression.end_run(enemies.kills)
	achievements.record_best("bestTime", enemies.run_time)
	achievements.live = {}
	achievements.check()
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
	enemies.active = false
	bow.active = false
	weapons.active = false
	_end_run()
	camera_rig.capture_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var loot := _run_loot.slice(0, 6)
	if _run_loot.size() > 6:
		loot.append("+%d daha" % (_run_loot.size() - 6))
	hud.show_death(progression.level, enemies.kills, _run_gold, enemies.run_time, loot)


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
