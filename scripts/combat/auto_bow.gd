## Starting weapon: automatically shoots an arrow at the nearest enemy in range.
## Arrows fly straight and hit the first enemy they touch.
extends Node3D

const Config := preload("res://scripts/core/config.gd")
const Toon := preload("res://scripts/core/toon.gd")
const EnemyManager := preload("res://scripts/enemies/enemy_manager.gd")

const MAX_ARROWS := 64

var player: CharacterBody3D
var enemies: EnemyManager
var active := false
## Multiplier from character level; 1.0 = base damage.
var damage_multiplier := 1.0

var _w: Dictionary
var _cooldown := 0.0
var _arrow_pos := PackedVector3Array()
var _arrow_vel := PackedVector3Array()
var _arrow_life := PackedFloat32Array()
var _mm: MultiMesh


func setup(p_player: CharacterBody3D, p_enemies: EnemyManager) -> void:
	player = p_player
	enemies = p_enemies
	_w = Config.load_json("res://data/weapons.json").bow

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.12, 0.12, 0.9)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.mesh = mesh
	_mm.instance_count = MAX_ARROWS
	_mm.visible_instance_count = 0
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = _mm
	var mat := Toon.material(Color("#ffe08a"))
	mat.emission_enabled = true
	mat.emission = Color("#ffcc55")
	instance.material_override = mat
	add_child(instance)


func clear() -> void:
	_arrow_pos.clear()
	_arrow_vel.clear()
	_arrow_life.clear()
	_cooldown = 0.0


func _physics_process(delta: float) -> void:
	if not active:
		return
	_cooldown -= delta
	if _cooldown <= 0.0:
		_try_fire()
	_update_arrows(delta)


func _try_fire() -> void:
	var origin := player.global_position + Vector3.UP * 1.3
	var target := enemies.nearest(origin, float(_w["range"]))
	if target < 0 or _arrow_pos.size() >= MAX_ARROWS:
		return
	var dir := (enemies.position_of(target) - origin).normalized()
	_arrow_pos.append(origin)
	_arrow_vel.append(dir * float(_w.projectileSpeed))
	_arrow_life.append(_w.projectileLifetime)
	_cooldown = _w.cooldown


func _update_arrows(delta: float) -> void:
	var i := 0
	while i < _arrow_pos.size():
		_arrow_pos[i] += _arrow_vel[i] * delta
		_arrow_life[i] -= delta
		var hit := enemies.hit_test(_arrow_pos[i], _w.hitRadius)
		if hit >= 0:
			enemies.damage(hit, float(_w.damage) * damage_multiplier)
		if hit >= 0 or _arrow_life[i] <= 0.0:
			_remove(i)
		else:
			i += 1


func _process(_delta: float) -> void:
	var n := _arrow_pos.size()
	_mm.visible_instance_count = n
	for i in n:
		var facing := Basis.looking_at(_arrow_vel[i].normalized(), Vector3.UP)
		_mm.set_instance_transform(i, Transform3D(facing, _arrow_pos[i]))


func _remove(index: int) -> void:
	var last := _arrow_pos.size() - 1
	_arrow_pos[index] = _arrow_pos[last]
	_arrow_vel[index] = _arrow_vel[last]
	_arrow_life[index] = _arrow_life[last]
	_arrow_pos.resize(last)
	_arrow_vel.resize(last)
	_arrow_life.resize(last)
