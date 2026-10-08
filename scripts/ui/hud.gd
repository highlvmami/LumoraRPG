## In-run HUD: account and character level, exp and health bars, run stats,
## floating "+EXP" texts over killed enemies and a level-up toast.
extends CanvasLayer

const UiTheme := preload("res://scripts/ui/theme.gd")
const Progression := preload("res://scripts/progression/progression.gd")
const EnemyManager := preload("res://scripts/enemies/enemy_manager.gd")

signal restart_requested

var player: CharacterBody3D
var progression: Progression
var enemies: EnemyManager
var camera: Camera3D

var _account: Label
var _level: Label
var _exp_bar: ProgressBar
var _hp_bar: ProgressBar
var _stats: Label
var _toast: Label
var _start_hint: Control
var _death: Control
var _death_text: Label
var _small: LabelSettings


func setup(p_player: CharacterBody3D, p_progression: Progression, p_enemies: EnemyManager, p_camera: Camera3D) -> void:
	player = p_player
	progression = p_progression
	enemies = p_enemies
	camera = p_camera
	_small = UiTheme.label_settings(10)

	var top_left := VBoxContainer.new()
	top_left.position = Vector2(6, 4)
	top_left.add_theme_constant_override("separation", 1)
	add_child(top_left)
	_account = UiTheme.label("", UiTheme.label_settings(8, Color("#9fd3ff"), 2))
	top_left.add_child(_account)
	_level = UiTheme.label("", _small)
	top_left.add_child(_level)
	_exp_bar = _bar(Color("#5fb8ff"))
	top_left.add_child(_exp_bar)
	_hp_bar = _bar(Color("#e0484f"))
	top_left.add_child(_hp_bar)

	_stats = UiTheme.label("", UiTheme.label_settings(8, Color("#f0f0e0"), 2))
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stats.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 6)
	_stats.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(_stats)

	var controls := UiTheme.label("WASD: yürü   BOŞLUK: zıpla   FARE: bak   ESC: fareyi bırak", UiTheme.label_settings(8, Color("#f0f0e0"), 2))
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 6)
	add_child(controls)

	_toast = UiTheme.label("", UiTheme.label_settings(16, Color("#ffd866"), 4))
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.position.y = 40
	_toast.modulate.a = 0.0
	add_child(_toast)

	_start_hint = _overlay("Oynamak için tıkla")
	_death = _overlay("")
	_death_text = _death.get_child(0).get_child(0) as Label
	var again := Button.new()
	again.text = "Tekrar Oyna"
	again.add_theme_font_size_override("font_size", 10)
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.pressed.connect(func() -> void: restart_requested.emit())
	_death.get_child(0).add_child(again)
	_death.visible = false

	progression.level_up.connect(func(lv: int) -> void: _show_toast("SEVİYE %d!" % lv))
	progression.account_level_up.connect(func(lv: int) -> void: _show_toast("HESAP SEVİYESİ %d!" % lv))
	enemies.enemy_killed.connect(_on_enemy_killed)


func show_death(level: int, kills: int, seconds: float) -> void:
	_death_text.text = "ÖLDÜN\n\nSeviye %d  ·  %d canavar  ·  %d:%02d" % [level, kills, int(seconds) / 60, int(seconds) % 60]
	_death.visible = true


func hide_death() -> void:
	_death.visible = false


func _process(_delta: float) -> void:
	if player == null:
		return
	_start_hint.visible = not _death.visible and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	_account.text = "%s  ·  Hesap Sv. %d  (%d/%d)" % [
		progression.profile.name, progression.account_level(),
		progression.account_exp(), progression.exp_to_next_account_level()]
	_level.text = "Sv. %d" % progression.level
	_exp_bar.max_value = progression.exp_to_next_level()
	_exp_bar.value = progression.level_exp
	_hp_bar.max_value = float(player.get("max_hp"))
	_hp_bar.value = float(player.get("hp"))
	var t := int(enemies.run_time)
	_stats.text = "%d:%02d\n%d canavar\nFPS %d" % [t / 60, t % 60, enemies.kills, Engine.get_frames_per_second()]


## Small "+3 EXP" text that rises from where the enemy died.
func _on_enemy_killed(at_position: Vector3, exp_amount: int) -> void:
	if camera == null or camera.is_position_behind(at_position):
		return
	var label := UiTheme.label("+%d EXP" % exp_amount, UiTheme.label_settings(8, Color("#8fe3ff"), 2))
	label.position = camera.unproject_position(at_position + Vector3.UP * 0.8) - Vector2(14, 0)
	add_child(label)
	var tween := create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 18.0, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(90, 5)
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


## Full-screen dimmed overlay with a centered message.
func _overlay(text: String) -> Control:
	var rect := ColorRect.new()
	rect.color = Color(0.04, 0.06, 0.08, 0.55)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.add_child(box)
	var label := UiTheme.label(text, UiTheme.label_settings(12))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	return rect
