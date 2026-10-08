## Headless smoke test: logs in, uses the main menu, drives the player with
## simulated input and checks movement, enemies, auto-attack, exp/gold/levels,
## level-up boost choices, the pause menu, saving and the death flow.
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
	for i in 1500:
		await physics_frame
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

	# Level-up: the game pauses and offers 3 boosts; picking one applies it.
	level_up.call("close")
	boosts.call("reset")
	main.call("_apply_stats")
	var crit_before := float(bow.get("crit_chance"))
	progression.call("add_exp", int(progression.call("exp_to_next_level")))
	await _frames(1)
	_check(bool(level_up.get("visible")) and paused, "level-up opens the boost choice and pauses")
	var choices: Array = level_up.get("_choices")
	_check(choices.size() == 3, "three boosts are offered (%d)" % choices.size())
	var crit_index := -1
	for c in choices.size():
		if choices[c].id == "crit_chance":
			crit_index = c
	level_up.call("pick", maxi(crit_index, 0))
	await _frames(1)
	_check(not bool(level_up.get("visible")) and not paused, "picking a boost resumes the game")
	_check((boosts.call("picked") as Array).size() == 1, "picked boost is recorded")
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
