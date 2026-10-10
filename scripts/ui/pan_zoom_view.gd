## A clipped window onto a bigger picture (the skill tree): drag the empty
## background (or hold the middle / right button anywhere on it) to move
## around, scroll the wheel to zoom towards the pointer, and the buttons in
## the corner zoom in and out or fit the whole picture again.
extends Control

const UiTheme := preload("res://scripts/ui/theme.gd")

const MAX_ZOOM := 1.6
const STEP := 1.15

## The big control being looked at; set it before the view enters the tree.
var content: Control
var zoom := 1.0
var _fit_zoom := 1.0
var _dragging := false
var _fitted := false


func setup(p_content: Control) -> void:
	content = p_content
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(content)
	content.position = Vector2.ZERO
	content.pivot_offset = Vector2.ZERO
	resized.connect(_on_resized)

	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bar.offset_top = 6
	bar.offset_right = -8
	bar.add_theme_constant_override("separation", 4)
	add_child(bar)
	for spec: Array in [["−", -1], ["+", 1], ["Sığdır", 0]]:
		var b := Button.new()
		b.text = spec[0]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 14)
		b.custom_minimum_size = Vector2(0, 26)
		b.tooltip_text = "Sürükle: kaydır · Tekerlek: yakınlaştır"
		var dir: int = spec[1]
		b.pressed.connect(func() -> void:
			if dir == 0:
				fit()
			else:
				zoom_at(size * 0.5, STEP if dir > 0 else 1.0 / STEP))
		bar.add_child(b)
	var hint := UiTheme.label("Sürükle: kaydır  ·  Tekerlek: yakınlaştır", UiTheme.label_settings(12, UiTheme.MUTED, 3))
	hint.position = Vector2(10, 8)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)


func _on_resized() -> void:
	_fit_zoom = _compute_fit()
	if not _fitted and size.x > 10.0 and size.y > 10.0:
		_fitted = true
		# Start closer than the whole picture, on its middle.
		var k := clampf(maxf(_fit_zoom, 0.55), _fit_zoom, MAX_ZOOM)
		_apply(k, (size - content.size * k) * 0.5)
	else:
		_apply(zoom, content.position)


func _compute_fit() -> float:
	if content == null or size.x < 10.0 or size.y < 10.0:
		return 0.3
	return clampf(minf(size.x / content.size.x, size.y / content.size.y), 0.2, 1.0)


## Shows the whole picture, centered.
func fit() -> void:
	_fit_zoom = _compute_fit()
	var k := _fit_zoom
	_apply(k, (size - content.size * k) * 0.5)


## Zooms by `factor`, keeping the point `at` (in this view) where it is.
func zoom_at(at: Vector2, factor: float) -> void:
	var k := clampf(zoom * factor, _fit_zoom * 0.8, MAX_ZOOM)
	var world := (at - content.position) / zoom
	_apply(k, at - world * k)


## Moves the picture by `delta` pixels.
func pan(delta: Vector2) -> void:
	_apply(zoom, content.position + delta)


func _apply(k: float, pos: Vector2) -> void:
	zoom = k
	var shown := content.size * k
	# Keep some of the picture in view, and center it when it is smaller.
	var margin := 120.0
	for axis in 2:
		if shown[axis] <= size[axis]:
			pos[axis] = (size[axis] - shown[axis]) * 0.5
		else:
			pos[axis] = clampf(pos[axis], size[axis] - shown[axis] - margin, margin)
	content.scale = Vector2(k, k)
	content.position = pos


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom_at(mb.position, STEP)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom_at(mb.position, 1.0 / STEP)
			accept_event()
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			_dragging = mb.pressed
			if mb.pressed:
				accept_event()
	elif event is InputEventMouseMotion and _dragging:
		pan((event as InputEventMouseMotion).relative)
		accept_event()
