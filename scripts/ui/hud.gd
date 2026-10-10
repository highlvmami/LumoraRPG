## In-run HUD: account level (top left), run time and kills (top right),
## a character panel at the bottom center (portrait, level, health, exp, gold
## and combat stats), floating "+EXP" / damage numbers and the death screen.
## In co-op the party is listed on the left: character name and health bar.
extends CanvasLayer

const UiTheme := preload("res://scripts/ui/theme.gd")
const Progression := preload("res://scripts/progression/progression.gd")
const EnemyManager := preload("res://scripts/enemies/enemy_manager.gd")
const PixelIcons := preload("res://scripts/ui/pixel_icons.gd")
const ItemArt := preload("res://scripts/ui/item_art.gd")

signal restart_requested
signal menu_requested

var player: CharacterBody3D
var progression: Progression
var enemies: EnemyManager
var camera: Camera3D
## The 3D view renders at a lower resolution than the UI; screen positions
## from the camera are multiplied by this to land in UI space.
var world_scale := 1.0
## Shown in the character panel; set when a run starts.
var character_name := ""
var class_name_text := ""

var _root: Control
var _account: Label
var _account_bar: ProgressBar
var _weapon_row: HBoxContainer
var _boss_box: VBoxContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _name: Label
var _portrait_letter: Label
var _level: Label
var _exp_bar: ProgressBar
var _exp_text: Label
var _hp_bar: ProgressBar
var _hp_text: Label
var _gold: Label
var _stats_grid: GridContainer
var _stat_values: Array[Label] = []
var _stats: Label
var _toast: Label
var _title_box: VBoxContainer
var _title: Label
var _subtitle: Label
## Floating damage numbers on hits (settings).
var show_damage_numbers := true
## Gear rules, to draw the items found (set by main).
var gear: RefCounted
var _death_drops: HFlowContainer
var _death: Control
var _death_text: Label
var _float_settings: LabelSettings
var _gold_settings: LabelSettings
var _hit_settings: LabelSettings
var _crit_settings: LabelSettings
## Class ultimate (Ultimate node): its button fills up while it charges.
var ultimate: Node
var _ult_fill: ColorRect
var _ult_text: Label
var _ult_box: PanelContainer
var _ult_style: StyleBoxFlat
var _flash: ColorRect
var _flash_tween: Tween
var _party: VBoxContainer
## One row per party member: [panel, name label, info label, health bar].
var _party_rows: Array = []


func setup(p_player: CharacterBody3D, p_progression: Progression, p_enemies: EnemyManager, p_camera: Camera3D, p_world_scale: float) -> void:
	player = p_player
	progression = p_progression
	enemies = p_enemies
	camera = p_camera
	world_scale = p_world_scale
	_float_settings = UiTheme.label_settings(14, Color("#8fe3ff"), 4)
	_gold_settings = UiTheme.label_settings(13, UiTheme.ACCENT, 4)
	_hit_settings = UiTheme.label_settings(15, Color("#ffffff"), 4)
	_crit_settings = UiTheme.label_settings(22, Color("#ff9a3c"), 5)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.theme()
	add_child(_root)

	var top_left := VBoxContainer.new()
	top_left.position = Vector2(20, 16)
	top_left.add_theme_constant_override("separation", 4)
	_root.add_child(top_left)
	_account = UiTheme.label("", UiTheme.label_settings(18, Color("#9fd3ff"), 5))
	top_left.add_child(_account)
	_account_bar = _bar(Color("#9fd3ff"), Vector2(220, 6))
	top_left.add_child(_account_bar)
	_weapon_row = HBoxContainer.new()
	_weapon_row.add_theme_constant_override("separation", 6)
	top_left.add_child(_weapon_row)

	_boss_box = VBoxContainer.new()
	_boss_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 14)
	_boss_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_boss_box.add_theme_constant_override("separation", 2)
	_boss_box.visible = false
	_root.add_child(_boss_box)
	_boss_name = UiTheme.label("", UiTheme.label_settings(18, Color("#ff8a8a"), 5))
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(_boss_name)
	_boss_bar = _bar(Color("#c0392b"), Vector2(460, 14))
	_boss_bar.max_value = 1.0
	_boss_box.add_child(_boss_bar)

	var top_right := VBoxContainer.new()
	top_right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
	top_right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top_right.alignment = BoxContainer.ALIGNMENT_BEGIN
	_root.add_child(top_right)
	_stats = UiTheme.label("", UiTheme.label_settings(20))
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_right.add_child(_stats)
	var controls := UiTheme.label("WASD yürü · BOŞLUK zıpla · R ulti · TIKLA + FARE bak · ESC duraklat", UiTheme.label_settings(14, UiTheme.MUTED, 4))
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_right.add_child(controls)

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	_root.add_child(_flash)

	_build_character_panel()

	_party = VBoxContainer.new()
	_party.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	_party.grow_vertical = Control.GROW_DIRECTION_BOTH
	_party.add_theme_constant_override("separation", 6)
	_party.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_party.visible = false
	_root.add_child(_party)

	_toast = UiTheme.label("", UiTheme.label_settings(40, UiTheme.ACCENT, 10))
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.position.y = 110
	_toast.modulate.a = 0.0
	_root.add_child(_toast)

	_title_box = VBoxContainer.new()
	_title_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_title_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_title_box.position.y -= 120
	_title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_box.visible = false
	_root.add_child(_title_box)
	_title = UiTheme.label("", UiTheme.label_settings(64, UiTheme.ACCENT, 12))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(_title)
	_subtitle = UiTheme.label("", UiTheme.label_settings(22, UiTheme.TEXT, 6))
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(_subtitle)

	_death = _overlay()
	var death_box := _death.get_child(0) as VBoxContainer
	_death_text = _centered_label("", 30)
	death_box.add_child(_death_text)
	_death_drops = HFlowContainer.new()
	_death_drops.alignment = FlowContainer.ALIGNMENT_CENTER
	_death_drops.add_theme_constant_override("h_separation", 14)
	_death_drops.add_theme_constant_override("v_separation", 10)
	death_box.add_child(_death_drops)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	death_box.add_child(buttons)
	var again := UiTheme.primary_button("Tekrar Oyna")
	again.add_theme_font_size_override("font_size", 26)
	again.pressed.connect(func() -> void: restart_requested.emit())
	buttons.add_child(again)
	var menu := Button.new()
	menu.text = "Ana Menü"
	menu.add_theme_font_size_override("font_size", 26)
	menu.pressed.connect(func() -> void: menu_requested.emit())
	buttons.add_child(menu)
	_death.visible = false

	progression.account_level_up.connect(func(lv: int) -> void: _show_toast("HESAP SEVİYESİ %d!" % lv))
	enemies.kind_unlocked.connect(func(kind_name: String) -> void: _show_toast("YENİ DÜŞMAN: %s" % kind_name.to_upper()))
	enemies.swarm_started.connect(func(kind_name: String) -> void: _show_toast("SÜRÜ GELİYOR: %s!" % kind_name.to_upper()))
	enemies.boss_spawned.connect(func(boss_name: String) -> void: _show_toast("BOSS GELDİ: %s!" % boss_name.to_upper()))
	enemies.boss_defeated.connect(func(_boss_name: String) -> void: _show_toast("BOSS YENİLDİ!"))
	enemies.boss_phase_changed.connect(func(boss_name: String, phase: int) -> void:
		_show_toast(("%s ÖFKELENDİ! Saldırıları hızlanıyor" if phase == 2 else "%s ÇILDIRDI! Yeni saldırılar geliyor") % boss_name.to_upper()))
	enemies.enemy_killed.connect(_on_enemy_killed)


## `loot` lists the items and chests found this run (already in the backpack).
## Co-op party on the left (empty hides it). Each entry: name (character),
## account, class, hp, max_hp, dead, me.
func set_party(entries: Array) -> void:
	_party.visible = not entries.is_empty()
	while _party_rows.size() < entries.size():
		_party_rows.append(_party_row())
	while _party_rows.size() > entries.size():
		(_party_rows.pop_back()[0] as Control).queue_free()
	for i in entries.size():
		var e: Dictionary = entries[i]
		var row: Array = _party_rows[i]
		var dead := bool(e.get("dead", false))
		(row[1] as Label).text = str(e.get("name", "?")) + ("  (sen)" if e.get("me", false) else "")
		(row[2] as Label).text = "ÖLDÜ" if dead else "%s  ·  %s" % [e.get("account", ""), e.get("class", "")]
		var bar := row[3] as ProgressBar
		bar.max_value = maxf(1.0, float(e.get("max_hp", 100.0)))
		bar.value = 0.0 if dead else float(e.get("hp", 0.0))
		var ratio := bar.value / bar.max_value
		var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
		fill.bg_color = Color("#3ddc84") if ratio > 0.5 else (Color("#ffc94d") if ratio > 0.25 else Color("#ff5a5a"))
		(row[0] as Control).modulate.a = 0.55 if dead else 1.0


func _party_row() -> Array:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiTheme.box(Color(0.05, 0.08, 0.11, 0.78), 8, 8)
	style.border_width_left = 3
	style.border_color = UiTheme.ACCENT.darkened(0.2)
	panel.add_theme_stylebox_override("panel", style)
	_party.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.custom_minimum_size.x = 190
	panel.add_child(box)
	var name_label := UiTheme.label("", UiTheme.label_settings(16, UiTheme.TEXT, 3))
	box.add_child(name_label)
	var info := UiTheme.label("", UiTheme.label_settings(12, UiTheme.MUTED, 2))
	box.add_child(info)
	var bar := _bar(Color("#3ddc84"), Vector2(186, 10))
	box.add_child(bar)
	return [panel, name_label, info, bar]


func show_death(level: int, kills: int, gold: int, seconds: float, loot: PackedStringArray = PackedStringArray(), drops: Array = []) -> void:
	_death_text.text = "ÖLDÜN\n\nSeviye %d   ·   %d canavar   ·   +%d altın   ·   %d:%02d" % [level, kills, gold, int(seconds) / 60, int(seconds) % 60]
	for child in _death_drops.get_children():
		_death_drops.remove_child(child)
		child.queue_free()
	if gear != null and not drops.is_empty():
		_death_text.text += "\n\nBulunanlar (çantaya eklendi):"
		for d: Dictionary in drops.slice(0, 12):
			_death_drops.add_child(_drop_card(d))
		if drops.size() > 12:
			_death_drops.add_child(UiTheme.label("+%d daha" % (drops.size() - 12), UiTheme.label_settings(16, UiTheme.MUTED, 2)))
	elif not loot.is_empty():
		_death_text.text += "\n\nBulunanlar (çantaya eklendi):\n" + ", ".join(loot)
	_death.visible = true


## One found item or chest: its picture with the name under it.
func _drop_card(d: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	var art: Control
	var name_text := ""
	var color := Color.WHITE
	if d.has("item"):
		var it: Dictionary = d.item
		color = gear.rarity_color(int(it.rarity))
		art = ItemArt.make(it, color, gear.tier(int(it.rarity)), 56.0)
		name_text = gear.item_name(it)
	else:
		var tier := int(d.chest)
		color = Color(str(gear.chest(tier).color))
		art = ItemArt.chest(tier, color, 56.0)
		name_text = str(gear.chest(tier).name)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(art)
	var label := UiTheme.label(name_text, UiTheme.label_settings(12, color, 3))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(label)
	return col


func hide_death() -> void:
	_death.visible = false


## Weapon icons with their level under the account line; `weapons` is [def, level].
func set_weapons(weapons: Array) -> void:
	for child in _weapon_row.get_children():
		child.queue_free()
	for pair: Array in weapons:
		var slot := PanelContainer.new()
		slot.add_theme_stylebox_override("panel", UiTheme.box(Color(0, 0, 0, 0.5), 6, 3))
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := PixelIcons.rect(str(pair[0].get("icon", "")), 30)
		slot.add_child(icon)
		var lv := UiTheme.label(str(pair[1]), UiTheme.label_settings(12, UiTheme.ACCENT, 3))
		lv.size_flags_horizontal = Control.SIZE_SHRINK_END
		lv.size_flags_vertical = Control.SIZE_SHRINK_END
		slot.add_child(lv)
		_weapon_row.add_child(slot)


## Updates the stat grid in the character panel; `stats` is a list of [name, value].
func set_stats(stats: Array) -> void:
	if _stat_values.size() != stats.size():
		for child in _stats_grid.get_children():
			child.queue_free()
		_stat_values.clear()
		for s: Array in stats:
			_stats_grid.add_child(UiTheme.label(str(s[0]), UiTheme.label_settings(12, UiTheme.MUTED, 3)))
			var value := UiTheme.label("", UiTheme.label_settings(13, UiTheme.TEXT, 3))
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			value.custom_minimum_size.x = 56
			_stats_grid.add_child(value)
			_stat_values.append(value)
	for i in stats.size():
		_stat_values[i].text = str(stats[i][1])


## Damage number over an enemy that was hit; critical hits are bigger and orange.
func show_hit(at_position: Vector3, amount: float, crit: bool) -> void:
	if not show_damage_numbers:
		return
	if camera == null or not camera.is_inside_tree() or camera.is_position_behind(at_position):
		return
	var screen := camera.unproject_position(at_position + Vector3.UP * 1.4) * world_scale
	screen.x += randf_range(-14.0, 14.0)
	var text: String = ("%d!" % roundi(amount)) if crit else str(roundi(amount))
	_float_text(text, _crit_settings if crit else _hit_settings, screen)


func _process(_delta: float) -> void:
	if player == null or not visible:
		return
	_account.text = "%s   ·   Hesap Sv. %d" % [progression.profile.name, progression.account_level()]
	_account_bar.max_value = progression.exp_to_next_account_level()
	_account_bar.value = progression.account_exp()
	_name.text = character_name if character_name != "" else str(progression.profile.name)
	_portrait_letter.text = _name.text.left(1).to_upper()
	_level.text = "Sv. %d" % progression.level
	if class_name_text != "":
		_level.text += "  ·  " + class_name_text
	_exp_bar.max_value = progression.exp_to_next_level()
	_exp_bar.value = progression.level_exp
	_exp_text.text = "%d / %d EXP" % [progression.level_exp, progression.exp_to_next_level()]
	var max_hp := float(player.get("max_hp"))
	var hp := float(player.get("hp"))
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_text.text = "%d / %d" % [ceili(hp), int(max_hp)]
	_gold.text = "%d altın" % progression.gold()
	_update_ultimate()
	var boss := enemies.boss_index()
	_boss_box.visible = boss >= 0
	if boss >= 0:
		_boss_name.text = enemies.kind_name(boss).to_upper() + ["", "  ·  ÖFKELİ", "  ·  ÇILGIN"][enemies.boss_phase() - 1]
		_boss_bar.value = enemies.health_ratio(boss)
	var t := int(enemies.run_time)
	_stats.text = "%d:%02d   ·   %d canavar   ·   FPS %d" % [t / 60, t % 60, enemies.kills, Engine.get_frames_per_second()]


## "+3 EXP" (and "+1 altın") rising from where the enemy died.
func _on_enemy_killed(at_position: Vector3, exp_amount: int, gold_amount: int) -> void:
	if camera == null or not camera.is_inside_tree() or camera.is_position_behind(at_position):
		return
	var screen := camera.unproject_position(at_position + Vector3.UP * 0.8) * world_scale
	_float_text("+%d EXP" % exp_amount, _float_settings, screen)
	if gold_amount > 0:
		_float_text("+%d altın" % gold_amount, _gold_settings, screen + Vector2(0, 16))


func _float_text(text: String, settings: LabelSettings, at: Vector2) -> void:
	var label := UiTheme.label(text, settings)
	_root.add_child(label)
	label.position = at - Vector2(label.get_minimum_size().x * 0.5, 0)
	var tween := create_tween().set_parallel()
	tween.tween_property(label, "position:y", at.y - 44.0, 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.35)
	tween.chain().tween_callback(label.queue_free)


## A short message in the middle of the screen (new enemy, loot, ...).
func toast(text: String) -> void:
	_show_toast(text)


## Big map name in the middle of the screen when a run starts.
func show_title(title: String, subtitle: String) -> void:
	_title.text = title
	_subtitle.text = subtitle
	_title_box.modulate.a = 1.0
	_title_box.visible = true
	var tween := create_tween()
	tween.tween_interval(2.2)
	tween.tween_property(_title_box, "modulate:a", 0.0, 0.9)
	tween.tween_callback(func() -> void: _title_box.visible = false)


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


## Bottom-center panel: portrait, name and level, health/exp bars, gold, stats.
func _build_character_panel() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.box(Color(0.06, 0.08, 0.11, 0.8), 10, 8))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 8)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	# Portrait with the level badge under it.
	var portrait_box := VBoxContainer.new()
	portrait_box.add_theme_constant_override("separation", 2)
	row.add_child(portrait_box)
	var portrait := PanelContainer.new()
	var portrait_style := UiTheme.box(Color("#3d6b4a"), 10, 0)
	portrait_style.set_border_width_all(2)
	portrait_style.border_color = UiTheme.ACCENT
	portrait.add_theme_stylebox_override("panel", portrait_style)
	portrait.custom_minimum_size = Vector2(48, 48)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_box.add_child(portrait)
	_portrait_letter = UiTheme.label("", UiTheme.label_settings(26, Color.WHITE, 6))
	_portrait_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait_letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait.add_child(_portrait_letter)
	_level = UiTheme.label("", UiTheme.label_settings(14, UiTheme.ACCENT, 4))
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_box.add_child(_level)

	# Name, health, exp and gold.
	var bars := VBoxContainer.new()
	bars.add_theme_constant_override("separation", 4)
	bars.custom_minimum_size.x = 200
	bars.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(bars)
	var name_row := HBoxContainer.new()
	bars.add_child(name_row)
	_name = UiTheme.label("", UiTheme.label_settings(16, UiTheme.TEXT, 4))
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name)
	_gold = UiTheme.label("", UiTheme.label_settings(14, UiTheme.ACCENT, 4))
	name_row.add_child(_gold)
	var hp := _labeled_bar(Color("#e0484f"), 15)
	_hp_bar = hp[0]
	_hp_text = hp[1]
	bars.add_child(_hp_bar)
	var xp := _labeled_bar(Color("#5fb8ff"), 11)
	_exp_bar = xp[0]
	_exp_text = xp[1]
	bars.add_child(_exp_bar)

	row.add_child(VSeparator.new())

	_stats_grid = GridContainer.new()
	_stats_grid.columns = 4
	_stats_grid.add_theme_constant_override("h_separation", 8)
	_stats_grid.add_theme_constant_override("v_separation", 0)
	_stats_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_stats_grid)

	row.add_child(VSeparator.new())
	row.add_child(_build_ultimate_button())


## The ultimate's button: an icon that fills up from the bottom while it
## charges and glows when ready, with the key under it.
func _build_ultimate_button() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ult_box = PanelContainer.new()
	_ult_box.custom_minimum_size = Vector2(54, 54)
	_ult_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ult_style = UiTheme.box(Color(0.1, 0.08, 0.16, 0.9), 10, 4)
	_ult_style.set_border_width_all(2)
	_ult_style.border_color = Color(1, 1, 1, 0.2)
	_ult_box.add_theme_stylebox_override("panel", _ult_style)
	col.add_child(_ult_box)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.clip_contents = true
	_ult_box.add_child(holder)
	_ult_fill = ColorRect.new()
	_ult_fill.color = Color(1.0, 0.75, 0.2, 0.35)
	_ult_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_ult_fill)
	var icon := PixelIcons.rect("ultimate", 40)
	icon.position = Vector2(3, 3)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(icon)
	_ult_text = UiTheme.label("", UiTheme.label_settings(18, Color.WHITE, 5))
	_ult_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ult_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ult_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(_ult_text)
	var key := UiTheme.label("R · ULTİ", UiTheme.label_settings(11, UiTheme.ACCENT, 3))
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(key)
	return col


func _update_ultimate() -> void:
	_ult_box.visible = ultimate != null
	if ultimate == null:
		return
	var ratio := float(ultimate.call("ratio"))
	var size := _ult_box.size - Vector2(8, 8)
	_ult_fill.size = Vector2(size.x, size.y * ratio)
	_ult_fill.position = Vector2(0, size.y * (1.0 - ratio))
	var ready := bool(ultimate.call("is_ready"))
	_ult_text.text = "" if ready else str(ceili(float(ultimate.get("cooldown_left"))))
	_ult_fill.color = Color(1.0, 0.75, 0.2, 0.55 if ready else 0.3)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
	_ult_style.border_color = Color(1.0, 0.8, 0.25, 0.6 + 0.4 * pulse) if ready else Color(1, 1, 1, 0.2)
	_ult_style.shadow_color = Color(1.0, 0.7, 0.2, 0.6 * pulse) if ready else Color(0, 0, 0, 0)
	_ult_style.shadow_size = 8 if ready else 0


## Tints the whole screen: fades in to `peak` alpha, holds, fades out.
func screen_flash(color: Color, fade_in: float, hold: float, fade_out: float, peak := 0.85) -> void:
	if _flash_tween:
		_flash_tween.kill()
	var from := _flash.color.a
	_flash.color = Color(color, from)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", peak, maxf(fade_in, 0.01))
	if hold > 0.0:
		_flash_tween.tween_interval(hold)
	_flash_tween.tween_property(_flash, "color:a", 0.0, maxf(fade_out, 0.05))


## A progress bar with its text drawn centered on top of it.
func _labeled_bar(color: Color, height: float) -> Array:
	var bar := _bar(color, Vector2(200, height))
	var text := UiTheme.label("", UiTheme.label_settings(10 if height < 13 else 12, UiTheme.TEXT, 3))
	text.set_anchors_preset(Control.PRESET_FULL_RECT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(text)
	return [bar, text]


func _bar(color: Color, min_size: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = min_size
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", UiTheme.box(Color(0, 0, 0, 0.55), 4, 0))
	bar.add_theme_stylebox_override("fill", UiTheme.box(color, 4, 0))
	return bar


func _centered_label(text: String, size: int) -> Label:
	var label := UiTheme.label(text, UiTheme.label_settings(size))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## Full-screen dimmed overlay; its first child is a centered VBoxContainer.
func _overlay() -> Control:
	var rect := ColorRect.new()
	rect.color = Color(0.03, 0.05, 0.07, 0.55)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(rect)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.add_child(box)
	return rect
