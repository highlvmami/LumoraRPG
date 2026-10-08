## Shared material helpers: hard-edged toon shading for the pixel-art look.
extends RefCounted


static func material(color: Color, use_vertex_color := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.roughness = 1.0
	mat.vertex_color_use_as_albedo = use_vertex_color
	return mat
