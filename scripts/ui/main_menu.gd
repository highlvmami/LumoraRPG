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
const ItemArt := preload("res://scripts/ui/item_art.gd")
const ItemSlot := preload("res://scripts/ui/item_slot.gd")
const CharacterPreview := preload("res://scripts/ui/character_preview.gd")

signal play_pressed
## The player wants to open this chest (the game shows the wheel).
signal chest_open_requested(uid: int)

const MAX_FRIENDS := 50
## [section id, button text, pixel icon]
const NAV := [
	["characters", "Karakterler", "cls_warrior"],
	["equipment", "Ekipman", "armor"],
	["backpack", "Çanta", "chest"],
	["market", "Market", "clover"],
	["profile", "Profil", "eye"],
	["friends", "Arkadaşlar", "heart"],
]
## Detail tier of the chest drawing per chest tier.
const CHEST_ART_TIER := [0, 1, 1, 2]
const CLASS_NAMES := {"warrior": "Savaşçı", "archer": "Okçu", "mage": "Büyücü"}

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
		button.text = "  " + str(entry[1])
		button.toggle_mode = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 46)
		button.add_theme_font_size_override("font_size", 20)
		button.icon = PixelIcons.texture(str(entry[2]), UiTheme.ACCENT)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 26)
		var normal := UiTheme.box(Color(0.12, 0.16, 0.21, 0.92), 8, 8)
		normal.border_width_left = 4
		normal.border_color = Color(0.12, 0.16, 0.21, 0.92)
		button.add_theme_stylebox_override("normal", normal)
		var hover := UiTheme.box(UiTheme.BUTTON_HOVER, 8, 8)
		hover.border_width_left = 4
		hover.border_color = UiTheme.ACCENT.darkened(0.4)
		button.add_theme_stylebox_override("hover", hover)
		var on := UiTheme.box(Color("#3a5270"), 8, 8)
		on.border_width_left = 4
		on.border_color = UiTheme.ACCENT
		button.add_theme_stylebox_override("pressed", on)
		button.add_theme_stylebox_override("hover_pressed", on)
		button.pressed.connect(open_section.bind(str(entry[0])))
		_tab_buttons[entry[0]] = button
		nav.add_child(button)
	return nav


## Side-by-side character cards: the 3D character with its gear, name, class,
## best level, worn items and a select button; plus a "new character" card.
func _build_characters() -> void:
	var active := inventory.active_character()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_content.add_child(row)
	for c: Dictionary in inventory.characters():
		var info := inventory.class_info(str(c["class"]))
		var class_color := Color(str(info.color))
		var is_active := not active.is_empty() and int(active.id) == int(c.id)
		var card := PanelContainer.new()
		card.custom_minimum_size.x = 210
		var style := _card_style(class_color if is_active else Color(1, 1, 1, 0.12), 3 if is_active else 1)
		card.add_theme_stylebox_override("panel", style)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		card.add_child(col)
		var stage := _stage(class_color)
		stage.add_child(_preview(c, Vector2(186, 190)))
		col.add_child(stage)
		col.add_child(_centered(str(c.name), UiTheme.label_settings(22, UiTheme.TEXT, 4)))
		col.add_child(_centered("%s  ·  En iyi Sv. %d" % [info.name, int(c.get("bestLevel", 0))], UiTheme.label_settings(14, class_color.lightened(0.2), 3)))
		var worn := GridContainer.new()
		worn.columns = 6
		worn.add_theme_constant_override("h_separation", 3)
		worn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		for s: Dictionary in inventory.gear.slots:
			worn.add_child(_slot_button(inventory.equipped(c, str(s.id)), str(s.id), 30))
		col.add_child(worn)
		var pick := Button.new()
		pick.text = "Aktif" if is_active else "Seç"
		pick.disabled = is_active
		pick.add_theme_font_size_override("font_size", 18)
		pick.pressed.connect(select_character.bind(int(c.id)))
		col.add_child(pick)
		row.add_child(card)

	if inventory.characters().size() < inventory.max_characters():
		var add := Button.new()
		add.custom_minimum_size = Vector2(170, 330)
		add.text = "+\nYeni\nKarakter"
		add.add_theme_font_size_override("font_size", 26)
		for state: String in ["normal", "hover", "pressed"]:
			add.add_theme_stylebox_override(state, _card_style(UiTheme.ACCENT if state == "hover" else Color(1, 1, 1, 0.2), 2))
		add.pressed.connect(open_section.bind("create"))
		row.add_child(add)
	if inventory.characters().is_empty():
		_text("Henüz karakterin yok. Savaşçı, Okçu ya da Büyücü oluşturarak başla.", 18, UiTheme.MUTED)
	else:
		_text("OYNA'ya basınca aktif karakterle oynarsın. Çanta tüm karakterlerin ortak çantasıdır.", 15, UiTheme.MUTED)


## Name field, three class cards (with the class in 3D) and the create button.
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
		card.custom_minimum_size = Vector2(0, 300)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for state: String in ["normal", "hover", "pressed"]:
			var style := _card_style(color if picked or state == "hover" else color.darkened(0.55), 4 if picked else 2)
			card.add_theme_stylebox_override(state, style)
		card.pressed.connect(_pick_class.bind(class_id))
		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 4)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(box)
		var preview := _preview({"class": class_id}, Vector2(150, 150))
		preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(preview)
		box.add_child(_centered(str(info.name), UiTheme.label_settings(24, color.lightened(0.2), 4)))
		box.add_child(_centered(str(info.desc), UiTheme.label_settings(13, UiTheme.TEXT, 0)))
		box.add_child(_centered("Can %d" % int(info.maxHp), UiTheme.label_settings(13, UiTheme.MUTED, 0)))
		cards.add_child(card)

	var create := UiTheme.primary_button("Oluştur: %s" % inventory.class_info(create_class).name)
	create.add_theme_font_size_override("font_size", 24)
	create.pressed.connect(func() -> void: create_character(_name_edit.text, create_class))
	_name_edit.text_submitted.connect(func(t: String) -> void: create_character(t, create_class))
	_content.add_child(create)


## Paper doll: the character in the middle; helmet, armor and boots stacked on
## the left, weapon, gloves (at hand height) and ring on the right. Hover a
## slot to see the item's stats. Below: gear totals and items to put on.
func _build_equipment() -> void:
	var c := inventory.active_character()
	if c.is_empty():
		_text("Önce bir karakter oluştur.", 20, UiTheme.MUTED)
		return
	var info := inventory.class_info(str(c["class"]))
	var class_color := Color(str(info.color))

	var doll := HBoxContainer.new()
	doll.alignment = BoxContainer.ALIGNMENT_CENTER
	doll.add_theme_constant_override("separation", 18)
	_content.add_child(doll)
	doll.add_child(_slot_column(c, ["helmet", "armor", "boots"], HORIZONTAL_ALIGNMENT_RIGHT))
	var middle := VBoxContainer.new()
	middle.add_theme_constant_override("separation", 2)
	var stage := _stage(class_color)
	stage.add_child(_preview(c, Vector2(250, 330)))
	middle.add_child(stage)
	middle.add_child(_centered("%s  ·  %s" % [c.name, info.name], UiTheme.label_settings(20, class_color.lightened(0.2), 4)))
	doll.add_child(middle)
	doll.add_child(_slot_column(c, ["weapon", "gloves", "ring"], HORIZONTAL_ALIGNMENT_LEFT))

	var totals := PackedStringArray()
	for a: Dictionary in inventory.gear.affixes:
		var v := inventory.gear_total(c, str(a.stat))
		if v > 0.0:
			totals.append(inventory.gear.stat_text(str(a.stat), v))
	var bonus := _centered("Ekipman bonusu: " + ("   ".join(totals) if not totals.is_empty() else "yok"), UiTheme.label_settings(15, Color("#8fe39a"), 3))
	bonus.custom_minimum_size.x = 600
	bonus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(bonus)

	_header("Kuşanabileceğin eşyalar")
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	_content.add_child(flow)
	for candidate: Dictionary in inventory.items():
		var w := inventory.wearer(int(candidate.uid))
		if inventory.can_wear(c, candidate) and (w.is_empty() or int(w.id) != int(c.id)):
			flow.add_child(_item_card(candidate, true))
	if flow.get_child_count() == 0:
		_text("Bu karaktere uygun eşya yok. Canavarlar ve boss kasaları eşya düşürür.", 15, UiTheme.MUTED)


## A column of big equipment slots with their names; filled slots get "Çıkar".
func _slot_column(c: Dictionary, slot_ids: Array, align: HorizontalAlignment) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	for slot_id: String in slot_ids:
		var it := inventory.equipped(c, slot_id)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		var title := UiTheme.label(inventory.gear.slot_name(slot_id).to_upper(), UiTheme.label_settings(13, UiTheme.MUTED, 3))
		title.horizontal_alignment = align
		box.add_child(title)
		var slot := _slot_button(it, slot_id, 92)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_END if align == HORIZONTAL_ALIGNMENT_RIGHT else Control.SIZE_SHRINK_BEGIN
		box.add_child(slot)
		if not it.is_empty():
			var item_name := UiTheme.label(inventory.gear.item_name(it), UiTheme.label_settings(13, inventory.gear.rarity_color(int(it.rarity)), 3))
			item_name.horizontal_alignment = align
			box.add_child(item_name)
			slot.pressed.connect(unequip.bind(slot_id))
			slot.tooltip_text += "\n(çıkarmak için tıkla)"
		col.add_child(box)
	return col


## Chests (open with the wheel) and the shared items as cards.
func _build_backpack() -> void:
	var chests := inventory.chests()
	_header("Kasalar (%d)" % chests.size())
	if chests.is_empty():
		_text("Kasa yok. Boss'lar kasa düşürür, Market'ten de alabilirsin.", 15, UiTheme.MUTED)
	else:
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 10)
		_content.add_child(flow)
		for ch: Dictionary in chests:
			var cd := inventory.gear.chest(int(ch.tier))
			var chest_color := Color(str(cd.color))
			var card := PanelContainer.new()
			card.add_theme_stylebox_override("panel", _card_style(chest_color, 2))
			var box := VBoxContainer.new()
			box.add_theme_constant_override("separation", 2)
			card.add_child(box)
			var art := ItemArt.make({"base": "chest"}, chest_color, CHEST_ART_TIER[int(ch.tier)], 76)
			art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			box.add_child(art)
			box.add_child(_centered(str(cd.name), UiTheme.label_settings(13, chest_color, 3)))
			var open := Button.new()
			open.text = "Aç"
			open.add_theme_font_size_override("font_size", 16)
			open.pressed.connect(func() -> void: chest_open_requested.emit(int(ch.uid)))
			box.add_child(open)
			flow.add_child(card)

	var items := inventory.items()
	_header("Eşyalar (%d / %d)" % [items.size(), int(inventory.gear.drops.stashLimit)])
	if items.is_empty():
		_text("Çantan boş. Canavarlar bazen eşya düşürür.", 15, UiTheme.MUTED)
		return
	var sorted := items.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.rarity) > int(b.rarity))
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_content.add_child(grid)
	for it: Dictionary in sorted:
		grid.add_child(_item_card(it, false))


func _build_market() -> void:
	_header("Kasalar")
	for tier in inventory.gear.chests.size():
		var cd := inventory.gear.chest(tier)
		var color := Color(str(cd.color))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(ItemArt.make({"base": "chest"}, color, CHEST_ART_TIER[tier], 64))
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

	_header("Kalıcı Geliştirmeler (tüm karakterler)")
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

## An item card: the detailed drawing on a rarity-colored stage, name, rarity
## and slot, every stat, who wears it, and Kuşan / Sat buttons.
func _item_card(it: Dictionary, equip_only: bool) -> Control:
	var gear := inventory.gear
	var rarity := int(it.rarity)
	var color := gear.rarity_color(rarity)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(172, 0)
	var style := _card_style(color, 3 if rarity >= 4 else 2)
	style.bg_color = color.darkened(0.82)
	card.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	card.add_child(col)

	var stage := PanelContainer.new()
	var stage_style := UiTheme.box(color.darkened(0.65), 6, 2)
	stage_style.border_width_bottom = 3
	stage_style.border_color = color.darkened(0.2)
	stage.add_theme_stylebox_override("panel", stage_style)
	var art := ItemArt.make(it, color, gear.tier(rarity), 100)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stage.add_child(art)
	col.add_child(stage)

	col.add_child(_centered(gear.item_name(it), UiTheme.label_settings(16, color.lightened(0.15), 4)))
	var cls := gear.item_class(it)
	var where := gear.slot_name(gear.item_slot(it)) + ("" if cls == "" else "  ·  " + str(inventory.class_info(cls).name))
	col.add_child(_centered("%s  ·  %s" % [gear.rarity(rarity).name, where], UiTheme.label_settings(11, UiTheme.MUTED, 2)))
	for line: String in gear.stat_lines(it):
		col.add_child(_centered(line, UiTheme.label_settings(13, Color("#8fe39a"), 2)))
	var w := inventory.wearer(int(it.uid))
	if not w.is_empty():
		col.add_child(_centered("Giyen: %s" % w.name, UiTheme.label_settings(12, UiTheme.ACCENT, 2)))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	var on := Button.new()
	on.text = "Kuşan"
	on.add_theme_font_size_override("font_size", 14)
	on.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	on.disabled = not inventory.can_wear(inventory.active_character(), it)
	on.pressed.connect(equip.bind(int(it.uid)))
	buttons.add_child(on)
	if not equip_only:
		var sell_button := Button.new()
		sell_button.text = "Sat %d" % gear.sell_price(it)
		sell_button.add_theme_font_size_override("font_size", 14)
		sell_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sell_button.pressed.connect(sell.bind(int(it.uid)))
		buttons.add_child(sell_button)
	col.add_child(buttons)
	return card


## A square equipment slot: the worn item's drawing (hover for its stats), or
## a faint outline of what goes there.
func _slot_button(it: Dictionary, slot_id: String, size: float) -> Button:
	var gear := inventory.gear
	var slot: Button = ItemSlot.new()
	slot.custom_minimum_size = Vector2(size, size)
	var color := Color(1, 1, 1, 0.25) if it.is_empty() else gear.rarity_color(int(it.rarity))
	for state: String in ["normal", "hover", "pressed"]:
		var style := UiTheme.box(Color(0, 0, 0, 0.45) if it.is_empty() else color.darkened(0.7 if state == "normal" else 0.55), 8, 2)
		style.set_border_width_all(2 if size < 60 else 3)
		style.border_color = color if state == "normal" else color.lightened(0.3)
		slot.add_theme_stylebox_override(state, style)
	var base := "sword" if slot_id == "weapon" else slot_id
	var art := ItemArt.make({"base": base} if it.is_empty() else it, color, 0 if it.is_empty() else gear.tier(int(it.rarity)), size - 8)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	if it.is_empty():
		art.modulate = Color(0, 0, 0, 0.45)
	slot.add_child(art)
	if it.is_empty():
		slot.tooltip_text = gear.slot_name(slot_id) + ": boş"
	else:
		slot.tooltip_text = gear.item_name(it)
		slot.set("tooltip_builder", func() -> Control: return ItemArt.tooltip(gear, it, CLASS_NAMES))
	return slot


## A 3D view of a character wearing its gear (or a fresh one of a class).
func _preview(c: Dictionary, view_size: Vector2) -> Control:
	var preview: SubViewportContainer = CharacterPreview.new()
	preview.call("setup", inventory.character_look(c), view_size)
	return preview


## A dark rounded backdrop with a soft glow of `color` for character previews.
func _stage(color: Color) -> PanelContainer:
	var stage := PanelContainer.new()
	var style := UiTheme.box(color.darkened(0.8), 10, 4)
	style.border_width_bottom = 4
	style.border_color = color.darkened(0.3)
	stage.add_theme_stylebox_override("panel", style)
	return stage


func _card_style(border: Color, width: int) -> StyleBoxFlat:
	var style := UiTheme.box(Color(0.1, 0.13, 0.17, 0.95), 10, 8)
	style.set_border_width_all(width)
	style.border_color = border
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style


func _header(text: String) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.add_child(UiTheme.label(text, UiTheme.label_settings(20, UiTheme.ACCENT, 3)))
	var line := ColorRect.new()
	line.color = Color(UiTheme.ACCENT, 0.3)
	line.custom_minimum_size = Vector2(0, 2)
	box.add_child(line)
	_content.add_child(box)



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
