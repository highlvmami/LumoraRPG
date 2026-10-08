## A co-op partner as seen in this game: their character (class and gear),
## moving smoothly to the spot they last sent, with their name and health
## above the head. On the host, enemies chase and hurt partners too; the hurt
## goes back to the partner's own game (`hurt`).
extends Node3D

const PlayerModel := preload("res://scripts/player/player_model.gd")
const INVULNERABLE_TIME := 0.5

signal hurt(amount: float)

var peer_id := 0
var player_name := ""
var hp := 100.0
var max_hp := 100.0
var dead := false

var _model: PlayerModel
var _label: Label3D
var _goal := Vector3.ZERO
var _facing := 0.0
var _speed := 0.0
var _attacks := -1
var _invulnerable := 0.0
var _has_state := false


func setup(id: int, display_name: String) -> void:
	peer_id = id
	player_name = display_name
	_model = PlayerModel.new()
	add_child(_model)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0022
	_label.font_size = 26
	_label.outline_size = 8
	_label.position = Vector3(0, 2.45, 0)
	add_child(_label)
	_update_label()


## A state sent by the partner (see Coop._send_state).
func apply_state(d: Dictionary) -> void:
	var p: Array = d.get("p", [0, 0, 0])
	_goal = Vector3(float(p[0]), float(p[1]), float(p[2]))
	if not _has_state:
		global_position = _goal
		_has_state = true
	_facing = float(d.get("f", 0.0))
	_speed = float(d.get("s", 0.0))
	hp = float(d.get("hp", hp))
	max_hp = maxf(1.0, float(d.get("mh", max_hp)))
	dead = bool(d.get("d", false))
	visible = not dead
	var attacks := int(d.get("a", 0))
	if _attacks >= 0 and attacks != _attacks:
		_model.attack()
	_attacks = attacks
	if d.has("lk") and d.lk is Dictionary:
		set_look(d.lk)
	_update_label()


func set_look(look: Dictionary) -> void:
	var clean := {}
	for key: String in look:
		# JSON turns whole numbers into floats; the model wants ints for tiers.
		clean[key] = int(look[key]) if key.ends_with("_tier") else look[key]
	_model.build(clean)


## Called by enemies on the host. Partners get a short safe time after a hit,
## like the local player.
func take_damage(amount: float) -> void:
	if dead or _invulnerable > 0.0:
		return
	_invulnerable = INVULNERABLE_TIME
	_model.flash()
	hurt.emit(amount)


func _process(delta: float) -> void:
	_invulnerable = maxf(0.0, _invulnerable - delta)
	global_position = global_position.lerp(_goal, minf(1.0, delta * 14.0))
	if global_position.distance_to(_goal) > 12.0:
		global_position = _goal
	_model.rotation.y = lerp_angle(_model.rotation.y, _facing, minf(1.0, delta * 16.0))
	_model.animate(delta, _speed, true)


func _update_label() -> void:
	if _label == null:
		return
	var ratio := hp / max_hp
	_label.text = "%s  %d%%" % [player_name, roundi(ratio * 100.0)]
	_label.modulate = Color("#ff8a8a") if ratio < 0.35 else Color("#ffffff")
