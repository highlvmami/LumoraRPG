## Esc during a run: pauses the game and shows resume, graphics quality,
## back to the main menu, and the weapons and boosts picked in this run.
extends CanvasLayer

const UiTheme := preload("res://scripts/ui/theme.gd")
const RunBoosts := preload("res://scripts/progression/run_boosts.gd")
const PixelIcons := preload("res://scripts/ui/pixel_icons.gd")

const QUALITIES := [["low", "Düşük"], ["medium", "Orta"], ["high", "Yüksek"]]

signal resumed
signal menu_requested
signal quality_selected(quality: String)

## False in a co-op run: the others keep playing while this menu is open.
var freezes := true
var boosts: RunBoosts
## Returns true when the game may be paused right now (in a run, alive, no other popup).
var can_pause: Callable = func() -> bool: return true
## Returns the current stats as [name, value] pairs, the same list the HUD shows.
var stats_source: Callable = func() -> Array: return []
## Returns the weapons carried this run as [def, level] pairs (bow included).
var weapons_source: Callable = func() -> Array: return []

var _quality_buttons := {}
var _boost_list: VBoxContainer
var _stats_text: Label


func setup(p_boosts: RunBoosts, quality: String) -> void:
	boosts = p_boosts
	layer = 7
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.theme = UiTheme.theme()
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	center.add_child(row)

	# Left: actions and settings.
	var left := PanelContainer.new()
	left.custom_minimum_size = Vector2(380, 460)
	row.add_child(left)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	left.add_child(actions)
	actions.add_child(UiTheme.label("DURAKLATILDI", UiTheme.label_settings(38, UiTheme.ACCENT, 8)))

	var resume_button := UiTheme.primary_button("Devam Et")
	resume_button.add_theme_font_size_override("font_size", 28)
	resume_button.pressed.connect(resume)
	actions.add_child(resume_button)

	actions.add_child(UiTheme.label("Grafik kalitesi", UiTheme.label_settings(20, UiTheme.MUTED, 4)))
	var quality_row := HBoxContainer.new()
	quality_row.add_theme_constant_override("separation", 8)
	actions.add_child(quality_row)
	var group := ButtonGroup.new()
	for q: Array in QUALITIES:
		var b := Button.new()
		b.text = q[1]
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.PRIMARY, 8, 10))
		b.pressed.connect(func() -> void: quality_selected.emit(q[0]))
		quality_row.add_child(b)
		_quality_buttons[q[0]] = b
	actions.add_child(UiTheme.label("Düşük: daha akıcı, daha pikselli.\nYüksek: daha net, daha ağır.", UiTheme.label_settings(16, UiTheme.MUTED, 4)))
	set_quality(quality)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var menu_button := Button.new()
	menu_button.text = "Ana Menüye Dön"
	menu_button.add_theme_font_size_override("font_size", 24)
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	actions.add_child(menu_button)
	actions.add_child(UiTheme.label("Kazandığın EXP ve altın kaydedilir.", UiTheme.label_settings(15, UiTheme.MUTED, 4)))

	# Right: boosts of this run and the resulting stats.
	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(420, 460)
	row.add_child(right)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 10)
	right.add_child(info)
	info.add_child(UiTheme.label("Bu oyunda aldıkların", UiTheme.label_settings(28, UiTheme.TEXT, 6)))
	_boost_list = VBoxContainer.new()
	_boost_list.add_theme_constant_override("separation", 3)
	info.add_child(_boost_list)
	info.add_child(HSeparator.new())
	_stats_text = UiTheme.label("", UiTheme.label_settings(15, UiTheme.MUTED, 4))
	info.add_child(_stats_text)


func open() -> void:
	if visible or not can_pause.call():
		return
	_refresh(stats_source.call())
	visible = true
	get_tree().paused = freezes
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func resume() -> void:
	if not visible:
		return
	close()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	resumed.emit()


## Hides the menu and unpauses without grabbing the mouse.
func close() -> void:
	visible = false
	get_tree().paused = false


func set_quality(quality: String) -> void:
	if _quality_buttons.has(quality):
		(_quality_buttons[quality] as Button).button_pressed = true


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if visible:
		resume()
	else:
		open()
	get_viewport().set_input_as_handled()


func _refresh(stats: Array) -> void:
	for child in _boost_list.get_children():
		child.queue_free()
	for pair: Array in weapons_source.call():
		_boost_list.add_child(_item_line(pair[0], "Sv. %d" % int(pair[1])))
	var picked := boosts.picked()
	if picked.is_empty():
		var none := UiTheme.label("Henüz boost yok. Seviye atlayınca seçersin.", UiTheme.label_settings(18, UiTheme.MUTED, 4))
		_boost_list.add_child(none)
	for pair: Array in picked:
		_boost_list.add_child(_item_line(pair[0], "x%d" % int(pair[1])))
	var lines: PackedStringArray = []
	for s: Array in stats:
		lines.append("%s: %s" % [s[0], s[1]])
	_stats_text.text = "\n".join(lines)


func _item_line(d: Dictionary, count_text: String) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	var icon := PixelIcons.rect(str(d.get("icon", "")), 22)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(icon)
	line.add_child(UiTheme.label("%s  %s" % [d.name, count_text], UiTheme.label_settings(17, UiTheme.TEXT, 4)))
	var detail := UiTheme.label("(%s)" % d.desc, UiTheme.label_settings(13, UiTheme.MUTED, 3))
	detail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(detail)
	return line
