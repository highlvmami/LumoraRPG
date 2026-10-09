## What shows on screen in the hub tavern: the title and keys on top, the
## prompt for the thing in reach, how many are inside, and the chat (last
## lines, plus a text box that opens with Enter).
extends CanvasLayer

const UiTheme := preload("res://scripts/ui/theme.gd")

## The player sent this chat line.
signal chat_submitted(text: String)
## The chat box closed (sent or cancelled).
signal chat_closed

const MAX_LINES := 8

var _root: Control
var _count: Label
var _prompt: Label
var _log: RichTextLabel
var _edit: LineEdit
var _hint: Label
var _lines := 0


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.theme()
	add_child(_root)

	var top := VBoxContainer.new()
	top.position = Vector2(24, 18)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 0)
	title.add_child(UiTheme.label("LUMORA ", UiTheme.label_settings(26, UiTheme.ACCENT, 6)))
	title.add_child(UiTheme.label("TAVERNASI", UiTheme.label_settings(26, Color("#ff9a4a"), 6)))
	top.add_child(title)
	_count = UiTheme.label("", UiTheme.label_settings(16, UiTheme.TEXT, 4))
	top.add_child(_count)
	_hint = UiTheme.label("WASD yürü · Boşluk zıpla · E kullan · Enter yaz · Esc çık", UiTheme.label_settings(14, UiTheme.MUTED, 3))
	top.add_child(_hint)

	_prompt = UiTheme.label("", UiTheme.label_settings(22, UiTheme.ACCENT, 6))
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.offset_top = -190
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_prompt)

	var chat := VBoxContainer.new()
	chat.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	chat.grow_vertical = Control.GROW_DIRECTION_BEGIN
	chat.offset_left = 24
	chat.offset_bottom = -22
	chat.custom_minimum_size = Vector2(440, 0)
	chat.add_theme_constant_override("separation", 6)
	chat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(chat)
	var back := PanelContainer.new()
	var style := UiTheme.box(Color(0.04, 0.05, 0.07, 0.55), 8, 8)
	back.add_theme_stylebox_override("panel", style)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat.add_child(back)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_active = false
	_log.fit_content = true
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.add_theme_font_size_override("normal_font_size", 15)
	_log.add_theme_constant_override("outline_size", 3)
	_log.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	back.add_child(_log)
	_edit = LineEdit.new()
	_edit.max_length = 200
	_edit.placeholder_text = "Tavernadakilere bir şey yaz... (Enter gönder, Esc vazgeç)"
	_edit.visible = false
	_edit.text_submitted.connect(_on_submitted)
	_edit.gui_input.connect(_on_edit_input)
	chat.add_child(_edit)
	back.visible = false
	_log.set_meta("back", back)


func set_count(n: int) -> void:
	_count.text = "Tavernada %d kişi" % n


## What E does right now ("" hides the line).
func set_prompt(text: String) -> void:
	_prompt.text = ("E · " + text) if text != "" else ""


## Shows a line of chat; older lines scroll away.
func add_line(from_name: String, text: String, mine := false) -> void:
	var color := "#ffd23f" if mine else "#8fe3ff"
	_log.append_text("[color=%s]%s:[/color] %s\n" % [color, from_name.replace("[", "[lb]"), text.replace("[", "[lb]")])
	_lines += 1
	if _lines > MAX_LINES:
		# Drop the oldest line.
		var all := _log.get_parsed_text().split("\n", false)
		_lines = MAX_LINES
		_log.clear()
		for i in range(all.size() - MAX_LINES, all.size()):
			_log.append_text(all[i].replace("[", "[lb]") + "\n")
	(_log.get_meta("back") as Control).visible = true


## A line in a different colour for things the tavern says itself.
func add_note(text: String) -> void:
	_log.append_text("[color=#b8c2cc][i]%s[/i][/color]\n" % text.replace("[", "[lb]"))
	_lines += 1
	(_log.get_meta("back") as Control).visible = true


func is_typing() -> bool:
	return _edit.visible


func open_chat() -> void:
	_edit.visible = true
	_edit.text = ""
	_edit.grab_focus()


func close_chat() -> void:
	if not _edit.visible:
		return
	_edit.visible = false
	_edit.release_focus()
	chat_closed.emit()


func _on_submitted(text: String) -> void:
	if text.strip_edges() != "":
		chat_submitted.emit(text)
	close_chat()


func _on_edit_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		_edit.accept_event()
		close_chat()
