## The dice or cards of a tavern game flying from both players, landing side
## by side and showing who won. Put it at the middle between the players.
extends Node3D

const FLY := 1.3
const LAND := 1.9
const SHOW := 2.3
const TOTAL := 5.4
const HEIGHT := 1.5
const SUITS := ["♠", "♥", "♦", "♣"]

var _t := 0.0
var _kind := "dice"
var _winner := 0
## Per side: {items: [{node, start, target, spin}], center, label}
var _sides: Array = []
var _banner: Label3D


## `result` is the server's game_result ({kind, bet, a, b, winner}); `from_a` and
## `from_b` are where the players stand (world positions).
func setup(result: Dictionary, me_name: String, from_a: Vector3, from_b: Vector3) -> void:
	_kind = str(result.kind)
	_winner = int(result.winner)
	var seed_rng := RandomNumberGenerator.new()
	seed_rng.randomize()
	var data: Array = [result.a, result.b]
	var starts: Array = [to_local(from_a) + Vector3(0, 1.4, 0), to_local(from_b) + Vector3(0, 1.4, 0)]
	for i in 2:
		var side: Dictionary = data[i]
		var cx := -1.0 if i == 0 else 1.0
		var items: Array = []
		var values: Array = side.v
		var count := 2 if _kind == "dice" else 1
		for k in count:
			var node: Node3D = _make_die(int(values[k])) if _kind == "dice" else _make_card(int(values[0]), int(values[1]))
			add_child(node)
			var offset := Vector3(0, 0, (k - 0.5) * 0.7) if _kind == "dice" else Vector3.ZERO
			items.append({
				"node": node,
				"start": starts[i] + Vector3(0, 0, k * 0.3),
				"target": Vector3(cx, HEIGHT, 0) + offset,
				"spin": Vector3(seed_rng.randf_range(6, 13), seed_rng.randf_range(4, 9), seed_rng.randf_range(5, 11)),
				"yaw": seed_rng.randf_range(-0.4, 0.4),
			})
		var mine := str(side.name).to_lower() == me_name.to_lower()
		var label := _label("%s\n%s" % [str(side.name), _total_text(side)], 64, Color("#ffe27a") if mine else Color("#e8f2ff"))
		label.position = Vector3(cx, HEIGHT + 0.85, 0)
		label.visible = false
		add_child(label)
		_sides.append({"items": items, "label": label})
	_banner = _label("", 90, Color("#ffd23f"))
	_banner.position = Vector3(0, HEIGHT + 1.7, 0)
	_banner.visible = false
	add_child(_banner)
	_apply(0.0)


func _total_text(side: Dictionary) -> String:
	if _kind == "dice":
		return "%d + %d = %d" % [int(side.v[0]), int(side.v[1]), int(side.total)]
	return _card_name(int(side.v[0]), int(side.v[1]))


static func _card_name(rank: int, suit: int) -> String:
	var names := {11: "J", 12: "Q", 13: "K", 14: "A"}
	return "%s%s" % [str(names.get(rank, rank)), SUITS[clampi(suit, 0, 3)]]


func _process(delta: float) -> void:
	_t += delta
	_apply(_t)
	if _t >= TOTAL:
		queue_free()


func _apply(t: float) -> void:
	for i in _sides.size():
		var won: bool = i == _winner
		for item: Dictionary in _sides[i].items:
			var node: Node3D = item.node
			var start: Vector3 = item.start
			var target: Vector3 = item.target
			if t < FLY:
				var p := t / FLY
				var eased := p * p * (3.0 - 2.0 * p)
				node.position = start.lerp(target, eased) + Vector3(0, sin(p * PI) * 1.4, 0)
				var spin: Vector3 = item.spin
				node.rotation = spin * t * (1.0 - p * 0.3)
			elif t < LAND:
				var q := (t - FLY) / (LAND - FLY)
				node.position = target + Vector3(0, absf(sin(q * PI * 2.0)) * 0.25 * (1.0 - q), 0)
				var from_rot: Vector3 = (item.spin as Vector3) * FLY * 0.7
				node.rotation = Vector3(wrapf(from_rot.x, -PI, PI), wrapf(from_rot.y, -PI, PI), wrapf(from_rot.z, -PI, PI)).lerp(Vector3(0, item.yaw, 0), q * q)
			else:
				node.rotation = Vector3(0, item.yaw, 0)
				node.position = target + Vector3(0, sin(t * 2.0) * 0.04, 0)
				if t > SHOW:
					var pulse := 1.0 + (0.22 + 0.06 * sin(t * 7.0) if won else -0.15)
					node.scale = Vector3.ONE * pulse
			if t > LAND and node.has_meta("front"):
				(node.get_meta("front") as Node3D).visible = true
		(_sides[i].label as Label3D).visible = t > SHOW
	if t > SHOW and _banner and not _banner.visible:
		_banner.visible = true
	if _banner and _banner.visible:
		var winner_side: Dictionary = _sides[_winner]
		_banner.text = "KAZANDI!"
		_banner.position.x = (-1.0 if _winner == 0 else 1.0)
		_banner.position.y = HEIGHT + 1.7 + sin(t * 4.0) * 0.06
		winner_side.label.modulate = Color("#fff2a0")


func _make_die(value: int) -> Node3D:
	var die := Node3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 0.5
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#f4efe4")
	mat.emission_enabled = true
	mat.emission = Color("#f4efe4")
	mat.emission_energy_multiplier = 0.25
	mesh.material_override = mat
	die.add_child(mesh)
	# Numbers on all six faces: the top shows the rolled value, the others the rest.
	var others: Array = [1, 2, 3, 4, 5, 6]
	others.erase(value)
	others.erase(7 - value)
	var faces := [
		[Vector3(0, 0.26, 0), Vector3(-PI / 2, 0, 0), value],
		[Vector3(0, -0.26, 0), Vector3(PI / 2, 0, 0), 7 - value],
		[Vector3(0, 0, 0.26), Vector3.ZERO, int(others[0])],
		[Vector3(0, 0, -0.26), Vector3(0, PI, 0), 7 - int(others[0])],
		[Vector3(0.26, 0, 0), Vector3(0, PI / 2, 0), int(others[1])],
		[Vector3(-0.26, 0, 0), Vector3(0, -PI / 2, 0), 7 - int(others[1])],
	]
	for f: Array in faces:
		var l := _label(str(f[2]), 90, Color("#2a1f18"))
		l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		l.no_depth_test = false
		l.fixed_size = false
		l.pixel_size = 0.0045
		l.position = f[0]
		l.rotation = f[1]
		die.add_child(l)
	return die


func _make_card(rank: int, suit: int) -> Node3D:
	var card := Node3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.55, 0.78, 0.03)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#f6f2e8")
	mat.emission_enabled = true
	mat.emission = Color("#f6f2e8")
	mat.emission_energy_multiplier = 0.25
	mesh.material_override = mat
	card.add_child(mesh)
	var red := suit == 1 or suit == 2
	var front := Node3D.new()
	for side in 2:
		var l := _label(_card_name(rank, suit), 110, Color("#c0302a") if red else Color("#1a1c22"))
		l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		l.no_depth_test = false
		l.fixed_size = false
		l.pixel_size = 0.0045
		l.position = Vector3(0, 0, 0.02 if side == 0 else -0.02)
		l.rotation = Vector3.ZERO if side == 0 else Vector3(0, PI, 0)
		front.add_child(l)
	front.visible = false
	card.add_child(front)
	card.set_meta("front", front)
	return card


func _label(text: String, size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.outline_size = 10
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0016
	return l
