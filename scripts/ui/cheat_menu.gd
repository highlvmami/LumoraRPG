## Developer cheat panel on the right edge (F1 or the "HİLE" tab).
## Stat rows add on top of everything else (base, level, items, boosts);
## action buttons ask the game to do things through `action_requested`.
extends CanvasLayer

const UiTheme := preload("res://scripts/ui/theme.gd")

## [stat key, label, step per click, display format, display multiplier]
const STATS := [
	["damage", "Hasar", 0.25, "+%d%%", 100.0],
	["attackSpeed", "Saldırı Hızı", 0.25, "+%d%%", 100.0],
	["range", "Saldırı Alanı", 1.0, "+%.0f", 1.0],
	["critChance", "Kritik Şansı", 0.05, "+%d%%", 100.0],
	["critDamage", "Kritik Hasarı", 0.25, "+%.2f", 1.0],
	["maxHp", "Maks. Can", 25.0, "+%.0f", 1.0],
	["moveSpeed", "Hareket Hızı", 0.1, "+%d%%", 100.0],
	["regen", "Can Yenileme", 1.0, "+%.0f", 1.0],
]
## [action id, button text]
const ACTIONS := [
	["gold", "+100 altın"],
	["level", "+1 seviye"],
	["heal", "Canı doldur"],
	["clear", "Canavarları sil"],
	["spawn_wolf", "5 kurt çağır"],
	["spawn_spider", "3 örümcek çağır"],
	["spawn_thrower", "3 goblin çağır"],
	["time", "+1 dakika (zorluk)"],
]

## A stat bonus changed; recalculate stats.
signal changed
signal action_requested(id: String)
signal god_mode_toggled(on: bool)

## Stat key -> bonus added by the cheat panel.
var bonus := {}
var god_mode := false

var _panel: PanelContainer
var _values := {}
var _god_button: Button


func setup() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.theme()
	add_child(root)

	var tab := Button.new()
	tab.text = "HİLE"
	tab.add_theme_font_size_override("font_size", 14)
	tab.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 6)
	tab.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tab.pressed.connect(toggle)
	root.add_child(tab)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiTheme.box(Color(0.07, 0.09, 0.12, 0.94), 10, 10))
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 60)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.visible = false
	root.add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_panel.add_child(col)
	col.add_child(UiTheme.label("Geliştirici (F1)", UiTheme.label_settings(16, UiTheme.ACCENT, 4)))

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 2)
	col.add_child(grid)
	for st: Array in STATS:
		bonus[st[0]] = 0.0
		var name_label := UiTheme.label(st[1], UiTheme.label_settings(13, UiTheme.TEXT, 3))
		name_label.custom_minimum_size.x = 110
		grid.add_child(name_label)
		grid.add_child(_small_button("-", _step.bind(st[0], -1)))
		var value := UiTheme.label("", UiTheme.label_settings(13, UiTheme.MUTED, 3))
		value.custom_minimum_size.x = 52
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(value)
		_values[st[0]] = value
		grid.add_child(_small_button("+", _step.bind(st[0], 1)))

	col.add_child(HSeparator.new())
	_god_button = Button.new()
	_god_button.toggle_mode = true
	_god_button.add_theme_font_size_override("font_size", 13)
	_god_button.toggled.connect(_on_god_toggled)
	col.add_child(_god_button)
	var actions := GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 4)
	actions.add_theme_constant_override("v_separation", 4)
	col.add_child(actions)
	for a: Array in ACTIONS:
		var b := Button.new()
		b.text = a[1]
		b.add_theme_font_size_override("font_size", 12)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: action_requested.emit(a[0]))
		actions.add_child(b)
	var reset := Button.new()
	reset.text = "Hileleri sıfırla"
	reset.add_theme_font_size_override("font_size", 12)
	reset.pressed.connect(reset_all)
	col.add_child(reset)
	_refresh()


func is_open() -> bool:
	return _panel.visible


func toggle() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func total(stat: String) -> float:
	return float(bonus.get(stat, 0.0))


func reset_all() -> void:
	for key: String in bonus:
		bonus[key] = 0.0
	_god_button.set_pressed_no_signal(false)
	_on_god_toggled(false)
	changed.emit()


func _step(stat: String, direction: int) -> void:
	for st: Array in STATS:
		if st[0] == stat:
			bonus[stat] = maxf(0.0, total(stat) + float(st[2]) * direction)
	_refresh()
	changed.emit()


func _on_god_toggled(on: bool) -> void:
	god_mode = on
	_refresh()
	god_mode_toggled.emit(on)


func _refresh() -> void:
	for st: Array in STATS:
		var v := total(st[0]) * float(st[4])
		var text: String = st[3] % (roundi(v) if "%d" in st[3] else v)
		(_values[st[0]] as Label).text = text
	_god_button.text = "Ölümsüzlük: %s" % ("AÇIK" if god_mode else "kapalı")


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_F1:
		toggle()
		get_viewport().set_input_as_handled()


func _small_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(26, 22)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.BUTTON, 5, 2))
	b.add_theme_stylebox_override("hover", UiTheme.box(UiTheme.BUTTON_HOVER, 5, 2))
	b.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.BUTTON_PRESSED, 5, 2))
	b.pressed.connect(on_press)
	return b
