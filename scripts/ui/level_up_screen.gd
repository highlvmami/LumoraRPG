## Level-up choice: the game pauses and a few random boosts are offered as cards.
## Click a card or press 1/2/3. Several level-ups in a row open it again.
extends CanvasLayer

const UiTheme := preload("res://scripts/ui/theme.gd")
const RunBoosts := preload("res://scripts/progression/run_boosts.gd")
const PixelIcons := preload("res://scripts/ui/pixel_icons.gd")

## Emitted after a boost is added, so stats can be recalculated.
signal chosen(id: String)
## Emitted when the last pending choice is made and the game resumes.
signal closed

var boosts: RunBoosts
var pending := 0

var _choices: Array = []
var _title: Label
var _cards: HBoxContainer


func setup(p_boosts: RunBoosts) -> void:
	boosts = p_boosts
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.theme = UiTheme.theme()
	add_child(dim)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	dim.add_child(column)

	_title = UiTheme.label("", UiTheme.label_settings(46, UiTheme.ACCENT, 10))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	var sub := UiTheme.label("Bir güçlendirme seç  (1 · 2 · 3)", UiTheme.label_settings(22, UiTheme.MUTED, 5))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(sub)

	_cards = HBoxContainer.new()
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", 24)
	column.add_child(_cards)


## Called on every character level-up.
func queue_level_up(level: int) -> void:
	pending += 1
	_title.text = "SEVİYE %d!" % level
	if not visible:
		_open()


func pick(index: int) -> void:
	if not visible or index < 0 or index >= _choices.size():
		return
	var id: String = _choices[index].id
	boosts.add(id)
	pending -= 1
	chosen.emit(id)
	if pending > 0:
		_open()
	else:
		close()


## Hides the screen and resumes the game (also used when a run is reset).
func close() -> void:
	var was_open := visible
	pending = 0
	visible = false
	get_tree().paused = false
	if was_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		closed.emit()


func _open() -> void:
	_choices = boosts.roll_choices()
	if _choices.is_empty():
		# Everything is maxed out; nothing to choose.
		pending = 0
		return
	for child in _cards.get_children():
		child.queue_free()
	for i in _choices.size():
		_cards.add_child(_card(_choices[i], i))
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if not visible or key_event == null or not key_event.pressed or key_event.echo:
		return
	var key := key_event.physical_keycode
	if key >= KEY_1 and key <= KEY_3:
		pick(key - KEY_1)
		get_viewport().set_input_as_handled()


func _card(d: Dictionary, index: int) -> Button:
	var color := Color(str(d.color))
	var card := Button.new()
	card.custom_minimum_size = Vector2(250, 300)
	for state: String in ["normal", "hover", "pressed"]:
		var style := UiTheme.box(UiTheme.PANEL if state == "normal" else Color(0.14, 0.18, 0.23, 0.97), 14, 16)
		style.set_border_width_all(4 if state == "hover" else 3)
		style.border_color = color if state != "normal" else color.darkened(0.35)
		card.add_theme_stylebox_override(state, style)
	card.pressed.connect(pick.bind(index))

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)

	# Pixel icon on a tinted tile, with the hotkey in the corner.
	var icon := PanelContainer.new()
	icon.add_theme_stylebox_override("panel", UiTheme.box(color.darkened(0.55), 12, 8))
	icon.custom_minimum_size = Vector2(104, 104)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_child(PixelIcons.rect(str(d.get("icon", "")), 88))
	var key := UiTheme.label(str(index + 1), UiTheme.label_settings(18, Color.WHITE, 5))
	key.size_flags_horizontal = Control.SIZE_SHRINK_END
	key.size_flags_vertical = Control.SIZE_SHRINK_END
	icon.add_child(key)
	box.add_child(icon)

	box.add_child(_centered(str(d.name), UiTheme.label_settings(28, color.lightened(0.25), 6)))
	box.add_child(_centered(str(d.desc), UiTheme.label_settings(22)))
	var now := boosts.count(d.id)
	box.add_child(_centered("Seviye %d → %d  (en fazla %d)" % [now, now + 1, int(d.maxStacks)], UiTheme.label_settings(16, UiTheme.MUTED, 4)))
	return card


func _centered(text: String, settings: LabelSettings) -> Label:
	var label := UiTheme.label(text, settings)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 210
	return label
