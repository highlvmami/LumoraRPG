## Headless smoke test: loads the main scene, drives the player with simulated
## input and checks that running, jumping and sliding work.
## Run: godot --headless --path . -s res://tests/smoke_test.gd
extends SceneTree

var _failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(60)

	var player: CharacterBody3D = main.get("player")
	_check(player != null, "player is spawned")
	if player == null:
		_finish()
		return
	_check(player.is_on_floor(), "player lands on the terrain")

	var start := player.global_position
	# Rocks can be as close as ~8 units to spawn, so each phase stays near the origin.
	Input.action_press("move_forward")
	await _frames(35)
	Input.action_release("move_forward")
	var moved := Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
	_check(moved > 3.0, "running moves the player (moved %.2f)" % moved)
	_check(player.global_position.z < start.z, "forward is -Z with the default camera")
	await _frames(30)

	var ground_y := player.global_position.y
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	await _frames(10)
	_check(player.global_position.y > ground_y + 0.8, "jump lifts the player")
	await _frames(90)
	_check(player.is_on_floor(), "player lands after the jump")

	player.global_position = start + Vector3.UP * 0.2
	await _frames(20)
	Input.action_press("move_forward")
	await _frames(4)
	Input.action_press("slide")
	await _frames(6)
	_check(bool(player.get("sliding")), "holding slide starts a slide")
	var slide_speed: float = player.call("horizontal_speed")
	_check(slide_speed > 12.0, "slide boosts speed (%.2f)" % slide_speed)
	Input.action_release("slide")
	Input.action_release("move_forward")
	await _frames(4)
	_check(not bool(player.get("sliding")), "releasing slide ends it")

	await _frames(60)
	var rest_speed: float = player.call("horizontal_speed")
	_check(rest_speed < 0.5, "player stops without input (%.2f)" % rest_speed)

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
