## Minimal HUD for M0: controls, a start prompt and debug stats.
extends CanvasLayer

var player: CharacterBody3D

var _stats: Label
var _start: Control


func _ready() -> void:
	var font := LabelSettings.new()
	font.font_size = 10
	font.outline_size = 3
	font.outline_color = Color.BLACK

	var controls := _label("WASD: yürü   BOŞLUK: zıpla   SHIFT: kay   FARE: bak   ESC: fareyi bırak", font)
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 6)
	add_child(controls)

	_stats = _label("", font)
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stats.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 6)
	_stats.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(_stats)

	_start = ColorRect.new()
	(_start as ColorRect).color = Color(0.04, 0.06, 0.08, 0.55)
	_start.set_anchors_preset(Control.PRESET_FULL_RECT)
	_start.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_start)

	var title_font := LabelSettings.new()
	title_font.font_size = 32
	title_font.font_color = Color("#ffd866")
	title_font.outline_size = 6
	title_font.outline_color = Color.BLACK
	var title := _label("LUMORA", title_font)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	title.position.y -= 20
	_start.add_child(title)

	var hint := _label("Başlamak için tıkla", font)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hint.position.y += 16
	_start.add_child(hint)


func _process(_delta: float) -> void:
	_start.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	if player == null:
		return
	var state := "yerde"
	if player.get("sliding"):
		state = "kayıyor"
	elif not player.is_on_floor():
		state = "havada"
	_stats.text = "FPS %d\nhız %.1f\n%s" % [Engine.get_frames_per_second(), player.call("horizontal_speed"), state]


func _label(text: String, settings: LabelSettings) -> Label:
	var label := Label.new()
	label.text = text
	label.label_settings = settings
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
