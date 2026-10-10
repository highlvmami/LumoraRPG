## The skill tree drawn as one tree: the core skill sits in the middle and
## the branches (Saldırı up, Savunma right, Talih down, Hazine left) grow out
## from it, each in its own color. Every node is a round button (click to
## learn the next level, hover for details); lines join a node to the ones it
## needs and light up in the branch color once those reach the level asked.
extends Control

const UiTheme := preload("res://scripts/ui/theme.gd")
const PixelIcons := preload("res://scripts/ui/pixel_icons.gd")
const ItemSlot := preload("res://scripts/ui/item_slot.gd")

const NODE := 58.0
const CORE := 78.0
## Distance of each row from the middle, and how far apart the side nodes are.
const RADII := [105.0, 185.0, 265.0, 340.0, 415.0, 490.0, 565.0]
const SPREAD := 62.0
const TITLE_RADIUS := 650.0
## The tree is drawn a little wider than tall to fit the screen.
const STRETCH := Vector2(1.2, 0.82)
const VIEW_SIZE := Vector2(1500, 1000)

## The skill tree (scripts/progression/skill_tree.gd).
var tree: RefCounted
## Called with a node id when it is clicked.
var learn: Callable

var _nodes := {}


func setup(p_tree: RefCounted, p_learn: Callable) -> void:
	tree = p_tree
	learn = p_learn
	size = VIEW_SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS
	for b: Dictionary in tree.get("branches"):
		var title := UiTheme.label(UiTheme.upper(str(b.name)), UiTheme.label_settings(20, Color(str(b.color)).lightened(0.2), 4))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.size = Vector2(160, 28)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.set_meta("branch", str(b.id))
		add_child(title)
	for id: String in tree.get("nodes"):
		var n := _node(id)
		_nodes[id] = n
		add_child(n)
	resized.connect(_place)
	_place()


## Color of a node's branch (the core is gold).
func node_color(id: String) -> Color:
	var b := _branch(str(tree.get("nodes")[id].branch))
	return Color(str(b.color)) if not b.is_empty() else UiTheme.ACCENT


## Where a node's middle is in this view.
func node_center(id: String) -> Vector2:
	var middle := size * 0.5
	var d: Dictionary = tree.get("nodes")[id]
	var b := _branch(str(d.branch))
	if b.is_empty():
		return middle
	var dir := Vector2.from_angle(deg_to_rad(float(b.angle)))
	var side := Vector2(-dir.y, dir.x)
	var row := clampi(int(d.row), 0, RADII.size() - 1)
	return middle + dir * float(RADII[row]) * STRETCH + side * (float(d.col) - 1.0) * SPREAD


func _branch(id: String) -> Dictionary:
	for b: Dictionary in tree.get("branches"):
		if str(b.id) == id:
			return b
	return {}


func _place() -> void:
	for child in get_children():
		if child.has_meta("skill"):
			var id := str(child.get_meta("skill"))
			var s := CORE if id == str(tree.get("center")) else NODE
			(child as Control).position = node_center(id) - Vector2(s, s) * 0.5
		elif child.has_meta("branch"):
			var b := _branch(str(child.get_meta("branch")))
			var at := size * 0.5 + Vector2.from_angle(deg_to_rad(float(b.angle))) * TITLE_RADIUS * STRETCH
			(child as Control).position = at - (child as Control).size * 0.5
	queue_redraw()


func _draw() -> void:
	var middle := size * 0.5
	# A soft glow per branch and faint rings at each row.
	for b: Dictionary in tree.get("branches"):
		var dir := Vector2.from_angle(deg_to_rad(float(b.angle)))
		var color := Color(str(b.color))
		for n in 5:
			draw_circle(middle + dir * 330.0 * STRETCH, 300.0 - n * 50.0, Color(color, 0.025))
	for r: float in RADII:
		var ring := PackedVector2Array()
		for k in 97:
			ring.append(middle + Vector2.from_angle(TAU * k / 96.0) * r * STRETCH)
		draw_polyline(ring, Color(1, 1, 1, 0.05), 2.0)
	draw_circle(middle, CORE * 0.9, Color(UiTheme.ACCENT, 0.06))
	var nodes: Dictionary = tree.get("nodes")
	for id: String in nodes:
		var req: Dictionary = nodes[id].get("requires", {})
		for need: String in req:
			var met := int(tree.call("level", need)) >= int(req[need])
			var from := node_center(need)
			var to := node_center(id)
			draw_line(from, to, Color(0, 0, 0, 0.55), 8.0)
			draw_line(from, to, node_color(id) if met else Color(1, 1, 1, 0.13), 3.5 if met else 2.0)


## One round skill button with its icon and a level badge below.
func _node(id: String) -> Control:
	var d: Dictionary = tree.get("nodes")[id]
	var color := node_color(id)
	var s := CORE if id == str(tree.get("center")) else NODE
	var lv := int(tree.call("level", id))
	var open := bool(tree.call("is_unlocked", id))
	var maxed := bool(tree.call("is_maxed", id))
	var ready := bool(tree.call("can_buy", id))
	var box := Control.new()
	box.set_meta("skill", id)
	box.size = Vector2(s, s + 22.0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var button: Button = ItemSlot.new()
	button.size = Vector2(s, s)
	# Wheel and drag go on to the pan-and-zoom window around the tree.
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.tooltip_text = str(d.name)
	button.set("tooltip_builder", func() -> Control: return tooltip(id))
	var border := UiTheme.ACCENT if maxed else (color if lv > 0 else (color.darkened(0.2) if ready else Color(1, 1, 1, 0.18)))
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style := UiTheme.box(color.darkened(0.55 if lv > 0 else 0.8), int(s * 0.5), 6)
		style.set_border_width_all(4 if maxed or ready else 3)
		style.border_color = border.lightened(0.3) if state == "hover" else border
		if maxed or lv > 0:
			style.shadow_color = Color(border, 0.55)
			style.shadow_size = 8 if maxed else 4
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(func() -> void: learn.call(id))
	var icon_size := s * 0.6
	var icon := PixelIcons.rect(str(d.icon), icon_size)
	icon.position = Vector2(s - icon_size, s - icon_size) * 0.5
	icon.size = Vector2(icon_size, icon_size)
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
	var badge := UiTheme.label("KİLİTLİ" if not open else ("MAKS" if maxed else "%d/%d" % [lv, int(tree.call("max_level", id))]),
		UiTheme.label_settings(12, UiTheme.ACCENT if maxed else (UiTheme.MUTED if not open else color.lightened(0.3)), 3))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.position = Vector2(-20, s + 1.0)
	badge.size = Vector2(s + 40.0, 18)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(badge)
	return box


## Hover card: name, level, what it gives now and next, cost and what it needs.
func tooltip(id: String) -> Control:
	var d: Dictionary = tree.get("nodes")[id]
	var color := node_color(id)
	var lv := int(tree.call("level", id))
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
	var b := _branch(str(d.branch))
	var where := str(b.name) if not b.is_empty() else "Merkez"
	names.add_child(UiTheme.label("%s  ·  Seviye %d / %d" % [where, lv, int(tree.call("max_level", id))], UiTheme.label_settings(13, UiTheme.MUTED, 3)))
	head.add_child(names)
	col.add_child(head)
	col.add_child(HSeparator.new())
	col.add_child(UiTheme.label("Şu an: " + (str(tree.call("effect_text", id, lv)) if lv > 0 else "yok"), UiTheme.label_settings(15, Color("#8fe39a") if lv > 0 else UiTheme.MUTED, 3)))
	if bool(tree.call("is_maxed", id)):
		col.add_child(UiTheme.label("En yüksek seviyede", UiTheme.label_settings(14, UiTheme.ACCENT, 3)))
	else:
		col.add_child(UiTheme.label("Sonraki seviye: " + str(tree.call("effect_text", id, 1)), UiTheme.label_settings(15, UiTheme.TEXT, 3)))
		var cost := int(tree.call("cost", id))
		var afford := int(tree.call("points_left")) >= cost
		col.add_child(UiTheme.label("Maliyet: %d yetenek puanı" % cost, UiTheme.label_settings(14, Color("#8fe3ff") if afford else Color("#ff6b6b"), 3)))
	if not bool(tree.call("is_unlocked", id)):
		col.add_child(UiTheme.label("Gerekli: " + str(tree.call("requirement_text", id)), UiTheme.label_settings(14, Color("#ff6b6b"), 3)))
	elif not bool(tree.call("is_maxed", id)):
		col.add_child(UiTheme.label("Öğrenmek için tıkla", UiTheme.label_settings(12, UiTheme.MUTED, 2)))
	return panel
