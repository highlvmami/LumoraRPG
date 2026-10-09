## Another visitor of the hub tavern: their character (class and gear) with
## a name and level above the head. Walks smoothly to where they last were,
## sits in the chair or swing they use, dances on the dance floor and shows
## what they say in a speech bubble.
extends Node3D

const PlayerModel := preload("res://scripts/player/player_model.gd")
const HubWorld := preload("res://scripts/world/hub_world.gd")

const BUBBLE_TIME := 6.0

var peer_id := 0
var player_name := ""
var level := 0
## What they are doing: "", "sit", "swing" or "dance", and which thing (index
## in HubWorld.interactables, -1 for none).
var action := ""
var object := -1

var _hub: Node3D
var _model: PlayerModel
var _tag: Label3D
var _bubble: Label3D
var _bubble_time := 0.0
var _goal := Vector3.ZERO
var _facing := 0.0
var _speed := 0.0
var _has_state := false
var _look_json := ""


func setup(id: int, display_name: String, p_level: int, hub_world: Node3D) -> void:
	peer_id = id
	player_name = display_name
	level = p_level
	_hub = hub_world
	_model = PlayerModel.new()
	add_child(_model)
	_tag = Label3D.new()
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.fixed_size = true
	_tag.pixel_size = 0.0022
	_tag.font_size = 26
	_tag.outline_size = 8
	_tag.position = Vector3(0, 2.5, 0)
	add_child(_tag)
	_bubble = make_bubble()
	_bubble.visible = false
	add_child(_bubble)
	_update_tag()
	# Nothing to show until their first state arrives.
	visible = false


## A speech bubble that floats above a character's head (also used for the local player).
static func make_bubble() -> Label3D:
	var bubble := Label3D.new()
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.no_depth_test = true
	bubble.fixed_size = true
	bubble.pixel_size = 0.0022
	bubble.font_size = 28
	bubble.outline_size = 10
	bubble.outline_modulate = Color("#2a1a0e")
	bubble.modulate = Color("#fff6e0")
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.width = 460.0
	bubble.position = Vector3(0, 3.1, 0)
	return bubble


func set_info(display_name: String, p_level: int) -> void:
	player_name = display_name
	level = p_level
	_update_tag()


func set_look(look: Dictionary) -> void:
	var json := JSON.stringify(look)
	if json == _look_json:
		return
	_look_json = json
	var clean := {}
	for key: String in look:
		# JSON turns whole numbers into floats; the model wants ints for tiers.
		clean[key] = int(look[key]) if key.ends_with("_tier") else look[key]
	_model.build(clean)


## A state sent by the visitor (see Hub._send_state); positions are local to the tavern.
func apply_state(d: Dictionary) -> void:
	var p: Array = d.get("p", [0, 0, 0])
	_goal = HubWorld.ORIGIN + Vector3(float(p[0]), float(p[1]), float(p[2]))
	_facing = float(d.get("f", 0.0))
	_speed = float(d.get("s", 0.0))
	action = str(d.get("a", ""))
	object = int(d.get("o", -1))
	if not _has_state:
		_has_state = true
		global_position = _goal
		visible = true


## Whether they sit (chair, bench, stool or swing) right now.
func is_seated() -> bool:
	return (action == "sit" or action == "swing") and object >= 0 and object < _hub.interactables.size()


## What they said shows over their head for a few seconds.
func say(text: String) -> void:
	_bubble.text = text
	_bubble.visible = true
	_bubble_time = BUBBLE_TIME


func bubble_text() -> String:
	return _bubble.text if _bubble.visible else ""


func _update_tag() -> void:
	if _tag:
		_tag.text = "%s  Sv.%d" % [player_name, level] if level > 0 else player_name


func _process(delta: float) -> void:
	if not _has_state:
		return
	if _bubble.visible:
		_bubble_time -= delta
		_bubble.visible = _bubble_time > 0.0
	if is_seated():
		var seat: Vector3 = _hub.origin_of(object)
		global_position = global_position.lerp(seat, minf(1.0, delta * 20.0))
		_model.rotation.y = _hub.facing_of(object)
		_model.sitting = true
		_model.dancing = false
		_model.position.y = HubWorld.SIT_DROP
		_model.animate(delta, 0.0, true)
		return
	_model.sitting = false
	_model.dancing = action == "dance"
	_model.position.y = 0.0
	global_position = global_position.lerp(_goal, minf(1.0, delta * 14.0))
	if global_position.distance_to(_goal) > 12.0:
		global_position = _goal
	_model.rotation.y = lerp_angle(_model.rotation.y, _facing, minf(1.0, delta * 16.0))
	_model.animate(delta, _speed, true)
