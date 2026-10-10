## The main menu's town: a living pixel-art street in three rows (back, middle,
## front), with detailed buildings (see city_art.gd), a sky that follows the
## real clock (dawn, day, dusk, stars and a moon at night), drifting clouds
## and birds, smoke from chimneys, waving flags, glowing windows and lamps at
## night, and townsfolk walking the streets. The rows move a little with the
## mouse, so the street has depth. Hovering a building outlines it; clicking
## opens its menu. Everything is drawn at a small size and scaled up by whole
## pixels (nearest filter) for crisp pixel art.
extends Control

signal building_clicked(id: String)

const UiTheme := preload("res://scripts/ui/theme.gd")
const PixelIcons := preload("res://scripts/ui/pixel_icons.gd")
const CityArt := preload("res://scripts/ui/city_art.gd")

## Row layout: ground line (share of the view height), building size, how
## hazy it looks (distance) and how far the mouse moves it (parallax).
const ROWS := {
	"back": {"gy": 0.5, "w": 38, "h": 40, "haze": 0.2, "par": 4.0},
	"mid": {"gy": 0.725, "w": 42, "h": 46, "haze": 0.09, "par": 8.0},
	"front": {"gy": 0.915, "w": 50, "h": 52, "haze": 0.0, "par": 14.0},
}
## Sky colors by hour: [hour, top, bottom, daylight].
const SKY := [
	[0.0, "#0a1030", "#1c2a5a", 0.12],
	[5.0, "#1a2250", "#7a4a7a", 0.15],
	[6.5, "#5a7ab8", "#ffb070", 0.6],
	[8.5, "#5a9ee0", "#bfe0f4", 1.0],
	[16.0, "#5a9ee0", "#bfe0f4", 1.0],
	[17.8, "#6a7ac0", "#ffa050", 0.75],
	[19.2, "#3a3070", "#e0705a", 0.4],
	[20.8, "#141a48", "#3a3a78", 0.15],
	[24.0, "#0a1030", "#1c2a5a", 0.12],
]

## A fixed hour for tests and screenshots (-1: the real clock).
var hour_override := -1.0
var px := 3
var lw := 400.0
var lh := 140.0

var _buildings: Array[Control] = []
var _time := 0.0
var _mouse := 0.5
var _crowds: Array[Control] = []
var _atmos: Control


## `defs`: [{id, name, style, wall, roof, icon, row ("back"/"mid"/"front"), slot, tip, extras, pattern}].
func setup(defs: Array) -> void:
	for child in get_children():
		child.queue_free()
	_buildings.clear()
	_crowds.clear()
	_defs = defs
	_rebuild()


var _defs: Array = []
var _built_px := 0


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_buildings.clear()
	_crowds.clear()
	_update_scale()
	_built_px = px
	var order := {"back": 0, "mid": 1, "front": 2}
	var sorted := _defs.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(order[a.row]) < int(order[b.row]))
	var added := {}
	for d: Dictionary in sorted:
		var row := str(d.row)
		# The townsfolk of a lane walk after the row behind it is drawn.
		if row == "front" and not added.has("mid_crowd"):
			added["mid_crowd"] = true
			_add_crowd("mid")
		var b := Building.new()
		b.view = self
		b.info = d
		b.clicked.connect(func(id: String) -> void: building_clicked.emit(id))
		add_child(b)
		_buildings.append(b)
	_add_crowd("front")
	_atmos = Atmos.new()
	_atmos.view = self
	add_child(_atmos)
	_layout()


func _add_crowd(lane: String) -> void:
	var c := Crowd.new()
	c.view = self
	c.lane = lane
	add_child(c)
	_crowds.append(c)


func _update_scale() -> void:
	px = 3 if size.x >= 900.0 and size.y >= 380.0 else 2
	lw = size.x / px
	lh = size.y / px


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and not _defs.is_empty():
		var before := px
		_update_scale()
		if px != before:
			_rebuild()
		else:
			_layout()


func hour() -> float:
	if hour_override >= 0.0:
		return hour_override
	var t := Time.get_datetime_dict_from_system()
	return float(t.hour) + float(t.minute) / 60.0


## [top color, bottom color, daylight 0..1] for an hour of the day.
func sky(h: float) -> Array:
	for i in range(1, SKY.size()):
		var a: Array = SKY[i - 1]
		var b: Array = SKY[i]
		if h <= float(b[0]):
			var t := (h - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0]))
			return [Color(str(a[1])).lerp(Color(str(b[1])), t), Color(str(a[2])).lerp(Color(str(b[2])), t), lerpf(float(a[3]), float(b[3]), t)]
	return [Color(str(SKY[0][1])), Color(str(SKY[0][2])), float(SKY[0][3])]


## 0 in full daylight, 1 deep night.
func night() -> float:
	return 1.0 - float(sky(hour())[2])


## How buildings are tinted: cool and dark at night, warm at dusk and dawn.
func tint() -> Color:
	var h := hour()
	var day: float = sky(h)[2]
	var warm := 0.0
	if (h >= 5.5 and h <= 8.0) or (h >= 17.0 and h <= 20.0):
		warm = 1.0 - minf(1.0, absf(day - 0.6) / 0.5)
	var cool := Color(0.52, 0.58, 0.9)
	var c := cool.lerp(Color.WHITE, clampf((day - 0.15) / 0.85, 0.0, 1.0))
	return c.lerp(Color(1.0, 0.82, 0.68), warm * 0.55)


func _layout() -> void:
	var by_row := {"back": [], "mid": [], "front": []}
	for b: Control in _buildings:
		(by_row[str(b.info.row)] as Array).append(b)
	for row: String in by_row:
		var cfg: Dictionary = ROWS[row]
		for b: Control in by_row[row]:
			b.build_art(cfg, px)
			var slot := int(b.info.slot)
			var cx_share := (float(slot) + 0.5) / 5.0 if row != "mid" else float(slot + 1) / 6.0
			var tex_size: Vector2i = b.art.size
			var ground := maxf(float(cfg.gy) * lh, float(tex_size.y - 4))
			b.base_position = Vector2(cx_share * lw - b.foot_x, ground - (tex_size.y - 4)) * px
			b.size = Vector2(tex_size) * px
			b.parallax = float(cfg.par)
			b.position = b.base_position
	for c: Control in _crowds:
		c.queue_redraw()
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	var m := get_local_mouse_position()
	var target := clampf(m.x / maxf(1.0, size.x), 0.0, 1.0) if Rect2(Vector2.ZERO, size).has_point(m) else 0.5
	_mouse = lerpf(_mouse, target, minf(1.0, delta * 4.0))
	var shift := _mouse - 0.5
	for b: Control in _buildings:
		b.position = b.base_position - Vector2(shift * b.parallax, 0.0)
		b.queue_redraw()
	for c: Control in _crowds:
		c.queue_redraw()
	_atmos.queue_redraw()
	queue_redraw()


func _unit(x: int, y: int, s: int) -> float:
	var n := (x * 374761393 + y * 668265263 + s * 1274126177) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n & 0xffff) / 65535.0


func _dot(x: float, y: float, c: Color) -> void:
	draw_rect(Rect2(floorf(x), floorf(y), 1, 1), c)


func _draw() -> void:
	if lw <= 0.0:
		return
	draw_set_transform(Vector2(-(_mouse - 0.5) * 3.0, 0), 0.0, Vector2(px, px))
	var h := hour()
	var colors := sky(h)
	var top: Color = colors[0]
	var bottom: Color = colors[1]
	var day: float = colors[2]
	var horizon := lh * 0.5
	# Sky in bands, with a dithered edge between them.
	var bands := int(horizon / 3.0) + 1
	for i in bands:
		var t := float(i) / bands
		draw_rect(Rect2(-4, i * 3, lw + 8, 4), top.lerp(bottom, t * t * 0.8 + t * 0.2))
	# Stars.
	if day < 0.7:
		for i in 70:
			var sx := _unit(i, 1, 5) * lw
			var sy := _unit(i, 2, 5) * horizon * 0.8
			var tw := 0.55 + 0.45 * sin(_time * (1.0 + _unit(i, 3, 5) * 2.0) + i)
			_dot(sx, sy, Color(1, 1, 0.9, (1.0 - day / 0.7) * tw))
	# Sun by day, moon by night.
	var sun_t := (h - 6.0) / 13.0
	if sun_t > -0.05 and sun_t < 1.05:
		var sx := lw * (0.08 + 0.84 * clampf(sun_t, 0.0, 1.0))
		var sy := horizon * (0.95 - 0.8 * sin(PI * clampf(sun_t, 0.0, 1.0)))
		draw_circle(Vector2(sx, sy), 11.0, Color(1.0, 0.95, 0.6, 0.18))
		draw_circle(Vector2(sx, sy), 8.0, Color(1.0, 0.95, 0.6, 0.3))
		draw_circle(Vector2(sx, sy), 6.0, Color("#fff4c2"))
	var moon_t := fposmod(h - 19.0, 24.0) / 11.0
	if moon_t >= 0.0 and moon_t <= 1.0:
		var mx := lw * (0.1 + 0.8 * moon_t)
		var my := horizon * (0.9 - 0.75 * sin(PI * moon_t))
		draw_circle(Vector2(mx, my), 7.0, Color("#eef2ff"))
		draw_circle(Vector2(mx + 3, my - 1), 6.0, bottom.lerp(top, 0.5))
		draw_circle(Vector2(mx - 2, my + 2), 1.2, Color("#c8cee8"))
	# Clouds.
	for i in 5:
		var speed := 2.0 + i * 0.7
		var cx := fposmod(_unit(i, 7, 3) * lw + _time * speed, lw + 70.0) - 35.0
		var cy := 6.0 + _unit(i, 8, 3) * horizon * 0.5
		_cloud(cx, cy, 0.8 + _unit(i, 9, 3) * 0.7, Color(1, 1, 1, 0.2 + 0.7 * day).lerp(Color(0.4, 0.45, 0.7, 0.5), (1.0 - day) * 0.5))
	# Far hills in two hazy layers, with a few pines on the nearer one.
	var far_c := bottom.lerp(Color("#6f8fb0"), 0.55).darkened(0.1 * (1.0 - day))
	var near_c := bottom.lerp(Color("#4f8a60"), 0.6).darkened(0.25 * (1.0 - day))
	for layer in 2:
		var pts := PackedVector2Array([Vector2(-4, horizon + 4)])
		var base := horizon - (14.0 if layer == 0 else 6.0)
		var amp := 9.0 if layer == 0 else 5.0
		for i in 33:
			var x := -4.0 + lw * i / 32.0
			pts.append(Vector2(x, base - amp * (0.5 + 0.5 * sin(i * (0.55 + layer * 0.4) + layer * 2.0)) - amp * 0.4 * sin(i * 1.7)))
		pts.append(Vector2(lw + 4, horizon + 4))
		draw_colored_polygon(pts, far_c if layer == 0 else near_c)
	for i in 26:
		var x := _unit(i, 4, 8) * lw
		var y := horizon - 3.0 - _unit(i, 5, 8) * 4.0
		var pine := near_c.darkened(0.2)
		draw_rect(Rect2(floorf(x), floorf(y) - 6, 1, 7), pine)
		draw_rect(Rect2(floorf(x) - 1, floorf(y) - 4, 3, 2), pine)
		draw_rect(Rect2(floorf(x) - 1, floorf(y) - 1, 3, 2), pine)
	# Grass behind and dirt roads under the rows, a cobbled street in front.
	var grass := Color("#5fa050").lerp(Color("#2a4a3a"), (1.0 - day) * 0.6)
	draw_rect(Rect2(-4, horizon, lw + 8, lh - horizon), grass)
	for i in 220:
		var gx := _unit(i, 1, 2) * lw
		var gy := horizon + _unit(i, 2, 2) * (lh - horizon)
		var gc := grass.lightened(0.1) if _unit(i, 3, 2) > 0.5 else grass.darkened(0.1)
		draw_rect(Rect2(floorf(gx), floorf(gy), 2, 1), gc)
	var dirt := Color("#b09f7a").lerp(Color("#3a3a50"), (1.0 - day) * 0.6)
	for row: String in ["back", "mid"]:
		var gy := maxf(float(ROWS[row].gy) * lh, float(ROWS[row].h) + 21.0)
		draw_rect(Rect2(-4, gy, lw + 8, 7 if row == "mid" else 5), dirt)
		draw_rect(Rect2(-4, gy, lw + 8, 1), dirt.darkened(0.2))
	var street_y := float(ROWS.front.gy) * lh
	var street := Color("#a89878").lerp(Color("#33334a"), (1.0 - day) * 0.65)
	draw_rect(Rect2(-4, street_y, lw + 8, lh - street_y + 2), street)
	draw_rect(Rect2(-4, street_y, lw + 8, 1), street.darkened(0.3))
	for i in 160:
		var cx := _unit(i, 1, 6) * lw
		var cy := street_y + 2.0 + _unit(i, 2, 6) * (lh - street_y)
		draw_rect(Rect2(floorf(cx), floorf(cy), 3, 2), street.darkened(0.12) if _unit(i, 3, 6) > 0.5 else street.lightened(0.08))
	# Flower beds, lamp posts and trees along the edges.
	for i in 14:
		var fx := 4.0 + i * (lw - 8.0) / 13.0
		var fy := horizon + 3.0 + _unit(i, 5, 7) * 4.0
		draw_rect(Rect2(floorf(fx), floorf(fy), 3, 2), Color("#3f8a46"))
		_dot(fx + 1, fy - 1, [Color("#ff7aa8"), Color("#ffd23f"), Color("#ffffff"), Color("#b98cff")][i % 4])
	var lamp_xs := [0.03, 0.27, 0.5, 0.73, 0.97]
	for lx: float in lamp_xs:
		_street_lamp(lx * lw, street_y + 7.0, day)
	_tree(8.0, horizon + 5.0, day)
	_tree(lw - 9.0, horizon + 5.0, day)


func _cloud(x: float, y: float, s: float, c: Color) -> void:
	for part: Array in [[0.0, 3.0, 22.0, 5.0], [4.0, 0.0, 12.0, 4.0], [14.0, 1.0, 9.0, 3.0], [-3.0, 5.0, 28.0, 2.0]]:
		draw_rect(Rect2(floorf(x + part[0] * s), floorf(y + part[1] * s), ceilf(part[2] * s), ceilf(part[3] * s)), c)


func _street_lamp(x: float, y: float, day: float) -> void:
	var fx := floorf(x)
	draw_rect(Rect2(fx, y - 16, 1, 16), Color("#2c2c34"))
	draw_rect(Rect2(fx - 1, y - 19, 3, 3), Color("#ffd86a") if day < 0.6 else Color("#e8d8a0"))
	draw_rect(Rect2(fx - 1, y - 20, 3, 1), Color("#2c2c34"))
	var night_amt := clampf((0.7 - day) / 0.55, 0.0, 1.0)
	if night_amt > 0.0:
		draw_circle(Vector2(fx + 0.5, y - 17.5), 10.0, Color(1.0, 0.82, 0.4, 0.07 * night_amt))
		draw_circle(Vector2(fx + 0.5, y - 17.5), 6.0, Color(1.0, 0.82, 0.4, 0.12 * night_amt))


func _tree(x: float, y: float, day: float) -> void:
	var fx := floorf(x)
	draw_rect(Rect2(fx - 1, y - 10, 3, 11), Color("#5b4630"))
	var leaf := Color("#3f8a46").lerp(Color("#1f3a3a"), (1.0 - day) * 0.55)
	for part: Array in [[-7.0, -22.0, 15.0, 12.0], [-5.0, -26.0, 11.0, 5.0], [-4.0, -12.0, 9.0, 3.0]]:
		draw_rect(Rect2(fx + part[0], y + part[1], part[2], part[3]), leaf)
	draw_rect(Rect2(fx - 5, y - 21, 5, 2), leaf.lightened(0.18))
	draw_rect(Rect2(fx + 2, y - 15, 5, 3), leaf.darkened(0.2))


## One clickable building: its pixel art, glowing windows, smoke and flags.
class Building extends Control:
	signal clicked(id: String)

	var view: Control
	var info: Dictionary = {}
	var art: Dictionary = {}
	var base_position := Vector2.ZERO
	var parallax := 0.0
	var foot_x := 0.0
	var _hover := false
	var _scale := 3
	var _mask: Image
	var _sign: Label
	var _plank := Rect2()
	var _emblem_tex: ImageTexture

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _ready() -> void:
		tooltip_text = str(info.get("tip", ""))
		_sign = UiTheme.label(UiTheme.upper(str(info.name)), UiTheme.label_settings(15, Color("#fff4d6"), 5))
		_sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_sign)
		mouse_entered.connect(func() -> void:
			_hover = true)
		mouse_exited.connect(func() -> void:
			_hover = false)
		_emblem_tex = PixelIcons.texture(str(info.icon), Color("#ffd23f"))

	## Paints the building for this row (called by the view on layout).
	func build_art(cfg: Dictionary, px: int) -> void:
		_scale = px
		var kind := str(info.style)
		var w := int(cfg.w)
		var h := int(cfg.h)
		match kind:
			"tower":
				h += 10
				w -= 6
			"hall", "gate":
				w += 6
			"market":
				w += 4
		# Buildings on the right of the street are mirrored so their side faces the middle.
		var flip := int(info.slot) >= (3 if str(info.row) != "mid" else 2)
		var seed_value := int(hash(str(info.id)) & 0xffff)
		art = CityArt.paint(kind, Color(str(info.wall)), Color(str(info.roof)), w, h, seed_value, info.get("extras", []), str(info.get("pattern", "brick")), flip)
		var center := 7.0 + w * 0.5
		foot_x = center if not flip else float(art.size.x) - center
		_mask = (art.sil as ImageTexture).get_image()
		var text_size := _sign.get_minimum_size()
		_sign.size = text_size
		var plank_w := text_size.x + 14.0
		var cx := foot_x * _scale
		_plank = Rect2(cx - plank_w * 0.5, 3.0 * _scale, plank_w, text_size.y + 6.0)
		_sign.position = _plank.position + Vector2(7.0, 3.0)

	func _has_point(point: Vector2) -> bool:
		if _plank.has_point(point):
			return true
		if _mask == null:
			return false
		var x := int(point.x / _scale)
		var y := int(point.y / _scale)
		return x >= 0 and y >= 0 and x < _mask.get_width() and y < _mask.get_height() and _mask.get_pixel(x, y).a > 0.0

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(str(info.id))
			accept_event()

	func _draw() -> void:
		if art.is_empty():
			return
		var s := float(_scale)
		var cfg: Dictionary = ROWS[str(info.row)]
		var tint: Color = view.tint()
		var night: float = view.night()
		var rect := Rect2(Vector2.ZERO, Vector2(art.size) * s)
		# A soft shadow on the ground.
		draw_rect(Rect2(foot_x * s - 30 * s * 0.5, rect.size.y - 5 * s, 30 * s, 2 * s), Color(0, 0, 0, 0.16))
		draw_texture_rect(art.tex, rect, false, tint)
		var haze: float = float(cfg.haze)
		if haze > 0.0:
			var sky: Array = view.sky(view.hour())
			draw_texture_rect(art.sil, rect, false, Color((sky[1] as Color).lerp(Color.WHITE, 0.2), haze))
		var t: float = view._time
		var details: Dictionary = art.info
		# Windows glow warmly in the evening and at night.
		if night > 0.05:
			var glow: Color = details.glow
			var idx := 0
			for r: Rect2i in details.windows:
				var flick := 0.8 + 0.2 * sin(t * 3.0 + idx * 1.7 + float(hash(str(info.id)) & 15))
				draw_rect(Rect2(Vector2(r.position) * s, Vector2(r.size) * s), Color(glow, clampf(night * 1.2, 0.0, 0.95) * flick))
				draw_rect(Rect2(Vector2(r.position - Vector2i(1, 1)) * s, Vector2(r.size + Vector2i(2, 2)) * s), Color(glow, 0.1 * night * flick))
				idx += 1
			var door: Rect2i = details.door
			if door.size.x > 0:
				draw_rect(Rect2(Vector2(door.position) * s, Vector2(door.size) * s), Color(glow, 0.16 * night))
		for lamp: Vector2i in details.lamps:
			if night > 0.05:
				draw_circle(Vector2(lamp) * s, 9.0 * s, Color(1.0, 0.82, 0.4, 0.07 * night))
				draw_circle(Vector2(lamp) * s, 5.0 * s, Color(1.0, 0.82, 0.4, 0.16 * night))
			draw_rect(Rect2(Vector2(lamp) * s - Vector2(s, s) * 0.5, Vector2(s, s)), Color("#fff1a8"))
		# The emblem on the wall.
		var emblem: Rect2i = details.emblem
		if emblem.size.x > 0:
			var es := float(emblem.size.x) * s
			draw_texture_rect(_emblem_tex, Rect2(Vector2(emblem.position) * s, Vector2(es, es)), false, tint.lerp(Color.WHITE, 0.3))
		# Smoke from the chimney: little squares rising and fading.
		var chim: Vector2i = details.chimney
		if chim.x >= 0:
			var forge: bool = details.has("forge")
			for i in 5:
				var age := fposmod(t * 0.55 + i * 0.2, 1.0)
				var sx := float(chim.x) + sin(age * 5.0 + i) * 1.5 + age * 3.0
				var sy := float(chim.y) - age * 16.0
				var size_px := 1.0 + age * 2.5
				var c := Color(0.78, 0.78, 0.82, 0.7 * (1.0 - age)) if not forge else Color(0.4, 0.4, 0.45, 0.65 * (1.0 - age))
				draw_rect(Rect2(floorf(sx) * s, floorf(sy) * s, size_px * s, size_px * s), c)
			if forge and night > 0.05:
				draw_circle(Vector2(chim) * s, 4.0 * s, Color(1.0, 0.5, 0.15, 0.12 * night))
		# A flag that waves.
		var flag: Vector2i = details.flag
		if flag.x >= 0:
			var dir := -1.0 if details.get("flipped", false) else 1.0
			var col := Color(str(info.roof)).lightened(0.25)
			for i in 6:
				var wave := sin(t * 5.0 - i * 0.9) * (0.5 + i * 0.15)
				draw_rect(Rect2((flag.x + dir * i - (0 if dir > 0 else 0)) * s, (flag.y + 1 + wave) * s, s, 4 * s - i * s * 0.35), col)
		# The name plank.
		var cx := _plank.get_center().x
		var chain := Color("#3a3a40")
		for off in [-0.3, 0.3]:
			draw_rect(Rect2(cx + _plank.size.x * off, _plank.end.y, s, 5 * s), chain)
		var lift := -2.0 if _hover else 0.0
		draw_rect(Rect2(_plank.position + Vector2(0, lift), _plank.size), Color("#5a3a1c") if not _hover else Color("#7a4f26"))
		draw_rect(Rect2(_plank.position + Vector2(0, lift), Vector2(_plank.size.x, 3)), Color("#8a5a2b"))
		draw_rect(Rect2(_plank.position + Vector2(0, lift + _plank.size.y - 2), Vector2(_plank.size.x, 2)), Color("#3a2410"))
		_sign.position = _plank.position + Vector2(7.0, 3.0 + lift)
		if _hover:
			draw_texture_rect(art.ring, rect, false, Color("#ffd23f"))
			draw_texture_rect(art.sil, rect, false, Color(1, 0.95, 0.6, 0.12))


## Townsfolk walking along one street of the town.
class Crowd extends Control:
	var view: Control
	var lane := "front"
	var _people: Array = []
	var _ready_done := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _make() -> void:
		_ready_done = true
		var rng := RandomNumberGenerator.new()
		rng.seed = 5 if lane == "front" else 9
		var skin := [Color("#f2c9a0"), Color("#d9a273"), Color("#a8744a"), Color("#f7d9b8")]
		var cloth := [Color("#d9534f"), Color("#4a90d9"), Color("#5fcf6a"), Color("#ffd23f"), Color("#b65cff"), Color("#e8e2d0"), Color("#ff9a4a")]
		var count := 9 if lane == "front" else 6
		for i in count:
			var kind := "person"
			var r := rng.randf()
			if r < 0.12:
				kind = "dog"
			elif r < 0.25:
				kind = "knight"
			elif r < 0.4:
				kind = "kid"
			_people.append({
				"x": rng.randf() * 400.0, "speed": rng.randf_range(6.0, 13.0) * (1.0 if rng.randf() < 0.5 else -1.0), "kind": kind,
				"skin": skin[rng.randi() % skin.size()], "cloth": cloth[rng.randi() % cloth.size()], "hair": [Color("#3a2416"), Color("#d8a24a"), Color("#c0392b"), Color("#222"), Color("#e8e2d0")][rng.randi() % 5],
				"phase": rng.randf() * 10.0, "wait": 0.0, "dy": rng.randf_range(-1.0, 3.0),
			})

	func _draw() -> void:
		if not _ready_done:
			_make()
		var s: float = view.px
		var lw: float = view.lw
		var lh: float = view.lh
		var cfg: Dictionary = ROWS["front" if lane == "front" else "mid"]
		var gy: float = (lh - 7.0) if lane == "front" else float(cfg.gy) * lh + 5.0
		var night: float = view.night()
		var tint: Color = view.tint()
		var t: float = view._time
		for p: Dictionary in _people:
			var x := fposmod(float(p.x) + float(p.speed) * t, lw + 20.0) - 10.0
			var y := gy + float(p.dy) * (1.0 if lane == "front" else 0.4)
			var step := int(t * 6.0 + float(p.phase)) % 2
			var bob := 0.0 if step == 0 else -1.0
			var face := 1.0 if float(p.speed) > 0.0 else -1.0
			draw_rect(Rect2((floorf(x) - 2) * s, (floorf(y) - 1) * s, 5 * s, s), Color(0, 0, 0, 0.18))
			var skin: Color = (p.skin as Color) * tint
			var cloth: Color = (p.cloth as Color) * tint
			var hair: Color = (p.hair as Color) * tint
			match str(p.kind):
				"dog":
					var dc := Color("#a8744a") * tint
					draw_rect(Rect2((floorf(x) - 3) * s, (y - 4 + bob * 0.0) * s, 6 * s, 2 * s), dc)
					draw_rect(Rect2((floorf(x) + 2 * face - (1 if face < 0 else 0)) * s, (y - 6) * s, 2 * s, 2 * s), dc.lightened(0.1))
					var lf := 0.0 if step == 0 else 1.0
					draw_rect(Rect2((floorf(x) - 3 + lf) * s, (y - 2) * s, s, 2 * s), dc.darkened(0.2))
					draw_rect(Rect2((floorf(x) + 2 - lf) * s, (y - 2) * s, s, 2 * s), dc.darkened(0.2))
					draw_rect(Rect2((floorf(x) - 4 * face) * s, (y - 5 + bob) * s, s, s), dc)
				_:
					var h := 9.0 if str(p.kind) != "kid" else 6.0
					var body_h := 4.0 if str(p.kind) != "kid" else 3.0
					var leg := 3.0 if str(p.kind) != "kid" else 2.0
					draw_rect(Rect2((floorf(x) - 1) * s, (y - leg + (1 if step == 0 else 0)) * s, s, leg * s), Color("#3a2f4a") * tint)
					draw_rect(Rect2((floorf(x) + 1) * s, (y - leg + (0 if step == 0 else 1)) * s, s, leg * s), Color("#3a2f4a") * tint)
					var body_y := y - leg - body_h + bob
					draw_rect(Rect2((floorf(x) - 1) * s, body_y * s, 3 * s, body_h * s), cloth)
					draw_rect(Rect2((floorf(x) - 1) * s, body_y * s, s, body_h * s), cloth.lightened(0.18))
					var head_y := body_y - 3.0
					draw_rect(Rect2((floorf(x) - 1) * s, head_y * s, 3 * s, 3 * s), skin)
					if str(p.kind) == "knight":
						draw_rect(Rect2((floorf(x) - 1) * s, head_y * s, 3 * s, 2 * s), Color("#b8c2cc") * tint)
						draw_rect(Rect2((floorf(x)) * s, (head_y - 1) * s, s, s), Color("#e0484f") * tint)
					else:
						draw_rect(Rect2((floorf(x) - 1) * s, head_y * s, 3 * s, s), hair)
					draw_rect(Rect2((floorf(x) + 0.0 + (1 if face > 0 else -1) * 0.0) * s, (head_y + 1) * s, s, s), Color(0.1, 0.07, 0.07, 0.8))
					if str(p.kind) == "knight":
						draw_rect(Rect2((floorf(x) + 2 * face - (1 if face < 0 else 0)) * s, (body_y) * s, s, 4 * s), Color("#cfc9bb") * tint)
			if night > 0.4 and str(p.kind) == "kid":
				draw_circle(Vector2(floorf(x) + 2.0 * face, y - 5.0) * s, 5.0 * s, Color(1.0, 0.85, 0.4, 0.1 * night))


## Birds, drifting petals and fireflies above everything.
class Atmos extends Control:
	var view: Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var s: float = view.px
		var lw: float = view.lw
		var lh: float = view.lh
		var t: float = view._time
		var night: float = view.night()
		var day := 1.0 - night
		# Birds: tiny Vs flapping across the sky by day.
		if day > 0.4:
			for i in 4:
				var bx := fposmod(float(i) * 97.0 + t * (14.0 + i * 3.0), lw + 40.0) - 20.0
				var by := 10.0 + i * 7.0 + sin(t * 0.8 + i) * 3.0
				var flap := 1 if int(t * 6.0 + i) % 2 == 0 else 0
				var c := Color(0.12, 0.12, 0.18, 0.8)
				draw_rect(Rect2(floorf(bx) * s, floorf(by) * s, s, s), c)
				draw_rect(Rect2((floorf(bx) - 1) * s, (floorf(by) - flap) * s, s, s), c)
				draw_rect(Rect2((floorf(bx) + 1) * s, (floorf(by) - flap) * s, s, s), c)
				draw_rect(Rect2((floorf(bx) - 2) * s, (floorf(by) - flap + (1 if flap == 1 else 0) * 0) * s, s, s), c)
				draw_rect(Rect2((floorf(bx) + 2) * s, (floorf(by) - flap) * s, s, s), c)
		# Petals and leaves drift down by day.
		if day > 0.5:
			for i in 14:
				var px := fposmod(float(i) * 61.0 + t * 7.0 + sin(t * 0.7 + i) * 6.0, lw)
				var py := fposmod(float(i) * 37.0 + t * (9.0 + i % 4), lh)
				draw_rect(Rect2(floorf(px) * s, floorf(py) * s, s, s), [Color("#ffb7c8"), Color("#ffe27a"), Color("#a8e08a")][i % 3])
		# Fireflies in the evening.
		if night > 0.3:
			for i in 22:
				var fx := fposmod(float(i) * 83.0 + sin(t * 0.5 + i) * 10.0, lw)
				var fy := lh * (0.45 + 0.5 * fposmod(float(i) * 0.37, 1.0)) + sin(t * 0.9 + i * 2.0) * 4.0
				var glow := 0.5 + 0.5 * sin(t * 2.0 + i * 1.3)
				draw_circle(Vector2(fx, fy) * s, 3.0 * s, Color(0.9, 1.0, 0.4, 0.1 * glow * night))
				draw_rect(Rect2(floorf(fx) * s, floorf(fy) * s, s, s), Color(0.95, 1.0, 0.5, glow * night))
		# A soft vignette, darker at night.
		var dark := 0.04 + night * 0.18
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0.02, 0.03, 0.12, night * 0.1))
		for i in 6:
			var a := dark * (1.0 - float(i) / 6.0)
			draw_rect(Rect2(i * s * 2, 0, s * 2, size.y), Color(0, 0, 0, a))
			draw_rect(Rect2(size.x - (i + 1) * s * 2, 0, s * 2, size.y), Color(0, 0, 0, a))
