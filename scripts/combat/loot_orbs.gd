## Little orbs that pop out of a killed enemy to show the reward: blue for EXP,
## yellow for gold. They bounce on the ground, then shrink away. Purely visual;
## the reward itself is added the moment the enemy dies.
extends Node3D

const Terrain := preload("res://scripts/world/terrain.gd")

const MAX_ORBS := 256
const MAX_PER_KIND := 5
const LIFETIME := 2.6
const SHRINK_TIME := 0.5
const GRAVITY := 22.0
const EXP_COLOR := Color("#4fb8ff")
const GOLD_COLOR := Color("#ffd23f")

var terrain: Terrain

var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _life := PackedFloat32Array()
var _color := PackedColorArray()
var _mm: MultiMesh
var _rng := RandomNumberGenerator.new()


func setup(p_terrain: Terrain) -> void:
	terrain = p_terrain
	var orb := SphereMesh.new()
	orb.radius = 0.14
	orb.height = 0.28
	orb.radial_segments = 8
	orb.rings = 4
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = orb
	_mm.instance_count = MAX_ORBS
	_mm.visible_instance_count = 0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = _mm
	instance.material_override = mat
	add_child(instance)


func count() -> int:
	return _pos.size()


func clear() -> void:
	_pos.clear()
	_vel.clear()
	_life.clear()
	_color.clear()
	_mm.visible_instance_count = 0


## One blue orb per EXP point and one yellow orb per gold (a few at most).
func burst(at: Vector3, exp_amount: int, gold_amount: int) -> void:
	for i in mini(exp_amount, MAX_PER_KIND):
		_add(at, EXP_COLOR)
	for i in mini(gold_amount, MAX_PER_KIND):
		_add(at, GOLD_COLOR)


func _add(at: Vector3, color: Color) -> void:
	if _pos.size() >= MAX_ORBS:
		return
	var angle := _rng.randf() * TAU
	var out := _rng.randf_range(1.5, 3.5)
	_pos.append(at)
	_vel.append(Vector3(cos(angle) * out, _rng.randf_range(5.0, 8.0), sin(angle) * out))
	_life.append(LIFETIME + _rng.randf_range(-0.3, 0.3))
	_color.append(color)


func _physics_process(delta: float) -> void:
	var i := 0
	while i < _pos.size():
		var v := _vel[i]
		v.y -= GRAVITY * delta
		var p := _pos[i] + v * delta
		var ground := terrain.height_at(p.x, p.z) + 0.14
		if p.y < ground:
			# Bounce with lots of energy loss, then settle.
			p.y = ground
			v = Vector3(v.x * 0.55, absf(v.y) * 0.4 if absf(v.y) > 1.5 else 0.0, v.z * 0.55)
		_pos[i] = p
		_vel[i] = v
		_life[i] -= delta
		if _life[i] <= 0.0:
			var last := _pos.size() - 1
			_pos[i] = _pos[last]
			_vel[i] = _vel[last]
			_life[i] = _life[last]
			_color[i] = _color[last]
			_pos.resize(last)
			_vel.resize(last)
			_life.resize(last)
			_color.resize(last)
		else:
			i += 1


func _process(_delta: float) -> void:
	var n := _pos.size()
	_mm.visible_instance_count = n
	for i in n:
		var s := clampf(_life[i] / SHRINK_TIME, 0.05, 1.0)
		_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * s), _pos[i]))
		_mm.set_instance_color(i, _color[i])
