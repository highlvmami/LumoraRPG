## Semi-transparent circle on the ground showing how far the weapon reaches.
## Rebuilt every frame so it follows the hills instead of cutting through them.
extends MeshInstance3D

const Terrain := preload("res://scripts/world/terrain.gd")

const SEGMENTS := 72
const WIDTH := 0.18
const LIFT := 0.12

var terrain: Terrain
var target: Node3D
var radius := 10.0

var _mesh := ImmediateMesh.new()


func _ready() -> void:
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.95, 0.75, 0.35)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	material_override = mat
	top_level = true


func _process(_delta: float) -> void:
	if terrain == null or target == null or not visible:
		return
	var c := target.global_position
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in SEGMENTS + 1:
		var a := TAU * float(i) / SEGMENTS
		var dir := Vector2(cos(a), sin(a))
		for r: float in [radius - WIDTH, radius + WIDTH]:
			var x := c.x + dir.x * r
			var z := c.z + dir.y * r
			_mesh.surface_add_vertex(Vector3(x, terrain.height_at(x, z) + LIFT, z))
	_mesh.surface_end()
