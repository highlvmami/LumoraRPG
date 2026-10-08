## Main menu after login: account level, Play, and the sections
## Characters (with their worn items), new character, Equipment, Backpack
## (shared items and chests), Market (chests and permanent upgrades),
## Profile and Friends.
extends CanvasLayer

const UiTheme := preload("res://scripts/ui/theme.gd")
const PixelIcons := preload("res://scripts/ui/pixel_icons.gd")
const Progression := preload("res://scripts/progression/progression.gd")
const Shop := preload("res://scripts/progression/shop.gd")
const Inventory := preload("res://scripts/progression/inventory.gd")

signal play_pressed
## The player wants to open this chest (the game shows the wheel).
signal chest_open_requested(uid: int)

const MAX_FRIENDS := 50
const NAV := [
	["characters", "Karakterler"],
	["equipment", "Ekipman"],
	["backpack", "Çanta"],
	["market", "Market"],
	["profile", "Profil"],
	["friends", "Arkadaşlar"],
]

var progression: Progression
var shop: Shop
var inventory: Inventory
var section := "characters"
## Item selected in the backpack (uid, -1 = none).
var selected_item := -1
## Class picked on the new character screen.
var create_class := "warrior"

var _root: Control
var _account_label: Label
var _account_bar: ProgressBar
var _gold_label: Label
var _notice: Label
var _content: VBoxContainer
var _section_title: Label
var _tab_buttons := {}
var _name_edit: LineEdit


func setup(p_progression: Progression, p_shop: Shop, p_inventory: Inventory) -> void:
	progression = p_progression
	shop = p_shop
	inventory = p_inventory
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
		margin.add_theme_constant_override("margin_" + side, 24)
	_root.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	layout.add_child(_build_top_bar())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	layout.add_child(body)
	body.add_child(_build_nav())

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(panel)
	var panel_box := VBoxContainer.new()
	panel_box.add_theme_constant_override("separation", 10)
	panel.add_child(panel_box)
	_section_title = UiTheme.label("", UiTheme.label_settings(26, UiTheme.ACCENT, 0))
	panel_box.add_child(_section_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_box.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_content)

	open_section("characters")


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
		(_tab_buttons[key] as Button).button_pressed = key == id or (key == "characters" and id == "create")
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	match id:
		"create":
			_section_title.text = "Yeni Karakter"
			_build_create()
		"equipment":
			_section_title.text = "Ekipman"
			_build_equipment()
		"backpack":
			_section_title.text = "Çanta (tüm karakterler ortak)"
			_build_backpack()
		"market":
			_section_title.text = "Market"
			_build_market()
		"profile":
			_section_title.text = "Profil"
			_build_profile()
		"friends":
			_section_title.text = "Arkadaşlar"
			_build_friends()
		_:
			section = "characters"
			_section_title.text = "Karakterler (%d / %d)" % [inventory.characters().size(), inventory.max_characters()]
			_build_characters()


## A short message under the gold counter that fades out.
func notify(text: String) -> void:
	_notice.text = text
	_notice.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(_notice, "modulate:a", 0.0, 0.8)


## Play: needs a character first, otherwise the creation screen opens.
func play() -> void:
	if inventory.characters().is_empty():
		open_section("create")
		notify("Önce bir karakter oluştur!")
		return
	play_pressed.emit()


# --- Actions (also used by tests) --------------------------------------------

## Buys a permanent market upgrade. Returns true on success.
func buy(id: String) -> bool:
	var ok := shop.buy(id)
	refresh()
	return ok


func buy_chest(tier: int) -> bool:
	var ok := inventory.buy_chest(tier)
	notify("%s alındı! Çanta'dan açabilirsin." % inventory.gear.chest(tier).name if ok else "Yeterli altının yok.")
	refresh()
	return ok


func create_character(char_name: String, class_id: String) -> bool:
	var c := inventory.create_character(char_name, class_id)
	if c.is_empty():
		notify("İsim en az 2 harf olmalı." if inventory.characters().size() < inventory.max_characters() else "En fazla %d karakter açabilirsin." % inventory.max_characters())
		return false
	notify("%s oluşturuldu!" % c.name)
	open_section("characters")
	refresh()
	return true


func select_character(id: int) -> void:
	inventory.set_active(id)
	refresh()


## Puts the item on the active character.
func equip(uid: int) -> bool:
	var c := inventory.active_character()
	if c.is_empty():
		notify("Önce bir karakter seç.")
		return false
	var ok := inventory.equip(int(c.id), uid)
	if not ok:
		notify("Bu eşyayı %s kullanamaz." % inventory.class_info(str(c["class"])).name)
	refresh()
	return ok


func unequip(slot_id: String) -> void:
	var c := inventory.active_character()
	if not c.is_empty():
		inventory.unequip(int(c.id), slot_id)
	refresh()


func sell(uid: int) -> int:
	var gold := inventory.sell(uid)
	if gold > 0:
		notify("+%d altın" % gold)
	selected_item = -1
	refresh()
	return gold


func select_item(uid: int) -> void:
	selected_item = uid
	refresh()


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


func _pick_class(class_id: String) -> void:
	create_class = class_id
	var typed := _name_edit.text if _name_edit else ""
	open_section("create")
	_name_edit.text = typed


# --- Layout -------------------------------------------------------------------

func _build_top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 20)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(left)
	left.add_child(UiTheme.label("LUMORA", UiTheme.label_settings(40, UiTheme.ACCENT, 8)))
	_account_label = UiTheme.label("", UiTheme.label_settings(20))
	left.add_child(_account_label)
	_account_bar = _bar(Color("#5fb8ff"), Vector2(320, 10))
	_account_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	left.add_child(_account_bar)
	var right := VBoxContainer.new()
	bar.add_child(right)
	_gold_label = UiTheme.label("", UiTheme.label_settings(26, UiTheme.ACCENT))
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_gold_label)
	_notice = UiTheme.label("", UiTheme.label_settings(18, Color("#8fe3ff"), 4))
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_notice)
	return bar


func _build_nav() -> Control:
	var nav := VBoxContainer.new()
	nav.custom_minimum_size = Vector2(230, 0)
	nav.add_theme_constant_override("separation", 8)
	var play_button := UiTheme.primary_button("OYNA")
	play_button.custom_minimum_size = Vector2(0, 70)
	play_button.pressed.connect(play)
	nav.add_child(play_button)
	for entry: Array in NAV:
		var button := Button.new()
		button.text = entry[1]
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 46)
		button.add_theme_font_size_override("font_size", 21)
		button.add_theme_stylebox_override("hover_pressed", UiTheme.box(UiTheme.BUTTON_HOVER, 8, 8))
		button.add_theme_stylebox_override("pressed", UiTheme.box(Color("#4a6380"), 8, 8))
		button.pressed.connect(open_section.bind(str(entry[0])))
		_tab_buttons[entry[0]] = button
		nav.add_child(button)
	return nav


## One card per character: class icon, name, best level, worn items, select button.
func _build_characters() -> void:
	var active := inventory.active_character()
	for c: Dictionary in inventory.characters():
		var info := inventory.class_info(str(c["class"]))
		var is_active := not active.is_empty() and int(active.id) == int(c.id)
		var card := PanelContainer.new()
		var style := UiTheme.box(Color(1, 1, 1, 0.05), 10, 10)
		style.set_border_width_all(3 if is_active else 1)
		style.border_color = Color(str(info.color)) if is_active else Color(1, 1, 1, 0.15)
		card.add_theme_stylebox_override("panel", style)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		card.add_child(row)
		row.add_child(_icon_tile(str(info.icon), Color(str(info.color)), 64, Color(0, 0, 0, 0)))

		var text := VBoxContainer.new()
		text.custom_minimum_size.x = 190
		text.add_child(UiTheme.label(str(c.name), UiTheme.label_settings(24, UiTheme.TEXT, 0)))
		text.add_child(UiTheme.label("%s  ·  En iyi Sv. %d" % [info.name, int(c.get("bestLevel", 0))], UiTheme.label_settings(16, Color(str(info.color)), 0)))
		row.add_child(text)

		var worn := HBoxContainer.new()
		worn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		worn.add_theme_constant_override("separation", 4)
		for s: Dictionary in inventory.gear.slots:
			var it := inventory.equipped(c, str(s.id))
			worn.add_child(_slot_tile(it, str(s.id), 44))
		row.add_child(worn)

		var pick := Button.new()
		pick.text = "Aktif" if is_active else "Seç"
		pick.disabled = is_active
		pick.custom_minimum_size = Vector2(90, 0)
		pick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pick.pressed.connect(select_character.bind(int(c.id)))
		row.add_child(pick)
		_content.add_child(card)

	if inventory.characters().size() < inventory.max_characters():
		var add := Button.new()
		add.text = "+ Yeni Karakter Oluştur"
		add.custom_minimum_size = Vector2(0, 52)
		add.pressed.connect(open_section.bind("create"))
		_content.add_child(add)
	if inventory.characters().is_empty():
		_text("Henüz karakterin yok. Savaşçı, Okçu ya da Büyücü oluşturarak başla.", 18, UiTheme.MUTED)
	else:
		_text("OYNA'ya basınca aktif karakterle oynarsın. Çanta tüm karakterlerin ortak çantasıdır.", 16, UiTheme.MUTED)


## Name field, three class cards and the create button.
func _build_create() -> void:
	if inventory.characters().size() >= inventory.max_characters():
		_text("En fazla %d karakter açabilirsin." % inventory.max_characters(), 20, UiTheme.MUTED)
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(UiTheme.label("İsim:", UiTheme.label_settings(22, UiTheme.TEXT, 0)))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Karakter adı"
	_name_edit.max_length = 14
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_name_edit)
	_content.add_child(row)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 12)
	_content.add_child(cards)
	for class_id: String in inventory.classes:
		var info: Dictionary = inventory.classes[class_id]
		var color := Color(str(info.color))
		var picked := class_id == create_class
		var card := Button.new()
		card.custom_minimum_size = Vector2(0, 250)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for state: String in ["normal", "hover", "pressed"]:
			var style := UiTheme.box(Color(0.12, 0.15, 0.2, 0.95) if state == "normal" else Color(0.16, 0.2, 0.26, 0.97), 12, 12)
			style.set_border_width_all(4 if picked else 2)
			style.border_color = color if picked or state == "hover" else color.darkened(0.5)
			card.add_theme_stylebox_override(state, style)
		card.pressed.connect(_pick_class.bind(class_id))
		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 6)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(box)
		var icon := PixelIcons.rect(str(info.icon), 72, color)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
		box.add_child(_centered(str(info.name), UiTheme.label_settings(24, color.lightened(0.2), 4)))
		box.add_child(_centered(str(info.desc), UiTheme.label_settings(14, UiTheme.TEXT, 0)))
		box.add_child(_centered("Can %d" % int(info.maxHp), UiTheme.label_settings(14, UiTheme.MUTED, 0)))
		cards.add_child(card)

	var create := UiTheme.primary_button("Oluştur: %s" % inventory.class_info(create_class).name)
	create.add_theme_font_size_override("font_size", 24)
	create.pressed.connect(func() -> void: create_character(_name_edit.text, create_class))
	_name_edit.text_submitted.connect(func(t: String) -> void: create_character(t, create_class))
	_content.add_child(create)


## The active character's six slots, gear totals and the items it can put on.
func _build_equipment() -> void:
	var c := inventory.active_character()
	if c.is_empty():
		_text("Önce bir karakter oluştur.", 20, UiTheme.MUTED)
		return
	var info := inventory.class_info(str(c["class"]))
	_text("%s  ·  %s" % [c.name, info.name], 22, Color(str(info.color)))

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	_content.add_child(grid)
	for s: Dictionary in inventory.gear.slots:
		var it := inventory.equipped(c, str(s.id))
		var cell := HBoxContainer.new()
		cell.custom_minimum_size.x = 280
		cell.add_theme_constant_override("separation", 8)
		cell.add_child(_slot_tile(it, str(s.id), 56))
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(UiTheme.label(str(s.name), UiTheme.label_settings(14, UiTheme.MUTED, 0)))
		if it.is_empty():
			text.add_child(UiTheme.label("Boş", UiTheme.label_settings(17, UiTheme.MUTED, 0)))
		else:
			text.add_child(UiTheme.label(inventory.gear.item_name(it), UiTheme.label_settings(17, inventory.gear.rarity_color(int(it.rarity)), 0)))
			var off := Button.new()
			off.text = "Çıkar"
			off.add_theme_font_size_override("font_size", 14)
			off.pressed.connect(unequip.bind(str(s.id)))
			text.add_child(off)
		cell.add_child(text)
		grid.add_child(cell)

	var totals := PackedStringArray()
	for a: Dictionary in inventory.gear.affixes:
		var v := inventory.gear_total(c, str(a.stat))
		if v > 0.0:
			totals.append(inventory.gear.stat_text(str(a.stat), v))
	_text("Ekipman bonusu: " + (", ".join(totals) if not totals.is_empty() else "yok"), 17, UiTheme.ACCENT)

	_text("Kuşanabileceğin eşyalar", 20, UiTheme.TEXT)
	var any := false
	for candidate: Dictionary in inventory.items():
		var it := candidate
		var w := inventory.wearer(int(it.uid))
		if not inventory.can_wear(c, it) or (not w.is_empty() and int(w.id) == int(c.id)):
			continue
		any = true
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(_item_tile(it, 44, false))
		var label := UiTheme.label("%s  ·  %s  ·  %s" % [inventory.gear.item_name(it), inventory.gear.rarity(int(it.rarity)).name, ", ".join(inventory.gear.stat_lines(it))], UiTheme.label_settings(15, inventory.gear.rarity_color(int(it.rarity)), 0))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(label)
		if not w.is_empty():
			row.add_child(UiTheme.label("(%s giyiyor)" % w.name, UiTheme.label_settings(13, UiTheme.MUTED, 0)))
		var on := Button.new()
		on.text = "Kuşan"
		on.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		on.pressed.connect(equip.bind(int(it.uid)))
		row.add_child(on)
		_content.add_child(row)
	if not any:
		_text("Bu karaktere uygun eşya yok. Canavarlar ve boss kasaları eşya düşürür.", 16, UiTheme.MUTED)


## Chests (open with the wheel) and the shared item grid with a details panel.
func _build_backpack() -> void:
	var chests := inventory.chests()
	_text("Kasalar (%d)" % chests.size(), 20, UiTheme.TEXT)
	if chests.is_empty():
		_text("Kasa yok. Boss'lar kasa düşürür, Market'ten de alabilirsin.", 15, UiTheme.MUTED)
	else:
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		_content.add_child(flow)
		for ch: Dictionary in chests:
			var cd := inventory.gear.chest(int(ch.tier))
			var chest_color := Color(str(cd.color))
			var box := VBoxContainer.new()
			box.add_child(_icon_tile("chest", chest_color, 52, chest_color))
			var open := Button.new()
			open.text = "Aç"
			open.add_theme_font_size_override("font_size", 15)
			open.tooltip_text = str(cd.name)
			open.pressed.connect(func() -> void: chest_open_requested.emit(int(ch.uid)))
			box.add_child(open)
			flow.add_child(box)

	var items := inventory.items()
	_text("Eşyalar (%d / %d)" % [items.size(), int(inventory.gear.drops.stashLimit)], 20, UiTheme.TEXT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_content.add_child(row)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(grid)
	for it: Dictionary in items:
		grid.add_child(_item_tile(it, 58, true))
	if items.is_empty():
		_text("Çantan boş. Canavarlar bazen eşya düşürür.", 16, UiTheme.MUTED)

	var sel := inventory.item(selected_item)
	if sel.is_empty():
		return
	var details := PanelContainer.new()
	details.custom_minimum_size.x = 270
	details.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	details.add_theme_stylebox_override("panel", UiTheme.box(Color(0, 0, 0, 0.35), 10, 12))
	row.add_child(details)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	details.add_child(col)
	var color := inventory.gear.rarity_color(int(sel.rarity))
	var icon := PixelIcons.item_rect(inventory.gear.item_icon(sel), int(sel.rarity), color, 72)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(icon)
	var title := UiTheme.label(inventory.gear.item_name(sel), UiTheme.label_settings(20, color, 3))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)
	var cls := inventory.gear.item_class(sel)
	var who := "tüm sınıflar" if cls == "" else str(inventory.class_info(cls).name)
	col.add_child(UiTheme.label("%s  ·  %s" % [inventory.gear.rarity(int(sel.rarity)).name, inventory.gear.slot_name(inventory.gear.item_slot(sel))], UiTheme.label_settings(14, UiTheme.MUTED, 0)))
	col.add_child(UiTheme.label("Kullanabilen: " + who, UiTheme.label_settings(14, UiTheme.MUTED, 0)))
	for line: String in inventory.gear.stat_lines(sel):
		col.add_child(UiTheme.label(line, UiTheme.label_settings(15, Color("#8fe39a"), 0)))
	var w := inventory.wearer(int(sel.uid))
	if not w.is_empty():
		col.add_child(UiTheme.label("%s giyiyor" % w.name, UiTheme.label_settings(14, UiTheme.ACCENT, 0)))
	var buttons := HBoxContainer.new()
	var on := Button.new()
	on.text = "Kuşan"
	on.disabled = not inventory.can_wear(inventory.active_character(), sel)
	on.pressed.connect(equip.bind(int(sel.uid)))
	buttons.add_child(on)
	var sell_button := Button.new()
	sell_button.text = "Sat (%d)" % inventory.gear.sell_price(sel)
	sell_button.pressed.connect(sell.bind(int(sel.uid)))
	buttons.add_child(sell_button)
	col.add_child(buttons)


func _build_market() -> void:
	_text("Kasalar", 22, UiTheme.ACCENT)
	for tier in inventory.gear.chests.size():
		var cd := inventory.gear.chest(tier)
		var color := Color(str(cd.color))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(_icon_tile("chest", color, 48, color))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UiTheme.label(str(cd.name), UiTheme.label_settings(21, color, 0)))
		var odds := PackedStringArray()
		for r in (cd.odds as Array).size():
			if float(cd.odds[r]) > 0.0:
				odds.append("%s %%%d" % [inventory.gear.rarity(r).name, int(cd.odds[r])])
		var odds_label := UiTheme.label("  ·  ".join(odds), UiTheme.label_settings(13, UiTheme.MUTED, 0))
		odds_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(odds_label)
		row.add_child(info)
		var button := Button.new()
		button.custom_minimum_size = Vector2(140, 0)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.text = "%d altın" % int(cd.price)
		button.disabled = progression.gold() < int(cd.price)
		button.pressed.connect(buy_chest.bind(tier))
		row.add_child(button)
		_content.add_child(row)

	_text("Kalıcı Geliştirmeler (tüm karakterler)", 22, UiTheme.ACCENT)
	for id: String in shop.items:
		var item: Dictionary = shop.items[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var icon := ColorRect.new()
		icon.color = Color.html(str(item.color))
		icon.custom_minimum_size = Vector2(36, 36)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UiTheme.label(str(item.name), UiTheme.label_settings(20, UiTheme.TEXT, 0)))
		info.add_child(UiTheme.label(str(item.description), UiTheme.label_settings(14, UiTheme.MUTED, 0)))
		row.add_child(info)
		var button := Button.new()
		button.custom_minimum_size = Vector2(140, 0)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if shop.owns(id):
			button.text = "Alındı"
			button.disabled = true
		else:
			button.text = "%d altın" % shop.price(id)
			button.disabled = not shop.can_buy(id)
			button.pressed.connect(buy.bind(id))
		row.add_child(button)
		_content.add_child(row)


func _build_profile() -> void:
	var p := progression.profile
	_text("Hesap seviyesi: %d" % progression.account_level(), 24)
	_text("Karakterler: %d / %d" % [inventory.characters().size(), inventory.max_characters()], 20)
	_text("En yüksek karakter seviyesi: %d" % int(p.get("bestLevel", 0)), 20)
	_text("Toplam kesilen canavar: %d" % int(p.get("totalKills", 0)), 20)
	_text("Oynanan oyun: %d" % int(p.get("runs", 0)), 20)
	_text("Çantadaki eşya: %d   ·   Kasa: %d" % [inventory.items().size(), inventory.chests().size()], 20)
	_text("Canavar kesince EXP ve altın kazanırsın; bazen eşya düşer, boss'lar kasa bırakır. Eşyaları Ekipman'dan kuşan.", 16, UiTheme.MUTED)


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
		_text("Henüz arkadaşın yok. Kullanıcı adını yazıp ekleyebilirsin.", 18, UiTheme.MUTED)
	for friend: String in friends:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		var dot := ColorRect.new()
		dot.color = Color("#6b7280")
		dot.custom_minimum_size = Vector2(14, 14)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(dot)
		var name_label := UiTheme.label(friend, UiTheme.label_settings(22, UiTheme.TEXT, 0))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		line.add_child(UiTheme.label("çevrimdışı", UiTheme.label_settings(16, UiTheme.MUTED, 0)))
		var remove := Button.new()
		remove.text = "Sil"
		remove.pressed.connect(_remove_friend.bind(friend))
		line.add_child(remove)
		_content.add_child(line)
	_text("Arkadaşlarının çevrimiçi durumu ve birlikte oynama, çevrimiçi hesaplar gelince açılacak.", 15, UiTheme.MUTED)


# --- Small widgets -------------------------------------------------------------

## A clickable item square with a rarity-colored border (selects it in the backpack).
func _item_tile(it: Dictionary, size: float, selectable: bool) -> Control:
	var color := inventory.gear.rarity_color(int(it.rarity))
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(size, size)
	for state: String in ["normal", "hover", "pressed"]:
		var style := UiTheme.box(color.darkened(0.75) if state == "normal" else color.darkened(0.6), 6, 3)
		style.set_border_width_all(3 if selectable and int(it.uid) == selected_item else 2)
		style.border_color = Color.WHITE if selectable and int(it.uid) == selected_item else color
		tile.add_theme_stylebox_override(state, style)
	var icon := PixelIcons.item_rect(inventory.gear.item_icon(it), int(it.rarity), color, size - 10)
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(icon)
	var w := inventory.wearer(int(it.uid))
	if not w.is_empty():
		var mark := UiTheme.label("E", UiTheme.label_settings(12, UiTheme.ACCENT, 3))
		mark.position = Vector2(3, 0)
		tile.add_child(mark)
	tile.tooltip_text = "%s (%s)\n%s" % [inventory.gear.item_name(it), inventory.gear.rarity(int(it.rarity)).name, "\n".join(inventory.gear.stat_lines(it))]
	if selectable:
		tile.pressed.connect(select_item.bind(int(it.uid)))
	return tile


## An equipment slot: the worn item, or a dim outline of the slot.
func _slot_tile(it: Dictionary, slot_id: String, size: float) -> Control:
	if not it.is_empty():
		return _item_tile(it, size, false)
	var icon := "boot" if slot_id == "boots" else ("sword" if slot_id == "weapon" else slot_id)
	var tile := _icon_tile(icon, Color(1, 1, 1, 0.2), size, Color(0, 0, 0, 0))
	tile.modulate = Color(1, 1, 1, 0.35)
	tile.tooltip_text = inventory.gear.slot_name(slot_id) + ": boş"
	return tile


func _icon_tile(icon: String, border: Color, size: float, accent: Color) -> PanelContainer:
	var tile := PanelContainer.new()
	var style := UiTheme.box(Color(0, 0, 0, 0.35), 6, 3)
	style.set_border_width_all(2)
	style.border_color = border
	tile.add_theme_stylebox_override("panel", style)
	tile.custom_minimum_size = Vector2(size, size)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var rect := PixelIcons.rect(icon, size - 10, accent)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(rect)
	return tile


func _centered(text: String, settings: LabelSettings) -> Label:
	var label := UiTheme.label(text, settings)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 160
	return label


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
