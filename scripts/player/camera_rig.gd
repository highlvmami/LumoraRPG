## Third-person camera behind the player (Megabonk style).
## Click to capture the mouse, move the mouse to look around (Esc opens the pause menu).
## The mouse wheel moves the camera closer or further away.
## A SpringArm3D pulls the camera in when a hill or tree is in the way.
extends Node3D

const SENSITIVITY := 0.0035
const MIN_PITCH := deg_to_rad(-70.0)
const MAX_PITCH := deg_to_rad(20.0)
const FOLLOW_SPEED := 18.0
const HEAD_OFFSET := Vector3(0, 1.6, 0)
const MIN_ZOOM := 3.5
const MAX_ZOOM := 16.0
const ZOOM_STEP := 0.9

## Emitted when the wheel changes the distance (saved in the settings).
signal zoom_changed(distance: float)

var target: CharacterBody3D
## When false (menus, death screen) clicks never grab the mouse.
var capture_enabled := true
var yaw := 0.0
var pitch := deg_to_rad(-20.0)
## Wanted camera distance; the arm eases towards it.
var zoom := 7.0
## Mouse look speed multiplier (settings).
var sensitivity_scale := 1.0

var _pitch_pivot: Node3D
var _arm: SpringArm3D
var camera: Camera3D


func _ready() -> void:
	top_level = true
	_pitch_pivot = Node3D.new()
	add_child(_pitch_pivot)

	_arm = SpringArm3D.new()
	_arm.spring_length = 7.0
	_arm.margin = 0.3
	var probe := SphereShape3D.new()
	probe.radius = 0.3
	_arm.shape = probe
	_pitch_pivot.add_child(_arm)

	camera = Camera3D.new()
	camera.fov = 65.0
	camera.far = 300.0
	_arm.add_child(camera)
	camera.current = true

	if target:
		_arm.add_excluded_object(target.get_rid())
		global_position = target.global_position + HEAD_OFFSET


func _unhandled_input(event: InputEvent) -> void:
	var wheel := event as InputEventMouseButton
	if wheel and wheel.pressed and (wheel.button_index == MOUSE_BUTTON_WHEEL_UP or wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		if capture_enabled:
			zoom_by(-ZOOM_STEP if wheel.button_index == MOUSE_BUTTON_WHEEL_UP else ZOOM_STEP)
		return
	if event is InputEventMouseButton and event.pressed and capture_enabled and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		yaw -= motion.relative.x * SENSITIVITY * sensitivity_scale
		pitch = clampf(pitch - motion.relative.y * SENSITIVITY * sensitivity_scale, MIN_PITCH, MAX_PITCH)


## Moves the camera closer (negative) or further away (positive).
func zoom_by(amount: float) -> void:
	zoom = clampf(zoom + amount, MIN_ZOOM, MAX_ZOOM)
	zoom_changed.emit(zoom)


func _process(delta: float) -> void:
	if target == null:
		return
	var goal := target.global_position + HEAD_OFFSET
	global_position = global_position.lerp(goal, minf(1.0, delta * FOLLOW_SPEED))
	rotation.y = yaw
	_pitch_pivot.rotation.x = pitch
	_arm.spring_length = lerpf(_arm.spring_length, zoom, minf(1.0, delta * 10.0))
	target.set("camera_yaw", yaw)
