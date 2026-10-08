## Warning zones for boss attacks: a red area appears on the ground where the
## attack will land and fills up until it hits, so the player can step out.
## Only draws; the enemy manager decides when and whom the attack hits.
extends Node3D

const Terrain := preload("res://scripts/world/terrain.gd")

## Height falling rocks start from.
const DROP_HEIGHT := 14.0
## Rocks fall during the last part of the warning.
const DROP_TIME := 0.45

var terrain: Terrain
var _zones: Array = []


func active_count() -> int:
	return _zones.size()


func clear() -> void:
	for z: Dictionary in _zones:
		(z.root as Node3D).queue_free()
	_zones.clear()


## A round zone at `center` that hits after `time` seconds; `rock` drops a
## stone (or egg) from the sky onto it.
func circle(center: Vector3, radius: float, time: float, color: Color, rock := false) -> void:
	var root := _zone_root(center)
	var edge := _disc(radius, Color(color, 0.28))
	root.add_child(edge)
	var ring := _ring(radius, Color(color, 0.9))
	root.add_child(ring)
	var fill := _disc(radius, Color(color, 0.5))
	fill.scale = Vector3(0.01, 1, 0.01)
	root.add_child(fill)
	var falling: MeshInstance3D = null
	if rock:
		falling = MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = radius * 0.45
		s.height = radius * 0.9
		s.radial_segments = 10
		s.rings = 5
		falling.mesh = s
		falling.material_override = _material(color.darkened(0.35), false)
		falling.visible = false
		root.add_child(falling)
	_zones.append({"root": root, "fill": fill, "time": time, "total": time, "kind": "circle", "rock": falling, "radius": radius, "color": color})


## A ring-shaped zone (a shockwave) between `inner` and `outer` around `center`.
func ring(center: Vector3, inner: float, outer: float, time: float, color: Color) -> void:
	var root := _zone_root(center)
	var edge := _annulus(inner, outer, Color(color, 0.35))
	root.add_child(edge)
	root.add_child(_ring(outer, Color(color, 0.9)))
	if inner > 0.2:
		root.add_child(_ring(inner + 0.12, Color(color, 0.6)))
	var fill := _annulus(inner, outer, Color(color, 0.0))
	root.add_child(fill)
	_zones.append({"root": root, "fill": fill, "time": time, "total": time, "kind": "ring", "rock": null, "radius": outer, "inner": inner, "color": color})


## A straight zone from `from` to `to` (a charge or a web line).
func line(from: Vector3, to: Vector3, width: float, time: float, color: Color) -> void:
	var root := _zone_root(from)
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var length := flat.length()
	root.basis = Basis(Vector3.UP, atan2(flat.x, flat.z))
	var edge := _strip(width, length, Color(color, 0.28))
	root.add_child(edge)
	var fill := _strip(width, length, Color(color, 0.55))
	fill.scale = Vector3(1, 1, 0.01)
	root.add_child(fill)
	_zones.append({"root": root, "fill": fill, "time": time, "total": time, "kind": "line", "rock": null, "radius": width, "length": length, "color": color})


func _process(delta: float) -> void:
	var i := 0
	while i < _zones.size():
		var z: Dictionary = _zones[i]
		z.time = float(z.time) - delta
		var f := clampf(1.0 - float(z.time) / float(z.total), 0.0, 1.0)
		var fill: Node3D = z.fill
		if z.kind == "circle":
			fill.scale = Vector3(maxf(f, 0.01), 1, maxf(f, 0.01))
		elif z.kind == "ring":
			# Rings brighten instead of growing.
			((fill as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a = 0.65 * f * f
		else:
			fill.scale = Vector3(1, 1, maxf(f, 0.01))
		var rock: MeshInstance3D = z.rock
		if rock:
			var drop := clampf(1.0 - float(z.time) / DROP_TIME, 0.0, 1.0)
			rock.visible = float(z.time) < DROP_TIME
			rock.position = Vector3(0, DROP_HEIGHT * (1.0 - drop) + float(z.radius) * 0.3, 0)
		if float(z.time) <= 0.0:
			_impact(z)
			(z.root as Node3D).queue_free()
			_zones.remove_at(i)
		else:
			i += 1


## A short burst where the attack landed.
func _impact(z: Dictionary) -> void:
	var root := z.root as Node3D
	var flash: Node3D
	if z.kind == "ring":
		flash = _annulus(float(z.inner), float(z.radius), Color.WHITE)
	elif z.kind == "circle":
		var s := SphereMesh.new()
		s.radius = float(z.radius)
		s.height = float(z.radius) * 0.6
		var sphere := MeshInstance3D.new()
		sphere.mesh = s
		flash = sphere
	else:
		flash = _strip(float(z.radius) * 1.3, float(z.length), Color.WHITE)
	var mat := _material(Color(z.color as Color, 0.65), true)
	for m: MeshInstance3D in flash.find_children("*", "MeshInstance3D", true, false) + ([flash] if flash is MeshInstance3D else []):
		m.material_override = mat
	add_child(flash)
	flash.global_transform = root.global_transform
	if z.kind == "line":
		flash.scale = Vector3(1.0, 10.0, 1.0)
	elif z.kind == "ring":
		flash.scale = Vector3(1.0, 0.8 / maxf(float(z.radius) - float(z.inner), 0.1), 1.0)
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tween.tween_callback(flash.queue_free)


func _zone_root(at: Vector3) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var y := terrain.height_at(at.x, at.z) if terrain else at.y
	root.global_position = Vector3(at.x, y + 0.08, at.z)
	return root


func _disc(radius: float, color: Color) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = 0.04
	c.radial_segments = 32
	c.rings = 1
	var m := MeshInstance3D.new()
	m.mesh = c
	m.material_override = _material(color, true)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


## A flat band between `inner` and `outer` (a flattened torus).
func _annulus(inner: float, outer: float, color: Color) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = maxf(inner, 0.05)
	t.outer_radius = outer
	t.rings = 40
	t.ring_segments = 6
	var m := MeshInstance3D.new()
	m.mesh = t
	m.scale = Vector3(1.0, 0.02 / maxf(outer - inner, 0.1), 1.0)
	m.material_override = _material(color, true)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


func _ring(radius: float, color: Color) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = radius - 0.12
	t.outer_radius = radius
	t.rings = 32
	t.ring_segments = 4
	var m := MeshInstance3D.new()
	m.mesh = t
	m.material_override = _material(color, true)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


## A flat strip starting at the origin and going `length` along +Z
## (scaling the returned node along Z grows it away from the start).
func _strip(width: float, length: float, color: Color) -> Node3D:
	var b := BoxMesh.new()
	b.size = Vector3(width, 0.04, length)
	var m := MeshInstance3D.new()
	m.mesh = b
	m.material_override = _material(color, true)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = Vector3(0, 0, length * 0.5)
	var holder := Node3D.new()
	holder.add_child(m)
	return holder


func _material(color: Color, see_through: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	if see_through:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.no_depth_test = true
		mat.render_priority = 1
	return mat
