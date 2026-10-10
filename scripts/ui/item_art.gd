## Detailed, scalable drawing of a gear item for menus (vector shapes, so it
## stays sharp at any size). Rarer items get more detail: very rare/epic add
## trims, gems and a glow, legendary/divine add ornaments and sparkles.
## Chests have their own drawing per chest tier: a plain crate, an iron-bound
## chest, an ornate gem-locked trunk and a golden winged treasure chest.
## Also builds the rich hover tooltip for items.
extends Control

const UiTheme := preload("res://scripts/ui/theme.gd")

const STEEL := Color("#dfe6ee")
const STEEL_DARK := Color("#7f8b9a")
const WOOD := Color("#8a5a2b")
const WOOD_DARK := Color("#5a3818")
const GOLD := Color("#ffd23f")
const GOLD_DARK := Color("#b07d12")
const LEATHER := Color("#8a5530")
const OUTLINE := Color(0, 0, 0, 0.75)

## Item base id (sword, bow, staff, helmet, armor, gloves, boots, ring) or "chest".
var base := ""
## 0-2 detail tier, see Gear.tier.
var tier := 0
## Chest tier 0-3 when this draws a chest.
var chest_tier := 0
var color := Color.WHITE
var _time := 0.0


## A drawing of `item` (or of a chest when `item` has a "tier" but no "base").
static func make(item: Dictionary, rarity_color: Color, detail_tier: int, art_size: float) -> Control:
	var art: Control = load("res://scripts/ui/item_art.gd").new()
	art.set("base", str(item.get("base", "chest")))
	art.set("tier", detail_tier)
	art.set("color", rarity_color)
	art.custom_minimum_size = Vector2(art_size, art_size)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art


## A drawing of a chest of `chest_index` (0 common .. 3 legendary).
static func chest(chest_index: int, chest_color: Color, art_size: float) -> Control:
	var art := make({"base": "chest"}, chest_color, [0, 1, 2, 2][clampi(chest_index, 0, 3)], art_size)
	art.set("chest_tier", clampi(chest_index, 0, 3))
	return art


## Tooltip panel: name, rarity, slot, who can wear it and every stat.
## `compare` = {"worn": item worn in that slot ({} if none), "who": wearer
## name, "can_wear": bool} adds the difference to the worn item next to each
## stat: green when this item is better, red when worse.
static func tooltip(gear: RefCounted, item: Dictionary, class_names: Dictionary, compare := {}) -> Control:
	var rarity := int(item.rarity)
	var c: Color = gear.call("rarity_color", rarity)
	var panel := PanelContainer.new()
	var style := UiTheme.box(Color(0.05, 0.07, 0.1, 0.97), 8, 12)
	style.set_border_width_all(2)
	style.border_color = c
	panel.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	panel.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)
	head.add_child(make(item, c, int(gear.call("tier", rarity)), 64))
	var names := VBoxContainer.new()
	names.add_child(UiTheme.label(str(gear.call("item_name", item)), UiTheme.label_settings(20, c, 4)))
	names.add_child(UiTheme.label(str(gear.call("rarity", rarity).name), UiTheme.label_settings(14, c.lightened(0.3), 3)))
	var cls := str(gear.call("item_class", item))
	names.add_child(UiTheme.label("%s  ·  %s" % [gear.call("slot_name", gear.call("item_slot", item)), "Tüm sınıflar" if cls == "" else str(class_names.get(cls, cls))], UiTheme.label_settings(13, UiTheme.MUTED, 3)))
	head.add_child(names)
	col.add_child(HSeparator.new())
	var stats: Dictionary = item.stats
	if compare.is_empty():
		for line: String in gear.call("stat_lines", item):
			col.add_child(UiTheme.label(line, UiTheme.label_settings(15, Color("#8fe39a"), 3)))
	else:
		var worn: Dictionary = compare.get("worn", {})
		var worn_stats: Dictionary = worn.get("stats", {})
		var note := "Takılı: %s" % gear.call("item_name", worn) if not worn.is_empty() else "Bu yuvada takılı eşya yok"
		col.add_child(UiTheme.label("%s  (%s)" % [note, compare.get("who", "")], UiTheme.label_settings(12, UiTheme.MUTED, 2)))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 18)
		grid.add_theme_constant_override("v_separation", 2)
		col.add_child(grid)
		var better := 0
		var worse := 0
		for stat: String in gear.call("stat_order"):
			var mine := float(stats.get(stat, 0.0))
			var theirs := float(worn_stats.get(stat, 0.0))
			if not stats.has(stat) and not worn_stats.has(stat):
				continue
			var diff := mine - theirs
			if stats.has(stat):
				grid.add_child(UiTheme.label(str(gear.call("stat_text", stat, mine)), UiTheme.label_settings(15, UiTheme.TEXT, 3)))
			else:
				grid.add_child(UiTheme.label("—  " + str(gear.call("stat_label", stat)), UiTheme.label_settings(15, UiTheme.MUTED, 3)))
			if bool(gear.call("is_tiny", stat, diff)):
				grid.add_child(UiTheme.label("=", UiTheme.label_settings(15, UiTheme.MUTED, 3)))
			else:
				var up := diff > 0.0
				if up:
					better += 1
				else:
					worse += 1
				grid.add_child(UiTheme.label(("▲ " if up else "▼ ") + str(gear.call("signed_text", stat, diff)), UiTheme.label_settings(15, Color("#5ee06a") if up else Color("#ff5a5a"), 3)))
		var verdict := "Takılıdan daha iyi" if better > 0 and worse == 0 else ("Takılıdan daha zayıf" if worse > 0 and better == 0 else "Bazı yönlerden daha iyi")
		if better == 0 and worse == 0:
			verdict = "Takılıyla aynı"
		var verdict_color := Color("#5ee06a") if worse == 0 and better > 0 else (Color("#ff5a5a") if better == 0 and worse > 0 else UiTheme.ACCENT)
		col.add_child(UiTheme.label(verdict, UiTheme.label_settings(13, verdict_color, 3)))
		if not bool(compare.get("can_wear", true)):
			col.add_child(UiTheme.label("Bu karakter bu eşyayı kullanamaz", UiTheme.label_settings(12, Color("#ff5a5a"), 2)))
	col.add_child(UiTheme.label("Satış: %d altın" % int(gear.call("sell_price", item)), UiTheme.label_settings(12, UiTheme.ACCENT, 3)))
	return panel


func _process(delta: float) -> void:
	if tier >= 2 and is_visible_in_tree():
		_time += delta
		queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y) / 100.0
	draw_set_transform(Vector2((size.x - 100.0 * s) * 0.5, (size.y - 100.0 * s) * 0.5), 0.0, Vector2(s, s))
	if base == "chest":
		_draw_chest()
		return
	_draw_glow()
	match base:
		"sword":
			_draw_rotated(-PI / 4.0, _draw_sword)
		"bow":
			_draw_rotated(-PI / 4.0, _draw_bow)
		"staff":
			_draw_rotated(PI / 6.0, _draw_staff)
		"dagger":
			_draw_rotated(-PI / 4.0, _draw_dagger)
		"helmet":
			_draw_helmet()
		"armor":
			_draw_armor()
		"gloves":
			_draw_gloves()
		"boots":
			_draw_boots()
		"ring":
			_draw_ring()
		_:
			_draw_chest()
	if tier >= 2:
		_draw_sparkles()


## Draws in 0..100 space rotated around the middle.
func _draw_rotated(angle: float, painter: Callable) -> void:
	var s := minf(size.x, size.y) / 100.0
	var origin := Vector2(size.x * 0.5, size.y * 0.5)
	var rot := Transform2D(angle, Vector2(s, s), 0.0, origin) * Transform2D(0.0, Vector2(-50, -50))
	draw_set_transform_matrix(rot)
	painter.call()
	draw_set_transform(Vector2((size.x - 100.0 * s) * 0.5, (size.y - 100.0 * s) * 0.5), 0.0, Vector2(s, s))


func _draw_glow() -> void:
	if tier == 0:
		return
	var steps := 6
	for i in steps:
		var a := (0.05 if tier == 1 else 0.08) * (i + 1) / steps
		draw_circle(Vector2(50, 50), 48.0 - i * 6.0, Color(color, a))


func _draw_sparkles() -> void:
	for i in 4:
		var angle := _time * 0.8 + TAU * i / 4.0
		var at := Vector2(50, 50) + Vector2(cos(angle), sin(angle)) * (36.0 + 4.0 * sin(_time * 3.0 + i))
		var r := 3.0 + 1.5 * sin(_time * 4.0 + i * 1.7)
		_star(at, r, Color(color.lightened(0.5), 0.9))


func _star(at: Vector2, r: float, c: Color) -> void:
	_poly([at + Vector2(0, -r * 2), at + Vector2(r * 0.4, -r * 0.4), at + Vector2(r * 2, 0), at + Vector2(r * 0.4, r * 0.4),
		at + Vector2(0, r * 2), at + Vector2(-r * 0.4, r * 0.4), at + Vector2(-r * 2, 0), at + Vector2(-r * 0.4, -r * 0.4)], c, false)


func _poly(points: Array, c: Color, outline := true) -> void:
	var packed := PackedVector2Array(points)
	draw_colored_polygon(packed, c)
	if outline:
		packed.append(packed[0])
		draw_polyline(packed, OUTLINE, 1.6)


func _gem(at: Vector2, r: float, c: Color) -> void:
	_poly([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)], c)
	_poly([at + Vector2(0, -r), at + Vector2(r * 0.5, -r * 0.1), at + Vector2(0, r * 0.2), at + Vector2(-r * 0.5, -r * 0.1)], c.lightened(0.45), false)


## Metal color of armor pieces: leather, then steel, then the rarity color.
func _metal() -> Color:
	return [LEATHER, STEEL.darkened(0.15), color.darkened(0.15)][tier]


func _draw_sword() -> void:
	var w := 7.0 + tier * 2.5
	var blade_top := 4.0
	var guard_y := 64.0
	var blade := [Vector2(50, blade_top), Vector2(50 + w, blade_top + 12), Vector2(50 + w, guard_y), Vector2(50 - w, guard_y), Vector2(50 - w, blade_top + 12)]
	_poly(blade, STEEL if tier < 2 else STEEL.lerp(color, 0.25))
	_poly([Vector2(50, blade_top), Vector2(50 + w, blade_top + 12), Vector2(50 + w, guard_y), Vector2(50, guard_y)], STEEL_DARK.lerp(color, 0.15 * tier), false)
	if tier >= 1:
		draw_line(Vector2(50, blade_top + 14), Vector2(50, guard_y - 4), color.lightened(0.2), 2.5)
	# Guard.
	var guard_c: Color = [WOOD, GOLD, color][tier]
	var gw := 18.0 + tier * 6.0
	_poly([Vector2(50 - gw, guard_y), Vector2(50 + gw, guard_y), Vector2(50 + gw - 3, guard_y + 7), Vector2(50 - gw + 3, guard_y + 7)], guard_c)
	if tier >= 2:
		_poly([Vector2(50 - gw, guard_y), Vector2(50 - gw - 6, guard_y - 9), Vector2(50 - gw + 4, guard_y - 2)], guard_c)
		_poly([Vector2(50 + gw, guard_y), Vector2(50 + gw + 6, guard_y - 9), Vector2(50 + gw - 4, guard_y - 2)], guard_c)
	# Grip with wraps and pommel.
	_poly([Vector2(46, guard_y + 7), Vector2(54, guard_y + 7), Vector2(54, guard_y + 24), Vector2(46, guard_y + 24)], WOOD_DARK)
	for i in 3:
		draw_line(Vector2(46, guard_y + 11 + i * 5), Vector2(54, guard_y + 9 + i * 5), LEATHER.lightened(0.3), 1.5)
	if tier >= 1:
		_gem(Vector2(50, guard_y + 30), 6.0 + tier, color)
		_gem(Vector2(50, guard_y + 3.5), 3.0 + tier, color.lightened(0.2))
	else:
		draw_circle(Vector2(50, guard_y + 29), 5.0, GOLD_DARK)


func _draw_bow() -> void:
	var limb: Color = [WOOD, WOOD.lerp(GOLD_DARK, 0.4), color.darkened(0.35)][tier]
	var center := Vector2(22, 50)
	var radius := 40.0
	var spread := deg_to_rad(62.0)
	draw_arc(center, radius, -spread, spread, 24, OUTLINE, 9.0)
	draw_arc(center, radius, -spread, spread, 24, limb, 6.0)
	draw_arc(center, radius - 1.5, -spread * 0.9, spread * 0.9, 20, limb.lightened(0.3), 1.6)
	var top := center + Vector2(cos(-spread), sin(-spread)) * radius
	var bottom := center + Vector2(cos(spread), sin(spread)) * radius
	draw_line(top, bottom, Color("#f1ead6") if tier < 2 else color.lightened(0.5), 1.6 if tier < 2 else 2.4)
	# Grip.
	_poly([Vector2(58, 43), Vector2(66, 43), Vector2(66, 57), Vector2(58, 57)], LEATHER)
	# Nocked arrow.
	draw_line(Vector2(top.x - 2, 50), Vector2(92, 50), WOOD_DARK, 2.5)
	_poly([Vector2(92, 45), Vector2(100, 50), Vector2(92, 55)], STEEL if tier == 0 else color.lightened(0.2))
	_poly([Vector2(top.x - 2, 50), Vector2(top.x - 10, 44), Vector2(top.x - 4, 50), Vector2(top.x - 10, 56)], Color("#e8e2d0"))
	if tier >= 1:
		_gem(top, 4.0 + tier, color)
		_gem(bottom, 4.0 + tier, color)
	if tier >= 2:
		_gem(Vector2(62, 50), 5.0, color.lightened(0.3))


func _draw_dagger() -> void:
	var w := 6.0 + tier * 1.5
	var tip := 12.0
	var guard_y := 62.0
	_poly([Vector2(50, tip), Vector2(50 + w, tip + 16), Vector2(50 + w, guard_y), Vector2(50 - w, guard_y), Vector2(50 - w, tip + 16)], STEEL if tier < 2 else STEEL.lerp(color, 0.3))
	_poly([Vector2(50, tip), Vector2(50 + w, tip + 16), Vector2(50 + w, guard_y), Vector2(50, guard_y)], STEEL_DARK.lerp(color, 0.15 * tier), false)
	if tier >= 1:
		draw_line(Vector2(50, tip + 18), Vector2(50, guard_y - 4), color.lightened(0.2), 2.0)
	var guard_c: Color = [WOOD, GOLD, color][tier]
	_poly([Vector2(36, guard_y), Vector2(64, guard_y), Vector2(61, guard_y + 6), Vector2(39, guard_y + 6)], guard_c)
	_poly([Vector2(46, guard_y + 6), Vector2(54, guard_y + 6), Vector2(54, guard_y + 24), Vector2(46, guard_y + 24)], WOOD_DARK)
	for i in 3:
		draw_line(Vector2(46, guard_y + 10 + i * 5), Vector2(54, guard_y + 8 + i * 5), LEATHER.lightened(0.3), 1.5)
	if tier >= 1:
		_gem(Vector2(50, guard_y + 29), 5.0 + tier, color)


func _draw_staff() -> void:
	_poly([Vector2(47, 34), Vector2(53, 34), Vector2(54, 98), Vector2(46, 98)], WOOD)
	draw_line(Vector2(49, 36), Vector2(49, 96), WOOD.lightened(0.25), 1.5)
	for i in 2:
		_poly([Vector2(45, 60 + i * 18), Vector2(55, 60 + i * 18), Vector2(55, 64 + i * 18), Vector2(45, 64 + i * 18)], GOLD_DARK if tier == 0 else GOLD)
	var orb_c := Color("#b98cff") if tier == 0 else color
	var r := 9.0 + tier * 3.5
	var orb := Vector2(50, 24)
	if tier >= 1:
		draw_arc(orb + Vector2(0, 4), r + 4.0, 0.2, PI - 0.2, 12, GOLD, 3.0)
	for i in 3:
		draw_circle(orb, r + 6.0 - i * 2.0, Color(orb_c, 0.12))
	draw_circle(orb, r, orb_c)
	draw_circle(orb + Vector2(-r * 0.35, -r * 0.35), r * 0.35, orb_c.lightened(0.6))
	draw_arc(orb, r, 0, TAU, 20, OUTLINE, 1.6)
	if tier >= 2:
		draw_arc(orb, r + 9.0, _time, _time + PI * 1.3, 16, color.lightened(0.4), 2.0)
		draw_arc(orb, r + 9.0, _time + PI, _time + PI * 2.3, 16, color.lightened(0.4), 2.0)


func _draw_helmet() -> void:
	var m := _metal()
	var dome := [Vector2(18, 60)]
	for i in 13:
		var a := PI + PI * i / 12.0
		dome.append(Vector2(50, 58) + Vector2(cos(a), sin(a)) * 32.0)
	dome.append(Vector2(82, 60))
	dome.append(Vector2(82, 78))
	dome.append(Vector2(66, 84))
	dome.append(Vector2(66, 66))
	dome.append(Vector2(34, 66))
	dome.append(Vector2(34, 84))
	dome.append(Vector2(18, 78))
	_poly(dome, m)
	_poly([Vector2(54, 28), Vector2(76, 44), Vector2(80, 58), Vector2(62, 58)], m.darkened(0.2), false)
	_poly([Vector2(18, 56), Vector2(82, 56), Vector2(82, 63), Vector2(18, 63)], m.darkened(0.35))
	if tier >= 1:
		_poly([Vector2(46, 28), Vector2(54, 28), Vector2(56, 6), Vector2(44, 6)], color)
		for i in 4:
			draw_circle(Vector2(26 + i * 16, 59.5), 2.0, GOLD)
	if tier >= 2:
		_poly([Vector2(20, 44), Vector2(4, 22), Vector2(10, 18), Vector2(26, 38)], Color("#f4f1e6"))
		_poly([Vector2(80, 44), Vector2(96, 22), Vector2(90, 18), Vector2(74, 38)], Color("#f4f1e6"))
		_gem(Vector2(50, 46), 6.0, color.lightened(0.2))


func _draw_armor() -> void:
	var m := _metal()
	var body := [Vector2(30, 14), Vector2(42, 20), Vector2(58, 20), Vector2(70, 14), Vector2(90, 28), Vector2(82, 46),
		Vector2(74, 42), Vector2(74, 90), Vector2(26, 90), Vector2(26, 42), Vector2(18, 46), Vector2(10, 28)]
	_poly(body, m)
	_poly([Vector2(50, 20), Vector2(58, 20), Vector2(70, 14), Vector2(90, 28), Vector2(82, 46), Vector2(74, 42), Vector2(74, 90), Vector2(50, 90)], m.darkened(0.18), false)
	draw_line(Vector2(50, 24), Vector2(50, 88), m.darkened(0.4), 2.0)
	_poly([Vector2(26, 76), Vector2(74, 76), Vector2(74, 82), Vector2(26, 82)], LEATHER.darkened(0.2))
	draw_circle(Vector2(50, 79), 3.5, GOLD)
	if tier >= 1:
		draw_polyline(PackedVector2Array([Vector2(30, 16), Vector2(42, 22), Vector2(58, 22), Vector2(70, 16)]), color, 3.0)
		_poly([Vector2(8, 26), Vector2(30, 12), Vector2(34, 22), Vector2(14, 36)], m.lightened(0.15))
		_poly([Vector2(92, 26), Vector2(70, 12), Vector2(66, 22), Vector2(86, 36)], m.lightened(0.15))
	if tier >= 2:
		_gem(Vector2(50, 46), 9.0, color.lightened(0.25))
		_poly([Vector2(10, 22), Vector2(4, 8), Vector2(18, 16)], GOLD)
		_poly([Vector2(90, 22), Vector2(96, 8), Vector2(82, 16)], GOLD)


func _draw_gloves() -> void:
	var m := _metal()
	_poly([Vector2(30, 64), Vector2(70, 64), Vector2(74, 92), Vector2(26, 92)], m.darkened(0.25))
	_poly([Vector2(30, 34), Vector2(68, 34), Vector2(70, 66), Vector2(30, 66)], m)
	for i in 4:
		var x := 32.0 + i * 9.5
		_poly([Vector2(x, 12 + absf(i - 1.5) * 4), Vector2(x + 8, 12 + absf(i - 1.5) * 4), Vector2(x + 8, 36), Vector2(x, 36)], m.lightened(0.08))
	_poly([Vector2(30, 46), Vector2(18, 36), Vector2(12, 42), Vector2(26, 60)], m.lightened(0.05))
	if tier >= 1:
		for i in 4:
			draw_circle(Vector2(36 + i * 9.5, 40), 2.5, GOLD)
		_poly([Vector2(26, 82), Vector2(74, 82), Vector2(74, 88), Vector2(26, 88)], color)
	if tier >= 2:
		_gem(Vector2(50, 52), 7.0, color.lightened(0.25))


func _draw_boots() -> void:
	var m := _metal()
	_poly([Vector2(32, 10), Vector2(62, 10), Vector2(62, 62), Vector2(88, 70), Vector2(90, 86), Vector2(30, 86)], m)
	_poly([Vector2(28, 86), Vector2(92, 86), Vector2(92, 94), Vector2(28, 94)], Color("#2a1d14"))
	_poly([Vector2(30, 10), Vector2(64, 10), Vector2(64, 20), Vector2(30, 20)], m.darkened(0.3))
	draw_line(Vector2(36, 40), Vector2(58, 40), m.darkened(0.4), 2.0)
	draw_circle(Vector2(47, 40), 3.0, GOLD if tier >= 1 else GOLD_DARK)
	if tier >= 1:
		_poly([Vector2(30, 20), Vector2(64, 20), Vector2(64, 25), Vector2(30, 25)], color)
	if tier >= 2:
		_poly([Vector2(30, 30), Vector2(6, 16), Vector2(12, 30), Vector2(4, 34), Vector2(14, 42), Vector2(8, 48), Vector2(30, 48)], color.lightened(0.3))


func _draw_ring() -> void:
	var band: Color = [GOLD_DARK.lightened(0.2), GOLD, color.lerp(GOLD, 0.5)][tier]
	draw_arc(Vector2(50, 62), 24.0, 0, TAU, 32, OUTLINE, 11.0)
	draw_arc(Vector2(50, 62), 24.0, 0, TAU, 32, band, 8.0)
	draw_arc(Vector2(50, 62), 22.0, PI * 0.9, PI * 1.6, 10, band.lightened(0.5), 2.0)
	_poly([Vector2(40, 40), Vector2(60, 40), Vector2(56, 32), Vector2(44, 32)], band.darkened(0.2))
	_gem(Vector2(50, 26), 9.0 + tier * 3.0, color if tier > 0 else Color("#e0484f"))


func _draw_chest() -> void:
	match chest_tier:
		1:
			_chest_iron()
		2:
			_chest_ornate()
		3:
			_chest_legendary()
		_:
			_chest_crate()


## Common: a plain wooden crate with plank lines and iron corners.
func _chest_crate() -> void:
	var wood := WOOD.lerp(color, 0.12)
	_poly([Vector2(16, 42), Vector2(84, 42), Vector2(84, 88), Vector2(16, 88)], wood)
	for y: float in [57.0, 72.0]:
		draw_line(Vector2(17, y), Vector2(83, y), WOOD_DARK, 2.0)
	_poly([Vector2(12, 32), Vector2(88, 32), Vector2(88, 44), Vector2(12, 44)], wood.lightened(0.12))
	draw_line(Vector2(13, 38), Vector2(87, 38), WOOD_DARK, 1.5)
	for x: float in [16.0, 78.0]:
		_poly([Vector2(x, 44), Vector2(x + 6, 44), Vector2(x + 6, 88), Vector2(x, 88)], STEEL_DARK)
		draw_circle(Vector2(x + 3, 50), 1.4, STEEL)
		draw_circle(Vector2(x + 3, 82), 1.4, STEEL)
	_poly([Vector2(46, 40), Vector2(54, 40), Vector2(54, 52), Vector2(46, 52)], STEEL_DARK)


## Rare: a rounded-lid chest bound with tinted steel, rivets and a keyhole lock.
func _chest_iron() -> void:
	var wood := WOOD.lerp(color, 0.18)
	var steel := STEEL.lerp(color, 0.35)
	_poly([Vector2(14, 48), Vector2(86, 48), Vector2(86, 88), Vector2(14, 88)], wood)
	draw_line(Vector2(15, 68), Vector2(85, 68), WOOD_DARK, 1.6)
	var lid := [Vector2(14, 48)]
	for i in 11:
		var a := PI + PI * i / 10.0
		lid.append(Vector2(50, 48) + Vector2(cos(a) * 36.0, sin(a) * 24.0))
	lid.append(Vector2(86, 48))
	_poly(lid, wood.lightened(0.12))
	for x: float in [26.0, 74.0]:
		var top := 48.0 - sqrt(maxf(0.0, 1.0 - pow((x - 50.0) / 36.0, 2.0))) * 24.0
		_poly([Vector2(x - 4, top), Vector2(x + 4, top), Vector2(x + 4, 88), Vector2(x - 4, 88)], steel)
		for y: float in [top + 6.0, 56.0, 72.0, 84.0]:
			draw_circle(Vector2(x, y), 1.5, steel.lightened(0.5))
	_poly([Vector2(14, 46), Vector2(86, 46), Vector2(86, 52), Vector2(14, 52)], steel.darkened(0.25))
	# Corner plates.
	_poly([Vector2(14, 88), Vector2(14, 76), Vector2(24, 88)], steel)
	_poly([Vector2(86, 88), Vector2(86, 76), Vector2(76, 88)], steel)
	# Lock plate with a keyhole.
	_poly([Vector2(41, 46), Vector2(59, 46), Vector2(59, 60), Vector2(50, 68), Vector2(41, 60)], GOLD)
	draw_circle(Vector2(50, 54), 2.6, OUTLINE)
	_poly([Vector2(48.8, 55), Vector2(51.2, 55), Vector2(52, 61), Vector2(48, 61)], OUTLINE, false)


## Epic: a trunk widening to the top, gold-trimmed, a glowing seam under the
## lid, swirls, side handles, little feet and a big gem lock.
func _chest_ornate() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 3.0)
	for i in 6:
		draw_circle(Vector2(50, 54), 50.0 - i * 6.0, Color(color, 0.05 + 0.03 * i * (0.6 + 0.4 * pulse) / 3.0))
	var body := color.darkened(0.55).lerp(WOOD_DARK, 0.3)
	# Feet.
	for x: float in [20.0, 80.0]:
		_poly([Vector2(x - 6, 88), Vector2(x + 6, 88), Vector2(x + 4, 95), Vector2(x - 4, 95)], GOLD_DARK)
	_poly([Vector2(10, 52), Vector2(90, 52), Vector2(84, 90), Vector2(16, 90)], body)
	_poly([Vector2(50, 52), Vector2(90, 52), Vector2(84, 90), Vector2(50, 90)], body.darkened(0.15), false)
	# Gold swirls on the front.
	for side: float in [-1.0, 1.0]:
		var cx := 50.0 + side * 22.0
		draw_arc(Vector2(cx, 72), 7.0, 0, PI * 1.5, 12, GOLD, 2.0)
		draw_arc(Vector2(cx + side * 3.0, 72), 3.0, PI, PI * 2.5, 8, GOLD, 1.6)
	# Side ring handles.
	for x: float in [8.0, 92.0]:
		draw_arc(Vector2(x, 66), 6.0, 0, TAU, 14, OUTLINE, 4.0)
		draw_arc(Vector2(x, 66), 6.0, 0, TAU, 14, GOLD, 2.5)
	# Domed lid with gold ribs.
	var lid := [Vector2(8, 52)]
	for i in 13:
		var a := PI + PI * i / 12.0
		lid.append(Vector2(50, 52) + Vector2(cos(a) * 42.0, sin(a) * 30.0))
	lid.append(Vector2(92, 52))
	_poly(lid, body.lightened(0.15))
	for x: float in [22.0, 50.0, 78.0]:
		var top := 52.0 - sqrt(maxf(0.0, 1.0 - pow((x - 50.0) / 42.0, 2.0))) * 30.0
		draw_line(Vector2(x, top + 1.0), Vector2(x, 52), GOLD, 3.0)
	_poly([Vector2(6, 48), Vector2(94, 48), Vector2(94, 54), Vector2(6, 54)], GOLD)
	# Light leaking out of the seam.
	draw_line(Vector2(12, 55.5), Vector2(88, 55.5), Color(color.lightened(0.7), 0.6 + 0.4 * pulse), 2.5)
	for i in 4:
		var x := 22.0 + i * 19.0
		_poly([Vector2(x - 3, 54), Vector2(x + 3, 54), Vector2(x + 8, 34), Vector2(x - 8, 34)], Color(color.lightened(0.6), 0.10 + 0.08 * pulse), false)
	# Gem lock in a gold frame.
	_poly([Vector2(40, 50), Vector2(60, 50), Vector2(62, 62), Vector2(50, 72), Vector2(38, 62)], GOLD)
	_gem(Vector2(50, 60), 8.0, color.lightened(0.25))
	_gem(Vector2(50, 28), 4.0, color.lightened(0.4))
	_sparkle_ring(3, 44.0, color)


## Legendary: a golden treasure chest with a crown of spikes and gems, wings
## on its sides, claw feet, turning light rays behind and light bursting out.
func _chest_legendary() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 3.5)
	# Turning light rays.
	for i in 10:
		var a := _time * 0.35 + TAU * i / 10.0
		var tip_a := Vector2.from_angle(a - 0.12) * 60.0
		var tip_b := Vector2.from_angle(a + 0.12) * 60.0
		_poly([Vector2(50, 56), Vector2(50, 56) + tip_a, Vector2(50, 56) + tip_b], Color(color.lightened(0.5), 0.10 + 0.06 * pulse), false)
	for i in 6:
		draw_circle(Vector2(50, 56), 46.0 - i * 6.0, Color(GOLD, 0.05 + 0.02 * i))
	var gold := GOLD.lerp(color, 0.25)
	var panel_c := color.darkened(0.45)
	# Wings.
	for side: float in [-1.0, 1.0]:
		var root := Vector2(50 + side * 34.0, 62)
		for f in 3:
			var wing_len := 26.0 - f * 5.0
			var tip := root + Vector2(side * wing_len, -18.0 + f * 9.0)
			_poly([root + Vector2(0, -6 + f * 5.0), tip, root + Vector2(side * wing_len * 0.5, 4.0 + f * 4.0)], Color("#fff6dc").lerp(gold, f * 0.3))
	# Claw feet.
	for x: float in [20.0, 80.0]:
		_poly([Vector2(x - 7, 86), Vector2(x + 7, 86), Vector2(x + 9, 96), Vector2(x + 3, 92), Vector2(x, 97), Vector2(x - 3, 92), Vector2(x - 9, 96)], GOLD_DARK)
	# Body: gold frame with colored panels.
	_poly([Vector2(14, 54), Vector2(86, 54), Vector2(86, 88), Vector2(14, 88)], gold)
	for px: Array in [[19.0, 44.0], [56.0, 81.0]]:
		_poly([Vector2(px[0], 60), Vector2(px[1], 60), Vector2(px[1], 83), Vector2(px[0], 83)], panel_c)
		_gem(Vector2((px[0] + px[1]) * 0.5, 71.5), 4.0, color.lightened(0.3))
	# Tall lid with a crown.
	var lid := [Vector2(12, 54)]
	for i in 13:
		var a := PI + PI * i / 12.0
		lid.append(Vector2(50, 54) + Vector2(cos(a) * 38.0, sin(a) * 22.0))
	lid.append(Vector2(88, 54))
	_poly(lid, gold.lightened(0.1))
	_poly([Vector2(20, 44), Vector2(80, 44), Vector2(84, 50), Vector2(16, 50)], panel_c)
	var crown := [Vector2(28, 34), Vector2(30, 18), Vector2(39, 28), Vector2(50, 10), Vector2(61, 28), Vector2(70, 18), Vector2(72, 34)]
	_poly(crown, gold)
	_gem(Vector2(50, 22), 4.5, Color("#ff4d6d"))
	_gem(Vector2(31, 24), 3.0, Color("#4fb8ff"))
	_gem(Vector2(69, 24), 3.0, Color("#5fcf6a"))
	_poly([Vector2(10, 52), Vector2(90, 52), Vector2(90, 58), Vector2(10, 58)], GOLD_DARK)
	# Light bursting from the seam.
	draw_line(Vector2(14, 58.5), Vector2(86, 58.5), Color(1, 1, 0.85, 0.7 + 0.3 * pulse), 3.0)
	for i in 5:
		var x := 20.0 + i * 15.0
		_poly([Vector2(x - 2, 56), Vector2(x + 2, 56), Vector2(x + 7, 30), Vector2(x - 7, 30)], Color(1, 0.95, 0.7, 0.12 + 0.1 * pulse), false)
	# Big pulsing gem lock.
	_poly([Vector2(38, 52), Vector2(62, 52), Vector2(64, 66), Vector2(50, 78), Vector2(36, 66)], GOLD_DARK)
	draw_circle(Vector2(50, 63), 10.0 + 2.0 * pulse, Color(color.lightened(0.5), 0.35))
	_gem(Vector2(50, 63), 9.0, color.lightened(0.15))
	_sparkle_ring(6, 48.0, GOLD)


func _sparkle_ring(count: int, radius: float, c: Color) -> void:
	for i in count:
		var angle := _time * 0.7 + TAU * i / count
		var at := Vector2(50, 54) + Vector2(cos(angle), sin(angle) * 0.8) * (radius + 3.0 * sin(_time * 2.5 + i))
		_star(at, 2.5 + 1.5 * sin(_time * 4.0 + i * 1.3), Color(c.lightened(0.6), 0.95))
