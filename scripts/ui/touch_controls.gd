## On-screen controls for phones and tablets (web build): a stick on the left
## for walking, a drag area on the right for turning the camera, and buttons
## for the ultimate, jumping and pause. Shown only while playing and when the
## device has a touch screen or the setting is on.
extends CanvasLayer

signal ultimate_pressed
signal jump_pressed
signal pause_pressed

const STICK_RADIUS := 70.0
const ACTIONS := ["move_left", "move_right", "move_forward", "move_back"]

var camera_rig: Node
## The setting: "auto" (touch screens only), "on" or "off".
var mode := "auto"
var playing := false

var _stick_id := -1
var _look_id := -1
var _stick_center := Vector2.ZERO
var _stick_vec := Vector2.ZERO
var _pad: Control
var _buttons: Control


func _ready() -> void:
	layer = 15
	_pad = Control.new()
	_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.draw.connect(_draw_pad)
	add_child(_pad)
	_buttons = Control.new()
	_buttons.set_anchors_preset(Control.PRESET_FULL_RECT)
	_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_buttons)
	_add_button("ULTİ", Vector2(-170, -250), ultimate_pressed, Vector2(110, 110))
	_add_button("ZIPLA", Vector2(-300, -130), jump_pressed, Vector2(110, 110))
	_add_button("II", Vector2(-80, 24), pause_pressed, Vector2(64, 64), true)
	_refresh()


func _add_button(text: String, offset: Vector2, sig: Signal, size: Vector2, top := false) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = size
	b.size = size
	b.modulate = Color(1, 1, 1, 0.7)
	b.add_theme_font_size_override("font_size", 20)
	b.set_anchors_preset(Control.PRESET_TOP_RIGHT if top else Control.PRESET_BOTTOM_RIGHT)
	b.position = offset if top else Vector2(offset.x, offset.y)
	b.offset_left = offset.x
	b.offset_top = offset.y
	b.offset_right = offset.x + size.x
	b.offset_bottom = offset.y + size.y
	b.pressed.connect(func() -> void: sig.emit())
	_buttons.add_child(b)


## Whether the controls should show right now.
func wanted() -> bool:
	if not playing:
		return false
	match mode:
		"on":
			return true
		"off":
			return false
	return DisplayServer.is_touchscreen_available()


func set_playing(on: bool) -> void:
	playing = on
	_refresh()


func set_mode(value: String) -> void:
	mode = value
	_refresh()


func _refresh() -> void:
	var show := wanted()
	visible = show
	if not show:
		_release()


func _release() -> void:
	_stick_id = -1
	_look_id = -1
	_stick_vec = Vector2.ZERO
	for a: String in ACTIONS:
		Input.action_release(a)
	if _pad:
		_pad.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var half := get_viewport().get_visible_rect().size.x * 0.5
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if t.position.x < half and _stick_id < 0:
				_stick_id = t.index
				_stick_center = t.position
				_set_stick(Vector2.ZERO)
			elif t.position.x >= half and _look_id < 0 and not _on_button(t.position):
				_look_id = t.index
		else:
			if t.index == _stick_id:
				_stick_id = -1
				_set_stick(Vector2.ZERO)
			elif t.index == _look_id:
				_look_id = -1
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_id:
			_set_stick((d.position - _stick_center).limit_length(STICK_RADIUS) / STICK_RADIUS)
		elif d.index == _look_id and camera_rig:
			camera_rig.yaw -= d.relative.x * 0.006
			camera_rig.pitch = clampf(camera_rig.pitch - d.relative.y * 0.006, camera_rig.MIN_PITCH, camera_rig.MAX_PITCH)


func _on_button(at: Vector2) -> bool:
	for b: Control in _buttons.get_children():
		if b.get_global_rect().has_point(at):
			return true
	return false


func _set_stick(v: Vector2) -> void:
	_stick_vec = v
	Input.action_press("move_right", maxf(v.x, 0.0)) if v.x > 0.0 else Input.action_release("move_right")
	Input.action_press("move_left", maxf(-v.x, 0.0)) if v.x < 0.0 else Input.action_release("move_left")
	Input.action_press("move_back", maxf(v.y, 0.0)) if v.y > 0.0 else Input.action_release("move_back")
	Input.action_press("move_forward", maxf(-v.y, 0.0)) if v.y < 0.0 else Input.action_release("move_forward")
	_pad.queue_redraw()


func _draw_pad() -> void:
	if _stick_id < 0:
		return
	_pad.draw_circle(_stick_center, STICK_RADIUS, Color(1, 1, 1, 0.12))
	_pad.draw_arc(_stick_center, STICK_RADIUS, 0.0, TAU, 40, Color(1, 1, 1, 0.45), 3.0)
	_pad.draw_circle(_stick_center + _stick_vec * STICK_RADIUS, 28.0, Color(1, 1, 1, 0.55))
