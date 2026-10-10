## A little blocky mount the player sits on in the tavern.
extends Node3D

const HEIGHT := 0.55


func build(body_color: String, mane_color: String) -> void:
	var body := Color(body_color)
	var mane := Color(mane_color)
	_box(Vector3(0.7, 0.55, 1.5), Vector3(0, 0.62, 0), body)
	_box(Vector3(0.4, 0.4, 0.5), Vector3(0, 0.95, -0.85), body)
	_box(Vector3(0.3, 0.2, 0.3), Vector3(0, 0.88, -1.15), body.lightened(0.15))
	_box(Vector3(0.12, 0.34, 0.6), Vector3(0, 1.0, -0.4), mane)
	_box(Vector3(0.16, 0.16, 0.5), Vector3(0, 0.8, 0.9), mane)
	for x in [-0.22, 0.22]:
		for z in [-0.55, 0.55]:
			_box(Vector3(0.16, 0.5, 0.16), Vector3(x, 0.25, z), body.darkened(0.2))


func _box(size: Vector3, at: Vector3, color: Color) -> void:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	m.material_override = mat
	m.position = at
	add_child(m)
