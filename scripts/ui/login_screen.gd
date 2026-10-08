## Entry screen: pick a username to log in (a new name creates a new account).
## Accounts are stored on this device for now; online accounts come later.
extends CanvasLayer

const UiTheme := preload("res://scripts/ui/theme.gd")

signal logged_in(username: String)

const MIN_LEN := 3
const MAX_LEN := 16

var _name_edit: LineEdit
var _error: Label


func setup(last_name: String) -> void:
	layer = 10
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.03, 0.05, 0.07, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.theme = UiTheme.theme()
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(380, 0)
	panel.add_child(box)

	var title := UiTheme.label("LUMORA", UiTheme.label_settings(64, UiTheme.ACCENT, 10))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	box.add_child(UiTheme.label("Kullanıcı adı", UiTheme.label_settings(22, UiTheme.MUTED, 0)))

	_name_edit = LineEdit.new()
	_name_edit.text = last_name
	_name_edit.placeholder_text = "örn. mami"
	_name_edit.max_length = MAX_LEN
	_name_edit.text_submitted.connect(func(_t: String) -> void: _submit())
	box.add_child(_name_edit)

	var button := UiTheme.primary_button("Giriş Yap")
	button.add_theme_font_size_override("font_size", 26)
	button.pressed.connect(_submit)
	box.add_child(button)

	_error = UiTheme.label("", UiTheme.label_settings(18, Color("#ff8a8a"), 0))
	box.add_child(_error)

	box.add_child(UiTheme.label("Yeni bir ad yazarsan yeni hesap açılır. Hesabın bu cihazda saklanır.", UiTheme.label_settings(16, UiTheme.MUTED, 0)))
	(box.get_child(box.get_child_count() - 1) as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_name_edit.grab_focus.call_deferred()


func _submit() -> void:
	var username := _name_edit.text.strip_edges()
	if username.length() < MIN_LEN:
		_error.text = "En az %d karakter olmalı." % MIN_LEN
		return
	login(username)


## Also called directly by tests.
func login(username: String) -> void:
	logged_in.emit(username)
	queue_free()
