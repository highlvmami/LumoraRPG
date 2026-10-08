## Main menu after login: account level, Play, and the Friends / Backpack / Market sections.
extends CanvasLayer

const UiTheme := preload("res://scripts/ui/theme.gd")
const Progression := preload("res://scripts/progression/progression.gd")
const Shop := preload("res://scripts/progression/shop.gd")

signal play_pressed

const BACKPACK_SLOTS := 18
const MAX_FRIENDS := 50

var progression: Progression
var shop: Shop
var section := "profile"

var _root: Control
var _account_label: Label
var _account_bar: ProgressBar
var _gold_label: Label
var _content: VBoxContainer
var _section_title: Label
var _tab_buttons := {}


func setup(p_progression: Progression, p_shop: Shop) -> void:
	progression = p_progression
	shop = p_shop
	layer = 5

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiTheme.theme()
	add_child(_root)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.06, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	_root.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 24)
	margin.add_child(layout)

	layout.add_child(_build_top_bar())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 28)
	layout.add_child(body)
	body.add_child(_build_nav())

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(panel)
	var panel_box := VBoxContainer.new()
	panel_box.add_theme_constant_override("separation", 14)
	panel.add_child(panel_box)
	_section_title = UiTheme.label("", UiTheme.label_settings(30, UiTheme.ACCENT, 0))
	panel_box.add_child(_section_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_box.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_content)

	open_section("profile")


func show_menu() -> void:
	visible = true
	refresh()


func refresh() -> void:
	_account_label.text = "%s   ·   Hesap Seviyesi %d" % [progression.profile.name, progression.account_level()]
	_account_bar.max_value = progression.exp_to_next_account_level()
	_account_bar.value = progression.account_exp()
	_account_bar.tooltip_text = "%d / %d EXP" % [progression.account_exp(), progression.exp_to_next_account_level()]
	_gold_label.text = "Altın: %d" % progression.gold()
	open_section(section)


func open_section(id: String) -> void:
	section = id
	for key: String in _tab_buttons:
		(_tab_buttons[key] as Button).button_pressed = key == id
	for child in _content.get_children():
		child.queue_free()
	match id:
		"friends":
			_section_title.text = "Arkadaşlar"
			_build_friends()
		"backpack":
			_section_title.text = "Çanta"
			_build_backpack()
		"market":
			_section_title.text = "Market"
			_build_market()
		_:
			_section_title.text = "Profil"
			_build_profile()


## Buys an item from the market (also used by tests). Returns true on success.
func buy(id: String) -> bool:
	var ok := shop.buy(id)
	refresh()
	return ok


func add_friend(friend_name: String) -> bool:
	friend_name = friend_name.strip_edges()
	var friends: Array = progression.profile.friends
	if friend_name.length() < 3 or friend_name == progression.profile.name or friends.has(friend_name) or friends.size() >= MAX_FRIENDS:
		return false
	friends.append(friend_name)
	progression.store.save_to_disk()
	refresh()
	return true


func _remove_friend(friend_name: String) -> void:
	(progression.profile.friends as Array).erase(friend_name)
	progression.store.save_to_disk()
	refresh()


func _build_top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 20)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(left)
	left.add_child(UiTheme.label("LUMORA", UiTheme.label_settings(48, UiTheme.ACCENT, 10)))
	_account_label = UiTheme.label("", UiTheme.label_settings(24))
	left.add_child(_account_label)
	_account_bar = _bar(Color("#5fb8ff"), Vector2(360, 12))
	_account_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	left.add_child(_account_bar)
	_gold_label = UiTheme.label("", UiTheme.label_settings(28, UiTheme.ACCENT))
	_gold_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	bar.add_child(_gold_label)
	return bar


func _build_nav() -> Control:
	var nav := VBoxContainer.new()
	nav.custom_minimum_size = Vector2(300, 0)
	nav.add_theme_constant_override("separation", 14)
	var play := UiTheme.primary_button("OYNA")
	play.custom_minimum_size = Vector2(0, 84)
	play.pressed.connect(func() -> void: play_pressed.emit())
	nav.add_child(play)
	for entry: Array in [["profile", "Profil"], ["friends", "Arkadaşlar"], ["backpack", "Çanta"], ["market", "Market"]]:
		var button := Button.new()
		button.text = entry[1]
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 56)
		button.add_theme_font_size_override("font_size", 26)
		button.add_theme_stylebox_override("hover_pressed", UiTheme.box(UiTheme.BUTTON_HOVER, 8, 10))
		button.add_theme_stylebox_override("pressed", UiTheme.box(Color("#4a6380"), 8, 10))
		var id: String = entry[0]
		button.pressed.connect(func() -> void: open_section(id))
		_tab_buttons[id] = button
		nav.add_child(button)
	return nav


func _build_profile() -> void:
	var p := progression.profile
	_text("Hesap seviyesi: %d" % progression.account_level(), 26)
	_text("En yüksek karakter seviyesi: %d" % int(p.get("bestLevel", 0)), 22)
	_text("Toplam kesilen canavar: %d" % int(p.get("totalKills", 0)), 22)
	_text("Oynanan oyun: %d" % int(p.get("runs", 0)), 22)
	_text("Çantadaki eşya: %d" % (p.items as Array).size(), 22)
	_text("Canavar kesince EXP ve altın kazanırsın. Altınla Market'ten eşya al; eşyalar her oyunda seni güçlendirir.", 18, UiTheme.MUTED)


func _build_friends() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var edit := LineEdit.new()
	edit.placeholder_text = "Kullanıcı adı"
	edit.max_length = 16
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	var add := Button.new()
	add.text = "Ekle"
	add.pressed.connect(func() -> void: add_friend(edit.text))
	edit.text_submitted.connect(func(t: String) -> void: add_friend(t))
	row.add_child(add)
	_content.add_child(row)

	var friends: Array = progression.profile.friends
	if friends.is_empty():
		_text("Henüz arkadaşın yok. Kullanıcı adını yazıp ekleyebilirsin.", 20, UiTheme.MUTED)
	for friend: String in friends:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		var dot := ColorRect.new()
		dot.color = Color("#6b7280")
		dot.custom_minimum_size = Vector2(14, 14)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(dot)
		var name_label := UiTheme.label(friend, UiTheme.label_settings(24, UiTheme.TEXT, 0))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		line.add_child(UiTheme.label("çevrimdışı", UiTheme.label_settings(18, UiTheme.MUTED, 0)))
		var remove := Button.new()
		remove.text = "Sil"
		remove.pressed.connect(_remove_friend.bind(friend))
		line.add_child(remove)
		_content.add_child(line)
	_text("Arkadaşlarının çevrimiçi durumu ve birlikte oynama, çevrimiçi hesaplar gelince açılacak.", 16, UiTheme.MUTED)


func _build_backpack() -> void:
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_content.add_child(grid)
	var owned: Array = progression.profile.items
	for i in BACKPACK_SLOTS:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(118, 118)
		slot.add_theme_stylebox_override("panel", UiTheme.box(Color(1, 1, 1, 0.06), 8, 8))
		if i < owned.size() and shop.items.has(owned[i]):
			var item: Dictionary = shop.items[owned[i]]
			var inner := VBoxContainer.new()
			inner.alignment = BoxContainer.ALIGNMENT_CENTER
			var icon := ColorRect.new()
			icon.color = Color.html(str(item.color))
			icon.custom_minimum_size = Vector2(44, 44)
			icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			inner.add_child(icon)
			var item_name := UiTheme.label(str(item.name), UiTheme.label_settings(15, UiTheme.TEXT, 0))
			item_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			inner.add_child(item_name)
			slot.tooltip_text = "%s\n%s" % [item.name, item.description]
			slot.add_child(inner)
		grid.add_child(slot)
	if owned.is_empty():
		_text("Çantan boş. Market'ten eşya alabilirsin.", 20, UiTheme.MUTED)
	else:
		_text("Çantadaki her eşya oyuna başlarken bonusunu verir.", 18, UiTheme.MUTED)


func _build_market() -> void:
	_text("Altının: %d" % progression.gold(), 22, UiTheme.ACCENT)
	for id: String in shop.items:
		var item: Dictionary = shop.items[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var icon := ColorRect.new()
		icon.color = Color.html(str(item.color))
		icon.custom_minimum_size = Vector2(40, 40)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UiTheme.label(str(item.name), UiTheme.label_settings(24, UiTheme.TEXT, 0)))
		info.add_child(UiTheme.label(str(item.description), UiTheme.label_settings(18, UiTheme.MUTED, 0)))
		row.add_child(info)
		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 0)
		if shop.owns(id):
			button.text = "Alındı"
			button.disabled = true
		else:
			button.text = "%d altın" % shop.price(id)
			button.disabled = not shop.can_buy(id)
			button.pressed.connect(func() -> void: buy(id))
		row.add_child(button)
		_content.add_child(row)


func _text(text: String, size: int, color := UiTheme.TEXT) -> void:
	var l := UiTheme.label(text, UiTheme.label_settings(size, color, 0))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(l)


func _bar(color: Color, min_size: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = min_size
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", UiTheme.box(Color(0, 0, 0, 0.55), 4, 0))
	bar.add_theme_stylebox_override("fill", UiTheme.box(color, 4, 0))
	return bar
