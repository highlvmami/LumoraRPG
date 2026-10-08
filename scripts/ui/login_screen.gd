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
	backdrop.color = Color(0.04, 0.06, 0.08, 0.6)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.custom_minimum_size = Vector2(160, 0)
	center.add_child(box)

	var title := UiTheme.label("LUMORA", UiTheme.label_settings(32, Color("#ffd866"), 6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var prompt := UiTheme.label("Kullanıcı adı", UiTheme.label_settings(10))
	box.add_child(prompt)

	_name_edit = LineEdit.new()
	_name_edit.text = last_name
	_name_edit.placeholder_text = "örn. mami"
	_name_edit.max_length = MAX_LEN
	_name_edit.add_theme_font_size_override("font_size", 10)
	_name_edit.text_submitted.connect(func(_t: String) -> void: _submit())
	box.add_child(_name_edit)

	var button := Button.new()
	button.text = "Giriş Yap"
	button.add_theme_font_size_override("font_size", 10)
	button.pressed.connect(_submit)
	box.add_child(button)

	_error = UiTheme.label("", UiTheme.label_settings(8, Color("#ff7b7b"), 2))
	box.add_child(_error)

	var note := UiTheme.label("Hesabın bu cihazda saklanır.", UiTheme.label_settings(8, Color("#c0c8d0"), 2))
	box.add_child(note)

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
