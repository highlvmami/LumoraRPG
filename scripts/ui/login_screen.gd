## Entry screen with two tabs: Giriş Yap (username + password) and Kayıt Ol
## (username + password twice). "Beni hatırla" keeps the account logged in
## on this device so the next start skips this screen.
## Accounts are stored on this device for now; online accounts come later.
extends CanvasLayer

const UiTheme := preload("res://scripts/ui/theme.gd")

## `remember`: log in automatically on this device next time.
signal logged_in(username: String, remember: bool)

const MIN_LEN := 3
const MAX_LEN := 16

## Saved accounts (ProfileStore).
var store: RefCounted
var mode := "login"

var _tabs := {}
var _name_edit: LineEdit
var _pass_edit: LineEdit
var _pass2_edit: LineEdit
var _pass2_label: Label
var _remember: CheckBox
var _submit_button: Button
var _error: Label
var _hint: Label


func setup(p_store: RefCounted) -> void:
	store = p_store
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
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(400, 0)
	panel.add_child(box)

	var title := UiTheme.label("LUMORA", UiTheme.label_settings(64, UiTheme.ACCENT, 10))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	box.add_child(tabs)
	for entry: Array in [["login", "Giriş Yap"], ["register", "Kayıt Ol"]]:
		var tab := Button.new()
		tab.text = str(entry[1])
		tab.toggle_mode = true
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", 20)
		tab.pressed.connect(set_mode.bind(str(entry[0])))
		tabs.add_child(tab)
		_tabs[entry[0]] = tab

	box.add_child(UiTheme.label("Kullanıcı adı", UiTheme.label_settings(18, UiTheme.MUTED, 0)))
	_name_edit = LineEdit.new()
	_name_edit.text = store.call("last_name") if store else ""
	_name_edit.placeholder_text = "örn. mami"
	_name_edit.max_length = MAX_LEN
	_name_edit.text_submitted.connect(func(_t: String) -> void: _pass_edit.grab_focus())
	box.add_child(_name_edit)

	box.add_child(UiTheme.label("Şifre", UiTheme.label_settings(18, UiTheme.MUTED, 0)))
	_pass_edit = _password_field()
	box.add_child(_pass_edit)
	_pass2_label = UiTheme.label("Şifre (tekrar)", UiTheme.label_settings(18, UiTheme.MUTED, 0))
	box.add_child(_pass2_label)
	_pass2_edit = _password_field()
	box.add_child(_pass2_edit)

	_remember = CheckBox.new()
	_remember.text = "Beni hatırla (bu bilgisayarda bir daha sorma)"
	_remember.button_pressed = true
	_remember.add_theme_font_size_override("font_size", 16)
	box.add_child(_remember)

	_submit_button = UiTheme.primary_button("Giriş Yap")
	_submit_button.add_theme_font_size_override("font_size", 26)
	_submit_button.pressed.connect(_submit)
	box.add_child(_submit_button)

	_error = UiTheme.label("", UiTheme.label_settings(17, Color("#ff8a8a"), 0))
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_error)

	_hint = UiTheme.label("", UiTheme.label_settings(15, UiTheme.MUTED, 0))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_hint)

	set_mode("login" if _name_edit.text != "" else "register")
	_name_edit.grab_focus.call_deferred()


func _password_field() -> LineEdit:
	var edit := LineEdit.new()
	edit.secret = true
	edit.max_length = 32
	edit.placeholder_text = "en az 4 karakter"
	edit.text_submitted.connect(func(_t: String) -> void: _submit())
	return edit


func set_mode(id: String) -> void:
	mode = id
	for key: String in _tabs:
		(_tabs[key] as Button).button_pressed = key == id
	var registering := id == "register"
	_pass2_label.visible = registering
	_pass2_edit.visible = registering
	_submit_button.text = "Kayıt Ol" if registering else "Giriş Yap"
	_hint.text = "Hesabın bu bilgisayarda saklanır. Şifren açık hâlde kaydedilmez." if registering \
		else "Şifresi olmayan eski bir hesapsa, ilk girişte yazdığın şifre kaydedilir."
	_error.text = ""


## Logs in or registers with what is typed. Returns an error ("" on success).
func submit_with(username: String, password: String, password2 := "") -> String:
	username = username.strip_edges()
	var err := ""
	if username.length() < MIN_LEN:
		err = "Kullanıcı adı en az %d karakter olmalı." % MIN_LEN
	elif mode == "register":
		err = "Şifreler aynı değil." if password != password2 else str(store.call("register", username, password))
	else:
		err = str(store.call("check_login", username, password))
	_error.text = err
	if err == "":
		login(username, _remember.button_pressed)
	return err


func _submit() -> void:
	submit_with(_name_edit.text, _pass_edit.text, _pass2_edit.text)


## Enters the game as `username` (also called directly by tests).
func login(username: String, remember := false) -> void:
	logged_in.emit(username, remember)
	queue_free()
