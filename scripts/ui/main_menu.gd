## Main menu after login: account level, Play, and the sections
## Characters (with their worn items), new character, Equipment, Backpack
## (shared items and chests), Pets (3 slots of companions), Skill Tree
## (permanent upgrades bought with skill points), Market (chests, pet eggs),
## Achievements, Profile, Friends, Logs (past runs), Versions
## (what changed) and Settings (graphics, camera, interface, account).
extends CanvasLayer

const UiTheme := preload("res://scripts/ui/theme.gd")
const PixelIcons := preload("res://scripts/ui/pixel_icons.gd")
const Progression := preload("res://scripts/progression/progression.gd")
const SkillTree := preload("res://scripts/progression/skill_tree.gd")
const CityView := preload("res://scripts/ui/city_view.gd")
const SkillTreeView := preload("res://scripts/ui/skill_tree_view.gd")
const Inventory := preload("res://scripts/progression/inventory.gd")
const ItemArt := preload("res://scripts/ui/item_art.gd")
const ItemSlot := preload("res://scripts/ui/item_slot.gd")
const CharacterPreview := preload("res://scripts/ui/character_preview.gd")
const TooltipCard := preload("res://scripts/ui/tooltip_card.gd")
const PetIcons := preload("res://scripts/ui/pet_icons.gd")
const TavernView := preload("res://scripts/ui/tavern_view.gd")
const Config := preload("res://scripts/core/config.gd")
const Screen := preload("res://scripts/core/screen.gd")
const Daily := preload("res://scripts/progression/daily.gd")

signal play_pressed
signal duel_requested
signal world_boss_requested
## The player wants to open this chest (the game shows the wheel).
signal chest_open_requested(uid: int)
signal quality_selected(quality: String)
## A setting in profile.settings changed; the game applies it.
signal settings_changed
signal logout_requested
## The player wants to walk into the hub tavern (the game opens it).
signal hub_requested
## The player confirmed wiping the whole account.
signal reset_requested

const MAX_FRIENDS := 50
const DESKTOP_DOWNLOAD := "https://github.com/highlvmami/LumoraRPG/releases/download/latest/LumoraRPG-windows.zip"
## [section id, button text, pixel icon]
const NAV := [
	["characters", "Karakterler", "cls_warrior"],
	["equipment", "Ekipman", "armor"],
	["backpack", "Çanta", "chest"],
	["pets", "Petler", "paw"],
	["skills", "Yetenek Ağacı", "storm"],
	["market", "Market", "clover"],
	["quests", "Görevler", "scroll"],
	["worldboss", "Dünya Bossu", "skull"],
	["wardrobe", "Gardırop", "cls_mage"],
	["difficulty", "Zorluk", "sword"],
	["gems", "Taşlar", "trophy"],
	["stable", "Ahır", "paw"],
	["achievements", "Başarımlar", "skull"],
	["leaderboard", "Sıralama", "trophy"],
	["profile", "Profil", "eye"],
	["friends", "Arkadaşlar", "heart"],
	["guild", "Lonca", "shield"],
	["trade", "Ticaret", "trade"],
	["hub", "Taverna", "mug"],
	["logs", "Kayıtlar", "double_arrow"],
	["versions", "Sürümler", "staff"],
	["settings", "Ayarlar", "shield"],
]
## The town's buildings; clicking one opens its menu (its `sections` become the tabs).
const BUILDINGS := [
	{"id": "tower", "name": "Yetenek Kulesi", "style": "tower", "wall": "#6b5a8a", "roof": "#3a2f5a", "icon": "storm", "row": "back", "slot": 0, "sections": ["skills", "pets"]},
	{"id": "board", "name": "Görev Meydanı", "style": "house", "wall": "#b08a5a", "roof": "#7a3a2a", "icon": "scroll", "row": "back", "slot": 1, "sections": ["quests", "worldboss", "achievements", "leaderboard"]},
	{"id": "guildhall", "name": "Lonca Binası", "style": "hall", "wall": "#8a96a8", "roof": "#3a5a9a", "icon": "shield", "row": "back", "slot": 2, "sections": ["guild"]},
	{"id": "inn", "name": "Taverna", "style": "house", "wall": "#a5703a", "roof": "#5a3a1c", "icon": "mug", "row": "back", "slot": 3, "sections": ["hub", "friends", "trade"]},
	{"id": "barracks", "name": "Kahramanlar Evi", "style": "house", "wall": "#9a5a4a", "roof": "#5a2a22", "icon": "cls_warrior", "row": "front", "slot": 0, "sections": ["characters", "equipment", "backpack", "wardrobe"]},
	{"id": "bazaar", "name": "Pazar", "style": "market", "wall": "#b08a5a", "roof": "#d9534f", "icon": "clover", "row": "front", "slot": 1, "sections": ["market", "gems", "stable"]},
	{"id": "gate", "name": "Savaş Kapısı", "style": "gate", "wall": "#7b7f86", "roof": "#5a5e66", "icon": "sword", "row": "front", "slot": 2, "sections": ["difficulty"]},
]
## The small menu box in the bottom right corner (Ayarlar is the last one).
const UTILITY := ["profile", "logs", "versions", "settings"]
const CLASS_NAMES := {"warrior": "Savaşçı", "archer": "Okçu", "mage": "Büyücü", "rogue": "Gölge", "healer": "Şifacı"}
## Leaderboards: [id, title, where the number is in a saved game, format].
## The server (server/index.js BOARDS) uses the same ids and paths.
const LEADERBOARDS := [
	["level", "Hesap Seviyesi", ["accountLevel"], "level"],
	["kills", "Canavar Kesme", ["totalKills"], "number"],
	["bosses", "Boss Yenme", ["stats", "bossKills"], "number"],
	["bestLevel", "Karakter Seviyesi", ["bestLevel"], "level"],
	["bestTime", "Hayatta Kalma", ["stats", "bestTime"], "time"],
	["damage", "Verilen Hasar", ["stats", "damageDealt"], "number"],
	["gold", "Kazanılan Altın", ["stats", "goldEarned"], "number"],
]

var progression: Progression
var skill_tree: SkillTree
var inventory: Inventory
var food: RefCounted
## Returns the active character's duel stats (set by main).
var duel_fighter: Callable
## The duel being replayed: {a, b, winner, frames}, and its clock and bars.
var _duel: Dictionary = {}
var _duel_clock := 0.0
var _duel_bars: Array = []
var _duel_title: Label
var _duel_asked := false
## The gem picked in the gems page, waiting to be set into a socket.
var _gem_pick := ""
var _wb_asked := -10000
## Achievements (set by the game after setup).
var achievements: RefCounted
## Daily quests and the login reward (scripts/progression/daily.gd).
var daily: RefCounted
var _guild_list_asked := false
var _guild_typing := false
var _guild_tab := "main"
## The account's pets (set by the game after setup).
var pets: RefCounted
var mounts: RefCounted
var cosmetics: RefCounted
var section := "city"
## Item selected in the backpack (uid, -1 = none).
var selected_item := -1
## Backpack filters: an equipment slot ("" = all) and a rarity (-1 = all).
var bag_slot_filter := ""
var bag_rarity_filter := -1
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
var _fullscreen_button: Button
var _notice: Label
var _content: VBoxContainer
var _section_title: Label
var _tab_buttons := {}
var _city: Control
var _page: Control
var _tabs: HBoxContainer
var _back_button: Button
var _name_edit: LineEdit
var _pet_pictures: Node
## The room's tavern (kept while in a room so seated characters stay put).
var _tavern: Control
## Versions whose notes are open on the versions page.
var _open_versions := {}
## Leaderboard shown on the Sıralama page.
var board := "level"
## Leaderboards from the server: id -> {rows, me}.
var _boards := {}
## When each leaderboard was last asked for (ticks), so answers don't ask again.
var _board_asked := {}


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

	# The stage: the town, or the page of the building that was opened.
	var stage := Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(stage)
	_city = CityView.new()
	_city.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(_city)
	_city.setup(_building_defs())
	_city.building_clicked.connect(_on_building_clicked)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(panel)
	_page = panel
	var panel_box := VBoxContainer.new()
	panel_box.add_theme_constant_override("separation", 8)
	panel.add_child(panel_box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	panel_box.add_child(head)
	_back_button = Button.new()
	_back_button.text = "← Şehre dön"
	_back_button.add_theme_font_size_override("font_size", 16)
	_back_button.pressed.connect(open_section.bind("city"))
	head.add_child(_back_button)
	_section_title = UiTheme.label("", UiTheme.label_settings(26, UiTheme.ACCENT, 0))
	head.add_child(_section_title)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	panel_box.add_child(_tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_box.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_content)

	layout.add_child(_build_bottom_bar())
	open_section("city")


func _exit_tree() -> void:
	if _tavern and not _tavern.is_inside_tree():
		_tavern.queue_free()


func show_menu() -> void:
	visible = true
	refresh()


func refresh() -> void:
	_account_label.text = "%s   ·   Hesap Seviyesi %d" % [progression.profile.name, progression.account_level()]
	if skill_tree.points_left() > 0:
		_account_label.text += "   ·   %d yetenek puanı" % skill_tree.points_left()
	_account_bar.max_value = progression.exp_to_next_account_level()
	_account_bar.value = progression.account_exp()
	_account_bar.tooltip_text = "%d / %d EXP" % [progression.account_exp(), progression.exp_to_next_account_level()]
	_gold_label.text = "Altın: %d" % progression.gold()
	_sync_fullscreen_button()
	_sync_look()
	open_section(section)


func open_section(id: String) -> void:
	section = id
	if id != "hub":
		_duel_asked = false
	_city.visible = id == "city"
	_page.visible = id != "city"
	if id == "city":
		for key: String in _tab_buttons:
			(_tab_buttons[key] as Button).button_pressed = false
		return
	_rebuild_tabs(id)
	for key: String in _tab_buttons:
		(_tab_buttons[key] as Button).button_pressed = key == id or (key == "characters" and id == "create")
	for child in _content.get_children():
		_content.remove_child(child)
		if child != _tavern:
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
		"pets":
			_section_title.text = "Petler"
			_build_pets()
		"skills":
			_section_title.text = "Yetenek Ağacı"
			_build_skills()
		"market":
			_section_title.text = "Market"
			_build_market()
		"quests":
			_section_title.text = "Günlük Görevler"
			_build_quests()
		"achievements":
			_section_title.text = "Başarımlar"
			_build_achievements()
		"leaderboard":
			_section_title.text = "Sıralama"
			_build_leaderboard()
		"profile":
			_section_title.text = "Profil"
			_build_profile()
		"friends":
			_section_title.text = "Arkadaşlar"
			_build_friends()
		"guild":
			_section_title.text = "Lonca"
			_build_guild()
		"trade":
			_section_title.text = "Ticaret"
			_build_trade()
		"hub":
			_section_title.text = "Lumora Tavernası"
			_build_hub()
		"difficulty":
			_section_title.text = "Savaş Kapısı"
			_build_difficulty()
		"wardrobe":
			_section_title.text = "Gardırop"
			_build_wardrobe()
		"stable":
			_section_title.text = "Ahır"
			_build_stable()
		"gems":
			_section_title.text = "Taşlar ve Soketler"
			_build_gems()
		"worldboss":
			_section_title.text = "Dünya Bossu"
			_build_world_boss()
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
			notify("Yeterli yetenek puanın yok. Hesap seviyen arttıkça puan kazanırsın.")
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


func upgrade_item(uid: int) -> bool:
	var ok := inventory.upgrade(uid)
	if ok:
		notify("Eşya geliştirildi: %s" % inventory.gear.item_name(inventory.item(uid)))
	else:
		notify("Yeterli altının yok.")
	refresh()
	return ok


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
	# "LUMORA" with "RPG" joined on in another color.
	var logo := HBoxContainer.new()
	logo.add_theme_constant_override("separation", 0)
	logo.add_child(UiTheme.label("LUMORA", UiTheme.label_settings(40, UiTheme.ACCENT, 8)))
	logo.add_child(UiTheme.label("RPG", UiTheme.label_settings(40, Color("#ff5a4f"), 8)))
	left.add_child(logo)
	_account_label = UiTheme.label("", UiTheme.label_settings(20))
	left.add_child(_account_label)
	_account_bar = _bar(Color("#5fb8ff"), Vector2(320, 10))
	_account_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	left.add_child(_account_bar)
	var right := VBoxContainer.new()
	bar.add_child(right)
	# Gold with the full screen button beside it.
	var gold_row := HBoxContainer.new()
	gold_row.alignment = BoxContainer.ALIGNMENT_END
	gold_row.add_theme_constant_override("separation", 14)
	right.add_child(gold_row)
	var full := Button.new()
	full.text = "Pencere (F11)" if Screen.is_fullscreen() else "Tam ekran (F11)"
	full.add_theme_font_size_override("font_size", 14)
	full.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	full.pressed.connect(toggle_fullscreen)
	gold_row.add_child(full)
	_fullscreen_button = full
	_gold_label = UiTheme.label("", UiTheme.label_settings(26, UiTheme.ACCENT))
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold_row.add_child(_gold_label)
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


## The left column: Play and the section buttons. It scrolls when the window
## is too short for all of them, so nothing ends up off screen.
## Building data for the town view, with the names of what is inside.
func _building_defs() -> Array:
	var out: Array = []
	for b: Dictionary in BUILDINGS:
		var d: Dictionary = b.duplicate()
		var names := PackedStringArray()
		for id: String in b.sections:
			names.append(_nav_name(id))
		d.tip = ("İçinde: " + ", ".join(names)) if not names.is_empty() else "Maceraya başla!"
		out.append(d)
	return out


func _nav_name(id: String) -> String:
	for entry: Array in NAV:
		if str(entry[0]) == id:
			return str(entry[1])
	return id


func _nav_icon(id: String) -> String:
	for entry: Array in NAV:
		if str(entry[0]) == id:
			return str(entry[2])
	return "shield"


func _on_building_clicked(id: String) -> void:
	for b: Dictionary in BUILDINGS:
		if str(b.id) != id:
			continue
		if (b.sections as Array).is_empty():
			play()
		else:
			open_section(str(b.sections[0]))
		return


## The bottom row: the big play button, and in the corner a small box with
## the other menus (the settings are always the last one).
func _build_bottom_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 14)
	var play_button := UiTheme.primary_button("OYNA")
	play_button.custom_minimum_size = Vector2(230, 48)
	play_button.add_theme_font_size_override("font_size", 28)
	for state: String in ["normal", "hover", "pressed"]:
		var st := play_button.get_theme_stylebox(state) as StyleBoxFlat
		st.content_margin_top = 6
		st.content_margin_bottom = 6
	play_button.pressed.connect(play)
	bar.add_child(play_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _card_style(Color("#4a6a8a"), 2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	box.add_child(row)
	for id: String in UTILITY:
		var button := Button.new()
		button.text = "  " + _nav_name(id)
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 34)
		button.add_theme_font_size_override("font_size", 16)
		button.icon = PixelIcons.texture(_nav_icon(id), UiTheme.ACCENT)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 22)
		button.pressed.connect(open_section.bind(id))
		_tab_buttons[id] = button
		row.add_child(button)
	bar.add_child(box)
	return bar


## The tabs of the building a page belongs to (none for the corner menus).
func _rebuild_tabs(id: String) -> void:
	for child in _tabs.get_children():
		_tabs.remove_child(child)
		child.queue_free()
	for key: String in _tab_buttons.keys():
		if not UTILITY.has(key):
			_tab_buttons.erase(key)
	var page_id := "characters" if id == "create" else id
	for b: Dictionary in BUILDINGS:
		if not (b.sections as Array).has(page_id):
			continue
		for sid: String in b.sections:
			var button := Button.new()
			button.text = "  " + _nav_name(sid)
			button.toggle_mode = true
			button.custom_minimum_size = Vector2(0, 30)
			button.add_theme_font_size_override("font_size", 16)
			button.icon = PixelIcons.texture(_nav_icon(sid), UiTheme.ACCENT)
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 20)
			button.pressed.connect(open_section.bind(sid))
			_tab_buttons[sid] = button
			_tabs.add_child(button)
		return


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
	_header("Eşyalar (%d / %d)" % [items.size(), inventory.gear.stash_limit()])
	if items.is_empty():
		_text("Çantan boş. Canavarlar bazen eşya düşürür.", 15, UiTheme.MUTED)
		return
	_content.add_child(_bag_filters())
	var shown := backpack_items()
	if shown.is_empty():
		_text("Bu filtreye uyan eşya yok.", 15, UiTheme.MUTED)
		return
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_content.add_child(grid)
	for it: Dictionary in shown:
		grid.add_child(_item_card(it, false))


## Backpack items after the filters, rarest first; items another character
## wears go to the end.
func backpack_items() -> Array:
	var gear := inventory.gear
	var active := inventory.active_character()
	var slot_order := {}
	for i in gear.slots.size():
		slot_order[str(gear.slots[i].id)] = i
	var out: Array = inventory.items().filter(func(it: Dictionary) -> bool:
		return (bag_slot_filter == "" or gear.item_slot(it) == bag_slot_filter) and (bag_rarity_filter < 0 or int(it.rarity) == bag_rarity_filter))
	var elsewhere := func(it: Dictionary) -> bool:
		var w := inventory.wearer(int(it.uid))
		return not w.is_empty() and (active.is_empty() or int(w.id) != int(active.id))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ea: bool = elsewhere.call(a)
		var eb: bool = elsewhere.call(b)
		if ea != eb:
			return eb
		if int(a.rarity) != int(b.rarity):
			return int(a.rarity) > int(b.rarity)
		var sa := int(slot_order.get(gear.item_slot(a), 0))
		var sb := int(slot_order.get(gear.item_slot(b), 0))
		if sa != sb:
			return sa < sb
		return int(a.uid) < int(b.uid))
	return out


## Sets the backpack filters ("" / -1 = all) and redraws.
func filter_backpack(slot_id: String, rarity := -1) -> void:
	bag_slot_filter = slot_id
	bag_rarity_filter = rarity
	refresh()


## Slot buttons (with each slot's item count) and a rarity picker.
func _bag_filters() -> Control:
	var gear := inventory.gear
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	var counts := {}
	for it: Dictionary in inventory.items():
		var slot := gear.item_slot(it)
		counts[slot] = int(counts.get(slot, 0)) + 1
	var entries: Array = [["", "Tümü (%d)" % inventory.items().size()]]
	for sl: Dictionary in gear.slots:
		entries.append([str(sl.id), "%s (%d)" % [sl.name, int(counts.get(str(sl.id), 0))]])
	for entry: Array in entries:
		var b := Button.new()
		b.text = str(entry[1])
		b.toggle_mode = true
		b.button_pressed = bag_slot_filter == str(entry[0])
		b.add_theme_font_size_override("font_size", 14)
		if str(entry[0]) != "":
			b.icon = PixelIcons.texture(gear.item_icon({"base": "sword" if entry[0] == "weapon" else str(entry[0])}), UiTheme.ACCENT)
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 16)
		b.pressed.connect(filter_backpack.bind(str(entry[0]), bag_rarity_filter))
		row.add_child(b)
	var rarity := OptionButton.new()
	rarity.add_theme_font_size_override("font_size", 14)
	rarity.add_item("Tüm nadirlikler", 0)
	for r in gear.rarities.size():
		rarity.add_item(str(gear.rarity(r).name), r + 1)
		rarity.set_item_icon(r + 1, _swatch(gear.rarity_color(r)))
	rarity.select(bag_rarity_filter + 1)
	rarity.item_selected.connect(func(index: int) -> void: filter_backpack(bag_slot_filter, index - 1))
	row.add_child(rarity)
	return row


## A small square of one color (rarity marks in lists).
static func _swatch(color: Color) -> ImageTexture:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


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
		var chances := inventory.gear.chest_odds(tier)
		for r in chances.size():
			if float(chances[r]) > 0.0:
				odds.append("%s %%%s" % [inventory.gear.rarity(r).name, _percent(float(chances[r]))])
		var odds_label := UiTheme.label("  ·  ".join(odds), UiTheme.label_settings(13, UiTheme.MUTED, 0))
		odds_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(odds_label)
		row.add_child(info)
		var button := Button.new()
		button.custom_minimum_size = Vector2(140, 0)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var price := inventory.gear.chest_price(tier)
		button.text = "%d altın" % price
		if price < int(cd.price):
			button.tooltip_text = "Pazarlıkçı indirimi: %d yerine %d altın" % [int(cd.price), price]
		button.disabled = progression.gold() < price
		button.pressed.connect(buy_chest.bind(tier))
		row.add_child(button)
		_content.add_child(row)

	_header("Petler")
	_content.add_child(_egg_row())


## Buys a pet egg and shows what hatched. Returns the pet ({} if not bought).
func hatch_pet() -> Dictionary:
	var p: Dictionary = pets.hatch()
	if p.is_empty():
		notify("Yeterli altının yok." if progression.gold() < pets.egg_price() else "Pet yerin dolu. Önce birini serbest bırak.")
		return {}
	_check_achievements()
	refresh()
	_reveal_pet(p)
	return p


func equip_pet(uid: int) -> bool:
	var ok: bool = pets.equip(uid)
	if not ok:
		notify("Boş pet slotu yok. Slotlar hesap seviyesi %s'da açılır." % ", ".join((pets.cfg.slotLevels as Array).map(func(v: Variant) -> String: return str(int(v)))))
	_check_achievements()
	refresh()
	return ok


func unequip_pet(slot: int) -> void:
	pets.unequip(slot)
	refresh()


func release_pet(uid: int) -> int:
	var gold: int = pets.release(uid)
	if gold > 0:
		notify("Pet serbest bırakıldı (+%d altın)." % gold)
	_check_achievements()
	refresh()
	return gold


## Pets: the 3 slots on top (each pet standing on its stage, turned a little
## to the side; locked slots show the account level they open at), what they
## give, the account's pets (rarest first, each with a small picture), the
## collection of every pet kind (found ones in color, the rest gray, rarest
## first) and the egg shop.
func _build_pets() -> void:
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 14)
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(slots)
	for slot in pets.slot_count():
		slots.add_child(_pet_slot(slot))
	var given := PackedStringArray()
	for stat: String in pets.cfg.stats:
		var v: float = pets.total(stat)
		if v > 0.0:
			given.append(pets.stat_text(stat, v))
	_text("Petlerden gelen: " + ("  ·  ".join(given) if not given.is_empty() else "henüz yok"), 16, Color("#8fe39a") if not given.is_empty() else UiTheme.MUTED)

	_header("Petlerin (%d / %d)" % [pets.owned().size(), int(pets.cfg.maxPets)])
	if pets.owned().is_empty():
		_text("Henüz petin yok. Aşağıdan bir yumurta al!", 15, UiTheme.MUTED)
	else:
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 10)
		_content.add_child(flow)
		for p: Dictionary in pets.owned_sorted():
			flow.add_child(_pet_card(p))

	_header("Pet Koleksiyonu (%d / %d keşfedildi)" % [pets.discovered_count(), pets.kinds().size()])
	var shelf := HFlowContainer.new()
	shelf.add_theme_constant_override("h_separation", 8)
	shelf.add_theme_constant_override("v_separation", 8)
	_content.add_child(shelf)
	for k: Dictionary in pets.kinds_by_rarity():
		shelf.add_child(_collection_card(k))
	_header("Yumurta")
	_content.add_child(_egg_row())


## One kind in the collection: in color with its stats once found, gray
## with "Henüz bulunmadı" before.
func _collection_card(k: Dictionary) -> Control:
	var found: bool = pets.is_discovered(str(k.id))
	var rarity: Dictionary = pets.rarity(int(k.rarity))
	var color := Color(str(rarity.color)) if found else Color(0.45, 0.47, 0.5)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(112, 0)
	var style := _card_style(color.darkened(0.15) if found else Color(1, 1, 1, 0.1), 2 if found else 1)
	style.bg_color = color.darkened(0.82) if found else Color(0.08, 0.09, 0.11, 0.9)
	style.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	card.add_child(col)
	var pic: TextureRect = _pet_icons().call("rect", str(k.id), 72, not found)
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(pic)
	var name_label := _centered(str(k.name), UiTheme.label_settings(14, color.lightened(0.25) if found else UiTheme.MUTED, 3))
	name_label.custom_minimum_size.x = 100
	col.add_child(name_label)
	var sub := _centered(str(rarity.name) if found else "Henüz bulunmadı", UiTheme.label_settings(11, color if found else Color(UiTheme.MUTED, 0.6), 2))
	sub.custom_minimum_size.x = 100
	col.add_child(sub)
	var tips := PackedStringArray([str(k.name) + " (" + str(rarity.name) + ")", str(k.desc)])
	for stat: String in k.stats:
		tips.append(pets.stat_text(stat, float(k.stats[stat])))
	card.tooltip_text = "\n".join(tips)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	return card


## Shared small pet pictures (made on first use).
func _pet_icons() -> Node:
	if _pet_pictures == null:
		_pet_pictures = PetIcons.new()
		_pet_pictures.name = "PetPictures"
		add_child(_pet_pictures)
	return _pet_pictures


const PET_SLOT := Vector2(210, 300)


func _pet_slot(slot: int) -> Control:
	var p: Dictionary = pets.in_slot(slot)
	var open: bool = pets.is_slot_open(slot)
	var color := Color(str(pets.rarity(int(pets.info(p).rarity)).color)) if not p.is_empty() else Color(1, 1, 1, 0.25)
	var card := PanelContainer.new()
	card.custom_minimum_size = PET_SLOT
	var style := _card_style(color if open else Color(1, 1, 1, 0.1), 2 if not p.is_empty() else 1)
	if not p.is_empty():
		style.shadow_color = Color(color, 0.35)
		style.shadow_size = 10
	card.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)
	col.add_child(_centered("SLOT %d" % (slot + 1), UiTheme.label_settings(13, UiTheme.MUTED, 2)))
	if not open:
		var gap := Control.new()
		gap.custom_minimum_size.y = 70
		col.add_child(gap)
		col.add_child(_centered("KİLİTLİ", UiTheme.label_settings(24, UiTheme.MUTED, 4)))
		col.add_child(_centered("Hesap seviyesi %d olunca açılır" % pets.slot_level(slot), UiTheme.label_settings(14, UiTheme.MUTED, 2)))
		var bar := _bar(Color("#5fb8ff"), Vector2(150, 8))
		bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bar.max_value = pets.slot_level(slot)
		bar.value = progression.account_level()
		col.add_child(bar)
		return card
	if p.is_empty():
		var gap := Control.new()
		gap.custom_minimum_size.y = 80
		col.add_child(gap)
		col.add_child(_centered("Boş", UiTheme.label_settings(24, UiTheme.TEXT, 4)))
		col.add_child(_centered("Aşağıdan bir pet seçip \"Tak\"a bas.", UiTheme.label_settings(13, UiTheme.MUTED, 2)))
		return card
	var info: Dictionary = pets.info(p)
	var stage := _stage(color)
	var preview: SubViewportContainer = CharacterPreview.new()
	preview.call("setup_pet", str(p.kind), Vector2(PET_SLOT.x - 24, 150), 2, false)
	stage.add_child(preview)
	col.add_child(stage)
	col.add_child(_centered(str(info.name), UiTheme.label_settings(20, color.lightened(0.2), 4)))
	col.add_child(_centered(str(pets.rarity(int(info.rarity)).name), UiTheme.label_settings(12, color, 2)))
	for stat: String in info.stats:
		col.add_child(_centered(pets.stat_text(stat, float(info.stats[stat])), UiTheme.label_settings(13, Color("#8fe39a"), 2)))
	var off := Button.new()
	off.text = "Çıkar"
	off.add_theme_font_size_override("font_size", 13)
	off.pressed.connect(unequip_pet.bind(slot))
	col.add_child(off)
	return card


func _pet_card(p: Dictionary) -> Control:
	var info: Dictionary = pets.info(p)
	var rarity: Dictionary = pets.rarity(int(info.rarity))
	var color := Color(str(rarity.color))
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(190, 0)
	card.add_theme_stylebox_override("panel", _card_style(color.darkened(0.2), 2))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	card.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var pic_bg := PanelContainer.new()
	pic_bg.add_theme_stylebox_override("panel", UiTheme.box(color.darkened(0.75), 8, 2))
	pic_bg.add_child(_pet_icons().rect(str(p.kind), 56))
	head.add_child(pic_bg)
	var names := VBoxContainer.new()
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.add_child(UiTheme.label(str(info.name), UiTheme.label_settings(17, color.lightened(0.2), 3)))
	names.add_child(UiTheme.label(str(rarity.name), UiTheme.label_settings(12, color, 2)))
	head.add_child(names)
	col.add_child(head)
	for stat: String in info.stats:
		col.add_child(UiTheme.label(pets.stat_text(stat, float(info.stats[stat])), UiTheme.label_settings(13, Color("#8fe39a"), 2)))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	col.add_child(buttons)
	var slot: int = pets.slot_of(int(p.uid))
	if slot >= 0:
		buttons.add_child(UiTheme.label("Slot %d'de" % (slot + 1), UiTheme.label_settings(13, UiTheme.ACCENT, 2)))
	else:
		var on := Button.new()
		on.text = "Tak"
		on.add_theme_font_size_override("font_size", 13)
		on.pressed.connect(equip_pet.bind(int(p.uid)))
		buttons.add_child(on)
	var free := Button.new()
	free.text = "Bırak +%d" % int(rarity.release)
	free.tooltip_text = "Peti serbest bırak, altın kazan."
	free.add_theme_font_size_override("font_size", 12)
	free.pressed.connect(func() -> void:
		confirm("%s serbest bırakılsın mı?" % info.name, "Pet gider, %d altın kazanırsın." % int(rarity.release), "Serbest bırak", release_pet.bind(int(p.uid))))
	buttons.add_child(free)
	return card


## The pet egg on sale with its odds.
func _egg_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(PixelIcons.rect("egg", 70))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UiTheme.label(str(pets.cfg.egg.name), UiTheme.label_settings(21, UiTheme.ACCENT, 0)))
	var odds := PackedStringArray()
	var chances: Array = pets.egg_odds()
	for r in chances.size():
		var names := PackedStringArray()
		for k: Dictionary in pets.kinds():
			if int(k.rarity) == r:
				names.append(str(k.name))
		odds.append("%s (%s) %%%s" % [pets.rarity(r).name, ", ".join(names), _percent(float(chances[r]))])
	var odds_label := UiTheme.label("  ·  ".join(odds), UiTheme.label_settings(13, UiTheme.MUTED, 0))
	odds_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(odds_label)
	row.add_child(info)
	var button := Button.new()
	button.custom_minimum_size = Vector2(140, 0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.text = "%d altın" % pets.egg_price()
	button.disabled = progression.gold() < pets.egg_price()
	button.pressed.connect(hatch_pet)
	row.add_child(button)
	return row


## A popup with the pet that just hatched, turning on its stage.
func _reveal_pet(p: Dictionary) -> void:
	close_confirm()
	var info: Dictionary = pets.info(p)
	var rarity: Dictionary = pets.rarity(int(info.rarity))
	var color := Color(str(rarity.color))
	_confirm_layer = ColorRect.new()
	(_confirm_layer as ColorRect).color = Color(0, 0, 0, 0.65)
	_confirm_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_confirm_layer)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.add_child(center)
	var panel := PanelContainer.new()
	var style := _card_style(color, 3)
	style.set_content_margin_all(20)
	style.shadow_color = Color(color, 0.5)
	style.shadow_size = 24
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	col.add_child(_centered("Yumurta çatladı!", UiTheme.label_settings(18, UiTheme.MUTED, 3)))
	var stage := _stage(color)
	var preview: SubViewportContainer = CharacterPreview.new()
	preview.call("setup_pet", str(p.kind), Vector2(280, 230), 2)
	stage.add_child(preview)
	col.add_child(stage)
	col.add_child(_centered(str(info.name), UiTheme.label_settings(30, color.lightened(0.2), 6)))
	col.add_child(_centered(UiTheme.upper(str(rarity.name)), UiTheme.label_settings(15, color, 3)))
	for stat: String in info.stats:
		col.add_child(_centered(pets.stat_text(stat, float(info.stats[stat])), UiTheme.label_settings(15, Color("#8fe39a"), 2)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	if pets.slot_of(int(p.uid)) < 0:
		var put := UiTheme.primary_button("Hemen tak")
		put.add_theme_font_size_override("font_size", 20)
		put.custom_minimum_size = Vector2(140, 40)
		put.pressed.connect(func() -> void:
			close_confirm()
			equip_pet(int(p.uid)))
		row.add_child(put)
	var ok := Button.new()
	ok.text = "Harika!"
	ok.custom_minimum_size = Vector2(120, 40)
	ok.pressed.connect(close_confirm)
	row.add_child(ok)
	# A little pop.
	panel.pivot_offset = Vector2(170, 220)
	panel.scale = Vector2(0.6, 0.6)
	panel.create_tween().tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The skill tree: points and a reset button on top, a color key for the
## branches, then the tree growing out from the core skill in the middle.
func _build_skills() -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	_content.add_child(head)
	var points := UiTheme.label("Yetenek Puanı: %d" % skill_tree.points_left(), UiTheme.label_settings(24, Color("#8fe3ff"), 5))
	head.add_child(points)
	var info := UiTheme.label("Her hesap seviyesinde +%d puan. Tüm karakterler için kalıcıdır. Ortadaki Lumora Kalbi dalları açar; dışa doğru yetenekler daha çok puan ister." % SkillTree.POINTS_PER_LEVEL,
		UiTheme.label_settings(14, UiTheme.MUTED, 0))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(info)
	var reset := Button.new()
	reset.text = "Puanları sıfırla"
	reset.tooltip_text = "Öğrenilen her şeyi unut, harcanan puanları geri al."
	reset.disabled = skill_tree.points_spent() == 0
	reset.pressed.connect(func() -> void:
		confirm("Yetenekler sıfırlansın mı?", "Öğrendiğin tüm yetenekler silinir, puanların geri gelir.", "Sıfırla", func() -> void:
			skill_tree.reset()
			notify("Yetenek puanların geri verildi.")
			refresh()))
	head.add_child(reset)
	var key := HFlowContainer.new()
	key.add_theme_constant_override("h_separation", 12)
	_content.add_child(key)
	for b: Dictionary in skill_tree.branches:
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 6)
		var dot := ColorRect.new()
		dot.color = Color(str(b.color))
		dot.custom_minimum_size = Vector2(12, 12)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_child(dot)
		chip.add_child(UiTheme.label(str(b.name), UiTheme.label_settings(15, Color(str(b.color)).lightened(0.2), 2)))
		chip.add_child(UiTheme.label(str(b.get("desc", "")), UiTheme.label_settings(12, UiTheme.MUTED, 0)))
		key.add_child(chip)
	var view: Control = SkillTreeView.new()
	view.call("setup", skill_tree, learn_skill)
	var holder := Control.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_child(view)
	_content.add_child(holder)
	# Fit again whenever the page is laid out (window resized, text wrapped).
	var refit := func() -> void: _fit_tree(holder, view)
	_content.sort_children.connect(refit)
	holder.tree_exiting.connect(func() -> void:
		if _content.sort_children.is_connected(refit):
			_content.sort_children.disconnect(refit))


## Shrinks the skill tree to fit the page, so the whole tree shows without scrolling.
func _fit_tree(holder: Control, view: Control) -> void:
	if not is_instance_valid(holder) or not holder.is_inside_tree():
		return
	var scroll := _content.get_parent() as Control
	var full: Vector2 = SkillTreeView.VIEW_SIZE
	var room := Vector2(_content.size.x, scroll.size.y - holder.position.y - 6.0)
	var k := clampf(minf(room.x / full.x, room.y / full.y), 0.3, 1.0)
	view.scale = Vector2(k, k)
	view.size = full
	view.position = Vector2(maxf(0.0, (room.x - full.x * k) * 0.5), 0)
	if not is_equal_approx(holder.custom_minimum_size.y, full.y * k):
		holder.custom_minimum_size = Vector2(0, full.y * k)


## Every achievement with its progress and reward; finished ones glow gold.
## The daily login reward calendar (7 days) and today's three quests, each
## with its progress and a button to take the reward when done.
func _build_quests() -> void:
	if daily == null:
		return
	var chest_names: Array = inventory.gear.chests.map(func(c: Dictionary) -> String: return str(c.name))
	_text("Her gün giriş ödülü al ve 3 yeni görevi tamamla. Görevler gece yarısı yenilenir.", 15, UiTheme.MUTED)
	# Login calendar.
	var rewards: Array = daily.get("login_rewards")
	var today_index := int(daily.call("login_index"))
	var ready := bool(daily.call("login_ready"))
	var days := HBoxContainer.new()
	days.add_theme_constant_override("separation", 8)
	_content.add_child(days)
	for i in rewards.size():
		var taken := i < today_index or (i == today_index and not ready)
		var now := i == today_index and ready
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := _card_style(UiTheme.ACCENT if now else (Color("#5fcf6a") if taken else Color("#4b5563")), 2)
		if now:
			style.bg_color = Color(0.22, 0.18, 0.06, 0.95)
		card.add_theme_stylebox_override("panel", style)
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(box)
		var head := UiTheme.label("%d. Gün" % (i + 1), UiTheme.label_settings(14, UiTheme.ACCENT if now else UiTheme.TEXT, 2))
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(head)
		var r: Dictionary = rewards[i]
		var icon := PixelIcons.rect("chest" if r.has("chest") else "clover", 30)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.modulate = Color(1, 1, 1, 0.5) if taken else Color.WHITE
		box.add_child(icon)
		var what := UiTheme.label("ALINDI" if taken else Daily.reward_text(r, chest_names), UiTheme.label_settings(11, Color("#5fcf6a") if taken else UiTheme.MUTED, 2))
		what.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(what)
		days.add_child(card)
	var login_button := UiTheme.primary_button("Günlük ödülü al" if ready else "Yarın yeni ödül")
	login_button.disabled = not ready
	login_button.add_theme_font_size_override("font_size", 18)
	login_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	login_button.pressed.connect(func() -> void:
		var got: Dictionary = daily.call("claim_login")
		if not got.is_empty():
			notify("Günlük ödül: " + str(Daily.reward_text(got, chest_names)))
		refresh())
	_content.add_child(login_button)
	# Today's quests.
	var list: Array = daily.call("quests")
	for i in list.size():
		var q: Dictionary = list[i]
		var def: Dictionary = q.def
		var done := bool(q.done)
		var claimed := bool(q.claimed)
		var card := PanelContainer.new()
		var style := _card_style(UiTheme.ACCENT if done and not claimed else (Color("#5fcf6a") if claimed else Color("#6b7280")), 2)
		card.add_theme_stylebox_override("panel", style)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		row.add_child(PixelIcons.rect(str(def.icon), 36))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		row.add_child(info)
		info.add_child(UiTheme.label("%s  ·  %s" % [def.name, def.desc], UiTheme.label_settings(17, UiTheme.TEXT, 3)))
		var bar := ProgressBar.new()
		bar.max_value = float(q.goal)
		bar.value = float(q.progress)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 8)
		var fill := StyleBoxFlat.new()
		fill.bg_color = UiTheme.ACCENT if done else Color("#5fb8ff")
		fill.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("fill", fill)
		var track := StyleBoxFlat.new()
		track.bg_color = Color(1, 1, 1, 0.08)
		track.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("background", track)
		info.add_child(bar)
		info.add_child(UiTheme.label("%s / %s  ·  Ödül: %s" % [_short(float(q.progress)), _short(float(q.goal)), Daily.reward_text({"gold": int(def.get("gold", 0)), "chest": def.chest} if def.has("chest") else {"gold": int(def.get("gold", 0))}, chest_names)], UiTheme.label_settings(12, UiTheme.MUTED, 2)))
		var button := UiTheme.primary_button("ALINDI" if claimed else ("Ödülü al" if done else "Devam ediyor"))
		button.disabled = claimed or not done
		button.add_theme_font_size_override("font_size", 16)
		button.custom_minimum_size = Vector2(150, 40)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(func() -> void:
			var got: Dictionary = daily.call("claim", i)
			if not got.is_empty():
				notify("Görev ödülü: " + str(Daily.reward_text(got, chest_names)))
			refresh())
		row.add_child(button)
		_content.add_child(card)


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


## Leaderboards in categories: the best players online (or, offline, the
## accounts on this device), the top three in gold, silver and bronze, and
## this account's own place.
func _build_leaderboard() -> void:
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 6)
	tabs.add_theme_constant_override("v_separation", 6)
	_content.add_child(tabs)
	for entry: Array in LEADERBOARDS:
		var b := Button.new()
		b.text = str(entry[1])
		b.toggle_mode = true
		b.button_pressed = board == str(entry[0])
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(show_board.bind(str(entry[0])))
		tabs.add_child(b)
	var online: bool = net != null and net.is_online()
	var now := Time.get_ticks_msec()
	if online and now - int(_board_asked.get(board, -100000)) > 10000:
		_board_asked[board] = now
		net.ask_leaderboard(board)
	var data: Dictionary = _boards.get(board, {}) if online else local_board(board)
	var rows: Array = data.get("rows", [])
	if online and data.is_empty():
		_text("Sıralama yükleniyor...", 16, UiTheme.MUTED)
		return
	if not online:
		_text("Çevrimiçi değilsin: bu cihazdaki hesaplar sıralanıyor. Çevrimiçi olunca tüm oyuncular görünür.", 14, UiTheme.MUTED)
	var me: Dictionary = data.get("me", {})
	if not me.is_empty():
		_text("Senin sıran: %d.  ·  %s" % [int(me.rank), board_value(board, float(me.value))], 18, Color("#8fe3ff"))
	if rows.is_empty():
		_text("Henüz kimse yok.", 16, UiTheme.MUTED)
		return
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	_content.add_child(list)
	var medals := [Color("#ffd23f"), Color("#d8e1ea"), Color("#e09a5a")]
	var my_name := str(progression.profile.name).to_lower()
	for i in rows.size():
		var r: Dictionary = rows[i]
		var mine := str(r.name).to_lower() == my_name
		var color: Color = medals[i] if i < 3 else UiTheme.TEXT
		var card := PanelContainer.new()
		var style := _card_style(color if i < 3 else (Color("#8fe3ff") if mine else Color(1, 1, 1, 0.08)), 2 if i < 3 or mine else 1)
		style.set_content_margin_all(6)
		if i < 3:
			style.bg_color = color.darkened(0.85)
		card.add_theme_stylebox_override("panel", style)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		card.add_child(line)
		var place := UiTheme.label("%d." % (i + 1), UiTheme.label_settings(20 if i < 3 else 17, color, 3))
		place.custom_minimum_size.x = 44
		place.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(place)
		if i < 3:
			line.add_child(PixelIcons.rect("trophy", 24))
		var name_box := HBoxContainer.new()
		name_box.add_theme_constant_override("separation", 8)
		name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_box.add_child(UiTheme.label(str(r.name), UiTheme.label_settings(19, Color("#8fe3ff") if mine else UiTheme.TEXT, 2)))
		if board != "level":
			name_box.add_child(_level_tag(int(r.get("level", 0))))
		if mine:
			name_box.add_child(UiTheme.label("(sen)", UiTheme.label_settings(13, Color("#8fe3ff"), 0)))
		line.add_child(name_box)
		line.add_child(UiTheme.label(board_value(board, float(r.value)), UiTheme.label_settings(19, color if i < 3 else UiTheme.ACCENT, 3)))
		list.add_child(card)


## Opens one leaderboard.
func show_board(id: String) -> void:
	board = id
	refresh()


## A leaderboard arrived from the server.
func on_leaderboard(id: String, rows: Array, me: Dictionary) -> void:
	_boards[id] = {"rows": rows, "me": me}
	if visible and section == "leaderboard" and board == id and not is_confirm_open():
		open_section("leaderboard")


## The leaderboard of the accounts on this device (offline): {rows, me}.
func local_board(id: String) -> Dictionary:
	var path: Array = []
	for entry: Array in LEADERBOARDS:
		if str(entry[0]) == id:
			path = entry[2]
	var all: Array = [progression.profile] + progression.store.call("other_profiles", str(progression.profile.name))
	var rows: Array = []
	for p: Dictionary in all:
		rows.append({"name": str(p.get("name", "?")), "value": _number_at(p, path), "level": int(p.get("accountLevel", 1))})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.value) > float(b.value) or (float(a.value) == float(b.value) and int(a.level) > int(b.level)))
	var me := {}
	for i in rows.size():
		if str(rows[i].name) == str(progression.profile.name):
			me = {"rank": i + 1, "value": rows[i].value}
	return {"rows": rows.slice(0, 20), "me": me}


static func _number_at(data: Dictionary, path: Array) -> float:
	var v: Variant = data
	for k: String in path:
		v = (v as Dictionary).get(k) if v is Dictionary else null
	return float(v) if v is float or v is int else 0.0


## A leaderboard number as text: "Sv. 12", "1.234", "8:05".
func board_value(id: String, value: float) -> String:
	var fmt := "number"
	for entry: Array in LEADERBOARDS:
		if str(entry[0]) == id:
			fmt = str(entry[3])
	match fmt:
		"level":
			return "Sv. %d" % int(value)
		"time":
			return "%d:%02d" % [int(value) / 60, int(value) % 60]
		_:
			return _short(value)


## 12.0 -> "12", 2.46 -> "2.5" (chances in the market).
func _percent(v: float) -> String:
	return str(roundi(v)) if absf(v - roundf(v)) < 0.05 or v >= 10.0 else "%.1f" % v


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
		var name_box := HBoxContainer.new()
		name_box.add_theme_constant_override("separation", 8)
		name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_box.add_child(UiTheme.label(friend, UiTheme.label_settings(22, UiTheme.TEXT, 0)))
		var level_label := _level_tag(player_level(friend))
		name_box.add_child(level_label)
		line.add_child(name_box)
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
		_friend_rows[friend] = [dot, state, invite_button, level_label]
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
		_content.add_child(_room_tavern())
		_text("Masada %d / %d kişi. ★ ev sahibi." % [net.members().size(), net.MAX_MEMBERS], 14, UiTheme.MUTED)
		_text("Hazır olunca OYNA'ya bas: odadaki herkes seninle aynı haritada başlar." if net.is_host()
			else "Ev sahibi OYNA'ya basınca oyun başlar ve otomatik katılırsın.", 15, UiTheme.MUTED)
		if net.is_host() and net.members().size() == 2:
			var pvp := Button.new()
			pvp.text = "Gerçek zamanlı düello başlat"
			pvp.tooltip_text = "Odadaki diğer oyuncuyla 1'e 1 canlı dövüş. Kazanan galibiyet sayar."
			pvp.pressed.connect(func() -> void: duel_requested.emit())
			_content.add_child(pvp)
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


## The tavern with everyone in the room at the table; made when the room is
## first shown (people already there are seated), then newcomers walk in.
func _room_tavern() -> Control:
	var fresh := _tavern == null
	if fresh:
		_tavern = TavernView.new()
		_tavern.call("setup", Vector2(0, 300))
	var members: Array = []
	for m: Dictionary in net.members():
		members.append({"id": int(m.id), "name": str(m.name), "look": m.get("look", {}),
			"host": int(m.id) == int(net.room.host), "me": int(m.id) == net.my_id})
	_tavern.call("set_members", members, not fresh)
	return _tavern


## The Taverna page: what the hub is and a button to walk in (online only).
func _build_hub() -> void:
	_text("Lumora Tavernası, çevrimiçi herkesin buluştuğu büyük bir salon. İçinde yürüyebilir, sandalyelere ve tabureye oturabilir, salıncakta sallanabilir, pistte dans edebilir ve herkesle sohbet edebilirsin.", 17, UiTheme.TEXT)
	_text("E: kullan  ·  Enter: yaz  ·  Boşluk: zıpla  ·  Esc: çık", 15, UiTheme.MUTED)
	var online: bool = net != null and net.is_online()
	var enter := UiTheme.primary_button("TAVERNAYA GİR")
	enter.custom_minimum_size = Vector2(0, 64)
	enter.add_theme_font_size_override("font_size", 26)
	enter.disabled = not online
	enter.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	enter.pressed.connect(enter_hub)
	_content.add_child(enter)
	if not online:
		_text("Taverna için sunucuya bağlı olmalısın. Bağlanınca bu düğme açılır.", 15, Color("#ff8a8a"))
	_build_kitchen()
	_build_duel()


## The kitchen: fish caught at the tavern's dock can be cooked into a meal
## that helps in the next run.
func _build_kitchen() -> void:
	_header("Mutfak")
	_text("Tavernanın iskelesinde (E) olta at, tuttuğun balığı burada pişir. Yemek bir sonraki turda güç verir ve tur bitince biter.", 14, UiTheme.MUTED)
	var meal: Dictionary = food.meal()
	if meal.is_empty():
		_text("Şu an yemeğin yok.", 16, UiTheme.MUTED)
	else:
		_text("Sıradaki yemek: %s  ·  %s" % [meal.meal.name, meal.meal.desc], 16, UiTheme.ACCENT)
	var stock: Array = food.stock()
	if stock.is_empty():
		_text("Henüz balığın yok.", 15, UiTheme.MUTED)
	for entry: Dictionary in stock:
		var k: Dictionary = entry.kind
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _card_style(Color("#3a7a9a"), 2))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		card.add_child(line)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		info.add_child(UiTheme.label("%s x%d" % [k.name, int(entry.count)], UiTheme.label_settings(18, UiTheme.TEXT, 2)))
		info.add_child(UiTheme.label("%s: %s" % [k.meal.name, k.meal.desc], UiTheme.label_settings(13, UiTheme.MUTED, 0)))
		line.add_child(info)
		var eat := Button.new()
		eat.text = "Pişir ve ye"
		eat.pressed.connect(func() -> void:
			food.eat(str(k.id))
			progression.store.save_to_disk()
			open_section("hub"))
		line.add_child(eat)
		_content.add_child(card)


## Walks into the hub tavern (the game opens it).
func enter_hub() -> void:
	hub_requested.emit()


## Leaves the tavern behind once out of the room.
func _drop_tavern() -> void:
	if _tavern:
		if _tavern.get_parent():
			_tavern.get_parent().remove_child(_tavern)
		_tavern.queue_free()
		_tavern = null


## Sends this player's look (active character and gear) to the room when it changed.
func _sync_look() -> void:
	if net == null:
		return
	var c := inventory.active_character()
	var look: Dictionary = inventory.character_look(c) if not c.is_empty() else {}
	if JSON.stringify(look) != JSON.stringify(net.my_look):
		net.set_look(look)


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
## The guild or the guild list changed on the server.
func refresh_trade() -> void:
	if visible and section == "trade" and not is_confirm_open():
		open_section("trade")


## Trading with online players: offers made to you (accept / decline), your
## open offers (take back) and a new offer: who, which item, how much gold.
func _build_trade() -> void:
	if net == null or not net.is_online():
		_text("Ticaret için çevrimiçi olmalısın. Sunucuya bağlanınca bu sayfa açılır.", 16, UiTheme.MUTED)
		return
	_text("Çantandaki bir eşyayı çevrimiçi bir oyuncuya altın karşılığında teklif et (0 altın = hediye). Karşı taraf kabul edince eşya ve altın yer değiştirir. Teklifler ikiniz de çevrimiçiyken geçerli.", 14, UiTheme.MUTED)
	var gear := inventory.gear
	_header("Sana gelen teklifler")
	var incoming: Array = net.trade_offers(true)
	if incoming.is_empty():
		_text("Şimdilik teklif yok.", 15, UiTheme.MUTED)
	for o: Dictionary in incoming:
		var row := _trade_row(o, "%s sana teklif ediyor" % o.from)
		var price := int(o.price)
		var accept := UiTheme.primary_button("Al (%d altın)" % price if price > 0 else "Hediyeyi al")
		accept.custom_minimum_size = Vector2(150, 36)
		var short := int(progression.profile.gold) < price
		accept.disabled = short or inventory.stash_full()
		accept.tooltip_text = "Yeterli altının yok" if short else ("Çantan dolu" if inventory.stash_full() else "")
		accept.pressed.connect(func() -> void: net.answer_trade(int(o.id), true))
		row.add_child(accept)
		var decline := Button.new()
		decline.text = "Reddet"
		_danger(decline)
		decline.pressed.connect(func() -> void: net.answer_trade(int(o.id), false))
		row.add_child(decline)
	var mine: Array = net.trade_offers(false)
	if not mine.is_empty():
		_header("Senin tekliflerin")
		for o: Dictionary in mine:
			var row := _trade_row(o, "%s için · %d altın" % [o.to, int(o.price)])
			var cancel := Button.new()
			cancel.text = "Geri al"
			cancel.pressed.connect(func() -> void: net.cancel_trade(int(o.id)))
			row.add_child(cancel)

	_header("Yeni teklif")
	var form := HBoxContainer.new()
	form.add_theme_constant_override("separation", 10)
	var to := LineEdit.new()
	to.placeholder_text = "Oyuncu adı"
	to.max_length = 16
	to.custom_minimum_size.x = 200
	form.add_child(to)
	var friends: Array = progression.profile.friends
	if not friends.is_empty():
		var pick := OptionButton.new()
		pick.add_item("Arkadaş seç")
		for f: String in friends:
			pick.add_item(f)
		pick.item_selected.connect(func(i: int) -> void:
			if i > 0:
				to.text = pick.get_item_text(i))
		form.add_child(pick)
	form.add_child(UiTheme.label("Fiyat:", UiTheme.label_settings(16, UiTheme.TEXT, 0)))
	var price_box := SpinBox.new()
	price_box.min_value = 0
	price_box.max_value = 1000000
	price_box.step = 10
	price_box.value = 100
	price_box.custom_minimum_size.x = 130
	form.add_child(price_box)
	_content.add_child(form)
	var offered: Array = net.offered_uids()
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var any := false
	for it: Dictionary in inventory.items():
		if offered.has(int(it.uid)):
			continue
		any = true
		var color := gear.rarity_color(int(it.rarity))
		var b := Button.new()
		b.text = gear.item_name(it)
		b.custom_minimum_size = Vector2(170, 34)
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_color", color.lightened(0.2))
		b.tooltip_text = "%s'a teklif et" % gear.item_name(it)
		if not inventory.wearer(int(it.uid)).is_empty():
			b.text += " (giyili)"
		b.pressed.connect(func() -> void:
			if to.text.strip_edges() == "":
				notify("Önce kime teklif edeceğini yaz.")
				return
			net.offer_trade(to.text, it, int(price_box.value)))
		grid.add_child(b)
	if not any:
		_text("Çantanda teklif edilecek eşya yok.", 15, UiTheme.MUTED)
	else:
		_text("Oyuncuyu ve fiyatı seç, sonra teklif etmek istediğin eşyaya tıkla:", 14, UiTheme.MUTED)
	_content.add_child(grid)


func _trade_row(o: Dictionary, caption: String) -> HBoxContainer:
	var gear := inventory.gear
	var it: Dictionary = o.item
	var known := not gear.base(str(it.get("base", ""))).is_empty()
	var color := gear.rarity_color(int(it.get("rarity", 0))) if known else UiTheme.MUTED
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style(color, 2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	if known:
		var art := ItemArt.make(it, color, gear.tier(int(it.rarity)), 40)
		art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(art)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	info.add_child(UiTheme.label(gear.item_name(it) if known else "Bilinmeyen eşya", UiTheme.label_settings(17, color.lightened(0.15), 2)))
	var stats := "  ·  ".join(gear.stat_lines(it)) if known and it.get("stats") is Dictionary else ""
	info.add_child(UiTheme.label(caption + ("   " + stats if stats != "" else ""), UiTheme.label_settings(13, UiTheme.MUTED, 0)))
	row.add_child(info)
	_content.add_child(card)
	return row


func refresh_guild() -> void:
	if visible and section == "guild" and not is_confirm_open():
		open_section("guild")


## Your guild (members, chat, leave, kick) or, without one, creating a
## guild and the list of guilds to join. Needs the online server.
func _build_guild() -> void:
	if net == null or not net.is_online():
		_text("Lonca için çevrimiçi olmalısın. Sunucuya bağlanınca bu sayfa açılır.", 16, UiTheme.MUTED)
		return
	if not net.in_guild():
		_text("Bir loncaya katıl ya da kendi loncanı kur. Lonca üyeleri turlarda %%%d fazla altın kazanır, taverna adlarında lonca etiketi görünür." % roundi(0.05 * 100.0), 15, UiTheme.MUTED)
		_header("Lonca kur")
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_edit := LineEdit.new()
		name_edit.placeholder_text = "Lonca adı (3-20 harf)"
		name_edit.max_length = 20
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_edit)
		var tag_edit := LineEdit.new()
		tag_edit.placeholder_text = "Etiket (2-4)"
		tag_edit.max_length = 4
		tag_edit.custom_minimum_size.x = 130
		row.add_child(tag_edit)
		var create := UiTheme.primary_button("Kur")
		create.custom_minimum_size = Vector2(110, 40)
		create.pressed.connect(func() -> void: net.create_guild(name_edit.text, tag_edit.text))
		row.add_child(create)
		_content.add_child(row)
		_header("Loncalar")
		if net.guild_list.is_empty():
			_text("Henüz lonca yok. İlk loncayı sen kur!", 15, UiTheme.MUTED)
		for g: Dictionary in net.guild_list:
			var card := PanelContainer.new()
			card.add_theme_stylebox_override("panel", _card_style(Color("#3a5a9a"), 2))
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 12)
			card.add_child(line)
			var title := UiTheme.label("[%s] %s" % [g.get("tag", ""), g.get("name", "")], UiTheme.label_settings(18, UiTheme.TEXT, 2))
			title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(title)
			line.add_child(UiTheme.label("%d / 20 üye  ·  Lider: %s" % [int(g.get("members", 0)), g.get("leader", "")], UiTheme.label_settings(13, UiTheme.MUTED, 2)))
			var join := Button.new()
			join.text = "Katıl"
			join.disabled = int(g.get("members", 0)) >= 20
			join.pressed.connect(func() -> void: net.join_guild(str(g.name)))
			line.add_child(join)
			_content.add_child(card)
		if not _guild_list_asked:
			_guild_list_asked = true
			net.ask_guild_list()
		else:
			_guild_list_asked = false
		return
	var g: Dictionary = net.guild
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	var title := UiTheme.label("[%s] %s" % [g.tag, g.name], UiTheme.label_settings(26, Color("#9fc3ff"), 4))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var leave := Button.new()
	leave.text = "Loncadan ayrıl"
	_danger(leave)
	leave.pressed.connect(func() -> void: net.leave_guild())
	top.add_child(leave)
	_content.add_child(top)
	_text("%d / %d üye" % [(g.members as Array).size(), int(g.get("upgrades", {}).get("maxMembers", 20))], 14, UiTheme.MUTED)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	for t: Array in [["main", "Genel"], ["members", "Üyeler"], ["chat", "Sohbet"], ["upgrades", "Yükseltmeler"]]:
		var tb := Button.new()
		tb.text = str(t[0] == _guild_tab and "● " or "") + str(t[1])
		tb.toggle_mode = true
		tb.button_pressed = t[0] == _guild_tab
		tb.pressed.connect(func() -> void:
			_guild_tab = str(t[0])
			open_section("guild"))
		tabs.add_child(tb)
	_content.add_child(tabs)
	match _guild_tab:
		"members":
			_build_guild_members(g)
		"chat":
			_build_guild_chat(g)
		"upgrades":
			_build_guild_upgrades(g)
		_:
			_build_guild_goal(g)
			_build_guild_bonuses(g)


## The guild's member list (leaders can remove members).
func _build_guild_members(g: Dictionary) -> void:
	var members := VBoxContainer.new()
	members.add_theme_constant_override("separation", 4)
	_content.add_child(members)
	for m: Dictionary in g.members:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.color = Color("#3ddc84") if bool(m.online) else Color("#6b7280")
		row.add_child(dot)
		var leader: bool = str(m.name).to_lower() == str(g.leader).to_lower()
		var who := UiTheme.label(("★ " if leader else "") + str(m.name), UiTheme.label_settings(16, UiTheme.ACCENT if leader else UiTheme.TEXT, 2))
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(who)
		row.add_child(_level_tag(int(m.level)))
		if net.is_guild_leader() and not leader:
			var kick := Button.new()
			kick.text = "Çıkar"
			kick.add_theme_font_size_override("font_size", 12)
			kick.pressed.connect(func() -> void: net.kick_from_guild(str(m.name)))
			row.add_child(kick)
		members.add_child(row)


## The guild chat.
func _build_guild_chat(g: Dictionary) -> void:
	# Guild chat.
	var chat := VBoxContainer.new()
	chat.add_theme_constant_override("separation", 6)
	_content.add_child(chat)
	var log_panel := PanelContainer.new()
	log_panel.add_theme_stylebox_override("panel", _card_style(Color("#3a5a9a"), 1))
	log_panel.custom_minimum_size.y = 250
	chat.add_child(log_panel)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 2)
	log_panel.add_child(lines)
	var recent: Array = (g.chat as Array).slice(-11)
	if recent.is_empty():
		lines.add_child(UiTheme.label("Lonca sohbeti boş. İlk mesajı yaz!", UiTheme.label_settings(13, UiTheme.MUTED, 0)))
	for l: Dictionary in recent:
		var text := UiTheme.label("%s: %s" % [l.name, l.text], UiTheme.label_settings(14, UiTheme.TEXT, 0))
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lines.add_child(text)
	var say := LineEdit.new()
	say.placeholder_text = "Loncaya yaz ve Enter'a bas"
	say.max_length = 200
	say.text_submitted.connect(func(t: String) -> void:
		if net.send_guild_chat(t):
			say.text = ""
			_guild_typing = true)
	chat.add_child(say)
	if _guild_typing:
		_guild_typing = false
		say.grab_focus.call_deferred()


## What the guild's upgrades give every member right now.
func _build_guild_bonuses(g: Dictionary) -> void:
	_header("Lonca bonusları")
	var parts := PackedStringArray(["Altın +%%%d" % roundi((0.05 + net.guild_bonus("goldGain")) * 100.0)])
	for pair: Array in [["expGain", "EXP"], ["damage", "Hasar"]]:
		if net.guild_bonus(str(pair[0])) > 0.0:
			parts.append("%s +%%%d" % [pair[1], roundi(net.guild_bonus(str(pair[0])) * 100.0)])
	if net.guild_bonus("maxHp") > 0.0:
		parts.append("Can +%d" % roundi(net.guild_bonus("maxHp")))
	_text("  ·  ".join(parts), 16, UiTheme.TEXT)
	_text("Bonuslar lonca kasasından alınan yükseltmelerle büyür (Yükseltmeler sekmesi).", 13, UiTheme.MUTED)


## The treasury: members donate gold, the leader spends it on upgrades.
func _build_guild_upgrades(g: Dictionary) -> void:
	var up: Dictionary = g.get("upgrades", {})
	if up.is_empty():
		_text("Yükseltme bilgisi bekleniyor...", 15, UiTheme.MUTED)
		return
	_text("Lonca kasası: %d altın" % int(up.treasury), 22, UiTheme.ACCENT)
	var give := HBoxContainer.new()
	give.add_theme_constant_override("separation", 8)
	var amount := LineEdit.new()
	amount.placeholder_text = "Bağış (altın)"
	amount.custom_minimum_size.x = 160
	give.add_child(amount)
	var donate := UiTheme.primary_button("Bağışla")
	donate.pressed.connect(func() -> void:
		var n := int(amount.text)
		if n < 1 or n > progression.gold():
			notify("Geçerli bir miktar yaz (en çok %d)." % progression.gold())
			return
		net.donate_guild(n))
	give.add_child(donate)
	_content.add_child(give)
	if not (up.donors as Array).is_empty():
		var names := PackedStringArray()
		for d: Dictionary in up.donors:
			names.append("%s %d" % [d.name, int(d.gold)])
		_text("En cömertler: " + ", ".join(names), 13, UiTheme.MUTED)
	_header("Yükseltmeler" + ("" if net.is_guild_leader() else " (sadece lider alabilir)"))
	var per := {"gold": "+%2 altın", "exp": "+%3 EXP", "damage": "+%2 hasar", "health": "+8 can", "size": "+4 üye kapasitesi"}
	for id: String in ["gold", "exp", "damage", "health", "size"]:
		var lv := int(up.levels[id])
		var cost := int(up.costs[id])
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _card_style(Color("#3a5a9a"), 2))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		card.add_child(line)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		info.add_child(UiTheme.label("%s  (Sv. %d / 5)" % [up.names[id], lv], UiTheme.label_settings(18, UiTheme.TEXT, 2)))
		info.add_child(UiTheme.label("Her seviye: " + str(per[id]), UiTheme.label_settings(13, UiTheme.MUTED, 0)))
		line.add_child(info)
		var buy := UiTheme.primary_button("En üst seviye" if cost == 0 else "Al: %d altın" % cost)
		buy.disabled = cost == 0 or not net.is_guild_leader() or int(up.treasury) < cost
		buy.pressed.connect(func() -> void: net.upgrade_guild(id))
		line.add_child(buy)
		_content.add_child(card)


## The weekly guild goal: a progress bar, the best helpers and the reward button.
func _build_guild_goal(g: Dictionary) -> void:
	var q: Dictionary = g.get("quest", {})
	if q.is_empty():
		return
	var goal := maxi(1, int(q.goal))
	var progress := int(q.progress)
	var done := progress >= goal
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_style(Color("#e0b341") if done else Color("#3a5a9a"), 2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 3)
	row.add_child(left)
	var days := int(float(q.endsIn) / 86400000.0)
	left.add_child(UiTheme.label("Haftalık hedef: %d canavar yen  ·  %d gün kaldı" % [goal, days], UiTheme.label_settings(16, Color("#ffd23f"), 3)))
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = goal
	bar.value = mini(progress, goal)
	bar.custom_minimum_size.y = 18
	bar.show_percentage = false
	left.add_child(bar)
	var helpers := PackedStringArray()
	for t: Dictionary in q.get("top", []):
		helpers.append("%s %d" % [t.name, int(t.kills)])
	left.add_child(UiTheme.label("%d / %d" % [mini(progress, goal), goal] + ("   ·   En çok katkı: " + ", ".join(helpers) if not helpers.is_empty() else ""), UiTheme.label_settings(13, UiTheme.MUTED, 0)))
	var claimed: bool = (q.claimed as Array).has(net.account.to_lower())
	var claim := UiTheme.primary_button("Ödülü al: %d altın" % int(q.reward) if not claimed else "Ödül alındı")
	claim.disabled = not done or claimed
	claim.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	claim.pressed.connect(func() -> void: net.claim_guild_reward())
	row.add_child(claim)
	_content.add_child(panel)


func refresh_online() -> void:
	if net == null:
		return
	if not net.in_room():
		_drop_tavern()
	if visible and section == "hub" and not is_confirm_open():
		open_section("hub")
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
		_set_level_tag(row[3] as Label, player_level(friend))


func _process(delta: float) -> void:
	_play_duel(delta)
	if net == null or not visible or section != "friends":
		return
	_who_timer -= delta
	if _who_timer <= 0.0:
		_who_timer = 8.0
		net.ask_who(progression.profile.friends)
		net.ask_online_list()


## The duel arena (in the Taverna page): challenge someone who is online,
## answer challenges and watch the replay of the fight.
func _build_duel() -> void:
	_header("Düello Arenası")
	_text("Çevrimiçi bir oyuncuyu düelloya çağır. Sunucu, iki karakterin gücüyle (can, hasar, hız, kritik, savunma) dövüşü oynatır; ikiniz de aynı tekrarı izlersiniz. Kazanan galibiyet sayar.", 14, UiTheme.MUTED)
	var profile: Dictionary = progression.profile
	var st: Dictionary = profile.get("stats", {})
	_text("Galibiyet: %d  ·  Yenilgi: %d" % [int(st.get("duelsWon", 0)), int(st.get("duelsLost", 0))], 16, UiTheme.ACCENT)
	if net == null or not net.is_online():
		_text("Düello için sunucuya bağlı olmalısın.", 15, Color("#ff8a8a"))
		return
	_duel_bars.clear()
	if not _duel.is_empty():
		_build_duel_replay()
	for inv: Dictionary in net.duel_invites:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var who := UiTheme.label("%s seni düelloya çağırıyor (%s)" % [inv.from, CLASS_NAMES.get(inv.cls, "?")], UiTheme.label_settings(16, Color("#ffd23f"), 2))
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(who)
		var yes := UiTheme.primary_button("Kabul")
		yes.pressed.connect(func() -> void: net.answer_duel(str(inv.from), true, duel_fighter.call()))
		line.add_child(yes)
		var no := Button.new()
		no.text = "Reddet"
		no.pressed.connect(func() -> void: net.answer_duel(str(inv.from), false, {}))
		line.add_child(no)
		_content.add_child(line)
	if not _duel_asked:
		_duel_asked = true
		net.ask_online_list()
		net.ask_duel_inbox()
	var names: PackedStringArray = net.online_list
	if names.is_empty():
		_text("Şu an çevrimiçi başka oyuncu yok.", 15, UiTheme.MUTED)
	for n in names.slice(0, 8):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var nm := UiTheme.label(n + (_level_suffix(n)), UiTheme.label_settings(16, UiTheme.TEXT, 2))
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		var ch := Button.new()
		ch.text = "Düelloya çağır"
		ch.pressed.connect(func() -> void: net.challenge_duel(n, duel_fighter.call()))
		row.add_child(ch)
		_content.add_child(row)


func _level_suffix(player_name: String) -> String:
	var lv := int(net.levels.get(player_name, 0)) if net.get("levels") is Dictionary else 0
	return "  Sv. %d" % lv if lv > 0 else ""


## Two health bars that follow the server's replay of the fight.
func _build_duel_replay() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_style(Color("#d9534f"), 2))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	_duel_title = UiTheme.label("", UiTheme.label_settings(20, Color("#ffd23f"), 3))
	box.add_child(_duel_title)
	for side in 2:
		var f: Dictionary = _duel.a if side == 0 else _duel.b
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var nm := UiTheme.label("%s (%s)" % [f.name, CLASS_NAMES.get(str(f.cls), "?")], UiTheme.label_settings(15, UiTheme.TEXT, 2))
		nm.custom_minimum_size.x = 230
		row.add_child(nm)
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = float(f.hp)
		bar.value = float(f.hp)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 20)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bar)
		_duel_bars.append(bar)
		box.add_child(row)
	_content.add_child(panel)


## A duel was played: replay it (and count it for this account).
func show_duel(result: Dictionary) -> void:
	_duel = result
	_duel_clock = 0.0
	var me: String = str(net.account).to_lower()
	var winner := int(result.winner)
	if winner >= 0:
		var mine: bool = str((result.a if winner == 0 else result.b).name).to_lower() == me
		achievements.add("duelsWon" if mine else "duelsLost")
		achievements.check()
		progression.store.save_to_disk()
	if visible and section == "hub":
		open_section("hub")


func _play_duel(delta: float) -> void:
	if _duel.is_empty() or _duel_bars.is_empty() or not visible or section != "hub":
		return
	_duel_clock += delta * 3.0
	var frames: Array = _duel.frames
	var last: Array = frames[0]
	for f: Array in frames:
		if float(f[0]) <= _duel_clock:
			last = f
	for i in 2:
		if is_instance_valid(_duel_bars[i]):
			(_duel_bars[i] as ProgressBar).value = float(last[i + 1])
	var done: bool = _duel_clock >= float((frames[-1] as Array)[0])
	if _duel_title and is_instance_valid(_duel_title):
		var w := int(_duel.winner)
		_duel_title.text = ("%s kazandı!" % (_duel.a if w == 0 else _duel.b).name if w >= 0 else "Berabere!") if done else "Düello sürüyor... %.0f sn" % _duel_clock


## Duel invites changed on the server.
func refresh_duel() -> void:
	if visible and section == "hub" and not is_confirm_open():
		open_section("hub")


## The "Şu an çevrimiçi" list: everyone online, with add / invite buttons.
func update_online_list() -> void:
	if visible and section == "hub":
		refresh_duel()
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
		var name_box := HBoxContainer.new()
		name_box.add_theme_constant_override("separation", 8)
		name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_box.add_child(UiTheme.label(n, UiTheme.label_settings(19, UiTheme.TEXT, 0)))
		name_box.add_child(_level_tag(player_level(n)))
		line.add_child(name_box)
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


## Account level of another player: what the server said, else this
## device's copy of their account (0 when unknown).
func player_level(player_name: String) -> int:
	if net != null and net.level_of(player_name) > 0:
		return net.level_of(player_name)
	for other: Dictionary in progression.store.call("other_profiles", str(progression.profile.name)):
		if str(other.name).to_lower() == player_name.to_lower():
			return int(other.get("accountLevel", 1))
	return 0


## A small, faint "Sv. 12" next to a player's name.
func _level_tag(level: int) -> Label:
	var tag := UiTheme.label("", UiTheme.label_settings(14, Color(UiTheme.TEXT, 0.45), 0))
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_set_level_tag(tag, level)
	return tag


func _set_level_tag(tag: Label, level: int) -> void:
	tag.text = "Sv. %d" % level if level > 0 else ""
	tag.tooltip_text = "Hesap seviyesi"
	tag.mouse_filter = Control.MOUSE_FILTER_PASS


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
## The gate: pick the difficulty for the next runs. Nightmare levels open
## with the account level; they make enemies tougher but pay much more.
func _build_difficulty() -> void:
	var chosen := str(progression.profile.get("difficulty", "normal"))
	_text("Zorluk bir sonraki oyunlar için geçerli. Kabus seviyeleri hesap seviyesiyle açılır; düşmanlar çok daha güçlü olur ama EXP, altın ve boss kasaları artar.", 14, UiTheme.MUTED)
	for d: Dictionary in Config.load_json("res://data/difficulty.json").levels:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UiTheme.label(str(d.name), UiTheme.label_settings(20, UiTheme.ACCENT if str(d.id) == chosen else UiTheme.TEXT, 2)))
		var lines := UiTheme.label(str(d.desc), UiTheme.label_settings(13, UiTheme.MUTED, 0))
		lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(lines)
		row.add_child(info)
		var b := Button.new()
		var open: bool = progression.account_level() >= int(d.level)
		b.text = ("Seçili ✓" if str(d.id) == chosen else "Seç") if open else "Seviye %d" % int(d.level)
		b.disabled = not open or str(d.id) == chosen
		b.custom_minimum_size.x = 120
		b.pressed.connect(func() -> void:
			progression.profile.difficulty = str(d.id)
			progression.store.save_to_disk()
			open_section("difficulty"))
		row.add_child(b)
		_content.add_child(row)


## The wardrobe: outfits and dyes for the active character (looks only).
func _build_wardrobe() -> void:
	var c := inventory.active_character()
	if c.is_empty():
		_text("Önce bir karakter oluştur.", 16, UiTheme.MUTED)
		return
	_text("%s için görünüm. Giysi ve boyalar güç vermez, sadece görünüşü değiştirir. Boya giysinin rengini ezer." % str(c.name), 14, UiTheme.MUTED)
	var preview: SubViewportContainer = CharacterPreview.new()
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(preview)
	preview.setup(inventory.character_look(c), Vector2(200, 230), 2, true)
	for part: Array in [["Giysiler", "outfit", cosmetics.outfits], ["Gövde boyaları", "dyeTunic", cosmetics.tunic_dyes], ["Saç boyaları", "dyeHair", cosmetics.hair_dyes]]:
		_header(str(part[0]))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		_content.add_child(flow)
		var none := Button.new()
		none.text = "Çıkar"
		none.disabled = str(c.get(part[1], "")) == ""
		none.pressed.connect(func() -> void:
			cosmetics.wear(c, str(part[1]), "")
			open_section("wardrobe"))
		flow.add_child(none)
		for d: Dictionary in part[2]:
			var b := Button.new()
			var mine: bool = cosmetics.has(str(d.id))
			var worn := str(c.get(part[1], "")) == str(d.id)
			b.text = "%s%s" % [d.name, " ✓" if worn else ("" if mine else "  %d" % int(d.price))]
			if d.has("color"):
				b.add_theme_color_override("font_color", Color(str(d.color)).lightened(0.25))
			b.disabled = worn or (not mine and int(progression.profile.gold) < int(d.price))
			b.pressed.connect(func() -> void:
				if not mine:
					cosmetics.buy(str(d.id))
					refresh()
				cosmetics.wear(c, str(part[1]), str(d.id))
				open_section("wardrobe"))
			flow.add_child(b)


## The stable: buy a mount and pick the one to ride in the tavern.
func _build_stable() -> void:
	_text("Bineğinle Taverna'da çok daha hızlı gezersin. Satın aldığın binekten istediğini seç.", 14, UiTheme.MUTED)
	var riding: String = mounts.active()
	var foot := Button.new()
	foot.text = "Yaya (binek yok)%s" % ("  ✓" if riding == "" else "")
	foot.pressed.connect(func() -> void:
		mounts.ride("")
		open_section("stable"))
	_content.add_child(foot)
	for d: Dictionary in mounts.defs:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UiTheme.label(str(d.name), UiTheme.label_settings(18, Color(str(d.body)).lightened(0.3), 2)))
		info.add_child(UiTheme.label(str(d.desc), UiTheme.label_settings(13, UiTheme.MUTED, 0)))
		row.add_child(info)
		var b := Button.new()
		if mounts.has(str(d.id)):
			b.text = "Biniliyor ✓" if riding == str(d.id) else "Bin"
			b.disabled = riding == str(d.id)
			b.pressed.connect(func() -> void:
				mounts.ride(str(d.id))
				open_section("stable"))
		else:
			b.text = "Al %d" % int(d.price)
			b.disabled = int(progression.profile.gold) < int(d.price)
			b.pressed.connect(func() -> void:
				if mounts.buy(str(d.id)):
					refresh()
					open_section("stable"))
		b.custom_minimum_size.x = 130
		row.add_child(b)
		_content.add_child(row)


## Gems: buy them, then set them into the sockets of your items.
func _build_gems() -> void:
	var gear := inventory.gear
	if _gem_pick == "" or gear.gem(_gem_pick).is_empty():
		_gem_pick = str(gear.gems[0].id)
	_text("Soketli eşyalara taş tak: Ateş (hasar), Buz (savunma), Zehir (kritik hasarı), Fırtına (saldırı hızı), Can (can). Eski taş bir soketten çıkarılamaz, yenisiyle değişir. Taşlar boss ve kasalardan düşer, burada %d altına alınır." % gear.gem_price, 14, UiTheme.MUTED)
	_header("Taşların")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_content.add_child(row)
	for g: Dictionary in gear.gems:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		var pick := Button.new()
		pick.text = "%s x%d" % [g.name, inventory.gem_count(str(g.id))]
		pick.toggle_mode = true
		pick.button_pressed = str(g.id) == _gem_pick
		pick.add_theme_color_override("font_color", Color(str(g.color)))
		pick.tooltip_text = gear.stat_text(str(g.stat), float(g.value))
		pick.pressed.connect(func() -> void:
			_gem_pick = str(g.id)
			open_section("gems"))
		box.add_child(pick)
		var buy := Button.new()
		buy.text = "Al %d" % gear.gem_price
		buy.disabled = int(progression.profile.gold) < gear.gem_price
		buy.add_theme_font_size_override("font_size", 12)
		buy.pressed.connect(func() -> void:
			if inventory.buy_gem(str(g.id)):
				refresh()
				open_section("gems"))
		box.add_child(buy)
		row.add_child(box)
	_header("Soketli eşyaların")
	var shown := 0
	for it: Dictionary in inventory.items():
		var count := gear.sockets(it)
		if count <= 0:
			continue
		shown += 1
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		var nm := UiTheme.label(gear.item_name(it), UiTheme.label_settings(16, gear.rarity_color(int(it.rarity)), 2))
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(nm)
		var set_in: Array = gear.item_gems(it)
		for i in count:
			var slot := Button.new()
			var cur := gear.gem(str(set_in[i]))
			slot.text = str(cur.name) if not cur.is_empty() else "boş soket"
			slot.custom_minimum_size.x = 110
			if not cur.is_empty():
				slot.add_theme_color_override("font_color", Color(str(cur.color)))
			slot.disabled = inventory.gem_count(_gem_pick) <= 0
			slot.pressed.connect(func() -> void:
				if inventory.socket_gem(int(it.uid), i, _gem_pick):
					refresh()
					open_section("gems"))
			line.add_child(slot)
		_content.add_child(line)
	if shown == 0:
		_text("Soketli eşyan yok. Çok Nadir ve üstü eşyalarda 1-3 soket olur.", 15, UiTheme.MUTED)


## The weekly world boss: shared health bar, your damage, top fighters.
func _build_world_boss() -> void:
	if net == null or not net.is_online():
		_text("Dünya bossu için sunucuya bağlı olmalısın.", 16, Color("#ff8a8a"))
		return
	if Time.get_ticks_msec() - _wb_asked > 4000:
		_wb_asked = Time.get_ticks_msec()
		net.ask_world_boss()
	var info: Dictionary = net.world_boss
	if info.is_empty():
		_text("Boss aranıyor...", 16, UiTheme.MUTED)
		return
	_text("Bu hafta: %s" % info.name, 24, UiTheme.ACCENT)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 26)
	bar.max_value = float(info.max)
	bar.value = float(info.hp)
	bar.show_percentage = false
	_content.add_child(bar)
	var days := int(float(info.endsIn) / 86400000.0)
	_text("Can: %d / %d  ·  Haftanın bitmesine %d gün" % [int(info.hp), int(info.max), days], 15, UiTheme.MUTED)
	_text("Boss'la 2 dakika baş başa dövüşürsün; verdiğin hasar (en çok 40.000) sunucudaki ortak cana yazılır. Can bitince hasar payına göre altın alırsın.", 14, UiTheme.MUTED)
	_text("Senin hasarın: %d  ·  Sıran: %s" % [int(info.mine), str(info.rank) if int(info.rank) > 0 else "-"], 17, UiTheme.TEXT)
	for row: Dictionary in info.top:
		_text("%s: %d" % [row.name, int(row.dmg)], 15, UiTheme.MUTED)
	if bool(info.dead):
		var claim := UiTheme.primary_button("Ödülü al (%d altın)" % int(info.reward))
		claim.disabled = bool(info.claimed) or int(info.mine) <= 0
		claim.pressed.connect(func() -> void: net.claim_world_boss())
		_content.add_child(claim)
		_text("Boss yenildi! Yeni boss haftaya geliyor." if int(info.mine) > 0 else "Boss yenildi. Bu hafta vurmadığın için ödül yok.", 15, UiTheme.MUTED)
	else:
		var fight := UiTheme.primary_button("Savaşa gir")
		fight.disabled = net.in_room()
		fight.pressed.connect(func() -> void: world_boss_requested.emit())
		_content.add_child(fight)


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


## What changed in each version of the game (data/changelog.json). Each
## version is a card; clicking its title slides the notes open (or shut).
func _build_versions() -> void:
	if version_text != "":
		_text("Şu an oynadığın: %s" % version_text, 15, UiTheme.MUTED)
	_text("Ayrıntıları görmek için bir sürüme tıkla.", 13, UiTheme.MUTED)
	var data: Dictionary = Config.load_json("res://data/changelog.json")
	var versions: Array = data.get("versions", [])
	if _open_versions.is_empty() and not versions.is_empty():
		_open_versions[str(versions[0].version)] = true
	for v: Dictionary in versions:
		_content.add_child(_version_card(v))


func _version_card(v: Dictionary) -> Control:
	var key := str(v.version)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style(Color(1, 1, 1, 0.12), 1))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	card.add_child(col)
	var head := Button.new()
	head.flat = true
	head.focus_mode = Control.FOCUS_NONE
	head.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	head.custom_minimum_size.y = 34
	col.add_child(head)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(row)
	var arrow := UiTheme.label("▶", UiTheme.label_settings(15, UiTheme.ACCENT, 2))
	arrow.custom_minimum_size.x = 22
	arrow.pivot_offset = Vector2(7, 11)
	row.add_child(arrow)
	var title := UiTheme.label("v%s  ·  %s" % [v.version, v.title], UiTheme.label_settings(19, UiTheme.ACCENT, 3))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(UiTheme.label("%s  ·  %d not" % [v.date, (v.notes as Array).size()], UiTheme.label_settings(13, UiTheme.MUTED, 2)))
	# The notes sit in a clipping box whose height slides between 0 and theirs.
	var clip := Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(clip)
	var notes := VBoxContainer.new()
	notes.add_theme_constant_override("separation", 3)
	notes.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	clip.add_child(notes)
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	notes.add_child(gap)
	for note: String in v.notes:
		var line := UiTheme.label("•  " + note, UiTheme.label_settings(14, UiTheme.TEXT, 2))
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		notes.add_child(line)
	var open := bool(_open_versions.get(key, false))
	arrow.rotation = PI * 0.5 if open else 0.0
	clip.set_meta("open", open)
	notes.resized.connect(func() -> void:
		if bool(clip.get_meta("open")) and not clip.has_meta("sliding"):
			clip.custom_minimum_size.y = notes.size.y)
	head.pressed.connect(func() -> void:
		var now := not bool(clip.get_meta("open"))
		clip.set_meta("open", now)
		_open_versions[key] = now
		clip.set_meta("sliding", true)
		var tween := clip.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(clip, "custom_minimum_size:y", notes.size.y if now else 0.0, 0.3)
		tween.tween_property(arrow, "rotation", PI * 0.5 if now else 0.0, 0.2)
		tween.chain().tween_callback(func() -> void: clip.remove_meta("sliding")))
	return card


## Is a version's card open (true) on the versions page?
func is_version_open(version: String) -> bool:
	return bool(_open_versions.get(version, false))


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
	var full := CheckBox.new()
	full.text = "Tam ekran (F11 ile de açılıp kapanır)"
	full.button_pressed = Screen.is_fullscreen()
	full.add_theme_font_size_override("font_size", 17)
	full.toggled.connect(func(on: bool) -> void: Screen.set_fullscreen(on))
	_content.add_child(full)

	_header("Ses")
	_content.add_child(_slider_row("Müzik", "musicVolume", 0.0, 1.0, 0.05, 0.5))
	_content.add_child(_slider_row("Efektler", "sfxVolume", 0.0, 1.0, 0.05, 0.7))

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


## Switches full screen on or off.
func toggle_fullscreen() -> void:
	Screen.toggle()
	refresh()


## Keeps the full screen button's text in step with the window.
func _sync_fullscreen_button() -> void:
	if _fullscreen_button:
		_fullscreen_button.text = "Pencere (F11)" if Screen.is_fullscreen() else "Tam ekran (F11)"


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
	var up := Button.new()
	var cost := gear.upgrade_cost(it)
	up.text = "Geliştir %d" % cost if cost > 0 else "En üst seviye"
	up.add_theme_font_size_override("font_size", 12)
	up.disabled = cost <= 0 or int(progression.profile.gold) < cost
	up.tooltip_text = "Demirci: tüm özellikler %%%d artar" % roundi(gear.UPGRADE_STEP * 100.0) if cost > 0 else ""
	up.pressed.connect(upgrade_item.bind(int(it.uid)))
	col.add_child(up)
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
