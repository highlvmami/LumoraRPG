## Main menu after login: account level, Play, and the sections
## Characters (with their worn items), new character, Equipment, Backpack
## (shared items and chests), Skill Tree (permanent upgrades), Market
## (chests), Achievements, Profile, Friends, Logs (past runs), Versions
## (what changed) and Settings (graphics, camera, interface, account).
extends CanvasLayer

const UiTheme := preload("res://scripts/ui/theme.gd")
const PixelIcons := preload("res://scripts/ui/pixel_icons.gd")
const Progression := preload("res://scripts/progression/progression.gd")
const SkillTree := preload("res://scripts/progression/skill_tree.gd")
const Inventory := preload("res://scripts/progression/inventory.gd")
const ItemArt := preload("res://scripts/ui/item_art.gd")
const ItemSlot := preload("res://scripts/ui/item_slot.gd")
const CharacterPreview := preload("res://scripts/ui/character_preview.gd")
const TooltipCard := preload("res://scripts/ui/tooltip_card.gd")
const Config := preload("res://scripts/core/config.gd")

signal play_pressed
## The player wants to open this chest (the game shows the wheel).
signal chest_open_requested(uid: int)
signal quality_selected(quality: String)
## A setting in profile.settings changed; the game applies it.
signal settings_changed
signal logout_requested
## The player confirmed wiping the whole account.
signal reset_requested

const MAX_FRIENDS := 50
const DESKTOP_DOWNLOAD := "https://github.com/highlvmami/LumoraRPG/releases/download/latest/LumoraRPG-windows.zip"
## [section id, button text, pixel icon]
const NAV := [
	["characters", "Karakterler", "cls_warrior"],
	["equipment", "Ekipman", "armor"],
	["backpack", "Çanta", "chest"],
	["skills", "Yetenek Ağacı", "storm"],
	["market", "Market", "clover"],
	["achievements", "Başarımlar", "skull"],
	["profile", "Profil", "eye"],
	["friends", "Arkadaşlar", "heart"],
	["logs", "Kayıtlar", "double_arrow"],
	["versions", "Sürümler", "staff"],
	["settings", "Ayarlar", "shield"],
]
const CLASS_NAMES := {"warrior": "Savaşçı", "archer": "Okçu", "mage": "Büyücü"}

var progression: Progression
var skill_tree: SkillTree
var inventory: Inventory
## Achievements (set by the game after setup).
var achievements: RefCounted
var section := "characters"
## Item selected in the backpack (uid, -1 = none).
var selected_item := -1
## Class picked on the new character screen.
var create_class := "warrior"
## Graphics quality shown in the settings (low / medium / high).
var quality := "medium"
## Build number shown on the versions page.
var version_text := ""
## The open yes/no question, if any.
var _confirm_layer: Control
## Online server (NetClient): rooms, invites, who is online.
var net: Node
var _online_label: Label
var _friend_rows := {}
var _who_timer := 0.0
var _online_box: VBoxContainer

var _root: Control
var _account_label: Label
var _account_bar: ProgressBar
var _gold_label: Label
var _notice: Label
var _content: VBoxContainer
var _section_title: Label
var _tab_buttons := {}
var _name_edit: LineEdit


func setup(p_progression: Progression, p_skill_tree: SkillTree, p_inventory: Inventory) -> void:
	progression = p_progression
	skill_tree = p_skill_tree
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
		"skills":
			_section_title.text = "Yetenek Ağacı"
			_build_skills()
		"market":
			_section_title.text = "Market"
			_build_market()
		"achievements":
			_section_title.text = "Başarımlar"
			_build_achievements()
		"profile":
			_section_title.text = "Profil"
			_build_profile()
		"friends":
			_section_title.text = "Arkadaşlar"
			_build_friends()
		"logs":
			_section_title.text = "Kayıtlar"
			_build_logs()
		"versions":
			_section_title.text = "Sürümler"
			_build_versions()
		"settings":
			_section_title.text = "Ayarlar"
			_build_settings()
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

## Learns the next level of a skill tree node. Returns true on success.
func learn_skill(id: String) -> bool:
	var ok := skill_tree.buy(id)
	if not ok and skill_tree.nodes.has(id):
		if not skill_tree.is_unlocked(id):
			notify("Önce: %s" % skill_tree.requirement_text(id))
		elif not skill_tree.is_maxed(id):
			notify("Yeterli altının yok.")
	_check_achievements()
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


## Deletes a character for good (its items stay in the backpack).
func delete_character(id: int) -> bool:
	var ok := inventory.delete_character(id)
	if ok:
		notify("Karakter silindi.")
	refresh()
	return ok


## Asks first, then deletes.
func ask_delete_character(id: int) -> void:
	var c := inventory.character(id)
	if c.is_empty():
		return
	confirm("%s silinsin mi?" % c.name, "Karakter kalıcı olarak silinir. Üzerindeki eşyalar ortak çantada kalır.", "Sil", delete_character.bind(id))


## A yes/no question over the menu; `on_yes` runs only after "yes".
## `danger`: the yes button is red (it deletes something).
func confirm(question: String, detail: String, yes_text: String, on_yes: Callable, danger := true) -> void:
	close_confirm()
	_confirm_layer = ColorRect.new()
	(_confirm_layer as ColorRect).color = Color(0, 0, 0, 0.6)
	_confirm_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_confirm_layer)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.add_child(center)
	var panel := PanelContainer.new()
	var style := _card_style(Color("#ff5a5a"), 2)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size.x = 420
	panel.add_child(box)
	box.add_child(UiTheme.label(question, UiTheme.label_settings(24, UiTheme.TEXT, 3)))
	var info := UiTheme.label(detail, UiTheme.label_settings(16, UiTheme.MUTED, 2))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(row)
	var no := Button.new()
	no.text = "Vazgeç"
	no.custom_minimum_size = Vector2(120, 40)
	no.pressed.connect(close_confirm)
	row.add_child(no)
	var yes := Button.new()
	yes.text = yes_text
	yes.custom_minimum_size = Vector2(140, 40)
	if danger:
		_danger(yes)
	yes.pressed.connect(func() -> void:
		close_confirm()
		on_yes.call())
	row.add_child(yes)


func close_confirm() -> void:
	if _confirm_layer:
		_confirm_layer.queue_free()
		_confirm_layer = null


func is_confirm_open() -> bool:
	return _confirm_layer != null


## Red styling for buttons that delete something.
func _danger(button: Button) -> void:
	for state: String in ["normal", "hover", "pressed"]:
		var st := UiTheme.box(Color("#7a2323") if state != "hover" else Color("#9a2d2d"), 8, 6)
		button.add_theme_stylebox_override(state, st)
	button.add_theme_color_override("font_color", Color("#ffe0e0"))


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
	_check_achievements()
	refresh()
	return true


func _check_achievements() -> void:
	if achievements:
		achievements.call("check")


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
	_online_label = UiTheme.label("", UiTheme.label_settings(15, UiTheme.MUTED, 0))
	_online_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_online_label)
	if OS.has_feature("web"):
		var download := Button.new()
		download.text = "Masaüstü sürümünü indir"
		download.tooltip_text = "Windows için: bir kere indir, anında açılır."
		download.add_theme_font_size_override("font_size", 14)
		download.size_flags_horizontal = Control.SIZE_SHRINK_END
		download.pressed.connect(func() -> void: OS.shell_open(DESKTOP_DOWNLOAD))
		right.add_child(download)
	return bar


func _build_nav() -> Control:
	var nav := VBoxContainer.new()
	nav.custom_minimum_size = Vector2(230, 0)
	nav.add_theme_constant_override("separation", 4)
	var play_button := UiTheme.primary_button("OYNA")
	play_button.custom_minimum_size = Vector2(0, 58)
	play_button.pressed.connect(play)
	nav.add_child(play_button)
	for entry: Array in NAV:
		var button := Button.new()
		button.text = "  " + str(entry[1])
		button.toggle_mode = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 34)
		button.add_theme_font_size_override("font_size", 17)
		button.icon = PixelIcons.texture(str(entry[2]), UiTheme.ACCENT)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 22)
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
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 6)
		var pick := Button.new()
		pick.text = "Aktif" if is_active else "Seç"
		pick.disabled = is_active
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.add_theme_font_size_override("font_size", 18)
		pick.pressed.connect(select_character.bind(int(c.id)))
		buttons.add_child(pick)
		var remove := Button.new()
		remove.text = "Sil"
		remove.tooltip_text = "Karakteri sil (onay sorar)"
		remove.add_theme_font_size_override("font_size", 16)
		_danger(remove)
		remove.pressed.connect(ask_delete_character.bind(int(c.id)))
		buttons.add_child(remove)
		col.add_child(buttons)
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


## Equipment: the character standing at the top left with its slots beside
## it at body height (helmet by the head, armor by the chest, boots by the
## feet; ring, gloves at hand height and weapon in a second column), the
## gear totals on the right and the items it can put on below. Hover a slot
## or card to see the stats; click a worn slot to take it off.
func _build_equipment() -> void:
	var c := inventory.active_character()
	if c.is_empty():
		_text("Önce bir karakter oluştur.", 20, UiTheme.MUTED)
		return
	var info := inventory.class_info(str(c["class"]))
	var class_color := Color(str(info.color))

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	_content.add_child(top)
	top.add_child(_paper_doll(c, class_color))
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 4)
	top.add_child(side)
	side.add_child(UiTheme.label(str(c.name), UiTheme.label_settings(28, class_color.lightened(0.2), 5)))
	side.add_child(UiTheme.label(str(info.name), UiTheme.label_settings(15, UiTheme.MUTED, 3)))
	var gap := Control.new()
	gap.custom_minimum_size.y = 10
	side.add_child(gap)
	side.add_child(UiTheme.label("Ekipman bonusu", UiTheme.label_settings(17, UiTheme.ACCENT, 3)))
	var any := false
	for a: Dictionary in inventory.gear.affixes:
		var v := inventory.gear_total(c, str(a.stat))
		if v > 0.0:
			any = true
			side.add_child(UiTheme.label(inventory.gear.stat_text(str(a.stat), v), UiTheme.label_settings(15, Color("#8fe39a"), 3)))
	if not any:
		side.add_child(UiTheme.label("Henüz ekipman yok.", UiTheme.label_settings(15, UiTheme.MUTED, 3)))
	var hint := UiTheme.label("Eşyanın üstüne gelince özellikleri görünür. Takılı eşyaya tıklayınca çıkar.", UiTheme.label_settings(12, UiTheme.MUTED, 2))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 220
	side.add_child(hint)

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


const DOLL_SIZE := Vector2(170, 320)
const DOLL_SLOT := 58.0
## [slot, column (0 = next to the body, 1 = outer), body height it lines up with]
const DOLL_SLOTS := [
	["helmet", 0, 1.8], ["armor", 0, 1.1], ["boots", 0, 0.2],
	["ring", 1, 1.8], ["gloves", 1, 0.95], ["weapon", 1, 0.2],
]


## The standing character with its equipment slots placed at body height.
func _paper_doll(c: Dictionary, color: Color) -> Control:
	var doll := Control.new()
	var col_x := [DOLL_SIZE.x + 22.0, DOLL_SIZE.x + 22.0 + DOLL_SLOT + 12.0]
	doll.custom_minimum_size = Vector2(col_x[1] + DOLL_SLOT, DOLL_SIZE.y)
	var stage := _stage(color)
	var view := DOLL_SIZE - Vector2(8, 8)
	var preview: SubViewportContainer = CharacterPreview.new()
	preview.call("setup", inventory.character_look(c), view, 2, true)
	stage.add_child(preview)
	doll.add_child(stage)
	for entry: Array in DOLL_SLOTS:
		var slot_id := str(entry[0])
		var y := 4.0 + CharacterPreview.body_y(float(entry[2]), view.y)
		var top_y := clampf(y - DOLL_SLOT * 0.5, 18.0, DOLL_SIZE.y - DOLL_SLOT)
		var x: float = col_x[int(entry[1])]
		if int(entry[1]) == 0:
			# A faint line from the body part to its slot.
			var line := ColorRect.new()
			line.color = Color(color, 0.4)
			line.position = Vector2(DOLL_SIZE.x * 0.5 + 28.0, top_y + DOLL_SLOT * 0.5 - 1.0)
			line.size = Vector2(x - line.position.x, 2)
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			doll.add_child(line)
		var title := UiTheme.label(inventory.gear.slot_name(slot_id).to_upper(), UiTheme.label_settings(11, UiTheme.MUTED, 2))
		title.position = Vector2(x, top_y - 16.0)
		doll.add_child(title)
		var it := inventory.equipped(c, slot_id)
		var slot := _slot_button(it, slot_id, DOLL_SLOT)
		slot.position = Vector2(x, top_y)
		slot.size = Vector2(DOLL_SLOT, DOLL_SLOT)
		if not it.is_empty():
			slot.pressed.connect(unequip.bind(slot_id))
			slot.tooltip_text += "\n(çıkarmak için tıkla)"
		doll.add_child(slot)
	return doll


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
			var art := ItemArt.chest(int(ch.tier), chest_color, 84)
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
		row.add_child(ItemArt.chest(tier, color, 76))
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

	_text("Kalıcı geliştirmeler Yetenek Ağacı bölümüne taşındı.", 14, UiTheme.MUTED)


const SKILL_NODE := 58.0
const SKILL_COL := 92.0
const SKILL_ROW := 84.0
const SKILL_TOP := 40.0


## The skill tree: three branches side by side. Each node is a round button
## (click to learn the next level, hover for details); lines join a node to
## the nodes it needs and light up once those reach the required level.
func _build_skills() -> void:
	_text("Altınla kalıcı yetenekler öğren (tüm karakterler). Alttaki yetenekler, üstündekiler yeterli seviyeye gelince açılır.  ·  Öğrenilen seviye: %d" % skill_tree.points_spent(), 14, UiTheme.MUTED)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_content.add_child(row)
	for b: Dictionary in skill_tree.branches:
		row.add_child(_skill_branch(b))


func _skill_branch(b: Dictionary) -> Control:
	var color := Color(str(b.color))
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := _card_style(color.darkened(0.45), 2)
	style.bg_color = color.darkened(0.88)
	panel.add_theme_stylebox_override("panel", style)
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(SKILL_COL * 2.0 + SKILL_NODE + 16.0, SKILL_TOP + SKILL_ROW * 3.0 + SKILL_NODE + 30.0)
	panel.add_child(canvas)
	var title := UiTheme.label(UiTheme.upper(str(b.name)), UiTheme.label_settings(20, color.lightened(0.2), 4))
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 4)
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	canvas.add_child(title)
	var ids := skill_tree.branch_nodes(str(b.id))
	# Connection lines, drawn under the nodes.
	canvas.draw.connect(func() -> void:
		var origin_x := (canvas.size.x - (SKILL_COL * 2.0 + SKILL_NODE)) * 0.5
		for id: String in ids:
			var req: Dictionary = skill_tree.nodes[id].get("requires", {})
			for need: String in req:
				var met := skill_tree.level(need) >= int(req[need])
				var from := _skill_center(skill_tree.nodes[need], origin_x)
				var to := _skill_center(skill_tree.nodes[id], origin_x)
				canvas.draw_line(from, to, Color(0, 0, 0, 0.6), 7.0)
				canvas.draw_line(from, to, color if met else Color(1, 1, 1, 0.14), 3.0 if met else 2.0))
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(holder)
	holder.resized.connect(func() -> void:
		var origin_x := (holder.size.x - (SKILL_COL * 2.0 + SKILL_NODE)) * 0.5
		for child: Control in holder.get_children():
			var d: Dictionary = skill_tree.nodes[str(child.get_meta("skill"))]
			child.position = _skill_center(d, origin_x) - Vector2(SKILL_NODE * 0.5, SKILL_NODE * 0.5)
		canvas.queue_redraw())
	for id: String in ids:
		holder.add_child(_skill_node(id, color))
	return panel


func _skill_center(d: Dictionary, origin_x: float) -> Vector2:
	return Vector2(origin_x + float(d.col) * SKILL_COL + SKILL_NODE * 0.5, SKILL_TOP + float(d.row) * SKILL_ROW + SKILL_NODE * 0.5)


## One round skill button with its icon and a level badge below.
func _skill_node(id: String, color: Color) -> Control:
	var d: Dictionary = skill_tree.nodes[id]
	var lv := skill_tree.level(id)
	var open := skill_tree.is_unlocked(id)
	var maxed := skill_tree.is_maxed(id)
	var ready := skill_tree.can_buy(id)
	var box := Control.new()
	box.set_meta("skill", id)
	box.size = Vector2(SKILL_NODE, SKILL_NODE + 22.0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var button: Button = ItemSlot.new()
	button.size = Vector2(SKILL_NODE, SKILL_NODE)
	button.tooltip_text = str(d.name)
	button.set("tooltip_builder", func() -> Control: return _skill_tooltip(id, color))
	var border := UiTheme.ACCENT if maxed else (color if lv > 0 else (color.darkened(0.2) if ready else Color(1, 1, 1, 0.18)))
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style := UiTheme.box(color.darkened(0.6 if lv > 0 else 0.82), int(SKILL_NODE * 0.5), 6)
		style.set_border_width_all(4 if maxed or ready else 3)
		style.border_color = border.lightened(0.3) if state == "hover" else border
		if maxed or lv > 0:
			style.shadow_color = Color(border, 0.55)
			style.shadow_size = 8 if maxed else 4
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(learn_skill.bind(id))
	var icon := PixelIcons.rect(str(d.icon), 34)
	icon.position = Vector2((SKILL_NODE - 34.0) * 0.5, (SKILL_NODE - 34.0) * 0.5)
	icon.size = Vector2(34, 34)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not open:
		icon.modulate = Color(0.3, 0.3, 0.3, 0.8)
	button.add_child(icon)
	box.add_child(button)
	if ready:
		# A soft pulse on nodes that can be learned right now.
		var tween := button.create_tween().set_loops()
		tween.tween_property(button, "self_modulate", Color(1.35, 1.35, 1.35), 0.6)
		tween.tween_property(button, "self_modulate", Color.WHITE, 0.6)
	var badge := UiTheme.label("KİLİTLİ" if not open else ("MAKS" if maxed else "%d/%d" % [lv, skill_tree.max_level(id)]),
		UiTheme.label_settings(12, UiTheme.ACCENT if maxed else (UiTheme.MUTED if not open else color.lightened(0.3)), 3))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.position = Vector2(-20, SKILL_NODE + 1.0)
	badge.size = Vector2(SKILL_NODE + 40.0, 18)
	box.add_child(badge)
	return box


func _skill_tooltip(id: String, color: Color) -> Control:
	var d: Dictionary = skill_tree.nodes[id]
	var lv := skill_tree.level(id)
	var panel := PanelContainer.new()
	var style := UiTheme.box(Color(0.05, 0.07, 0.1, 0.97), 8, 12)
	style.set_border_width_all(2)
	style.border_color = color
	panel.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	panel.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(PixelIcons.rect(str(d.icon), 40))
	var names := VBoxContainer.new()
	names.add_child(UiTheme.label(str(d.name), UiTheme.label_settings(20, color.lightened(0.2), 4)))
	names.add_child(UiTheme.label("Seviye %d / %d" % [lv, skill_tree.max_level(id)], UiTheme.label_settings(13, UiTheme.MUTED, 3)))
	head.add_child(names)
	col.add_child(head)
	col.add_child(HSeparator.new())
	col.add_child(UiTheme.label("Şu an: " + (skill_tree.effect_text(id, lv) if lv > 0 else "yok"), UiTheme.label_settings(15, Color("#8fe39a") if lv > 0 else UiTheme.MUTED, 3)))
	if skill_tree.is_maxed(id):
		col.add_child(UiTheme.label("En yüksek seviyede", UiTheme.label_settings(14, UiTheme.ACCENT, 3)))
	else:
		col.add_child(UiTheme.label("Sonraki seviye: " + skill_tree.effect_text(id, 1), UiTheme.label_settings(15, UiTheme.TEXT, 3)))
		var afford := progression.gold() >= skill_tree.price(id)
		col.add_child(UiTheme.label("Fiyat: %d altın" % skill_tree.price(id), UiTheme.label_settings(14, UiTheme.ACCENT if afford else Color("#ff6b6b"), 3)))
	if not skill_tree.is_unlocked(id):
		col.add_child(UiTheme.label("Gerekli: " + skill_tree.requirement_text(id), UiTheme.label_settings(14, Color("#ff6b6b"), 3)))
	elif not skill_tree.is_maxed(id):
		col.add_child(UiTheme.label("Öğrenmek için tıkla", UiTheme.label_settings(12, UiTheme.MUTED, 2)))
	return panel


## Every achievement with its progress and reward; finished ones glow gold.
func _build_achievements() -> void:
	if achievements == null:
		return
	var defs: Array = achievements.get("defs")
	_text("%d / %d tamamlandı  ·  Her başarım altın ödülü verir." % [int(achievements.call("done_count")), defs.size()], 16, UiTheme.MUTED)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_content.add_child(grid)
	for d: Dictionary in defs:
		var done := bool(achievements.call("is_done", str(d.id)))
		var target := float(d.target)
		var now := minf(float(achievements.call("value", str(d.stat))), target)
		var color := UiTheme.ACCENT if done else Color("#6b7280")
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := _card_style(color, 2)
		if done:
			style.bg_color = Color(0.2, 0.17, 0.06, 0.95)
		card.add_theme_stylebox_override("panel", style)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var icon := PixelIcons.rect(str(d.icon), 36)
		icon.modulate = Color.WHITE if done else Color(1, 1, 1, 0.45)
		row.add_child(icon)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		row.add_child(info)
		var title := HBoxContainer.new()
		var name_label := UiTheme.label(str(d.name), UiTheme.label_settings(17, UiTheme.ACCENT if done else UiTheme.TEXT, 3))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.add_child(name_label)
		title.add_child(UiTheme.label("TAMAMLANDI" if done else "+%d altın" % int(d.reward), UiTheme.label_settings(12, UiTheme.ACCENT if done else Color("#ffd23f"), 2)))
		info.add_child(title)
		info.add_child(UiTheme.label(str(d.desc), UiTheme.label_settings(13, UiTheme.MUTED, 2)))
		var bar := ProgressBar.new()
		bar.max_value = target
		bar.value = now
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 8)
		var fill := StyleBoxFlat.new()
		fill.bg_color = UiTheme.ACCENT if done else Color("#5fb8ff")
		fill.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("fill", fill)
		info.add_child(bar)
		info.add_child(UiTheme.label("%s / %s" % [_short(now), _short(target)], UiTheme.label_settings(11, UiTheme.MUTED, 2)))
		grid.add_child(card)


## 1234 -> "1.234", 300 seconds shown as plain numbers.
func _short(v: float) -> String:
	var n := str(int(v))
	var out := ""
	while n.length() > 3:
		out = "." + n.right(3) + out
		n = n.left(n.length() - 3)
	return n + out


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
	_build_room()
	_header("Arkadaşlar")
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

	_friend_rows.clear()
	var friends: Array = progression.profile.friends
	if friends.is_empty():
		_text("Henüz arkadaşın yok. Kullanıcı adını yazıp ekleyebilirsin.", 18, UiTheme.MUTED)
	for friend: String in friends:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(14, 14)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(dot)
		var name_label := UiTheme.label(friend, UiTheme.label_settings(22, UiTheme.TEXT, 0))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		var state := UiTheme.label("", UiTheme.label_settings(16, UiTheme.MUTED, 0))
		line.add_child(state)
		var invite_button := Button.new()
		invite_button.text = "Odaya davet et"
		invite_button.pressed.connect(invite_friend.bind(friend))
		line.add_child(invite_button)
		var remove := Button.new()
		remove.text = "Sil"
		remove.pressed.connect(_remove_friend.bind(friend))
		line.add_child(remove)
		_content.add_child(line)
		_friend_rows[friend] = [dot, state, invite_button]
	update_friend_status()
	_who_timer = 0.0

	_header("Şu an çevrimiçi")
	_online_box = VBoxContainer.new()
	_online_box.add_theme_constant_override("separation", 6)
	_content.add_child(_online_box)
	update_online_list()

	_header("Arkadaş önerileri")
	var suggestions := friend_suggestions()
	if suggestions.is_empty():
		_text("Şimdilik öneri yok. Bu cihazda oynayan diğer oyuncular burada önerilir; çevrimiçi hesaplar gelince başka oyuncular da önerilecek.", 14, UiTheme.MUTED)
	for s: Dictionary in suggestions:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		var avatar := PanelContainer.new()
		avatar.add_theme_stylebox_override("panel", UiTheme.box(Color("#2a3a4f"), 8, 4))
		avatar.custom_minimum_size = Vector2(36, 36)
		avatar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var letter := _centered(str(s.name).left(1).to_upper(), UiTheme.label_settings(18, UiTheme.ACCENT, 2))
		letter.custom_minimum_size.x = 0
		avatar.add_child(letter)
		line.add_child(avatar)
		var who := VBoxContainer.new()
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.add_theme_constant_override("separation", 0)
		who.add_child(UiTheme.label(str(s.name), UiTheme.label_settings(19, UiTheme.TEXT, 0)))
		who.add_child(UiTheme.label("Hesap Sv. %d  ·  %s" % [int(s.level), s.reason], UiTheme.label_settings(13, UiTheme.MUTED, 0)))
		line.add_child(who)
		var add_button := Button.new()
		add_button.text = "Ekle"
		add_button.pressed.connect(func() -> void: add_friend(str(s.name)))
		line.add_child(add_button)
		_content.add_child(line)


# --- Online: rooms and invites ----------------------------------------------

## The "Birlikte Oyna" box: server status, the room (code, members, invite)
## and invites waiting for an answer.
func _build_room() -> void:
	_header("Birlikte Oyna")
	if net == null:
		_text("Çevrimiçi oyun kapalı.", 16, UiTheme.MUTED)
		return
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 10)
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(14, 14)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.color = {"online": Color("#3ddc84"), "connecting": Color("#ffc94d"), "connected": Color("#ffc94d")}.get(net.status, Color("#ff6b6b"))
	status_row.add_child(dot)
	status_row.add_child(UiTheme.label({
		"online": "Çevrimiçi: %s" % net.account,
		"connected": "Sunucuya bağlı, hesabına giriş yapılıyor...",
		"connecting": "Sunucuya bağlanıyor... (sunucu uyuyorsa ilk bağlantı 1 dakika sürebilir)",
	}.get(net.status, "Bağlantı yok, tekrar deneniyor..."), UiTheme.label_settings(17, UiTheme.TEXT, 0)))
	_content.add_child(status_row)

	if not net.in_room():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var create := UiTheme.primary_button("Oda Kur")
		create.custom_minimum_size = Vector2(150, 40)
		create.disabled = not net.is_online()
		create.pressed.connect(func() -> void: net.create_room())
		row.add_child(create)
		var code := LineEdit.new()
		code.placeholder_text = "Oda kodu (örn. K7QX2)"
		code.max_length = 5
		code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		code.text_submitted.connect(func(t: String) -> void: net.join_room(t))
		row.add_child(code)
		var join := Button.new()
		join.text = "Katıl"
		join.disabled = not net.is_online()
		join.pressed.connect(func() -> void: net.join_room(code.text))
		row.add_child(join)
		_content.add_child(row)
		_text("Oda kur, arkadaşını davet et ya da oda kodunu ver. En fazla %d kişi aynı haritada canlı oynar." % net.MAX_MEMBERS, 15, UiTheme.MUTED)
	else:
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 14)
		var code_label := UiTheme.label("Oda kodu: %s" % net.room.code, UiTheme.label_settings(26, UiTheme.ACCENT, 4))
		code_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(code_label)
		var leave := Button.new()
		leave.text = "Odadan ayrıl"
		_danger(leave)
		leave.pressed.connect(func() -> void: net.leave_room())
		top.add_child(leave)
		_content.add_child(top)
		for m: Dictionary in net.members():
			var tags := PackedStringArray()
			if int(m.id) == int(net.room.host):
				tags.append("ev sahibi")
			if int(m.id) == net.my_id:
				tags.append("sen")
			_text("•  %s%s" % [m.name, "  (%s)" % ", ".join(tags) if not tags.is_empty() else ""], 19)
		_text("Hazır olunca OYNA'ya bas: odadaki herkes seninle aynı haritada başlar." if net.is_host()
			else "Ev sahibi OYNA'ya basınca oyun başlar ve otomatik katılırsın.", 15, UiTheme.MUTED)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var who := LineEdit.new()
		who.placeholder_text = "Davet edilecek kullanıcı adı"
		who.max_length = 16
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.text_submitted.connect(func(t: String) -> void: invite_friend(t))
		row.add_child(who)
		var send := Button.new()
		send.text = "Davet et"
		send.pressed.connect(func() -> void: invite_friend(who.text))
		row.add_child(send)
		_content.add_child(row)

	for inv: Dictionary in net.invites:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var text := UiTheme.label("%s seni odasına çağırıyor" % inv.from, UiTheme.label_settings(18, Color("#8fe3ff"), 0))
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(text)
		var accept := UiTheme.primary_button("Katıl")
		accept.pressed.connect(func() -> void: net.join_room(str(inv.code)))
		line.add_child(accept)
		var ignore := Button.new()
		ignore.text = "Yok say"
		ignore.pressed.connect(func() -> void:
			net.decline_invite(str(inv.code))
			refresh_online())
		line.add_child(ignore)
		_content.add_child(line)


## Invites an online player to this player's room (opens one if needed).
func invite_friend(friend_name: String) -> void:
	friend_name = friend_name.strip_edges()
	if net == null or friend_name == "":
		return
	if not net.is_online():
		notify("Sunucuya bağlı değilsin.")
		return
	net.invite(friend_name)


## An invite arrived while in the menu.
func ask_invite(from_name: String, code: String) -> void:
	confirm("%s seni odasına çağırıyor" % from_name, "Katılırsan ev sahibi oyunu başlatınca aynı haritada birlikte oynarsınız.",
		"Katıl", func() -> void: net.join_room(code), false)


## Online state changed (connection, room, who is online): redraw what shows it.
func refresh_online() -> void:
	if net == null:
		return
	var parts := PackedStringArray()
	parts.append({"online": "● Çevrimiçi", "connecting": "● Bağlanıyor", "connected": "● Giriş yapılıyor"}.get(net.status, "● Çevrimdışı"))
	if net.in_room():
		parts.append("Oda %s · %d kişi" % [net.room.code, net.members().size()])
	if not net.invites.is_empty():
		parts.append("%d davet" % net.invites.size())
	_online_label.text = "   ".join(parts)
	if visible and section == "friends" and not is_confirm_open():
		var focus := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
		if focus is LineEdit and (focus as LineEdit).text != "":
			# Don't wipe what the player is typing; only the friend list.
			update_friend_status()
		else:
			open_section("friends")


## Online dots of the friend list (after a `who` answer).
func update_friend_status() -> void:
	for friend: String in _friend_rows:
		var row: Array = _friend_rows[friend]
		if not is_instance_valid(row[0]):
			continue
		var on: bool = net != null and net.is_online() and net.is_name_online(friend)
		(row[0] as ColorRect).color = Color("#3ddc84") if on else Color("#6b7280")
		(row[1] as Label).text = "çevrimiçi" if on else "çevrimdışı"
		(row[2] as Button).visible = on


func _process(delta: float) -> void:
	if net == null or not visible or section != "friends":
		return
	_who_timer -= delta
	if _who_timer <= 0.0:
		_who_timer = 8.0
		net.ask_who(progression.profile.friends)
		net.ask_online_list()


## The "Şu an çevrimiçi" list: everyone online, with add / invite buttons.
func update_online_list() -> void:
	if _online_box == null or not is_instance_valid(_online_box):
		return
	for child in _online_box.get_children():
		child.queue_free()
	var names: PackedStringArray = net.online_list if net and net.is_online() else PackedStringArray()
	if names.is_empty():
		_online_box.add_child(UiTheme.label("Şu an çevrimiçi başka oyuncu yok." if net and net.is_online() else "Çevrimiçi olunca burada diğer oyuncular görünür.",
			UiTheme.label_settings(15, UiTheme.MUTED, 0)))
		return
	var friends: Array = progression.profile.friends
	for n in names:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var dot := ColorRect.new()
		dot.color = Color("#3ddc84")
		dot.custom_minimum_size = Vector2(12, 12)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(dot)
		var label := UiTheme.label(n, UiTheme.label_settings(19, UiTheme.TEXT, 0))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(label)
		if not friends.has(n):
			var add := Button.new()
			add.text = "Arkadaş ekle"
			add.pressed.connect(func() -> void: add_friend(n))
			line.add_child(add)
		var invite := Button.new()
		invite.text = "Odaya davet et"
		invite.pressed.connect(invite_friend.bind(n))
		line.add_child(invite)
		_online_box.add_child(line)


## Other players to befriend: accounts that played on this device and are
## not friends yet, closest account level first.
func friend_suggestions() -> Array:
	var me: Dictionary = progression.profile
	var friends: Array = me.friends
	var out: Array = []
	for other: Dictionary in progression.store.call("other_profiles", str(me.name)):
		if friends.has(str(other.name)):
			continue
		var level := int(other.get("accountLevel", 1))
		var mutual := 0
		for f: String in other.get("friends", []):
			if friends.has(f):
				mutual += 1
		out.append({"name": str(other.name), "level": level, "mutual": mutual,
			"reason": "%d ortak arkadaş" % mutual if mutual > 0 else "Bu cihazda oynuyor"})
	var my_level := progression.account_level()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.mutual) > int(b.mutual) or (int(a.mutual) == int(b.mutual) and absi(int(a.level) - my_level) < absi(int(b.level) - my_level)))
	return out.slice(0, 6)


## Past runs, newest first: when, map, character, level, kills, time, gold.
func _build_logs() -> void:
	var history: Array = progression.profile.get("history", [])
	if history.is_empty():
		_text("Henüz kayıt yok. Bir oyun oynayınca burada görünür.", 18, UiTheme.MUTED)
		return
	_text("Son %d oyun (en yenisi üstte)." % history.size(), 15, UiTheme.MUTED)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 6)
	_content.add_child(grid)
	for head: String in ["Tarih", "Harita", "Karakter", "Seviye", "Canavar", "Süre", "Altın"]:
		grid.add_child(UiTheme.label(head, UiTheme.label_settings(15, UiTheme.ACCENT, 2)))
	for h: Dictionary in history:
		var t := int(h.get("time", 0))
		var cls := str(CLASS_NAMES.get(str(h.get("class", "")), ""))
		var cells := [str(h.get("at", "")).left(16), str(h.get("map", "")), "%s (%s)" % [h.get("character", ""), cls],
			str(int(h.get("level", 0))), str(int(h.get("kills", 0))), "%d:%02d" % [t / 60, t % 60], str(int(h.get("gold", 0)))]
		for n in cells.size():
			var color := UiTheme.TEXT if n != 1 else Color("#8fe3ff")
			grid.add_child(UiTheme.label(str(cells[n]), UiTheme.label_settings(14, color, 2)))


## What changed in each version of the game (data/changelog.json).
func _build_versions() -> void:
	if version_text != "":
		_text("Şu an oynadığın: %s" % version_text, 15, UiTheme.MUTED)
	var data: Dictionary = Config.load_json("res://data/changelog.json")
	for v: Dictionary in data.get("versions", []):
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _card_style(Color(1, 1, 1, 0.12), 1))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 3)
		card.add_child(col)
		var head := HBoxContainer.new()
		var title := UiTheme.label("v%s  ·  %s" % [v.version, v.title], UiTheme.label_settings(19, UiTheme.ACCENT, 3))
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		head.add_child(UiTheme.label(str(v.date), UiTheme.label_settings(13, UiTheme.MUTED, 2)))
		col.add_child(head)
		for note: String in v.notes:
			var line := UiTheme.label("•  " + note, UiTheme.label_settings(14, UiTheme.TEXT, 2))
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			col.add_child(line)
		_content.add_child(card)


func _settings() -> Dictionary:
	if not progression.profile.has("settings"):
		progression.profile.settings = {}
	return progression.profile.settings


## Changes one setting, saves and lets the game apply it.
func set_setting(key: String, value: Variant) -> void:
	_settings()[key] = value
	progression.store.save_to_disk()
	settings_changed.emit()


## Settings in titled groups: graphics, camera, interface and account.
func _build_settings() -> void:
	_header("Grafik")
	var q_row := HBoxContainer.new()
	q_row.add_theme_constant_override("separation", 8)
	q_row.add_child(_setting_label("Görüntü kalitesi"))
	for entry: Array in [["low", "Düşük"], ["medium", "Orta"], ["high", "Yüksek"]]:
		var b := Button.new()
		b.text = str(entry[1])
		b.toggle_mode = true
		b.button_pressed = quality == entry[0]
		b.custom_minimum_size.x = 90
		b.pressed.connect(func() -> void:
			quality = str(entry[0])
			quality_selected.emit(quality)
			refresh())
		q_row.add_child(b)
	_content.add_child(q_row)
	_text("Düşük kalite daha hızlı çalışır (piksel daha iri).", 13, UiTheme.MUTED)

	_header("Kamera")
	_content.add_child(_slider_row("Kamera uzaklığı", "cameraZoom", 3.5, 16.0, 0.5, 7.0))
	_content.add_child(_slider_row("Fare hassasiyeti", "mouseSpeed", 0.3, 2.5, 0.1, 1.0))
	_text("Oyunda fare tekerleğiyle de yaklaşıp uzaklaşabilirsin.", 13, UiTheme.MUTED)

	_header("Arayüz")
	var dmg := CheckBox.new()
	dmg.text = "Hasar sayılarını göster"
	dmg.button_pressed = bool(_settings().get("damageNumbers", true))
	dmg.add_theme_font_size_override("font_size", 17)
	dmg.toggled.connect(func(on: bool) -> void: set_setting("damageNumbers", on))
	_content.add_child(dmg)

	_header("Hesap")
	var store: RefCounted = progression.store
	var acc_name := str(progression.profile.name)
	var remember := CheckBox.new()
	remember.text = "Bu bilgisayarda beni hatırla (girişte şifre sorma)"
	remember.button_pressed = str(store.call("remembered")) == acc_name
	remember.add_theme_font_size_override("font_size", 17)
	remember.toggled.connect(func(on: bool) -> void: store.call("set_remember", acc_name if on else ""))
	_content.add_child(remember)
	var pass_row := HBoxContainer.new()
	pass_row.add_theme_constant_override("separation", 8)
	pass_row.add_child(_setting_label("Yeni şifre"))
	var pass_edit := LineEdit.new()
	pass_edit.secret = true
	pass_edit.max_length = 32
	pass_edit.placeholder_text = "en az 4 karakter"
	pass_edit.custom_minimum_size.x = 220
	pass_row.add_child(pass_edit)
	var pass_button := Button.new()
	pass_button.text = "Şifreyi değiştir"
	pass_button.pressed.connect(func() -> void: change_password(pass_edit.text))
	pass_row.add_child(pass_button)
	_content.add_child(pass_row)
	var acc_row := HBoxContainer.new()
	acc_row.add_theme_constant_override("separation", 10)
	var logout := Button.new()
	logout.text = "Çıkış yap"
	logout.custom_minimum_size = Vector2(150, 40)
	logout.pressed.connect(func() -> void: logout_requested.emit())
	acc_row.add_child(logout)
	var reset := Button.new()
	reset.text = "Hesabı sıfırla"
	reset.custom_minimum_size = Vector2(170, 40)
	_danger(reset)
	reset.pressed.connect(ask_reset_account)
	acc_row.add_child(reset)
	_content.add_child(acc_row)
	_text("Hesabı sıfırlamak karakterleri, eşyaları, kasaları, altını, seviyeleri, yetenekleri ve başarımları siler. Geri alınamaz.", 13, Color("#ff8a8a"))


func change_password(password: String) -> bool:
	if password.length() < 4:
		notify("Şifre en az 4 karakter olmalı.")
		return false
	progression.store.call("set_password", str(progression.profile.name), password)
	if net and net.is_online():
		net.change_password(password)
	notify("Şifre değiştirildi.")
	return true


func ask_reset_account() -> void:
	confirm("Hesap sıfırlansın mı?", "Tüm karakterler, eşyalar, kasalar, altın, seviyeler, yetenekler ve başarımlar kalıcı olarak silinir. Bu işlem geri alınamaz.",
		"Evet, sıfırla", func() -> void: reset_requested.emit())


func _setting_label(text: String) -> Label:
	var l := UiTheme.label(text, UiTheme.label_settings(17, UiTheme.TEXT, 2))
	l.custom_minimum_size.x = 190
	return l


func _slider_row(text: String, key: String, low: float, high: float, step: float, fallback: float) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_setting_label(text))
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = float(_settings().get(key, fallback))
	slider.custom_minimum_size = Vector2(260, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var value := UiTheme.label("%.1f" % slider.value, UiTheme.label_settings(15, UiTheme.MUTED, 2))
	row.add_child(value)
	slider.value_changed.connect(func(v: float) -> void:
		value.text = "%.1f" % v
		_settings()[key] = v
		settings_changed.emit())
	slider.drag_ended.connect(func(_changed: bool) -> void: progression.store.save_to_disk())
	return row


# --- Small widgets -------------------------------------------------------------

## A small item card: the drawing on a rarity-colored stage, the name, who
## wears it and Kuşan / Sat buttons. Hovering shows every stat.
func _item_card(it: Dictionary, equip_only: bool) -> Control:
	var gear := inventory.gear
	var rarity := int(it.rarity)
	var color := gear.rarity_color(rarity)
	var card: PanelContainer = TooltipCard.new()
	card.custom_minimum_size = Vector2(128, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.tooltip_text = gear.item_name(it)
	card.set("tooltip_builder", func() -> Control: return ItemArt.tooltip(gear, it, CLASS_NAMES, compare_info(it)))
	var style := _card_style(color, 3 if rarity >= 4 else 2)
	style.bg_color = color.darkened(0.82)
	style.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)

	var stage := PanelContainer.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stage_style := UiTheme.box(color.darkened(0.65), 6, 4)
	stage_style.border_width_bottom = 3
	stage_style.border_color = color.darkened(0.2)
	stage.add_theme_stylebox_override("panel", stage_style)
	var art := ItemArt.make(it, color, gear.tier(rarity), 62)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stage.add_child(art)
	col.add_child(stage)

	var name_label := _centered(gear.item_name(it), UiTheme.label_settings(12, color.lightened(0.15), 3))
	name_label.custom_minimum_size.x = 114
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(name_label)
	var w := inventory.wearer(int(it.uid))
	if not w.is_empty():
		var worn := _centered("Giyen: %s" % w.name, UiTheme.label_settings(11, UiTheme.ACCENT, 2))
		worn.custom_minimum_size.x = 114
		worn.autowrap_mode = TextServer.AUTOWRAP_OFF
		worn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(worn)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	var on := Button.new()
	on.text = "Kuşan"
	on.add_theme_font_size_override("font_size", 12)
	on.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	on.disabled = not inventory.can_wear(inventory.active_character(), it)
	on.pressed.connect(equip.bind(int(it.uid)))
	buttons.add_child(on)
	if not equip_only:
		var sell_button := Button.new()
		sell_button.text = "Sat %d" % gear.sell_price(it)
		sell_button.add_theme_font_size_override("font_size", 12)
		sell_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sell_button.pressed.connect(sell.bind(int(it.uid)))
		buttons.add_child(sell_button)
	col.add_child(buttons)
	return card


## What an item is compared with in its tooltip: the item the active
## character wears in the same slot. Empty (no comparison) when there is no
## active character or the item is the one it wears.
func compare_info(it: Dictionary) -> Dictionary:
	var c := inventory.active_character()
	if c.is_empty():
		return {}
	var worn := inventory.equipped(c, inventory.gear.item_slot(it))
	if not worn.is_empty() and int(worn.uid) == int(it.uid):
		return {}
	return {"worn": worn, "who": str(c.name), "can_wear": inventory.can_wear(c, it)}


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
