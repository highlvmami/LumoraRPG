## What shows on screen in the hub tavern: the title and keys on top, the
## prompt for the thing in reach, how many are inside, and the chat (last
## lines, plus a text box that opens with Enter).
extends CanvasLayer

const UiTheme := preload("res://scripts/ui/theme.gd")

## The player sent this chat line.
signal chat_submitted(text: String)
## The chat box closed (sent or cancelled).
signal chat_closed

## The player picked "leave" in the leave question.
signal leave_confirmed
## The leave question closed without leaving.
signal leave_cancelled
## The notice panel (rankings) was closed.
signal panel_closed

## The player picked a game (dice or cards) with a guest: name, kind, bet.
signal game_challenge(target: String, kind: String, bet: int)
## The player answered a game invitation.
signal game_answered(from_name: String, accept: bool)

const MAX_LINES := 8

var _root: Control
var _count: Label
var _prompt: Label
var _log: RichTextLabel
var _edit: LineEdit
var _hint: Label
var _lines := 0
var _leave_box: Control
var _run_label: Label
var _panel: Control
var _panel_text: Label
var _games_box: PanelContainer
var _games_list: VBoxContainer
var _bet: SpinBox
var _invite_box: PanelContainer
var _invite_label: Label
var _invite_from := ""
var _invite_yes: Button


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
	_hint = UiTheme.label("WASD yürü · Boşluk zıpla · E kullan · G zar/kart · Enter yaz · Esc çık", UiTheme.label_settings(14, UiTheme.MUTED, 3))
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

	_leave_box = PanelContainer.new()
	_leave_box.add_theme_stylebox_override("panel", UiTheme.box(Color(0.05, 0.06, 0.09, 0.94), 12, 22))
	_leave_box.set_anchors_preset(Control.PRESET_CENTER)
	_leave_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_leave_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_leave_box.visible = false
	var ask := VBoxContainer.new()
	ask.add_theme_constant_override("separation", 14)
	_leave_box.add_child(ask)
	var ask_text := UiTheme.label("Tavernadan çıkmak istiyor musun?", UiTheme.label_settings(22, UiTheme.TEXT, 5))
	ask_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ask.add_child(ask_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	ask.add_child(row)
	var yes := Button.new()
	yes.text = "Evet, çık"
	yes.pressed.connect(func() -> void: leave_confirmed.emit())
	row.add_child(yes)
	var no := Button.new()
	no.text = "Kal"
	no.pressed.connect(close_leave)
	row.add_child(no)
	_root.add_child(_leave_box)

	_run_label = UiTheme.label("", UiTheme.label_settings(24, Color("#ffe27a"), 6))
	_run_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_run_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_run_label.offset_top = 14
	_run_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_run_label)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiTheme.box(Color(0.05, 0.06, 0.09, 0.95), 12, 24))
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.visible = false
	var panel_col := VBoxContainer.new()
	panel_col.add_theme_constant_override("separation", 12)
	_panel.add_child(panel_col)
	_panel_text = UiTheme.label("", UiTheme.label_settings(18, UiTheme.TEXT, 4))
	panel_col.add_child(_panel_text)
	var close := Button.new()
	close.text = "Kapat"
	close.pressed.connect(close_panel)
	panel_col.add_child(close)
	_root.add_child(_panel)
	_build_games_box()
	_build_invite_box()


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


## The parkour clock line on top ("" hides it).
func set_run(text: String) -> void:
	_run_label.text = text


func is_panel_open() -> bool:
	return _panel.visible


func show_panel(text: String) -> void:
	_panel_text.text = text
	_panel.visible = true


func close_panel() -> void:
	if _panel.visible:
		_panel.visible = false
		panel_closed.emit()


func is_asking_leave() -> bool:
	return _leave_box.visible


func ask_leave() -> void:
	_leave_box.visible = true


func close_leave() -> void:
	if _leave_box.visible:
		_leave_box.visible = false
		leave_cancelled.emit()


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


# --- Dice and card games --------------------------------------------------------

func _build_games_box() -> void:
	_games_box = PanelContainer.new()
	_games_box.add_theme_stylebox_override("panel", UiTheme.box(Color(0.05, 0.06, 0.09, 0.95), 12, 22))
	_games_box.set_anchors_preset(Control.PRESET_CENTER)
	_games_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_games_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_games_box.visible = false
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size.x = 380
	_games_box.add_child(col)
	var title := UiTheme.label("Zar ve Kart", UiTheme.label_settings(26, UiTheme.ACCENT, 6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var info := UiTheme.label("Yakındaki biriyle bahse gir: ikiniz de kabul ederseniz zarlar ya da kartlar masada atılır, yüksek gelen kazanır.", UiTheme.label_settings(14, UiTheme.MUTED, 3))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(info)
	var bet_row := HBoxContainer.new()
	bet_row.add_theme_constant_override("separation", 10)
	bet_row.add_child(UiTheme.label("Bahis:", UiTheme.label_settings(17, UiTheme.TEXT, 3)))
	_bet = SpinBox.new()
	_bet.min_value = 10
	_bet.max_value = 5000
	_bet.step = 10
	_bet.value = 100
	bet_row.add_child(_bet)
	col.add_child(bet_row)
	_games_list = VBoxContainer.new()
	_games_list.add_theme_constant_override("separation", 6)
	col.add_child(_games_list)
	var close := Button.new()
	close.text = "Kapat"
	close.pressed.connect(close_games)
	col.add_child(close)
	_root.add_child(_games_box)


func _build_invite_box() -> void:
	_invite_box = PanelContainer.new()
	_invite_box.add_theme_stylebox_override("panel", UiTheme.box(Color(0.12, 0.09, 0.03, 0.94), 12, 14))
	_invite_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_invite_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_invite_box.offset_top = 62
	_invite_box.visible = false
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_invite_box.add_child(col)
	_invite_label = UiTheme.label("", UiTheme.label_settings(19, Color("#ffe27a"), 5))
	_invite_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_invite_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	_invite_yes = UiTheme.primary_button("Kabul (Y)")
	_invite_yes.pressed.connect(answer_invite.bind(true))
	row.add_child(_invite_yes)
	var no := Button.new()
	no.text = "Reddet (N)"
	no.pressed.connect(answer_invite.bind(false))
	row.add_child(no)
	_root.add_child(_invite_box)


## Opens the game panel with the `names` of the guests in reach.
func open_games(names: Array, gold: int) -> void:
	for c in _games_list.get_children():
		_games_list.remove_child(c)
		c.queue_free()
	_bet.max_value = maxi(10, mini(5000, gold))
	_bet.value = clampf(_bet.value, 10.0, _bet.max_value)
	if names.is_empty():
		_games_list.add_child(UiTheme.label("Yakında kimse yok. Birinin yanına git (en fazla 6 adım).", UiTheme.label_settings(16, Color("#ff8a8a"), 3)))
	for n: String in names:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var who := UiTheme.label(n, UiTheme.label_settings(18, UiTheme.TEXT, 3))
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(who)
		for kind: Array in [["dice", "Zar at"], ["cards", "Kart çek"]]:
			var b := Button.new()
			b.text = str(kind[1])
			b.disabled = gold < 10
			b.pressed.connect(func() -> void:
				game_challenge.emit(n, str(kind[0]), int(_bet.value))
				close_games())
			row.add_child(b)
		_games_list.add_child(row)
	_games_box.visible = true


func is_games_open() -> bool:
	return _games_box.visible


func close_games() -> void:
	if _games_box.visible:
		_games_box.visible = false
		panel_closed.emit()


## A game invitation on top of the screen (answered with Y / N or the buttons).
func show_invite(from_name: String, kind: String, bet: int, can_pay: bool) -> void:
	_invite_from = from_name
	_invite_label.text = "%s seni %s oyununa çağırıyor: %d altın" % [from_name, "zar" if kind == "dice" else "kart", bet]
	_invite_yes.disabled = not can_pay
	_invite_box.visible = true


func hide_invite() -> void:
	_invite_box.visible = false
	_invite_from = ""


func has_invite() -> bool:
	return _invite_box.visible


func answer_invite(accept: bool) -> void:
	if not _invite_box.visible:
		return
	var from_name := _invite_from
	hide_invite()
	game_answered.emit(from_name, accept)
