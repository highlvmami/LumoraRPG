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

## Buildings far up the view are smaller, hazier and move less with the mouse than
## the ones near the front: a size class is interpolated from the ground line.
const BACK := {"w": 38, "h": 40, "haze": 0.2, "par": 4.0}
const FRONT := {"w": 50, "h": 52, "haze": 0.0, "par": 14.0}
const HORIZON := 0.4
const Y_BACK := 0.455
const Y_FRONT := 0.945
const PLAZA := Vector2(0.47, 0.765)
const POND := Vector2(0.175, 0.845)
## The walking ways between the buildings (shares of the view); the first of
## each pair of flags says whether it is a wide road.
const PATHS := [
	{"wide": true, "pts": [[0.47, 0.72], [0.40, 0.67], [0.335, 0.64]]},
	{"wide": false, "pts": [[0.335, 0.64], [0.38, 0.58], [0.425, 0.515]]},
	{"wide": false, "pts": [[0.425, 0.515], [0.52, 0.50], [0.60, 0.465]]},
	{"wide": false, "pts": [[0.335, 0.64], [0.28, 0.56], [0.235, 0.47]]},
	{"wide": false, "pts": [[0.335, 0.65], [0.26, 0.70], [0.185, 0.735]]},
	{"wide": false, "pts": [[0.185, 0.735], [0.12, 0.63], [0.075, 0.545]]},
	{"wide": true, "pts": [[0.47, 0.765], [0.56, 0.745], [0.665, 0.715]]},
	{"wide": false, "pts": [[0.665, 0.715], [0.74, 0.69], [0.795, 0.66]]},
	{"wide": false, "pts": [[0.795, 0.66], [0.87, 0.73], [0.955, 0.79]]},
	{"wide": false, "pts": [[0.795, 0.66], [0.85, 0.59], [0.905, 0.53]]},
	{"wide": true, "pts": [[0.47, 0.785], [0.36, 0.83], [0.265, 0.88]]},
	{"wide": false, "pts": [[0.265, 0.88], [0.17, 0.915], [0.075, 0.93]]},
	{"wide": true, "pts": [[0.47, 0.80], [0.52, 0.865], [0.545, 0.93]]},
	{"wide": true, "pts": [[0.545, 0.93], [0.62, 0.905], [0.69, 0.895]]},
	{"wide": false, "pts": [[0.69, 0.895], [0.78, 0.935], [0.865, 0.96]]},
]
## Things in the streets: [kind, x share, y share, variant].
const PROPS := [
	["tree", 0.02, 0.47, 0], ["tree", 0.165, 0.55, 1], ["tree", 0.33, 0.45, 2], ["tree", 0.51, 0.43, 0], ["tree", 0.70, 0.50, 1],
	["tree", 0.985, 0.50, 2], ["tree", 0.02, 0.73, 1], ["tree", 0.455, 0.60, 0], ["tree", 0.875, 0.60, 2], ["tree", 0.635, 0.82, 1],
	["tree", 0.40, 0.975, 0], ["tree", 0.69, 0.985, 2], ["tree", 0.17, 0.995, 1], ["tree", 0.995, 0.86, 0],
	["pine", 0.30, 0.44, 0], ["pine", 0.77, 0.475, 1], ["pine", 0.555, 0.41, 0], ["pine", 0.995, 0.60, 1], ["pine", 0.045, 0.45, 0],
	["bush", 0.20, 0.66, 0], ["bush", 0.44, 0.575, 1], ["bush", 0.62, 0.76, 0], ["bush", 0.73, 0.86, 1], ["bush", 0.12, 0.82, 0],
	["bush", 0.52, 0.935, 1], ["bush", 0.98, 0.70, 0], ["bush", 0.36, 0.745, 1],
	["fountain", 0.47, 0.78, 0], ["well", 0.215, 0.775, 0],
	["stall", 0.385, 0.815, 0], ["stall", 0.58, 0.82, 1], ["stall", 0.63, 0.865, 2],
	["bench", 0.405, 0.74, 0], ["bench", 0.535, 0.75, 1],
	["barrel", 0.275, 0.665, 0], ["barrel", 0.29, 0.675, 1], ["crate", 0.395, 0.675, 0], ["crate", 0.41, 0.685, 1],
	["haystack", 0.955, 0.865, 0], ["haystack", 0.98, 0.88, 1],
	["fence", 0.945, 0.91, 0], ["fence", 0.99, 0.915, 0],
	["flowers", 0.225, 0.625, 0], ["flowers", 0.58, 0.675, 1], ["flowers", 0.335, 0.915, 2], ["flowers", 0.70, 0.955, 0], ["flowers", 0.05, 0.80, 1], ["flowers", 0.975, 0.90, 2],
	["sign", 0.47, 0.705, 0],
	["lamp", 0.40, 0.70, 0], ["lamp", 0.56, 0.715, 0], ["lamp", 0.31, 0.845, 0], ["lamp", 0.62, 0.905, 0], ["lamp", 0.745, 0.705, 0],
	["lamp", 0.20, 0.745, 0], ["lamp", 0.505, 0.545, 0], ["lamp", 0.85, 0.705, 0],
	["duck", 0.165, 0.84, 0], ["duck", 0.185, 0.855, 1],
	["chicken", 0.935, 0.835, 0], ["chicken", 0.95, 0.85, 1], ["chicken", 0.92, 0.85, 2],
	["pigeons", 0.455, 0.815, 0],
]
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
var _props: Array[Control] = []
var _ground: ImageTexture
var _paths_px: Array = []


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
	_props.clear()
	_update_scale()
	_built_px = px
	if lw < 8.0 or lh < 8.0:
		return
	_bake_paths()
	_bake_ground()
	# Buildings, props and walkers are drawn from the back to the front.
	var items: Array = []
	for d: Dictionary in _defs:
		var b := Building.new()
		b.view = self
		b.info = d
		b.clicked.connect(func(id: String) -> void: building_clicked.emit(id))
		_buildings.append(b)
		items.append([float(d.at[1]), b])
	for entry: Array in PROPS:
		var pr := Prop.new()
		pr.view = self
		pr.kind = str(entry[0])
		pr.share = Vector2(float(entry[1]), float(entry[2]))
		pr.variant = int(entry[3])
		_props.append(pr)
		items.append([float(entry[2]) - 0.001, pr])
	for i in PATHS.size():
		var c := Crowd.new()
		c.view = self
		c.path_index = i
		_crowds.append(c)
		var pts: Array = PATHS[i].pts
		items.append([float(pts[pts.size() / 2][1]) + 0.004, c])
	items.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for it: Array in items:
		add_child(it[1])
	_atmos = Atmos.new()
	_atmos.view = self
	add_child(_atmos)
	_layout()


## Smooth walking lines in view pixels, with their lengths.
func _bake_paths() -> void:
	_paths_px.clear()
	for def: Dictionary in PATHS:
		var pts := PackedVector2Array()
		for p: Array in def.pts:
			pts.append(Vector2(float(p[0]) * lw, float(p[1]) * lh))
		for _i in 3:
			var out := PackedVector2Array([pts[0]])
			for i in range(pts.size() - 1):
				out.append(pts[i].lerp(pts[i + 1], 0.25))
				out.append(pts[i].lerp(pts[i + 1], 0.75))
			out.append(pts[pts.size() - 1])
			pts = out
		var cum := PackedFloat32Array([0.0])
		for i in range(1, pts.size()):
			cum.append(cum[i - 1] + pts[i].distance_to(pts[i - 1]))
		_paths_px.append({"pts": pts, "cum": cum, "len": cum[cum.size() - 1]})


## The grass, dirt ways, the cobbled square and the pond, painted once.
func _bake_ground() -> void:
	var w := int(ceil(lw)) + 8
	var h := int(ceil(lh))
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var top := int(lh * HORIZON)
	var grass := Color("#5fa050")
	for y in range(top, h):
		for x in w:
			var u := _unit(x, y, 11)
			var c := grass
			if u > 0.94:
				c = grass.lightened(0.12)
			elif u < 0.06:
				c = grass.darkened(0.12)
			elif u > 0.5 and u < 0.52:
				c = grass.lightened(0.2)
			img.set_pixel(x, y, c)
	var dirt := Color("#b09f7a")
	var edge := Color("#8c7c58")
	var stone := Color("#b8b2a2")
	var stone_edge := Color("#847e72")
	for pass_i in 2:
		for i in PATHS.size():
			var wide: bool = PATHS[i].wide
			var hw := 5.0 if wide else 3.6
			var hh := 3.0 if wide else 2.2
			var info: Dictionary = _paths_px[i]
			var pts: PackedVector2Array = info.pts
			var cum: PackedFloat32Array = info.cum
			var d := 0.0
			while d <= float(info.len):
				var at := _sample(pts, cum, d)
				_stamp(img, at.x, at.y, hw + (1.0 if pass_i == 0 else 0.0), hh + (1.0 if pass_i == 0 else 0.0), (edge if pass_i == 0 else dirt), pass_i == 1)
				d += 0.8
	# The square in the middle.
	var plaza := Vector2(PLAZA.x * lw, PLAZA.y * lh)
	_stamp(img, plaza.x, plaza.y, 31.0, 11.0, stone_edge, false)
	_stamp(img, plaza.x, plaza.y, 29.5, 10.0, stone, true)
	_stamp(img, plaza.x, plaza.y, 21.0, 7.0, stone.darkened(0.06), true)
	# The pond.
	var pond := Vector2(POND.x * lw, POND.y * lh)
	_stamp(img, pond.x, pond.y, 14.0, 5.5, Color("#7a6a4a"), false)
	_stamp(img, pond.x, pond.y, 12.5, 4.5, Color("#3f86c0"), false)
	_stamp(img, pond.x - 3.0, pond.y - 1.0, 5.0, 1.5, Color("#6aaee0"), false)
	_ground = ImageTexture.create_from_image(img)


func _stamp(img: Image, cx: float, cy: float, rx: float, ry: float, color: Color, speckle: bool) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in range(maxi(0, int(cy - ry) - 1), mini(h, int(cy + ry) + 2)):
		for x in range(maxi(0, int(cx - rx) - 1), mini(w, int(cx + rx) + 2)):
			var dx := (float(x) - cx) / rx
			var dy := (float(y) - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				var c := color
				if speckle:
					var u := _unit(x, y, 21)
					c = color.lightened(0.07) if u > 0.88 else (color.darkened(0.08) if u < 0.1 else color)
				img.set_pixel(x, y, c)


## A point `d` view pixels along a baked line.
static func _sample(pts: PackedVector2Array, cum: PackedFloat32Array, d: float) -> Vector2:
	var i := 1
	while i < pts.size() - 1 and cum[i] < d:
		i += 1
	var seg := maxf(0.001, cum[i] - cum[i - 1])
	return pts[i - 1].lerp(pts[i], clampf((d - cum[i - 1]) / seg, 0.0, 1.0))


func tangent_x(index: int, d: float) -> float:
	var info: Dictionary = _paths_px[index]
	var a := _sample(info.pts, info.cum, maxf(0.0, d - 1.0))
	var b := _sample(info.pts, info.cum, minf(float(info.len), d + 1.0))
	return b.x - a.x


func path_point(index: int, d: float) -> Vector2:
	var info: Dictionary = _paths_px[index]
	return _sample(info.pts, info.cum, clampf(d, 0.0, float(info.len)))


func path_length(index: int) -> float:
	return float(_paths_px[index].len)


## Size class for a building standing at `y` (share of the view height).
func cfg_for(y: float) -> Dictionary:
	var t := clampf((y - Y_BACK) / (Y_FRONT - Y_BACK), 0.0, 1.0)
	return {
		"w": roundi(lerpf(float(BACK.w), float(FRONT.w), t)), "h": roundi(lerpf(float(BACK.h), float(FRONT.h), t)),
		"haze": lerpf(float(BACK.haze), float(FRONT.haze), t), "par": lerpf(float(BACK.par), float(FRONT.par), t),
	}


func _update_scale() -> void:
	px = 2
	lw = size.x / px
	lh = size.y / px


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and not _defs.is_empty():
		# The ground and the ways are painted for one size: repaint on a new size.
		_rebuild()


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
	for b: Control in _buildings:
		var at: Array = b.info.at
		var cfg := cfg_for(float(at[1]))
		b.build_art(cfg, px)
		var tex_size: Vector2i = b.art.size
		var ground := maxf(float(at[1]) * lh, float(tex_size.y - 4))
		b.base_position = Vector2(float(at[0]) * lw - b.foot_x, ground - (tex_size.y - 4)) * px
		b.size = Vector2(tex_size) * px
		b.parallax = float(cfg.par)
		b.position = b.base_position
	for pr: Control in _props:
		pr.place()
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
	for pr: Control in _props:
		pr.queue_redraw()
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
	var horizon := lh * HORIZON
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
	# The ground: grass, ways, the square and the pond, tinted by the hour.
	if _ground:
		var ground_tint := tint().lerp(Color.WHITE, 0.0)
		draw_texture_rect(_ground, Rect2(Vector2(0, 0), Vector2(_ground.get_width(), _ground.get_height())), false, ground_tint)
	# Ripples on the pond.
	var pond := Vector2(POND.x * lw, POND.y * lh)
	for i in 3:
		var ph := fposmod(_time * 0.5 + i * 0.33, 1.0)
		draw_rect(Rect2(floorf(pond.x - 8.0 + i * 5.0 + sin(_time + i) * 2.0), floorf(pond.y - 2.0 + ph * 3.0), 3, 1), Color(1, 1, 1, 0.35 * (1.0 - ph)) * tint())
	# Little flowers along the grass edge behind the first row.
	for i in 18:
		var fx := 4.0 + i * (lw - 8.0) / 17.0
		var fy := horizon + 1.0 + _unit(i, 5, 7) * 4.0
		_dot(fx + 1, fy - 1, [Color("#ff7aa8"), Color("#ffd23f"), Color("#ffffff"), Color("#b98cff")][i % 4])


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
		var flip := float(info.at[0]) >= 0.5
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
		var cfg: Dictionary = view.cfg_for(float(info.at[1]))
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


## Townsfolk walking up and down one of the ways between the buildings.
class Crowd extends Control:
	var view: Control
	var path_index := 0
	var _people: Array = []
	var _ready_done := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _make() -> void:
		_ready_done = true
		var rng := RandomNumberGenerator.new()
		rng.seed = 5 + path_index * 7
		var skin := [Color("#f2c9a0"), Color("#d9a273"), Color("#a8744a"), Color("#f7d9b8")]
		var cloth := [Color("#d9534f"), Color("#4a90d9"), Color("#5fcf6a"), Color("#ffd23f"), Color("#b65cff"), Color("#e8e2d0"), Color("#ff9a4a")]
		var count := 3 + path_index % 2
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
				"u": rng.randf(), "speed": rng.randf_range(4.0, 9.0), "kind": kind,
				"skin": skin[rng.randi() % skin.size()], "cloth": cloth[rng.randi() % cloth.size()], "hair": [Color("#3a2416"), Color("#d8a24a"), Color("#c0392b"), Color("#222"), Color("#e8e2d0")][rng.randi() % 5],
				"phase": rng.randf() * 10.0,
			})

	func _draw() -> void:
		if not _ready_done:
			_make()
		var s: float = view.px
		var night: float = view.night()
		var tint: Color = view.tint()
		var t: float = view._time
		var path_len: float = view.path_length(path_index)
		for p: Dictionary in _people:
			var d := fposmod(float(p.u) * path_len * 2.0 + float(p.speed) * t, path_len * 2.0)
			var forward := d <= path_len
			var dist := d if forward else path_len * 2.0 - d
			var at: Vector2 = view.path_point(path_index, dist)
			var x := at.x
			var y := at.y + 1.0
			var step := int(t * 6.0 + float(p.phase)) % 2
			var bob := 0.0 if step == 0 else -1.0
			var face := (1.0 if view.tangent_x(path_index, dist) >= 0.0 else -1.0) * (1.0 if forward else -1.0)
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


## A thing standing in the streets: trees, a fountain, stalls, lamps, ducks...
class Prop extends Control:
	var view: Control
	var kind := "tree"
	var share := Vector2.ZERO
	var variant := 0
	var foot := Vector2.ZERO
	var _tint := Color.WHITE
	var _s := 3.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func place() -> void:
		foot = Vector2(floorf(share.x * view.lw), floorf(share.y * view.lh))

	## A rectangle in view pixels, relative to the foot.
	func r(x: float, y: float, w: float, h: float, c: Color) -> void:
		draw_rect(Rect2((foot.x + x) * _s, (foot.y + y) * _s, w * _s, h * _s), c * _tint)

	func _draw() -> void:
		if view == null:
			return
		_s = view.px
		_tint = view.tint()
		var t: float = view._time
		var night: float = view.night()
		var sway := roundf(sin(t * 0.9 + share.x * 9.0) * 0.8)
		match kind:
			"tree":
				var leaf: Color = [Color("#3f8a46"), Color("#4f9a3a"), Color("#2f7a52")][variant % 3]
				r(-1, -10, 3, 11, Color("#5b4630"))
				r(-7 + sway, -22, 15, 12, leaf)
				r(-5 + sway, -26, 11, 5, leaf.lightened(0.06))
				r(-4, -12, 9, 3, leaf.darkened(0.12))
				r(-5 + sway, -21, 5, 2, leaf.lightened(0.18))
				r(2 + sway, -15, 5, 3, leaf.darkened(0.2))
			"pine":
				var leaf := Color("#2f6a40") if variant == 0 else Color("#3a7a4a")
				r(-1, -4, 3, 5, Color("#4b3826"))
				for i in 5:
					var wid := 3 + i * 2
					r(-(wid / 2) + (sway if i < 2 else 0.0), -24 + i * 4, wid, 4, leaf if i % 2 == 0 else leaf.lightened(0.1))
			"bush":
				var leaf := Color("#3f8a46") if variant == 0 else Color("#4f9a3a")
				r(-4, -4, 9, 4, leaf)
				r(-3, -6, 6, 2, leaf.lightened(0.12))
				r(-2, -3, 1, 1, Color("#ff5a6a"))
				r(2, -4, 1, 1, Color("#ff5a6a"))
			"fountain":
				var stone := Color("#b8b2a2")
				r(-12, -4, 25, 5, stone.darkened(0.12))
				r(-11, -5, 23, 2, stone)
				r(-9, -5, 19, 2, Color("#6ab0e8"))
				r(-1, -13, 3, 9, stone)
				r(-4, -14, 9, 2, stone)
				r(-6, -6, 13, 1, Color("#8fc8f4"))
				for i in 8:
					var ph := fposmod(t * 0.9 + float(i) / 8.0, 1.0)
					var dx := (float(i) - 3.5) * 2.0 * ph
					var dy := -14.0 + (-12.0 * ph + 20.0 * ph * ph) * 0.9
					r(dx, dy, 1, 1, Color(0.8, 0.92, 1.0, 0.9 * (1.0 - ph * 0.3)))
				if night > 0.2:
					draw_circle(Vector2(foot.x, foot.y - 8.0) * _s, 14.0 * _s, Color(0.6, 0.8, 1.0, 0.06 * night))
			"well":
				var stone := Color("#9a968a")
				r(-5, -5, 11, 6, stone)
				r(-4, -6, 9, 2, Color("#2a3a4a"))
				r(-5, -14, 1, 9, Color("#6a4a2a"))
				r(5, -14, 1, 9, Color("#6a4a2a"))
				r(-6, -16, 13, 2, Color("#a8483a"))
				r(-4, -17, 9, 1, Color("#c85a48"))
				r(0, -12, 1, 4, Color("#cfc9bb"))
				r(-1, -9, 3, 2, Color("#8a5a2b"))
			"stall":
				var colors: Array = [[Color("#d9534f"), Color("#f4efe4")], [Color("#4a90d9"), Color("#f4efe4")], [Color("#5fcf6a"), Color("#ffd23f")]][variant % 3]
				r(-9, -4, 19, 4, Color("#8a5a2b"))
				r(-9, -4, 19, 1, Color("#b07a3a"))
				r(-8, -15, 1, 11, Color("#6a4a2a"))
				r(9, -15, 1, 11, Color("#6a4a2a"))
				for i in 10:
					r(-9 + i * 2, -15, 2, 4, colors[i % 2])
					r(-9 + i * 2, -11, 2, 1, (colors[i % 2] as Color).darkened(0.2))
				for i in 6:
					r(-7 + i * 3, -6, 2, 2, [Color("#ff5a4a"), Color("#ffd23f"), Color("#7ad060"), Color("#ff9a4a"), Color("#b65cff"), Color("#f4efe4")][(i + variant) % 6])
			"bench":
				var wood := Color("#8a5a2b")
				r(-7, -7, 14, 1, wood.lightened(0.1))
				r(-7, -4, 14, 2, wood)
				r(-6, -2, 1, 3, wood.darkened(0.3))
				r(5, -2, 1, 3, wood.darkened(0.3))
			"barrel":
				r(-3, -7, 7, 8, Color("#8a5a2b"))
				r(-3, -5, 7, 1, Color("#3a3a40"))
				r(-3, -2, 7, 1, Color("#3a3a40"))
				r(-2, -8, 5, 1, Color("#a87a42"))
			"crate":
				r(-3, -6, 7, 7, Color("#a87a42"))
				r(-3, -6, 7, 1, Color("#c89a5a"))
				r(-3, -3, 7, 1, Color("#7a5a2a"))
				r(0, -6, 1, 7, Color("#7a5a2a"))
			"haystack":
				var hay := Color("#d8b84a")
				r(-7, -4, 15, 5, hay.darkened(0.08))
				r(-6, -7, 13, 3, hay)
				r(-4, -9, 9, 2, hay.lightened(0.08))
				r(-1, -10, 3, 1, hay.lightened(0.15))
				r(-5, -3, 2, 1, hay.darkened(0.25))
				r(3, -5, 2, 1, hay.darkened(0.25))
			"fence":
				var wood := Color("#7a5a32")
				for px_off in [-7, 0, 7]:
					r(px_off, -7, 1, 8, wood)
				r(-7, -6, 15, 1, wood.lightened(0.08))
				r(-7, -3, 15, 1, wood.lightened(0.08))
			"flowers":
				r(-6, -2, 13, 3, Color("#3f8a46"))
				for i in 7:
					var fy := -3.0 - float(int(t * 2.0 + i) % 2) * 0.0
					var lift := 1.0 if sin(t * 2.0 + i * 1.7) > 0.5 else 0.0
					r(-6 + i * 2, fy - lift, 1, 1, [Color("#ff7aa8"), Color("#ffd23f"), Color("#ffffff"), Color("#b98cff"), Color("#ff5a4a")][(i + variant) % 5])
			"sign":
				var wood := Color("#8a5a2b")
				r(0, -14, 1, 14, Color("#5a3a1c"))
				r(-5, -13, 9, 3, wood)
				r(4, -12, 1, 1, wood)
				r(-1, -9, 9, 3, wood.lightened(0.08))
				r(-2, -8, 1, 1, wood.lightened(0.08))
			"lamp":
				r(0, -16, 1, 17, Color("#2c2c34"))
				r(-1, -19, 3, 3, Color("#ffd86a") if night > 0.3 else Color("#e8d8a0"))
				r(-1, -20, 3, 1, Color("#2c2c34"))
				if night > 0.1:
					draw_circle(Vector2(foot.x + 0.5, foot.y - 17.5) * _s, 11.0 * _s, Color(1.0, 0.82, 0.4, 0.07 * night))
					draw_circle(Vector2(foot.x + 0.5, foot.y - 17.5) * _s, 6.0 * _s, Color(1.0, 0.82, 0.4, 0.13 * night))
			"duck":
				var dx := sin(t * 0.4 + variant * 2.4) * 6.0
				var dy := sin(t * 0.6 + variant) * 1.5
				var dir := 1.0 if cos(t * 0.4 + variant * 2.4) >= 0.0 else -1.0
				var bx := roundf(dx)
				var by := roundf(dy)
				r(bx - 2, by - 2, 5, 2, Color("#f4f0e8"))
				r(bx + (2 if dir > 0 else -3), by - 4, 2, 2, Color("#2e7a3a"))
				r(bx + (4 if dir > 0 else -4), by - 3, 1, 1, Color("#ffb02a"))
				r(bx - 3, by, 7, 1, Color(1, 1, 1, 0.25))
			"chicken":
				var peck := 1.0 if fposmod(t * 0.9 + variant * 0.7, 2.0) > 1.6 else 0.0
				var wander := roundf(sin(t * 0.3 + variant * 2.0) * 3.0)
				var cx := wander
				var col := Color("#f4efe4") if variant != 1 else Color("#c8843a")
				r(cx - 2, -3, 4, 3, col)
				r(cx + 1, -5 + peck * 2.0, 2, 2, col)
				r(cx + 2, -6 + peck * 2.0, 1, 1, Color("#e0303a"))
				r(cx + 3, -4 + peck * 2.0, 1, 1, Color("#ffb02a"))
				r(cx - 1, 0, 1, 1, Color("#ffb02a"))
				r(cx + 1, 0, 1, 1, Color("#ffb02a"))
			"pigeons":
				for i in 4:
					var hop := 1.0 if sin(t * 3.0 + i * 1.9) > 0.8 else 0.0
					var bx := float(i) * 6.0 - 9.0 + roundf(sin(t * 0.5 + i) * 2.0)
					r(bx, -2 - hop, 3, 2, Color("#9aa0b0"))
					r(bx + 2, -3 - hop, 2, 2, Color("#7a8090"))
					r(bx + 4, -2 - hop, 1, 1, Color("#ffb02a"))


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
