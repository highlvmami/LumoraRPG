## Entry screen with two tabs: Giriş Yap (username + password) and Kayıt Ol
## (username + password twice). "Beni hatırla" keeps the account logged in
## on this device so the next start skips this screen.
## Accounts are online (server): the same account and its game work on any
## computer. When the server can't be reached, an account already on this
## device can still play offline and signs in online once it connects.
extends CanvasLayer

const UiTheme := preload("res://scripts/ui/theme.gd")

## `remember`: log in automatically on this device next time.
signal logged_in(username: String, remember: bool)

const MIN_LEN := 3
const MAX_LEN := 16

## Saved accounts (ProfileStore).
var store: RefCounted
## Online server (NetClient); null or disabled = accounts on this device only.
var net: Node
## Waiting for the server to answer a sign-in.
var waiting := false
var _typed_password := ""
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


func setup(p_store: RefCounted, p_net: Node = null) -> void:
	store = p_store
	net = p_net
	if net:
		net.signed_in.connect(_on_signed_in)
		net.sign_in_failed.connect(_on_sign_in_failed)
		net.status_changed.connect(func(_s: String) -> void: _update_hint())
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
	if not DisplayServer.is_touchscreen_available():
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
	_error.text = ""
	_update_hint()


func _online() -> bool:
	return net != null and bool(net.get("enabled"))


func _update_hint() -> void:
	if _hint == null:
		return
	if not _online():
		_hint.text = "Hesabın bu bilgisayarda saklanır. Şifren açık hâlde kaydedilmez."
		return
	var st := str(net.status)
	if st == "connected" or st == "online":
		_hint.text = "● Sunucuya bağlı. Hesabın ve oyunun sunucuda saklanır; her bilgisayardan girebilirsin."
	else:
		_hint.text = "● Sunucuya bağlanılıyor... (sunucu uyuyorsa 1 dakika sürebilir). Bu bilgisayardaki hesabınla çevrimdışı da girebilirsin."


## Logs in or registers with what is typed. Returns an error ("" on success).
func submit_with(username: String, password: String, password2 := "") -> String:
	username = username.strip_edges()
	if waiting:
		return "Bekleniyor"
	var err := ""
	if username.length() < MIN_LEN:
		err = "Kullanıcı adı en az %d karakter olmalı." % MIN_LEN
	elif password.length() < 4:
		err = "Şifre en az 4 karakter olmalı."
	elif mode == "register" and password != password2:
		err = "Şifreler aynı değil."
	elif _online():
		return _submit_online(username, password)
	elif mode == "register":
		err = "Şifreler aynı değil." if password != password2 else str(store.call("register", username, password))
	else:
		err = str(store.call("check_login", username, password))
	_error.text = err
	if err == "":
		login(username, _remember.button_pressed)
	return err


## Signs in on the server. An account already on this device (right
## password) can play offline at once when the server can't be reached.
func _submit_online(username: String, password: String) -> String:
	var local_ok: bool = mode == "login" and store.call("has_account", username) and str(store.call("check_login", username, password)) == ""
	var local_profile: Dictionary = store.get("_data").profiles[username] if local_ok else {}
	_typed_password = password
	net.sign_in(username, password, mode == "register", local_profile)
	if not net.is_connected_to_server() and local_ok:
		_error.text = ""
		login(username, _remember.button_pressed)
		return ""
	waiting = true
	_submit_button.disabled = true
	_error.modulate = Color(0.75, 0.9, 1.3)
	_error.text = "Giriş yapılıyor..." if net.is_connected_to_server() else "Sunucu bekleniyor..."
	return "pending"


func _on_signed_in(account_name: String, token: String, profile: Dictionary, saved_at: float) -> void:
	if not waiting:
		return
	waiting = false
	store.call("adopt", account_name, profile, saved_at)
	if not store.call("has_account", account_name):
		store.call("login", account_name)
	store.call("set_password", account_name, _typed_password)
	if _remember.button_pressed:
		store.call("set_token", account_name, token)
	login(account_name, _remember.button_pressed)


func _on_sign_in_failed(_code: String, message: String) -> void:
	if not waiting:
		return
	waiting = false
	_submit_button.disabled = false
	_error.modulate = Color.WHITE
	_error.text = message


func _submit() -> void:
	submit_with(_name_edit.text, _pass_edit.text, _pass2_edit.text)


## Enters the game as `username` (also called directly by tests).
func login(username: String, remember := false) -> void:
	logged_in.emit(username, remember)
	queue_free()
