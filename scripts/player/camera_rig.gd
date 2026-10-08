## Third-person camera behind the player (Megabonk style).
## Click to capture the mouse, move the mouse to look around (Esc opens the pause menu).
## A SpringArm3D pulls the camera in when a hill or tree is in the way.
extends Node3D

const SENSITIVITY := 0.0035
const MIN_PITCH := deg_to_rad(-70.0)
const MAX_PITCH := deg_to_rad(20.0)
const FOLLOW_SPEED := 18.0
const HEAD_OFFSET := Vector3(0, 1.6, 0)

var target: CharacterBody3D
## When false (menus, death screen) clicks never grab the mouse.
var capture_enabled := true
var yaw := 0.0
var pitch := deg_to_rad(-20.0)

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
	if event is InputEventMouseButton and event.pressed and capture_enabled and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		yaw -= motion.relative.x * SENSITIVITY
		pitch = clampf(pitch - motion.relative.y * SENSITIVITY, MIN_PITCH, MAX_PITCH)


func _process(delta: float) -> void:
	if target == null:
		return
	var goal := target.global_position + HEAD_OFFSET
	global_position = global_position.lerp(goal, minf(1.0, delta * FOLLOW_SPEED))
	rotation.y = yaw
	_pitch_pivot.rotation.x = pitch
	target.set("camera_yaw", yaw)
