## Chest opening: a strip of items the chest can give scrolls past a marker,
## slows down and stops on the prize. The prize is decided (and already in the
## backpack) before the spin starts; the wheel only shows it.
extends CanvasLayer

const UiTheme := preload("res://scripts/ui/theme.gd")
const ItemArt := preload("res://scripts/ui/item_art.gd")
const Gear := preload("res://scripts/progression/gear.gd")

## The result panel was closed.
signal closed

const TILES := 40
const WIN_INDEX := 34
const TILE := 112.0
const GAP := 10.0
const WINDOW := Vector2(940, 150)
const SPIN_TIME := 4.5
const CLASS_NAMES := {"warrior": "Savaşçı", "archer": "Okçu", "mage": "Büyücü"}

var gear: Gear
var spinning := false
## The item won by the last spin.
var result: Dictionary = {}

var _title: Label
var _chest_art: CenterContainer
var _window: Control
var _strip: Control
var _result_box: VBoxContainer
var _result_icon: CenterContainer
var _result_name: Label
var _result_info: Label
var _tween: Tween


func setup(p_gear: Gear) -> void:
	gear = p_gear
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.theme = UiTheme.theme()
	add_child(dim)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	dim.add_child(column)

	_chest_art = CenterContainer.new()
	column.add_child(_chest_art)
	_title = UiTheme.label("", UiTheme.label_settings(38, UiTheme.ACCENT, 8))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)

	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.add_theme_stylebox_override("panel", UiTheme.box(Color(0.08, 0.1, 0.13, 0.95), 12, 8))
	column.add_child(frame)
	_window = Control.new()
	_window.custom_minimum_size = WINDOW
	_window.clip_contents = true
	frame.add_child(_window)
	_strip = Control.new()
	_window.add_child(_strip)
	# Marker in the middle of the window.
	var marker := ColorRect.new()
	marker.color = UiTheme.ACCENT
	marker.size = Vector2(4, WINDOW.y)
	marker.position = Vector2(WINDOW.x * 0.5 - 2, 0)
	_window.add_child(marker)

	_result_box = VBoxContainer.new()
	_result_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_result_box.add_theme_constant_override("separation", 6)
	_result_box.custom_minimum_size.y = 270
	column.add_child(_result_box)
	_result_icon = CenterContainer.new()
	_result_box.add_child(_result_icon)
	_result_name = UiTheme.label("", UiTheme.label_settings(32, Color.WHITE, 6))
	_result_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_box.add_child(_result_name)
	_result_info = UiTheme.label("", UiTheme.label_settings(18, UiTheme.TEXT, 4))
	_result_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_box.add_child(_result_info)
	var ok := UiTheme.primary_button("Tamam")
	ok.add_theme_font_size_override("font_size", 26)
	ok.custom_minimum_size = Vector2(220, 0)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(close)
	_result_box.add_child(ok)


## Spins a chest of `tier` that gives `prize`.
func spin(tier: int, prize: Dictionary) -> void:
	result = prize
	var chest := gear.chest(tier)
	_title.text = str(chest.name).to_upper()
	_title.label_settings = UiTheme.label_settings(38, Color(str(chest.color)), 8)
	for child in _chest_art.get_children():
		child.queue_free()
	_chest_art.add_child(ItemArt.chest(tier, Color(str(chest.color)), 110))
	for child in _strip.get_children():
		child.queue_free()
	for i in TILES:
		var it: Dictionary = prize if i == WIN_INDEX else gear.roll_item(gear.roll_weighted(chest.odds), -1)
		var tile := _tile(it)
		tile.position = Vector2(i * (TILE + GAP), (WINDOW.y - TILE) * 0.5)
		_strip.add_child(tile)
	_result_box.modulate.a = 0.0
	_result_box.visible = true
	visible = true
	spinning = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_strip.position.x = WINDOW.x * 0.5 - TILE * 0.5
	var stop := WINDOW.x * 0.5 - (WIN_INDEX * (TILE + GAP) + TILE * 0.5) + randf_range(-TILE * 0.35, TILE * 0.35)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_strip, "position:x", stop, SPIN_TIME).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_show_result)


## Skips the rest of the animation.
func finish() -> void:
	if not spinning:
		return
	if _tween:
		_tween.kill()
	_strip.position.x = WINDOW.x * 0.5 - (WIN_INDEX * (TILE + GAP) + TILE * 0.5)
	_show_result()


func close() -> void:
	finish()
	visible = false
	closed.emit()


func _show_result() -> void:
	spinning = false
	var color := gear.rarity_color(int(result.rarity))
	for child in _result_icon.get_children():
		child.queue_free()
	_result_icon.add_child(ItemArt.make(result, color, gear.tier(int(result.rarity)), 120))
	_result_name.text = gear.item_name(result)
	_result_name.label_settings = UiTheme.label_settings(32, color, 6)
	var cls := gear.item_class(result)
	_result_info.text = "%s  ·  %s%s\n%s" % [
		gear.rarity(int(result.rarity)).name,
		gear.slot_name(gear.item_slot(result)),
		"" if cls == "" else "  ·  " + str(CLASS_NAMES.get(cls, cls)),
		"   ".join(gear.stat_lines(result)),
	]
	var tween := create_tween()
	tween.tween_property(_result_box, "modulate:a", 1.0, 0.3)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
		if spinning:
			finish()
		else:
			close()
		get_viewport().set_input_as_handled()


func _tile(it: Dictionary) -> Control:
	var color := gear.rarity_color(int(it.rarity))
	var tile := PanelContainer.new()
	tile.size = Vector2(TILE, TILE)
	tile.custom_minimum_size = Vector2(TILE, TILE)
	var style := UiTheme.box(color.darkened(0.7), 8, 6)
	style.set_border_width_all(3)
	style.border_color = color
	style.border_width_bottom = 8
	tile.add_theme_stylebox_override("panel", style)
	tile.add_child(ItemArt.make(it, color, gear.tier(int(it.rarity)), TILE - 16))
	return tile
