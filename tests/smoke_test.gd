## Headless smoke test: logs in, uses the main menu, drives the player with
## simulated input and checks movement, enemies, auto-attack, exp/gold/levels,
## level-up choices, weapons, the boss, the pause menu, enemy kinds, loot orbs,
## the cheat menu, saving and the death flow, characters and classes, items,
## equipment, chests and the chest wheel.
## Run: godot --headless --path . -s res://tests/smoke_test.gd
extends SceneTree

const TEST_SAVE := "user://smoke_test_profiles.json"

var _failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))

	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(10)

	var boot: GDScript = load("res://scripts/boot.gd")
	_check(boot != null and boot.can_instantiate(), "the self-updating start-up script loads")
	_check(str(ProjectSettings.get_setting("application/run/main_scene")) == "res://scenes/boot.tscn", "the game starts through the updater")
	_check(main.get("login_screen") != null, "login screen is shown")
	main.get("store").path = TEST_SAVE
	main.get("login_screen").login("ci_test")
	await _frames(5)

	# Main menu: sections, friends and buying from the market.
	var menu: Node = main.get("main_menu")
	_check(menu != null and bool(menu.get("visible")), "main menu opens after login")
	for section_id: String in ["characters", "create", "equipment", "friends", "backpack", "market", "profile"]:
		menu.call("open_section", section_id)
		await _frames(1)
	_check(bool(menu.call("add_friend", "arkadas1")), "a friend can be added")
	var shop: RefCounted = main.get("shop")
	var profile0: Dictionary = main.get("progression").get("profile")
	_check(not bool(menu.call("buy", "sharp_arrows")), "cannot buy without gold")
	profile0.gold = 100
	_check(bool(menu.call("buy", "sharp_arrows")), "buying an item with gold works")
	_check(int(profile0.gold) == 60 and bool(shop.call("owns", "sharp_arrows")), "gold is spent and item is in the backpack")

	# Characters: play asks for one first; up to 3, each with a class.
	var inv: RefCounted = main.get("inventory")
	menu.call("play")
	_check(str(menu.get("section")) == "create" and not bool(main.get("in_run")), "play without a character opens character creation")
	_check(not bool(menu.call("create_character", "x", "warrior")), "a too short name is refused")
	_check(bool(menu.call("create_character", "Kilicci", "warrior")), "a warrior can be created")
	_check(bool(menu.call("create_character", "Buyucu", "mage")), "a mage can be created")
	_check(bool(menu.call("create_character", "Okcu", "archer")), "an archer can be created")
	_check(not bool(menu.call("create_character", "Fazla", "archer")), "at most 3 characters")
	var archer: Dictionary = inv.call("active_character")
	_check(str(archer["class"]) == "archer", "the new character becomes active")
	var warrior: Dictionary = (inv.call("characters") as Array)[0]

	# Items: rarities, stats, equipping (class rules), selling.
	var divine: Dictionary = inv.call("add_random_item", 5)
	_check(int(divine.rarity) == 5 and (divine.stats as Dictionary).size() >= 6, "a divine item has many stats (%d)" % (divine.stats as Dictionary).size())
	var wearable: Dictionary = {}
	var bow_item: Dictionary = {}
	for i in 50:
		if not wearable.is_empty() and not bow_item.is_empty():
			break
		var it: Dictionary = inv.call("add_random_item", i % 6)
		var cls := str(inv.get("gear").call("item_class", it))
		if wearable.is_empty() and cls == "":
			wearable = it
		if bow_item.is_empty() and cls == "archer":
			bow_item = it
	_check(not wearable.is_empty() and not bow_item.is_empty(), "random items of every kind drop")
	_check(not bool(inv.call("can_wear", warrior, bow_item)), "a warrior cannot wear a bow")
	_check(bool(menu.call("equip", int(bow_item.uid))), "the archer can equip a bow")
	_check(int((inv.call("equipped", archer, "weapon") as Dictionary).get("uid", -1)) == int(bow_item.uid), "the bow is in the weapon slot")
	for section_id: String in ["characters", "equipment", "backpack"]:
		menu.call("select_item", int(bow_item.uid))
		menu.call("open_section", section_id)
		await _frames(1)
	menu.call("open_section", "equipment")
	await _frames(2)
	_check(menu.find_children("*", "SubViewportContainer", true, false).size() >= 1, "equipment shows the character in 3D")
	var slots := menu.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return b.get("tooltip_builder") is Callable and (b.get("tooltip_builder") as Callable).is_valid())
	_check(not slots.is_empty(), "equipped items sit in slots")
	if not slots.is_empty():
		var tip: Object = slots[0].call("_make_custom_tooltip", "")
		_check(tip is Control, "hovering a slot shows the item's stats")
		if tip:
			tip.free()
	var look: Dictionary = main.call("character_look", archer)
	_check(int(look.weapon_tier) >= 0, "the equipped weapon changes the character look")
	inv.call("unequip", int(archer.id), "weapon")
	var stash_before := (inv.call("items") as Array).size()
	var gold_before_sell := int(profile0.gold)
	_check(int(menu.call("sell", int(wearable.uid))) > 0 and (inv.call("items") as Array).size() == stash_before - 1, "selling an item removes it")
	_check(int(profile0.gold) > gold_before_sell, "selling gives gold")

	# Chests: buying and opening with the wheel.
	profile0.gold = int(profile0.gold) + 120
	_check(bool(menu.call("buy_chest", 0)), "a chest can be bought")
	var chest: Dictionary = (inv.call("chests") as Array)[0]
	stash_before = (inv.call("items") as Array).size()
	var prize: Dictionary = main.call("open_chest", int(chest.uid))
	var wheel: Node = main.get("chest_wheel")
	_check(not prize.is_empty() and bool(wheel.get("visible")) and bool(wheel.get("spinning")), "opening a chest spins the wheel")
	await _frames(20)
	wheel.call("finish")
	_check(not bool(wheel.get("spinning")) and (wheel.get("result") as Dictionary) == prize, "the wheel stops on the prize")
	wheel.call("close")
	_check((inv.call("chests") as Array).is_empty() and (inv.call("items") as Array).size() == stash_before + 1, "the prize is in the backpack")
	_check(not bool(wheel.get("visible")), "the wheel closes")

	menu.call("emit_signal", "play_pressed")
	await _frames(60)
	_check(not bool(menu.get("visible")), "play hides the main menu")
	var bow: Node = main.get("bow")
	_check(absf(float(bow.get("damage_multiplier")) - 1.15) < 0.001, "owned item boosts damage (x%.2f)" % float(bow.get("damage_multiplier")))
	_check(absf(float(main.get("range_ring").get("radius")) - 10.0) < 0.001, "range ring matches the attack range")

	var player: CharacterBody3D = main.get("player")
	_check(player != null, "player is spawned")
	if player == null:
		_finish()
		return
	_check(player.is_on_floor(), "player lands on the terrain")
	_check(not InputMap.has_action("slide"), "slide action is removed")

	# Movement (rocks can be ~8 units from spawn, so phases stay near the origin).
	var start := player.global_position
	Input.action_press("move_forward")
	await _frames(35)
	Input.action_release("move_forward")
	var moved := Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
	_check(moved > 3.0, "running moves the player (moved %.2f)" % moved)
	await _frames(30)

	var ground_y := player.global_position.y
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	await _frames(10)
	_check(player.global_position.y > ground_y + 0.8, "jump lifts the player")
	await _frames(90)
	_check(player.is_on_floor(), "player lands after the jump")

	# Enemies spawn, walk in and get shot by the automatic bow.
	var enemies: Node = main.get("enemies")
	var progression: RefCounted = main.get("progression")
	var level_up: Node = main.get("level_up_screen")
	var boosts: RefCounted = main.get("boosts")
	var loot: Node = main.get("loot_orbs")
	var orbs_seen := 0
	for i in 1500:
		await physics_frame
		orbs_seen = maxi(orbs_seen, int(loot.call("count")))
		# Level-ups pause the game until a boost is picked.
		if bool(level_up.get("visible")):
			level_up.call("pick", 0)
		if int(enemies.get("kills")) >= 3:
			break
	_check(int(enemies.call("count")) + int(enemies.get("kills")) > 0, "enemies spawn")
	var kills := int(enemies.get("kills"))
	_check(kills >= 3, "auto bow kills enemies (%d kills)" % kills)
	var level := int(progression.get("level"))
	var level_exp := int(progression.get("level_exp"))
	_check(level > 1 or level_exp > 0, "kills give character exp (level %d, exp %d)" % [level, level_exp])
	var profile: Dictionary = progression.get("profile")
	_check(int(profile.accountExp) > 0 or int(profile.accountLevel) > 1, "kills give account exp")
	_check(int(profile.gold) > 60, "kills give gold (%d)" % int(profile.gold))
	_check(orbs_seen > 0, "killed enemies drop exp/gold orbs (%d seen)" % orbs_seen)

	# Level-up: the game pauses and offers 3 cards; picking one applies it.
	var weapons: Node = main.get("weapons")
	level_up.call("close")
	boosts.call("reset")
	weapons.call("reset")
	main.call("_apply_stats")
	var crit_before := float(bow.get("crit_chance"))
	progression.call("add_exp", int(progression.call("exp_to_next_level")))
	await _frames(1)
	_check(bool(level_up.get("visible")) and paused, "level-up opens the choice and pauses")
	var choices: Array = level_up.get("_choices")
	_check(choices.size() == 3, "three cards are offered (%d)" % choices.size())
	_check(choices.any(func(c: Dictionary) -> bool: return c.type == "weapon"), "a weapon card is offered")
	var crit_index := -1
	for c in choices.size():
		if choices[c].id == "crit_chance":
			crit_index = c
	level_up.call("pick", maxi(crit_index, 0))
	await _frames(1)
	_check(not bool(level_up.get("visible")) and not paused, "picking a card resumes the game")
	var picked_count := (boosts.call("picked") as Array).size() + (weapons.call("owned") as Array).size()
	_check(picked_count == 1, "picked card is recorded")
	if crit_index >= 0:
		_check(float(bow.get("crit_chance")) > crit_before, "crit boost raises crit chance")
	var hud: Node = main.get("hud")
	_check((hud.get("_stat_values") as Array).size() == 8, "character panel shows 8 stats")

	# Pause menu: pauses, changes quality, resumes.
	var pause: Node = main.get("pause_menu")
	pause.call("open")
	await _frames(1)
	_check(bool(pause.get("visible")) and paused, "pause menu opens and pauses the game")
	pause.emit_signal("quality_selected", "low")
	_check(int(main.get("_world_view").get("stretch_shrink")) == 3 and str(profile.get("quality")) == "low", "low quality renders fewer pixels and is saved")
	pause.emit_signal("quality_selected", "medium")
	pause.call("resume")
	await _frames(1)
	_check(not bool(pause.get("visible")) and not paused, "resume closes the pause menu")

	# Every enemy kind can spawn; ranged goblins throw at the player.
	var cheats: Node = main.get("cheat_menu")
	cheats.call("_on_god_toggled", true)  # keep the player alive meanwhile
	var near := player.global_position
	for kind: String in ["wolf", "spider", "thrower"]:
		_check(bool(enemies.call("spawn", kind, near + Vector3(10, 0, 0))), "%s can spawn" % kind)
		_check(int(enemies.call("count_kind", kind)) >= 1, "%s is alive" % kind)
	for i in 300:
		await physics_frame
		if bool(level_up.get("visible")):
			level_up.call("pick", 0)
		if int(enemies.get("shots_fired")) > 0:
			break
	_check(int(enemies.get("shots_fired")) > 0, "goblin throws at the player")
	enemies.set("run_time", 95.0)
	await _frames(2)
	_check((enemies.get("_announced") as Dictionary).size() == 5, "all enemy kinds unlock as time goes on")
	_check(float(enemies.call("growth", "hpGrowthPerMinute")) > 1.4, "enemies get tougher over time")

	# Every extra weapon damages enemies around the player.
	main.call("cheat", "clear")
	for id: String in ["orbit", "fireball", "lightning", "aura"]:
		weapons.call("add", id)
	_check((weapons.call("owned") as Array).size() == 4, "all four weapons can be carried")
	var dealt: Dictionary = weapons.get("damage_dealt")
	for i in 400:
		if i % 40 == 0:
			for n in 6:
				var a := TAU * n / 6.0
				enemies.call("spawn", "slime", player.global_position + Vector3(cos(a), 0, sin(a)) * 4.0)
		await physics_frame
		if bool(level_up.get("visible")):
			level_up.call("pick", 0)
		if dealt.size() == 4:
			break
	for id: String in ["orbit", "fireball", "lightning", "aura"]:
		_check(float(dealt.get(id, 0.0)) > 0.0, "%s deals damage (%.0f)" % [id, float(dealt.get(id, 0.0))])

	# Boss: spawns with a health bar and announces its defeat.
	var defeated: Array = []
	enemies.connect("boss_defeated", func(boss_name: String) -> void: defeated.append(boss_name))
	if bool(level_up.get("visible")):
		level_up.call("pick", 0)
	main.call("cheat", "boss")
	await _frames(2)
	await process_frame
	await process_frame
	var boss := int(enemies.call("boss_index"))
	_check(boss >= 0, "boss spawns")
	_check(bool(hud.get("_boss_box").get("visible")), "boss health bar is shown")
	if boss >= 0:
		enemies.call("damage", boss, 1000000.0)
	await _frames(2)
	_check(defeated.size() == 1 and int(enemies.call("boss_index")) < 0, "boss can be defeated")
	_check((inv.call("chests") as Array).size() == 1, "the boss drops a chest")
	var stash_now := (inv.call("items") as Array).size()
	main.call("_drop_item", 3)
	_check((inv.call("items") as Array).size() == stash_now + 1, "enemy item drops go to the backpack")

	# Developer cheat menu: stat bonuses, god mode, actions.
	var dmg_before := float(bow.get("damage_multiplier"))
	cheats.call("_step", "damage", 1)
	_check(absf(float(bow.get("damage_multiplier")) - dmg_before - 0.25) < 0.001, "cheat raises damage")
	cheats.call("_on_god_toggled", true)
	var hp_before := float(player.get("hp"))
	player.call("take_damage", 50.0)
	_check(float(player.get("hp")) == hp_before, "god mode ignores damage")
	var gold_before := int(profile.gold)
	main.call("cheat", "gold")
	_check(int(profile.gold) == gold_before + 100, "cheat gives gold")
	main.call("cheat", "clear")
	_check(int(enemies.call("count")) == 0, "cheat clears enemies")
	cheats.call("_step", "expGain", 1)
	cheats.call("_step", "goldGain", 1)
	var gold_mid := int(profile.gold)
	main.call("_on_enemy_killed", player.global_position, 0, 5)
	_check(int(profile.gold) == gold_mid + 10, "cheat gold multiplier doubles gold")
	_check(float(main.call("_extra", "expGain")) >= 1.0, "cheat exp multiplier is applied")
	cheats.call("reset_all")
	_check(not bool(player.get("god_mode")) and absf(float(bow.get("damage_multiplier")) - dmg_before) < 0.001, "cheat reset restores stats")

	# Death ends the run and saves the account; restarting resets the character.
	player.call("take_damage", 100000.0)
	await _frames(2)
	_check(bool(player.get("dead")), "player dies at 0 hp")
	_check(not bool(enemies.get("active")), "enemies stop after death")
	_check(FileAccess.file_exists(TEST_SAVE), "profile is saved")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE))
	var saved_runs := 0
	if typeof(saved) == TYPE_DICTIONARY and (saved as Dictionary).profiles.has("ci_test"):
		saved_runs = int(saved.profiles.ci_test.runs)
	_check(saved_runs == 1, "saved profile records the run (runs=%d)" % saved_runs)

	main.call("start_run")
	await _frames(2)
	_check(not bool(player.get("dead")), "restart revives the player")
	_check(int(progression.get("level")) == 1, "restart resets character level")
	_check(int(enemies.get("kills")) == 0, "restart clears enemies")

	_check((boosts.call("picked") as Array).is_empty(), "restart clears boosts")

	# Leaving a run from the pause menu counts the run and opens the main menu.
	pause.call("open")
	await _frames(1)
	pause.emit_signal("menu_requested")
	await _frames(2)
	_check(bool(menu.get("visible")) and not bool(main.get("in_run")) and not paused, "pause menu can go back to the main menu")
	_check(int(profile.runs) == 2, "leaving the run records it (runs=%d)" % int(profile.runs))

	# Warrior and mage start with their own weapon instead of the bow.
	for pair: Array in [[warrior, "slash"], [(inv.call("characters") as Array)[1], "magic"]]:
		menu.call("select_character", int(pair[0].id))
		main.call("start_run")
		await _frames(2)
		cheats.call("_on_god_toggled", true)
		var id: String = pair[1]
		_check(int(weapons.call("level", id)) == 1 and not bool(bow.get("active")), "%s starts with %s" % [str(pair[0]["class"]), id])
		var dealt_by: Dictionary = weapons.get("damage_dealt")
		for i in 300:
			if i % 40 == 0:
				for n in 4:
					var a := TAU * n / 4.0
					enemies.call("spawn", "slime", player.global_position + Vector3(cos(a), 0, sin(a)) * 2.5)
			await physics_frame
			if bool(level_up.get("visible")):
				level_up.call("pick", 0)
			if float(dealt_by.get(id, 0.0)) > 0.0:
				break
		_check(float(dealt_by.get(id, 0.0)) > 0.0, "%s deals damage" % id)
		# Worn gear adds its stats.
		var gear_item: Dictionary = inv.call("add_random_item", 4)
		var c: Dictionary = inv.call("active_character")
		if bool(inv.call("equip", int(c.id), int(gear_item.uid))):
			var stat: String = (gear_item.stats as Dictionary).keys()[0]
			_check(float(main.call("_extra", stat)) >= float(gear_item.stats[stat]) - 0.0001, "worn gear adds %s" % stat)
		cheats.call("reset_all")
		main.call("leave_run")
		await _frames(2)

	_finish()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(ok: bool, what: String) -> void:
	if ok:
		print("PASS ", what)
	else:
		_failures += 1
		printerr("FAIL ", what)


func _finish() -> void:
	print("%d check(s) failed" % _failures if _failures else "all checks passed")
	quit(1 if _failures else 0)
