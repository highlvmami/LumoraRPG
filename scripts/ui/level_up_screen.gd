## Level-up choice: a row of cards at the bottom of the screen (stat boosts,
## new weapons or weapon upgrades). The game keeps running; pick any time with
## 1/2/3 or by clicking a card. Several level-ups wait in line ("+2 seçim").
## The game decides what is offered (`roll`) and what picking does (`apply`);
## a choice is a dictionary with id, type ("boost" or "weapon"), def (the data
## entry), now and max (levels).
extends CanvasLayer

const UiTheme := preload("res://scripts/ui/theme.gd")
const PixelIcons := preload("res://scripts/ui/pixel_icons.gd")

## Emitted after a choice is applied.
signal chosen(id: String)
## Emitted when the last waiting choice is made and the cards go away.
signal closed

var roll: Callable
var apply: Callable
var pending := 0

var _choices: Array = []
var _title: Label
var _cards: HBoxContainer
var _level := 0


func setup(p_roll: Callable, p_apply: Callable) -> void:
	roll = p_roll
	apply = p_apply
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.theme()
	add_child(root)

	var panel := PanelContainer.new()
	var style := UiTheme.box(Color(0.05, 0.07, 0.1, 0.82), 12, 10)
	style.set_border_width_all(2)
	style.border_color = UiTheme.ACCENT.darkened(0.3)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 104)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	_title = UiTheme.label("", UiTheme.label_settings(18, UiTheme.ACCENT, 4))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_cards = HBoxContainer.new()
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", 10)
	column.add_child(_cards)


## Called on every character level-up.
func queue_level_up(level: int) -> void:
	pending += 1
	_level = level
	if not visible:
		_open()
	else:
		_update_title()


func pick(index: int) -> void:
	if not visible or index < 0 or index >= _choices.size():
		return
	var choice: Dictionary = _choices[index]
	apply.call(choice)
	pending -= 1
	chosen.emit(str(choice.id))
	if pending > 0:
		_open()
	else:
		close()


## Hides the cards (also used when a run ends or restarts).
func close() -> void:
	var was_open := visible
	pending = 0
	visible = false
	if was_open:
		closed.emit()


func _open() -> void:
	_choices = roll.call()
	if _choices.is_empty():
		# Everything is maxed out; nothing to choose.
		pending = 0
		visible = false
		return
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for i in _choices.size():
		_cards.add_child(_card(_choices[i], i))
	_update_title()
	visible = true


func _update_title() -> void:
	_title.text = "SEVİYE %d!  Seçmek için %s" % [_level, " · ".join(range(1, _choices.size() + 1).map(func(n: int) -> String: return str(n)))]
	if pending > 1:
		_title.text += "   (+%d seçim daha)" % (pending - 1)


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if not visible or get_tree().paused or key_event == null or not key_event.pressed or key_event.echo:
		return
	var key := key_event.physical_keycode
	if key >= KEY_1 and key <= KEY_3:
		pick(key - KEY_1)
		get_viewport().set_input_as_handled()


func _card(choice: Dictionary, index: int) -> Button:
	var d: Dictionary = choice.def
	var now := int(choice.now)
	var is_weapon: bool = choice.type == "weapon"
	var color := Color(str(d.color))
	var card := Button.new()
	card.custom_minimum_size = Vector2(270, 84)
	card.focus_mode = Control.FOCUS_NONE
	for state: String in ["normal", "hover", "pressed"]:
		var style := UiTheme.box(Color(0.1, 0.13, 0.17, 0.95) if state == "normal" else Color(0.15, 0.19, 0.25, 0.97), 10, 8)
		style.set_border_width_all(3 if state == "hover" else 2)
		style.border_color = color if state != "normal" else color.darkened(0.3)
		card.add_theme_stylebox_override(state, style)
	card.pressed.connect(pick.bind(index))

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	# Pixel icon on a tinted tile, with the hotkey in the corner.
	var icon := PanelContainer.new()
	icon.add_theme_stylebox_override("panel", UiTheme.box(color.darkened(0.55), 8, 4))
	icon.custom_minimum_size = Vector2(60, 60)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_child(PixelIcons.rect(str(d.get("icon", "")), 52))
	var key := UiTheme.label(str(index + 1), UiTheme.label_settings(14, Color.WHITE, 4))
	key.size_flags_horizontal = Control.SIZE_SHRINK_END
	key.size_flags_vertical = Control.SIZE_SHRINK_END
	icon.add_child(key)
	row.add_child(icon)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var tag := "YENİ SİLAH" if is_weapon and now == 0 else ("SİLAH" if is_weapon else "GÜÇLENDİRME")
	if d.has("class") and not d.get("starter", false):
		tag = "SINIFA ÖZEL"
	text.add_child(UiTheme.label("%s  ·  Sv. %d" % [tag, now + 1], UiTheme.label_settings(11, UiTheme.ACCENT if is_weapon else UiTheme.MUTED, 3)))
	text.add_child(UiTheme.label(str(d.name), UiTheme.label_settings(18, color.lightened(0.25), 4)))
	var desc := UiTheme.label(str(d.upgrade) if is_weapon and now > 0 else str(d.desc), UiTheme.label_settings(12, UiTheme.TEXT, 3))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 160
	text.add_child(desc)
	return card
