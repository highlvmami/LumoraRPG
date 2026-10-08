## Headless smoke test: logs in, uses the main menu, drives the player with
## simulated input and checks movement, enemies, auto-attack, exp/gold/levels,
## level-up choices, weapons, the boss, the pause menu, enemy kinds, loot orbs,
## the cheat menu, saving and the death flow.
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

	_check(main.get("login_screen") != null, "login screen is shown")
	main.get("store").path = TEST_SAVE
	main.get("login_screen").login("ci_test")
	await _frames(5)

	# Main menu: sections, friends and buying from the market.
	var menu: Node = main.get("main_menu")
	_check(menu != null and bool(menu.get("visible")), "main menu opens after login")
	for section_id: String in ["friends", "backpack", "market", "profile"]:
		menu.call("open_section", section_id)
		await _frames(1)
	_check(bool(menu.call("add_friend", "arkadas1")), "a friend can be added")
	var shop: RefCounted = main.get("shop")
	var profile0: Dictionary = main.get("progression").get("profile")
	_check(not bool(menu.call("buy", "sharp_arrows")), "cannot buy without gold")
	profile0.gold = 100
	_check(bool(menu.call("buy", "sharp_arrows")), "buying an item with gold works")
	_check(int(profile0.gold) == 60 and bool(shop.call("owns", "sharp_arrows")), "gold is spent and item is in the backpack")

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
	main.call("cheat", "boss")
	await _frames(2)
	var boss := int(enemies.call("boss_index"))
	_check(boss >= 0, "boss spawns")
	_check(bool(hud.get("_boss_box").get("visible")), "boss health bar is shown")
	if boss >= 0:
		enemies.call("damage", boss, 1000000.0)
	await _frames(2)
	_check(defeated.size() == 1 and int(enemies.call("boss_index")) < 0, "boss can be defeated")

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
