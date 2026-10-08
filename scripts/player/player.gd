## Player movement (run, jump with coyote time and jump buffering) and health.
## Attacks are automatic, so moving and dodging is the player's whole job.
extends CharacterBody3D

const Config := preload("res://scripts/core/config.gd")
const PlayerModel := preload("res://scripts/player/player_model.gd")
## Defense never blocks more than this share of a hit.
const MAX_DEFENSE := 0.6

signal health_changed(hp: float, max_hp: float)
signal died

## Set by the camera rig every frame: movement input is relative to where the camera looks.
var camera_yaw := 0.0
var max_hp := 100.0
var hp := 100.0
var dead := false
## 1.0 = base move speed (items can raise it).
var speed_multiplier := 1.0
## Health regained per second.
var regen := 0.0
## Developer cheat: ignore all damage.
var god_mode := false
## Direction the character faces, in radians around Y (0 = +Z).
var facing := 0.0
## Share of incoming damage blocked (pets, up to MAX_DEFENSE).
var defense := 0.0

var t: Dictionary
var _since_grounded := 0.0
var _jump_buffer := 0.0
var _model: PlayerModel
var _spawn_point := Vector3.ZERO
var _invulnerable := 0.0
## While > 0 the character faces its last shot instead of its movement.
var _aim_time := 0.0
var _aim_facing := 0.0


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
	max_hp = t.maxHp
	hp = max_hp


## Puts the player back at the spawn point with full health (new run).
func reset(new_max_hp: float) -> void:
	global_position = _spawn_point
	velocity = Vector3.ZERO
	max_hp = new_max_hp
	hp = max_hp
	dead = false
	_invulnerable = 0.0
	health_changed.emit(hp, max_hp)


func set_max_hp(value: float) -> void:
	hp += value - max_hp
	max_hp = value
	health_changed.emit(hp, max_hp)


## Rebuilds the character's look (class, weapon, helmet); see PlayerModel.build.
func set_look(look: Dictionary) -> void:
	_model.build(look)


## Plays the attack animation and turns toward the shot for a moment.
func play_attack(direction: Vector3) -> void:
	_model.attack()
	_aim_facing = atan2(direction.x, direction.z)
	_aim_time = 0.3


func take_damage(amount: float) -> void:
	if dead or god_mode or _invulnerable > 0.0:
		return
	hp = maxf(0.0, hp - amount * (1.0 - clampf(defense, 0.0, MAX_DEFENSE)))
	_invulnerable = t.invulnerableTime
	_model.flash()
	health_changed.emit(hp, max_hp)
	if hp <= 0.0:
		dead = true
		died.emit()


func move_speed() -> float:
	return float(t.moveSpeed) * speed_multiplier


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func _physics_process(delta: float) -> void:
	_invulnerable = maxf(0.0, _invulnerable - delta)
	if dead:
		step(delta, Vector2.ZERO, false)
		return
	if regen > 0.0 and hp < max_hp:
		hp = minf(max_hp, hp + regen * delta)
	var raw := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var world := Vector3(raw.x, 0.0, raw.y).rotated(Vector3.UP, camera_yaw)
	step(delta, Vector2(world.x, world.z), Input.is_action_just_pressed("jump"))


func _process(delta: float) -> void:
	_model.rotation.y = facing
	_model.animate(delta, horizontal_speed(), is_on_floor())


## One movement tick. `move` is the desired ground direction in world space (length 0..1).
func step(delta: float, move: Vector2, jump_pressed: bool) -> void:
	var on_floor := is_on_floor()
	_jump_buffer = t.jumpBufferTime if jump_pressed else maxf(0.0, _jump_buffer - delta)
	_since_grounded = 0.0 if on_floor else _since_grounded + delta

	# Accelerate toward the target velocity (less control in the air).
	var horiz := Vector2(velocity.x, velocity.z)
	var target: Vector2 = move * float(t.moveSpeed) * speed_multiplier
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

	_aim_time = maxf(0.0, _aim_time - delta)
	if _aim_time > 0.0:
		facing = lerp_angle(facing, _aim_facing, minf(1.0, delta * 20.0))
	elif horiz.length_squared() > 0.25:
		var target_facing := atan2(horiz.x, horiz.y)
		facing = lerp_angle(facing, target_facing, minf(1.0, delta * 14.0))

	# Safety net: never fall forever.
	if global_position.y < -50.0:
		global_position = _spawn_point
		velocity = Vector3.ZERO
