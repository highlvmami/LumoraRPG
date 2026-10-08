## Small pictures of every pet kind for the menus: each kind is rendered once
## in its own tiny 3D stage (standing still, turned a little to the side) and
## the picture is shared by every card that shows it. `rect` gives a crisp
## pixel picture; `gray` shows it without color (pets not found yet).
extends Node

const CharacterPreview := preload("res://scripts/ui/character_preview.gd")
const PetModel := preload("res://scripts/player/pet_model.gd")

## Render size of each picture (shown bigger with crisp pixels).
const RENDER := Vector2i(52, 52)
const GRAY_SHADER := """
shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	COLOR = vec4(vec3(g * 0.55 + 0.05), c.a * 0.75);
}
"""

var _stages := {}
var _gray: ShaderMaterial


## The picture of a pet kind.
func texture(kind_id: String) -> Texture2D:
	if not _stages.has(kind_id):
		var pet := PetModel.new()
		pet.build(kind_id)
		var center := pet.center_height()
		var stage := CharacterPreview.make_stage(Vector3(0, center + 0.9, pet.view_distance() * 0.92), Vector3(0, center, 0))
		stage.size = RENDER
		stage.render_target_update_mode = SubViewport.UPDATE_ONCE
		var pivot := Node3D.new()
		pivot.rotation.y = CharacterPreview.STILL_ANGLE
		pivot.add_child(pet)
		stage.add_child(pivot)
		add_child(stage)
		_stages[kind_id] = stage
	return (_stages[kind_id] as SubViewport).get_texture()


## A TextureRect with a pet's picture; `gray` takes the color out.
func rect(kind_id: String, size: float, gray := false) -> TextureRect:
	var r := TextureRect.new()
	r.texture = texture(kind_id)
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if gray:
		if _gray == null:
			var shader := Shader.new()
			shader.code = GRAY_SHADER
			_gray = ShaderMaterial.new()
			_gray.shader = shader
		r.material = _gray
	return r
