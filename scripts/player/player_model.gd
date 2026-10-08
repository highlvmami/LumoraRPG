## Blocky placeholder character built from boxes (real voxel models come in M5).
## Faces +Z. Animates legs/arms from movement speed and blinks when hurt.
extends Node3D

const Toon := preload("res://scripts/core/toon.gd")

const SKIN := Color("#f1c27d")
const TUNIC := Color("#3a6ea5")
const PANTS := Color("#3b2f2a")
const HAIR := Color("#5a3820")
const EYES := Color("#1a1a1a")

var _visual: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _phase := 0.0
var _flash_time := 0.0


func _ready() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	_box(_visual, Vector3(0.7, 0.75, 0.4), Vector3(0, 1.1, 0), TUNIC)
	_box(_visual, Vector3(0.5, 0.5, 0.5), Vector3(0, 1.75, 0), SKIN)
	_box(_visual, Vector3(0.54, 0.16, 0.54), Vector3(0, 2.02, -0.02), HAIR)
	_box(_visual, Vector3(0.08, 0.08, 0.02), Vector3(-0.12, 1.78, 0.26), EYES)
	_box(_visual, Vector3(0.08, 0.08, 0.02), Vector3(0.12, 1.78, 0.26), EYES)
	_leg_l = _limb(Vector3(-0.17, 0.72, 0), Vector3(0.24, 0.72, 0.26), PANTS)
	_leg_r = _limb(Vector3(0.17, 0.72, 0), Vector3(0.24, 0.72, 0.26), PANTS)
	_arm_l = _limb(Vector3(-0.47, 1.45, 0), Vector3(0.2, 0.65, 0.22), TUNIC)
	_arm_r = _limb(Vector3(0.47, 1.45, 0), Vector3(0.2, 0.65, 0.22), TUNIC)


## Called every frame by the player with its current movement state.
func animate(delta: float, speed: float, on_floor: bool) -> void:
	var amount := clampf(speed / 9.0, 0.0, 1.0)
	_phase += delta * (4.0 + speed * 0.9)
	var swing := sin(_phase) * 0.9 * amount
	if not on_floor:
		swing = 0.0
	var leg_tuck := 0.0 if on_floor else 0.6
	_leg_l.rotation.x = swing - leg_tuck
	_leg_r.rotation.x = -swing - leg_tuck * 0.4
	_arm_l.rotation.x = -swing
	_arm_r.rotation.x = swing

	# Blink while invulnerable after taking a hit.
	_flash_time = maxf(0.0, _flash_time - delta)
	_visual.visible = _flash_time <= 0.0 or fmod(_flash_time, 0.1) < 0.05


func flash() -> void:
	_flash_time = 0.5


func _box(parent: Node3D, box_size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = Toon.material(color)
	instance.position = pos
	parent.add_child(instance)
	return instance


## A limb pivots at its top (hip or shoulder).
func _limb(pivot_pos: Vector3, box_size: Vector3, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_pos
	_visual.add_child(pivot)
	_box(pivot, box_size, Vector3(0, -box_size.y * 0.5, 0), color)
	return pivot
