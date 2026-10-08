## Player movement: run, jump (with coyote time and jump buffering) and slide.
## Sliding keeps momentum, speeds up downhill and can be chained into jumps.
## Attacks are automatic (from M1), so movement is the player's whole job.
extends CharacterBody3D

const Config := preload("res://scripts/core/config.gd")
const PlayerModel := preload("res://scripts/player/player_model.gd")

## Set by the camera rig every frame: movement input is relative to where the camera looks.
var camera_yaw := 0.0
var sliding := false
## Direction the character faces, in radians around Y (0 = +Z).
var facing := 0.0

var t: Dictionary
var _since_grounded := 0.0
var _jump_buffer := 0.0
var _model: PlayerModel
var _spawn_point := Vector3.ZERO


func _ready() -> void:
	t = Config.load_json("res://data/player.json")

	var capsule := CapsuleShape3D.new()
	capsule.radius = t.radius
	capsule.height = t.height
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = t.height * 0.5
	add_child(collision)

	floor_snap_length = t.groundSnapDistance
	floor_max_angle = deg_to_rad(t.maxFloorAngleDeg)

	_model = PlayerModel.new()
	add_child(_model)
	_spawn_point = global_position


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func _physics_process(delta: float) -> void:
	var raw := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var world := Vector3(raw.x, 0.0, raw.y).rotated(Vector3.UP, camera_yaw)
	step(delta, Vector2(world.x, world.z), Input.is_action_just_pressed("jump"), Input.is_action_pressed("slide"))


func _process(delta: float) -> void:
	_model.rotation.y = facing
	_model.animate(delta, horizontal_speed(), is_on_floor(), sliding)


## One movement tick. `move` is the desired ground direction in world space (length 0..1).
func step(delta: float, move: Vector2, jump_pressed: bool, slide_held: bool) -> void:
	var on_floor := is_on_floor()
	_jump_buffer = t.jumpBufferTime if jump_pressed else maxf(0.0, _jump_buffer - delta)
	_since_grounded = 0.0 if on_floor else _since_grounded + delta

	var horiz := Vector2(velocity.x, velocity.z)
	var moving := move.length_squared() > 0.01

	# Start / stop sliding.
	if slide_held and on_floor and not sliding and (moving or horiz.length() > 2.0):
		sliding = true
		var dir := move.normalized() if moving else horiz.normalized()
		horiz = dir * maxf(horiz.length(), t.slideBoostSpeed)
	if sliding and (not slide_held or (on_floor and horiz.length() < t.slideMinSpeed)):
		sliding = false

	if sliding:
		if on_floor:
			# Friction, plus gravity pulling the slide down the slope.
			var speed := horiz.length()
			if speed > 0.0:
				horiz *= maxf(0.0, speed - t.slideFriction * delta) / speed
			var n := get_floor_normal()
			horiz += Vector2(n.x, n.z) * t.slideSlopeAccel * delta
			if moving:
				horiz += move * t.airAccel * 0.5 * delta
			horiz = horiz.limit_length(t.maxSlideSpeed)
	elif on_floor or moving or horiz.length() <= t.moveSpeed:
		# Accelerate toward the target velocity. (In the air with no input and extra
		# momentum, e.g. after a slide jump, we coast instead of braking.)
		var target := move * t.moveSpeed
		var accel: float = t.groundAccel if on_floor else t.airAccel
		horiz = horiz.move_toward(target, accel * delta)

	var vy := velocity.y
	if _jump_buffer > 0.0 and _since_grounded <= t.coyoteTime:
		vy = t.jumpVelocity
		_jump_buffer = 0.0
		_since_grounded = t.coyoteTime + 1.0
	elif not on_floor:
		vy -= t.gravity * delta
	else:
		vy = minf(vy, 0.0)

	velocity = Vector3(horiz.x, vy, horiz.y)
	move_and_slide()

	if horiz.length_squared() > 0.25:
		var target_facing := atan2(horiz.x, horiz.y)
		facing = lerp_angle(facing, target_facing, minf(1.0, delta * 14.0))

	# Safety net: never fall forever.
	if global_position.y < -50.0:
		global_position = _spawn_point
		velocity = Vector3.ZERO
