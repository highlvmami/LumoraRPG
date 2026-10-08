## In-run HUD: account and character level, exp and health bars, gold, run stats,
## floating "+EXP" texts over killed enemies, a level-up toast and the death screen.
extends CanvasLayer

const UiTheme := preload("res://scripts/ui/theme.gd")
const Progression := preload("res://scripts/progression/progression.gd")
const EnemyManager := preload("res://scripts/enemies/enemy_manager.gd")

signal restart_requested
signal menu_requested

var player: CharacterBody3D
var progression: Progression
var enemies: EnemyManager
var camera: Camera3D
## The 3D view renders at a lower resolution than the UI; screen positions
## from the camera are multiplied by this to land in UI space.
var world_scale := 1.0

var _root: Control
var _account: Label
var _level: Label
var _exp_bar: ProgressBar
var _hp_bar: ProgressBar
var _hp_text: Label
var _gold: Label
var _stats: Label
var _toast: Label
var _start_hint: Control
var _death: Control
var _death_text: Label
var _float_settings: LabelSettings
var _gold_settings: LabelSettings


func setup(p_player: CharacterBody3D, p_progression: Progression, p_enemies: EnemyManager, p_camera: Camera3D, p_world_scale: float) -> void:
	player = p_player
	progression = p_progression
	enemies = p_enemies
	camera = p_camera
	world_scale = p_world_scale
	_float_settings = UiTheme.label_settings(20, Color("#8fe3ff"), 5)
	_gold_settings = UiTheme.label_settings(18, UiTheme.ACCENT, 5)

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
	_level = UiTheme.label("", UiTheme.label_settings(30))
	top_left.add_child(_level)
	_exp_bar = _bar(Color("#5fb8ff"), Vector2(260, 12))
	top_left.add_child(_exp_bar)
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	top_left.add_child(hp_row)
	_hp_bar = _bar(Color("#e0484f"), Vector2(260, 16))
	_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_row.add_child(_hp_bar)
	_hp_text = UiTheme.label("", UiTheme.label_settings(16, UiTheme.TEXT, 4))
	hp_row.add_child(_hp_text)
	_gold = UiTheme.label("", UiTheme.label_settings(22, UiTheme.ACCENT))
	top_left.add_child(_gold)

	_stats = UiTheme.label("", UiTheme.label_settings(20))
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stats.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
	_stats.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_root.add_child(_stats)

	var controls := UiTheme.label("WASD: yürü    BOŞLUK: zıpla    FARE: bak    ESC: fareyi bırak", UiTheme.label_settings(16, UiTheme.MUTED, 4))
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 20)
	_root.add_child(controls)

	_toast = UiTheme.label("", UiTheme.label_settings(40, UiTheme.ACCENT, 10))
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.position.y = 110
	_toast.modulate.a = 0.0
	_root.add_child(_toast)

	_start_hint = _overlay()
	_start_hint.get_child(0).add_child(_centered_label("Oynamak için tıkla", 30))

	_death = _overlay()
	var death_box := _death.get_child(0) as VBoxContainer
	_death_text = _centered_label("", 30)
	death_box.add_child(_death_text)
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

	progression.level_up.connect(func(lv: int) -> void: _show_toast("SEVİYE %d!" % lv))
	progression.account_level_up.connect(func(lv: int) -> void: _show_toast("HESAP SEVİYESİ %d!" % lv))
	enemies.enemy_killed.connect(_on_enemy_killed)


func show_death(level: int, kills: int, gold: int, seconds: float) -> void:
	_death_text.text = "ÖLDÜN\n\nSeviye %d   ·   %d canavar   ·   +%d altın   ·   %d:%02d" % [level, kills, gold, int(seconds) / 60, int(seconds) % 60]
	_death.visible = true


func hide_death() -> void:
	_death.visible = false


func _process(_delta: float) -> void:
	if player == null or not visible:
		return
	_start_hint.visible = not _death.visible and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	_account.text = "%s   ·   Hesap Sv. %d   (%d / %d)" % [
		progression.profile.name, progression.account_level(),
		progression.account_exp(), progression.exp_to_next_account_level()]
	_level.text = "Seviye %d" % progression.level
	_exp_bar.max_value = progression.exp_to_next_level()
	_exp_bar.value = progression.level_exp
	var max_hp := float(player.get("max_hp"))
	var hp := float(player.get("hp"))
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_text.text = "%d / %d" % [ceili(hp), int(max_hp)]
	_gold.text = "Altın: %d" % progression.gold()
	var t := int(enemies.run_time)
	_stats.text = "%d:%02d\n%d canavar\nFPS %d" % [t / 60, t % 60, enemies.kills, Engine.get_frames_per_second()]


## "+3 EXP" (and "+1 altın") rising from where the enemy died.
func _on_enemy_killed(at_position: Vector3, exp_amount: int, gold_amount: int) -> void:
	if camera == null or not camera.is_inside_tree() or camera.is_position_behind(at_position):
		return
	var screen := camera.unproject_position(at_position + Vector3.UP * 0.8) * world_scale
	_float_text("+%d EXP" % exp_amount, _float_settings, screen)
	if gold_amount > 0:
		_float_text("+%d altın" % gold_amount, _gold_settings, screen + Vector2(0, 24))


func _float_text(text: String, settings: LabelSettings, at: Vector2) -> void:
	var label := UiTheme.label(text, settings)
	_root.add_child(label)
	label.position = at - Vector2(label.get_minimum_size().x * 0.5, 0)
	var tween := create_tween().set_parallel()
	tween.tween_property(label, "position:y", at.y - 44.0, 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.35)
	tween.chain().tween_callback(label.queue_free)


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


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
