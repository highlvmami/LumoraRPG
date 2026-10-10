## The tavern's parkour course on the meadow east of the tavern: platforms
## wind up in switchbacks from a green start pad past blue checkpoints to a
## golden finish. The clock starts when the player steps off the start pad;
## falling to the grass puts the player back on the last checkpoint. The
## course is made from a fixed seed so it is the same for everyone (and
## course() can be checked: every jump must be possible).
extends Node3D

signal started
signal checkpoint_reached(index: int)
signal fell(falls: int)
signal finished(ms: int, falls: int)

## The switchback the platforms follow (x, z in tavern coordinates).
const WAYPOINTS := [Vector2(26, 2), Vector2(42, -5), Vector2(27, -13), Vector2(42, -21), Vector2(27, -29), Vector2(42, -37), Vector2(30, -42)]
const CHECK_EVERY := 7
const THICK := 0.5
## Farthest edge-to-edge gap a normal jump covers, less 1.2 per metre climbed.
const MAX_GAP := 3.3
const MAX_CLIMB := 0.9

var running := false
var time := 0.0
var falls := 0
var checkpoint := 0
var on_start := false
var plates: Array = []

var _hub: Node3D
var _spots: Array = []


## The platforms in order: {pos: Vector3 (middle of the top), size: float, kind}.
static func course() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var out: Array = [{"pos": Vector3(WAYPOINTS[0].x, 0.5, WAYPOINTS[0].y), "size": 4.0, "kind": "start"}]
	var y := 0.5
	var at: Vector2 = WAYPOINTS[0]
	var total := 0.0
	for i in range(1, WAYPOINTS.size()):
		total += (WAYPOINTS[i] - WAYPOINTS[i - 1]).length()
	var walked := 0.0
	for seg in range(1, WAYPOINTS.size()):
		var goal: Vector2 = WAYPOINTS[seg]
		var last_seg := seg == WAYPOINTS.size() - 1
		while true:
			var to := goal - at
			var progress := (walked + (WAYPOINTS[seg - 1] as Vector2).distance_to(at)) / total
			var size := lerpf(2.7, 1.8, progress)
			var prev: Dictionary = out[-1]
			var climb: float = [0.0, 0.4, 0.7, MAX_CLIMB][rng.randi() % 4]
			var gap := rng.randf_range(0.9, (MAX_GAP - 1.2 * climb) * 0.88)
			var step := (float(prev.size) + size) * 0.5 + gap
			var next_at := at
			var is_vertex := to.length() <= step + 0.5
			if is_vertex:
				next_at = goal
			else:
				var side := Vector2(-to.y, to.x).normalized() * rng.randf_range(-0.5, 0.5)
				next_at = at + to.normalized() * step + side
			y += climb
			var index := out.size()
			var kind := "plat"
			if index % CHECK_EVERY == 0:
				kind = "check"
				size = 3.4
			out.append({"pos": Vector3(next_at.x, y, next_at.y), "size": size, "kind": kind})
			at = next_at
			if is_vertex:
				break
		walked += (WAYPOINTS[seg - 1] as Vector2).distance_to(WAYPOINTS[seg])
		if last_seg:
			(out[-1] as Dictionary).kind = "finish"
			(out[-1] as Dictionary).size = 4.6
	return out


## The widest edge-to-edge gap between two platforms and how high the next is.
static func jump_between(a: Dictionary, b: Dictionary) -> Vector2:
	var half := (float(a.size) + float(b.size)) * 0.5
	var dx := maxf(0.0, absf(a.pos.x - b.pos.x) - half)
	var dz := maxf(0.0, absf(a.pos.z - b.pos.z) - half)
	return Vector2(Vector2(dx, dz).length(), b.pos.y - a.pos.y)


## True when every jump along the course is one the player can make.
static func possible(path: Array) -> bool:
	for i in range(1, path.size()):
		var j := jump_between(path[i - 1], path[i])
		if j.x > MAX_GAP - 1.2 * maxf(0.0, j.y) + 0.05 or j.y > MAX_CLIMB + 0.01:
			return false
	return true


## Number of checkpoints (the finish counts as the last).
func checkpoints() -> int:
	var n := 0
	for d: Dictionary in _spots:
		if str(d.kind) == "check" or str(d.kind) == "finish":
			n += 1
	return n


func build(hub: Node3D) -> void:
	_hub = hub
	_spots = course()
	var top := float((_spots.back() as Dictionary).pos.y)
	for i in _spots.size():
		var d: Dictionary = _spots[i]
		var size := float(d.size)
		var color := Color("#8a6a45").lerp(Color("#c9a56a"), float(i) / _spots.size())
		var glow := Color.BLACK
		match str(d.kind):
			"start":
				color = Color("#3fae5a")
				glow = Color(0.1, 0.5, 0.2)
			"check":
				color = Color("#4a8fe0")
				glow = Color(0.15, 0.35, 0.8)
			"finish":
				color = Color("#e8c13a")
				glow = Color(0.8, 0.6, 0.1)
		var pos: Vector3 = d.pos
		var body := Vector3(size, THICK, size)
		var middle := pos - Vector3(0, THICK * 0.5, 0)
		_hub._box(body, middle, color, glow, self)
		_hub._collider(body, middle)
		# A pillar to the grass for the platforms high above it.
		if pos.y > 1.6:
			_hub._box(Vector3(0.5, pos.y - THICK, 0.5), Vector3(pos.x, (pos.y - THICK) * 0.5, pos.z), Color("#5b4630"), Color.BLACK, self)
		if str(d.kind) != "plat":
			_flag(pos + Vector3(size * 0.5 - 0.3, 0, size * 0.5 - 0.3), color.lightened(0.2), str(d.kind))
	var start: Dictionary = _spots[0]
	var sign_text := Label3D.new()
	sign_text.text = "PARKUR"
	sign_text.font_size = 96
	sign_text.pixel_size = 0.012
	sign_text.outline_size = 16
	sign_text.modulate = Color("#ffe27a")
	sign_text.position = (start.pos as Vector3) + Vector3(0, 3.2, 0)
	sign_text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sign_text)
	# The notice post with the rankings.
	var post_at := Vector3(22.8, 0, 3.4)
	_hub._box(Vector3(0.3, 2.0, 0.3), post_at + Vector3(0, 1.0, 0), Color("#5b4630"), Color.BLACK, self)
	_hub._box(Vector3(1.6, 1.0, 0.15), post_at + Vector3(0, 2.1, 0), Color("#a07a48"), Color(0.25, 0.18, 0.05), self)
	_hub._collider(Vector3(0.5, 2.0, 0.5), post_at + Vector3(0, 1.0, 0))
	var board := Label3D.new()
	board.text = "SIRALAMA"
	board.font_size = 64
	board.pixel_size = 0.01
	board.outline_size = 12
	board.position = post_at + Vector3(0, 2.1, 0.12)
	add_child(board)
	_hub.interactables.append({"kind": "pk_board", "label": "Parkur sıralamasına bak", "pos": _hub.to_global(post_at + Vector3(0.8, 0, 1.0)), "yaw": 0.0, "radius": 1.0})
	if top > 0.0:
		var beacon := OmniLight3D.new()
		beacon.position = (_spots.back() as Dictionary).pos + Vector3(0, 3.0, 0)
		beacon.light_color = Color("#ffd86a")
		beacon.light_energy = 1.6
		beacon.omni_range = 9.0
		add_child(beacon)


func _flag(at: Vector3, color: Color, kind: String) -> void:
	_hub._box(Vector3(0.12, 2.2, 0.12), at + Vector3(0, 1.1, 0), Color("#d8d0c0"), Color.BLACK, self)
	_hub._box(Vector3(0.9, 0.55, 0.06), at + Vector3(-0.45, 1.95, 0), color, color.darkened(0.3), self)
	if kind == "finish":
		_hub._box(Vector3(1.2, 0.8, 1.2), at + Vector3(-1.6, 0.4, -1.6), Color("#e8c13a"), Color(0.8, 0.6, 0.1), self)


## Where the course puts the player after a fall (the last checkpoint).
func respawn_point() -> Vector3:
	var d: Dictionary = _spots[checkpoint]
	return _hub.to_global((d.pos as Vector3) + Vector3(0, 0.3, 0))


func cancel() -> void:
	running = false
	on_start = false
	time = 0.0
	falls = 0
	checkpoint = 0


## Runs the clock and watches for steps on checkpoints, falls and the finish.
func update(delta: float, player: CharacterBody3D) -> void:
	if _spots.is_empty():
		return
	var local := _hub.to_local(player.global_position)
	var on_index := _platform_under(local)
	if on_index == 0:
		# Back on the start pad: ready for a new run.
		if running:
			cancel()
		on_start = true
		return
	if not running:
		if on_start and on_index != 0:
			if local.y >= 0.45:
				running = true
				time = 0.0
				falls = 0
				checkpoint = 0
				started.emit()
			else:
				# Walked off the pad onto the grass.
				on_start = false
		if not running:
			return
	time += delta
	if on_index > 0:
		var d: Dictionary = _spots[on_index]
		var kind := str(d.kind)
		if kind == "finish":
			var ms := roundi(time * 1000.0)
			var f := falls
			cancel()
			finished.emit(ms, f)
			return
		if kind == "check" and on_index > checkpoint:
			checkpoint = on_index
			checkpoint_reached.emit(on_index)
	# On the grass (or lower): back to the checkpoint.
	if local.y < 0.2 and player.is_on_floor() or local.y < -2.0:
		falls += 1
		player.velocity = Vector3.ZERO
		player.global_position = respawn_point()
		fell.emit(falls)


## Index of the platform the player stands over, or -1.
func _platform_under(local: Vector3) -> int:
	for k in _spots.size():
		var i := _spots.size() - 1 - k
		var d: Dictionary = _spots[i]
		var half := float(d.size) * 0.5 + 0.15
		if absf(local.x - d.pos.x) <= half and absf(local.z - d.pos.z) <= half and local.y >= float(d.pos.y) - 0.45 and local.y <= float(d.pos.y) + 1.4:
			return i
	return -1


func status_text() -> String:
	if not running:
		return ""
	var t := time
	return "PARKUR  %d:%04.1f   ·   Kontrol %d/%d   ·   Düşme %d" % [int(t) / 60, fmod(t, 60.0), _checks_done(), checkpoints(), falls]


func _checks_done() -> int:
	var n := 0
	for i in range(1, checkpoint + 1):
		if str((_spots[i] as Dictionary).kind) == "check":
			n += 1
	return n
