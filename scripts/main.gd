## Game flow: login → main menu → run → (death) → run again or back to the menu.
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
const Shop := preload("res://scripts/progression/shop.gd")
const RunBoosts := preload("res://scripts/progression/run_boosts.gd")
const Inventory := preload("res://scripts/progression/inventory.gd")
const ChestWheel := preload("res://scripts/ui/chest_wheel.gd")
const LoginScreen := preload("res://scripts/ui/login_screen.gd")
const MainMenu := preload("res://scripts/ui/main_menu.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const LevelUpScreen := preload("res://scripts/ui/level_up_screen.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")
const CheatMenu := preload("res://scripts/ui/cheat_menu.gd")

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
var shop: Shop
var boosts := RunBoosts.new()
var inventory: Inventory
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
	if _was_captured and not captured and not cheat_menu.is_open():
		pause_menu.open()
	_was_captured = captured


## Logs in (creating the account if new) and opens the main menu.
func login(username: String) -> void:
	var profile := store.login(username)
	progression = Progression.new(store, profile)
	shop = Shop.new(profile, store)
	inventory = Inventory.new(profile, store)
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
	main_menu.setup(progression, shop, inventory)
	main_menu.play_pressed.connect(start_run)
	main_menu.chest_open_requested.connect(open_chest)

	chest_wheel = ChestWheel.new()
	add_child(chest_wheel)
	chest_wheel.setup(inventory.gear)
	chest_wheel.closed.connect(main_menu.refresh)

	show_menu()


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
	if it.is_empty():
		main_menu.notify("Çanta dolu! Önce eşya sat.")
		return {}
	chest_wheel.spin(int(ch.tier), it)
	main_menu.refresh()
	return it


## Combines base stats, class, gear, character level, market items and boosts.
func _apply_stats() -> void:
	player.speed_multiplier = 1.0 + _extra("moveSpeed")
	player.regen = _extra("regen")
	player.set_max_hp(_max_hp())
	weapons.uses_bow = class_id() == "archer"
	bow.damage_multiplier = progression.damage_multiplier() + _extra("damage")
	bow.attack_speed_multiplier = 1.0 + _extra("attackSpeed")
	bow.range_bonus = _extra("range")
	bow.crit_chance = minf(1.0, bow.base_crit_chance + _extra("critChance"))
	bow.crit_multiplier = bow.base_crit_multiplier + _extra("critDamage")
	range_ring.radius = _attack_range()
	hud.set_stats(stat_list())


## Level-up cards: random boosts and weapons (new or upgrades). When any
## weapon can be offered, at least one card is a weapon.
func roll_level_up_choices() -> Array:
	var boost_cards: Array = []
	for d: Dictionary in boosts.defs:
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


## Run boosts, market upgrades, class bonus, worn gear and the developer cheat bonus for a stat.
func _extra(stat: String) -> float:
	var sum := boosts.total(stat) + (cheat_menu.total(stat) if cheat_menu else 0.0) + (shop.total(stat) if shop else 0.0)
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
		"boss":
			enemies.spawn("boss", player.global_position + Vector3(0, 0, 14), true)
			enemies.boss_spawned.emit(enemies.kind_name(enemies.boss_index()))
		"weapons":
			for d: Dictionary in weapons.defs:
				if d.get("starter", false) and weapons.level(d.id) == 0:
					continue
				while weapons.level(d.id) < int(d.maxLevel):
					weapons.add(str(d.id))
			hud.set_weapons(weapon_list())


func _can_pause() -> bool:
	return in_run and not player.dead and not level_up_screen.visible


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
	if in_run and _rng.randf() < float(inventory.gear.drops.enemyItemChance):
		_drop_item(inventory.gear.roll_weighted(inventory.gear.drops.enemyOdds))


## Every boss drops a chest; later bosses drop better chests.
func _on_boss_defeated(_boss_name: String) -> void:
	var odds: Array = inventory.gear.drops.bossChestOdds
	_drop_chest(inventory.gear.roll_weighted(odds[mini(_bosses_killed, odds.size() - 1)]))
	_bosses_killed += 1


func _drop_item(rarity_index: int) -> void:
	var it := inventory.add_random_item(rarity_index)
	if it.is_empty():
		hud.toast("ÇANTA DOLU!")
		return
	var text := "%s (%s)" % [inventory.gear.item_name(it), inventory.gear.rarity(rarity_index).name]
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
	progression.end_run(enemies.kills)
	inventory.save()


func _on_level_up(level: int) -> void:
	_apply_stats()
	if in_run and not player.dead:
		level_up_screen.queue_level_up(level)


func _on_player_died() -> void:
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
