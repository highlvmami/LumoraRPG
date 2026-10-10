## Pixel-art painter for the town's buildings. Every building is drawn once
## into a small Image (a few dozen pixels wide) with brick, plank, plaster and
## shingle textures, framed windows, doors, props and a dark outline; the city
## view scales it up with nearest-neighbour filtering. Buildings are shown
## in a slight 3D: the front face plus the side wall and roof slope that turn
## away to the right (buildings on the right of the street are mirrored).
##
## Kinds: gable (houses, shops, the inn), tower, hall, market, gate, barn,
## dome and den. `extras` add details (chimney, awning, forge, flag, ...).
extends RefCounted

const OUTLINE := Color("#1b1310")
const DEPTH := 9

## What paint() returns for one building.
## tex: the building, sil: white silhouette (haze, night tint), ring: 1px
## outline for hovering, windows/door/chimney/flag/lamp/emblem: places for
## animated details (in image pixels, already mirrored when flipped).


static func paint(kind: String, wall: Color, roof: Color, w: int, h: int, seed_value: int, extras: Array, pattern: String, flip: bool) -> Dictionary:
	var pad := 7
	var cw := w + DEPTH + pad * 2
	var ch := h + DEPTH / 2 + pad + 14
	var img := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var info := {"windows": [], "door": Rect2i(), "chimney": Vector2i(-1, -1), "flag": Vector2i(-1, -1), "lamps": [], "emblem": Rect2i(), "glow": Color(1, 0.8, 0.4)}
	var ctx := {"img": img, "w": w, "h": h, "x0": pad, "ground": ch - 4, "seed": seed_value, "extras": extras, "pattern": pattern, "wall": wall, "roof": roof, "info": info, "top": 0}
	match kind:
		"tower":
			_tower(ctx)
		"hall":
			_hall(ctx)
		"market":
			_market(ctx)
		"gate":
			_gate(ctx)
		"barn":
			_barn(ctx)
		"dome":
			_dome(ctx)
		"den":
			_den(ctx)
		_:
			_gable(ctx)
	_props(ctx)
	_outline(img)
	if flip:
		img.flip_x()
		_mirror(info, cw)
	var result := {"info": info, "size": Vector2i(cw, ch)}
	result.tex = ImageTexture.create_from_image(img)
	result.sil = ImageTexture.create_from_image(_silhouette(img, false))
	result.ring = ImageTexture.create_from_image(_silhouette(img, true))
	return result


# --- Image helpers ---------------------------------------------------------------

static func _hash(x: int, y: int, s: int) -> float:
	var n := (x * 374761393 + y * 668265263 + s * 1274126177) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n & 0xffff) / 65535.0


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	var r := Rect2i(x, y, w, h).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if r.size.x > 0 and r.size.y > 0:
		img.fill_rect(r, c)


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _poly(img: Image, pts: PackedVector2Array, c: Color) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	for y in range(maxi(0, floori(lo.y)), mini(img.get_height(), ceili(hi.y) + 1)):
		for x in range(maxi(0, floori(lo.x)), mini(img.get_width(), ceili(hi.x) + 1)):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
				img.set_pixel(x, y, c)


static func _line(img: Image, a: Vector2i, b: Vector2i, c: Color) -> void:
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var x := a.x
	var y := a.y
	for i in 400:
		_px(img, x, y, c)
		if x == b.x and y == b.y:
			return
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy


## Fills a rectangle with a wall texture ("brick", "plank", "stone" or "plaster").
static func _wall(img: Image, r: Rect2i, base: Color, pattern: String, s: int) -> void:
	_rect(img, r.position.x, r.position.y, r.size.x, r.size.y, base)
	var mortar := base.darkened(0.28)
	match pattern:
		"brick":
			for j in range(0, r.size.y, 4):
				_rect(img, r.position.x, r.position.y + j + 3, r.size.x, 1, mortar)
				var off := (j / 4) % 2 * 3
				for i in range(off, r.size.x, 6):
					_rect(img, r.position.x + i, r.position.y + j, 1, 3, mortar)
					var tone := _hash(i, j, s)
					if tone > 0.75:
						_rect(img, r.position.x + i + 1, r.position.y + j, 5, 3, base.lightened(0.08))
					elif tone < 0.2:
						_rect(img, r.position.x + i + 1, r.position.y + j, 5, 3, base.darkened(0.08))
		"plank":
			for i in range(0, r.size.x, 4):
				_rect(img, r.position.x + i + 3, r.position.y, 1, r.size.y, mortar)
				var tone := _hash(i, 3, s)
				_rect(img, r.position.x + i, r.position.y, 3, r.size.y, base.lightened(0.05) if tone > 0.5 else base.darkened(0.04))
				for k in 3:
					var ky := int(_hash(i, k, s + 5) * r.size.y)
					_px(img, r.position.x + i + 1, r.position.y + ky, mortar)
		"stone":
			var y := 0
			var row := 0
			while y < r.size.y:
				var bh := 5 + int(_hash(row, 1, s) * 3)
				_rect(img, r.position.x, r.position.y + y + bh - 1, r.size.x, 1, mortar)
				var x := int(_hash(row, 2, s) * 5)
				while x < r.size.x:
					var bw := 6 + int(_hash(x, row, s) * 6)
					_rect(img, r.position.x + x, r.position.y + y, 1, bh, mortar)
					var tone := _hash(x, y, s + 9)
					if tone > 0.7:
						_rect(img, r.position.x + x + 1, r.position.y + y, bw - 1, bh - 1, base.lightened(0.07))
					elif tone < 0.25:
						_rect(img, r.position.x + x + 1, r.position.y + y, bw - 1, bh - 1, base.darkened(0.07))
					x += bw
				y += bh
				row += 1
		_:
			# Plaster: speckles, and timber beams.
			for k in r.size.x * r.size.y / 14:
				var px := int(_hash(k, 4, s) * r.size.x)
				var py := int(_hash(k, 5, s) * r.size.y)
				_px(img, r.position.x + px, r.position.y + py, base.darkened(0.07) if _hash(k, 6, s) > 0.5 else base.lightened(0.06))
			var beam := Color("#5a3a22")
			_rect(img, r.position.x, r.position.y, r.size.x, 1, beam)
			_rect(img, r.position.x, r.position.y + r.size.y - 2, r.size.x, 2, beam)
			_rect(img, r.position.x, r.position.y, 2, r.size.y, beam)
			_rect(img, r.position.x + r.size.x - 2, r.position.y, 2, r.size.y, beam)
			var mid := r.position.x + r.size.x / 2
			_rect(img, mid, r.position.y, 1, r.size.y, beam)
			_line(img, Vector2i(r.position.x + 2, r.position.y + r.size.y - 3), Vector2i(mid, r.position.y + 1), beam)
			_line(img, Vector2i(r.position.x + r.size.x - 3, r.position.y + r.size.y - 3), Vector2i(mid, r.position.y + 1), beam)
	# Shade at the bottom and light at the top edge.
	_rect(img, r.position.x, r.position.y + r.size.y - 1, r.size.x, 1, base.darkened(0.35))
	_rect(img, r.position.x, r.position.y, r.size.x, 1, base.lightened(0.12))


## The wall that turns away to the right of a front face: a parallelogram.
static func _side(img: Image, x1: int, y_top: int, y_bot: int, base: Color, pattern: String, s: int) -> void:
	var d := DEPTH
	var pts := PackedVector2Array([Vector2(x1, y_top), Vector2(x1 + d, y_top - d / 2.0), Vector2(x1 + d, y_bot - d / 2.0), Vector2(x1, y_bot)])
	var dark := base.darkened(0.32)
	_poly(img, pts, dark)
	for i in d:
		var top := y_top - i / 2
		var bottom := y_bot - i / 2
		if pattern == "brick" or pattern == "stone":
			for y in range(top, bottom, 4):
				_px(img, x1 + i, y + 3, dark.darkened(0.25))
			if i % 5 == 0:
				for y in range(top + (i / 5 % 2) * 2, bottom, 4):
					_px(img, x1 + i, y, dark.darkened(0.2))
		else:
			if i % 3 == 0:
				_rect(img, x1 + i, top, 1, bottom - top, dark.darkened(0.14))
	# A dark edge where the two walls meet.
	_rect(img, x1, y_top, 1, y_bot - y_top, dark.darkened(0.3))
	_rect(img, x1, y_bot - 1, d + 1, 1, dark.darkened(0.4))


static func _window(ctx: Dictionary, x: int, y: int, w: int, h: int, shutter: Color, flowers := false) -> void:
	var img: Image = ctx.img
	var frame := Color("#3a2416")
	_rect(img, x - 1, y - 1, w + 2, h + 2, frame)
	_rect(img, x, y, w, h, Color("#7fa6c8"))
	_rect(img, x, y, w, 1, Color("#b8d4ea"))
	_rect(img, x + w / 2, y, 1, h, frame)
	_rect(img, x, y + h / 2, w, 1, frame)
	if shutter.a > 0.0:
		_rect(img, x - 3, y - 1, 2, h + 2, shutter)
		_rect(img, x + w + 1, y - 1, 2, h + 2, shutter)
		for k in range(0, h, 2):
			_px(img, x - 3, y + k, shutter.darkened(0.3))
			_px(img, x + w + 2, y + k, shutter.darkened(0.3))
	_rect(img, x - 2, y + h + 1, w + 4, 1, Color("#cfc2a8"))
	if flowers:
		_rect(img, x - 1, y + h + 2, w + 2, 2, Color("#6b4423"))
		for k in w:
			_px(img, x + k, y + h + 1, [Color("#e0484f"), Color("#ffd23f"), Color("#5fcf6a")][k % 3])
	(ctx.info.windows as Array).append(Rect2i(x, y, w, h))


static func _door(ctx: Dictionary, x: int, y: int, w: int, h: int, color: Color) -> void:
	var img: Image = ctx.img
	var frame := Color("#2c1a0e")
	_rect(img, x - 1, y - 1, w + 2, h + 1, frame)
	_rect(img, x, y, w, h, color)
	for i in range(1, w, 3):
		_rect(img, x + i, y, 1, h, color.darkened(0.25))
	_rect(img, x, y, 1, 1, frame)
	_rect(img, x + w - 1, y, 1, 1, frame)
	_rect(img, x + w - 3, y + h / 2, 1, 2, Color("#ffd23f"))
	_rect(img, x - 2, y + h, w + 4, 2, Color("#8a8478"))
	_rect(img, x - 2, y + h, w + 4, 1, Color("#b0a998"))
	ctx.info.door = Rect2i(x, y, w, h)


static func _emblem_spot(ctx: Dictionary, x: int, y: int, size: int) -> void:
	ctx.info.emblem = Rect2i(x, y, size, size)


static func _chimney(ctx: Dictionary, x: int, y_base: int, h: int) -> void:
	var img: Image = ctx.img
	_wall(img, Rect2i(x, y_base - h, 5, h), Color("#8a5a4a"), "brick", ctx.seed + 3)
	_rect(img, x - 1, y_base - h - 1, 7, 2, Color("#4a4540"))
	ctx.info.chimney = Vector2i(x + 2, y_base - h - 2)


## A gabled roof seen from the front: a triangle (the gable end) and the slope
## going back to the right, with shingle rows.
static func _gable_roof(ctx: Dictionary, x_left: int, x_right: int, y_eave: int, apex_y: int, wall: Color, roof: Color, over := 2, thatch := false) -> void:
	var img: Image = ctx.img
	var d := DEPTH
	var xm := (x_left + x_right) / 2
	# Gable end (front).
	var gable := PackedVector2Array([Vector2(x_left - over, y_eave + 1), Vector2(xm, apex_y), Vector2(x_right + over + 1, y_eave + 1)])
	_poly(img, gable, wall.darkened(0.05))
	# Right slope as a parallelogram from the front edge back.
	var steps_v := 60
	var edge_len := Vector2(x_right + over - xm, y_eave - apex_y).length()
	var seed_value: int = ctx.seed
	for vi in steps_v + 1:
		var v := float(vi) / steps_v
		var ex := lerpf(xm, x_right + over, v)
		var ey := lerpf(apex_y, y_eave, v)
		for ui in d * 2 + 1:
			var u := float(ui) / (d * 2)
			var px := roundi(ex + u * d)
			var py := roundi(ey - u * d / 2.0)
			var row := int(v * edge_len / 3.0)
			var col := int(u * d / 3.0)
			var c := roof.lightened(0.1) if (row + col) % 2 == 0 else roof
			if thatch:
				c = roof.lightened(0.06 + _hash(px, py, seed_value) * 0.1) if int(v * edge_len) % 2 == 0 else roof.darkened(0.1)
			elif int(v * edge_len) % 3 == 2:
				c = roof.darkened(0.22)
			_px(img, px, py, c)
	# Front rim: the gable's edge in roof color, thick.
	var rim := roof.darkened(0.1)
	_line(img, Vector2i(x_left - over, y_eave), Vector2i(xm, apex_y), rim)
	_line(img, Vector2i(x_left - over, y_eave + 1), Vector2i(xm, apex_y + 1), rim)
	_line(img, Vector2i(x_left - over, y_eave + 2), Vector2i(xm, apex_y + 2), rim.darkened(0.2))
	_line(img, Vector2i(xm, apex_y), Vector2i(x_right + over, y_eave), roof.lightened(0.18))
	_line(img, Vector2i(xm, apex_y), Vector2i(xm + d, apex_y - d / 2), roof.lightened(0.25))
	_rect(img, x_left - over, y_eave + 1, x_right - x_left + over * 2 + 1, 1, roof.darkened(0.35))
	# The eave's shadow on the wall.
	_rect(img, x_left, y_eave + 2, x_right - x_left + 1, 1, wall.darkened(0.3))
	(ctx.info as Dictionary).apex = Vector2i(xm, apex_y)


# --- Building kinds --------------------------------------------------------------

static func _gable(ctx: Dictionary) -> void:
	var img: Image = ctx.img
	var w: int = ctx.w
	var h: int = ctx.h
	var x0: int = ctx.x0
	var ground: int = ctx.ground
	var wall: Color = ctx.wall
	var roof: Color = ctx.roof
	var extras: Array = ctx.extras
	var s: int = ctx.seed
	var stories := 2 if extras.has("tall") else 1
	var body_h := int(h * (0.52 if stories == 1 else 0.66))
	var y_wall := ground - body_h
	var apex := ground - h
	_side(img, x0 + w, y_wall, ground, wall, ctx.pattern, s)
	_wall(img, Rect2i(x0, y_wall, w, body_h), wall, ctx.pattern, s)
	_gable_roof(ctx, x0, x0 + w, y_wall - 1, apex, wall, roof, 3, extras.has("thatch"))
	# Attic window in the gable.
	if w >= 36:
		_window(ctx, x0 + w / 2 - 2, y_wall - int((y_wall - apex) * 0.45), 4, 4, Color(0, 0, 0, 0))
	# Door and windows on the front.
	var door_w := 7
	var door_x := x0 + w / 2 - door_w / 2 if not extras.has("door_left") else x0 + 5
	_door(ctx, door_x, ground - 11, door_w, 11, Color("#6b4226"))
	var gap_l := door_x - x0
	var gap_r := x0 + w - (door_x + door_w)
	var shutter := Color("#3a6b4a") if _hash(s, 1, 0) > 0.5 else Color("#7a3a3a")
	var win_y := y_wall + 4
	if gap_l >= 9:
		_window(ctx, x0 + (gap_l - 6) / 2 + 1, win_y, 5, 6, shutter, extras.has("flowers"))
	if gap_r >= 9:
		_window(ctx, door_x + door_w + (gap_r - 6) / 2 + 1, win_y, 5, 6, shutter, extras.has("flowers"))
	if stories == 2:
		var upper_y := y_wall + 4
		_rect(img, x0, y_wall + body_h / 2 - 1, w, 2, Color("#4a2e1a"))
		for k in 3:
			_window(ctx, x0 + 5 + k * ((w - 14) / 2), upper_y, 4, 5, shutter)
		# Move ground floor windows down a little.
		var lower: Array = ctx.info.windows
		for k in lower.size():
			var r: Rect2i = lower[k]
			if r.position.y == win_y and r.size.y == 6:
				_rect(img, r.position.x - 3, r.position.y - 1, r.size.x + 6, r.size.y + 3, wall)
				_window(ctx, r.position.x, r.position.y + body_h / 2 - 1, r.size.x, 5, shutter, true)
				lower.remove_at(k)
				break
	_emblem_spot(ctx, x0 + w / 2 - 6, y_wall - int((y_wall - apex) * 0.2) - 6, 12)
	if extras.has("chimney"):
		_chimney(ctx, x0 + w / 2 + 6, y_wall - int((y_wall - apex) * 0.45) - 2, 10)
	if extras.has("forge"):
		_chimney(ctx, x0 + w - 11, y_wall - int((y_wall - apex) * 0.4) - 2, 14)
		(ctx.info as Dictionary).forge = true
	if extras.has("awning"):
		_awning(ctx, x0 + 2, y_wall + body_h - 14, w - 4, [Color("#d9534f"), Color("#ffd23f"), Color("#4a90d9")][int(_hash(s, 2, 0) * 3)])
	if extras.has("mug"):
		_line(img, Vector2i(x0 - 2, y_wall + 2), Vector2i(x0 - 6, y_wall + 2), Color("#3a2416"))
		_rect(img, x0 - 9, y_wall + 3, 5, 5, Color("#d8a24a"))
		_rect(img, x0 - 9, y_wall + 3, 5, 1, Color("#f4f1e6"))
		_px(img, x0 - 4, y_wall + 4, Color("#d8a24a"))
	if extras.has("flag"):
		var fx: int = (ctx.info.apex as Vector2i).x
		var fy: int = (ctx.info.apex as Vector2i).y
		_rect(img, fx, fy - 12, 1, 12, Color("#cfc9bb"))
		ctx.info.flag = Vector2i(fx + 1, fy - 12)
	if extras.has("heart"):
		var hx := x0 + w - 9
		var hy := y_wall + 3
		for p in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3)]:
			_px(img, hx + p.x, hy + p.y, Color("#e0484f"))
	if extras.has("board"):
		_rect(img, x0 - 10, ground - 12, 9, 8, Color("#8a5a2b"))
		_rect(img, x0 - 9, ground - 11, 7, 6, Color("#c9a56a"))
		for k in 3:
			_rect(img, x0 - 8 + k * 2, ground - 10 + (k % 2), 2, 3, Color("#f4f1e6"))
		_rect(img, x0 - 7, ground - 4, 1, 4, Color("#5b4630"))
		_rect(img, x0 - 4, ground - 4, 1, 4, Color("#5b4630"))
	if extras.has("lamp"):
		_lamp(ctx, x0 + w + 2, ground - 14)


static func _awning(ctx: Dictionary, x: int, y: int, w: int, color: Color) -> void:
	var img: Image = ctx.img
	for i in w:
		var stripe := color if (i / 3) % 2 == 0 else Color("#f4f1e6")
		_rect(img, x + i, y, 1, 4, stripe)
		if i % 3 == 1:
			_px(img, x + i, y + 4, stripe)
	_rect(img, x, y, w, 1, color.lightened(0.2))
	_rect(img, x, y + 5, w, 1, Color(0, 0, 0, 0.0))


static func _lamp(ctx: Dictionary, x: int, y: int) -> void:
	var img: Image = ctx.img
	_rect(img, x, y + 3, 1, 12, Color("#2c2c34"))
	_rect(img, x - 1, y, 3, 3, Color("#ffd86a"))
	_rect(img, x - 1, y - 1, 3, 1, Color("#2c2c34"))
	(ctx.info.lamps as Array).append(Vector2i(x, y + 1))


static func _tower(ctx: Dictionary) -> void:
	var img: Image = ctx.img
	var w: int = ctx.w
	var h: int = ctx.h
	var x0: int = ctx.x0
	var ground: int = ctx.ground
	var wall: Color = ctx.wall
	var roof: Color = ctx.roof
	var s: int = ctx.seed
	var tw := int(w * 0.62)
	var tx := x0 + (w - tw) / 2
	var body_top := ground - int(h * 0.7)
	_wall(img, Rect2i(tx, body_top, tw, ground - body_top), wall, "stone", s)
	# Cylinder shading: light on the left, dark on the right.
	for i in tw:
		var t := float(i) / tw
		var shade := Color(0, 0, 0, 0.0)
		if t < 0.22:
			shade = Color(1, 1, 1, 0.14 * (1.0 - t / 0.22))
		elif t > 0.5:
			shade = Color(0, 0, 0, 0.5 * (t - 0.5) / 0.5)
		for y in range(body_top, ground):
			var c := img.get_pixel(tx + i, y)
			img.set_pixel(tx + i, y, c.lerp(Color(shade, 1.0), shade.a) if shade.a > 0.0 else c)
	# A balcony ring near the top with crenels.
	_rect(img, tx - 2, body_top, tw + 4, 3, wall.darkened(0.2))
	for i in range(tx - 2, tx + tw + 2, 4):
		_rect(img, i, body_top - 3, 3, 3, wall.darkened(0.15))
	# Conical roof.
	var rx0 := tx - 3
	var rx1 := tx + tw + 3
	var apex := ground - h
	var cone := PackedVector2Array([Vector2(rx0, body_top - 3), Vector2(tx + tw / 2, apex), Vector2(rx1, body_top - 3)])
	_poly(img, cone, roof)
	for y in range(apex, body_top - 3):
		var t := float(y - apex) / maxf(1.0, body_top - 3 - apex)
		var half := t * (rx1 - rx0) / 2.0
		var cx := tx + tw / 2
		for x in range(roundi(cx - half), roundi(cx + half) + 1):
			var row := (y - apex) / 3
			var c := roof if (row + (x - cx + 100) / 4) % 2 == 0 else roof.darkened(0.14)
			if x > cx + half * 0.4:
				c = c.darkened(0.25)
			elif x < cx - half * 0.55:
				c = c.lightened(0.14)
			_px(img, x, y, c)
	_rect(img, tx + tw / 2, apex - 8, 1, 8, Color("#cfc9bb"))
	ctx.info.flag = Vector2i(tx + tw / 2 + 1, apex - 8)
	# Narrow arched windows and a door.
	for k in 2:
		var wy := body_top + 6 + k * 14
		if wy + 8 < ground - 12:
			_window(ctx, tx + tw / 2 - 1 - (3 if k == 0 else -1), wy, 3, 6, Color(0, 0, 0, 0))
	_door(ctx, tx + tw / 2 - 3, ground - 10, 6, 10, Color("#4a3322"))
	_emblem_spot(ctx, tx + tw / 2 - 6, body_top + 3, 12)
	ctx.info.glow = Color(0.7, 0.55, 1.0)
	_rect(img, tx + tw, ground - 1, DEPTH / 2, 1, Color(0, 0, 0, 0.0))


static func _hall(ctx: Dictionary) -> void:
	var img: Image = ctx.img
	var w: int = ctx.w
	var h: int = ctx.h
	var x0: int = ctx.x0
	var ground: int = ctx.ground
	var wall: Color = ctx.wall
	var roof: Color = ctx.roof
	var extras: Array = ctx.extras
	var s: int = ctx.seed
	var body_h := int(h * 0.6)
	var y_wall := ground - body_h
	var apex := ground - int(h * 0.92)
	_side(img, x0 + w, y_wall, ground, wall, "stone", s)
	_wall(img, Rect2i(x0, y_wall, w, body_h), wall, "stone", s)
	_gable_roof(ctx, x0 + 6, x0 + w - 6, y_wall - 1, apex, wall, roof, 2)
	# Two flanking turrets with crenellations.
	for tx in [x0 - 1, x0 + w - 7]:
		var th := int(h * 0.78)
		_wall(img, Rect2i(tx, ground - th, 8, th), wall.lightened(0.04), "stone", s + 7)
		_rect(img, tx + 5, ground - th, 3, th, Color(0, 0, 0, 0.0))
		for i in range(tx - 1, tx + 9, 3):
			_rect(img, i, ground - th - 3, 2, 3, wall.darkened(0.1))
		_rect(img, tx - 1, ground - th, 10, 2, wall.darkened(0.25))
		_window(ctx, tx + 3, ground - th + 6, 2, 5, Color(0, 0, 0, 0))
	# Banners on the front.
	var banner := roof.lightened(0.15)
	for bx in [x0 + 11, x0 + w - 17]:
		_rect(img, bx, y_wall + 3, 6, 15, banner)
		_poly(img, PackedVector2Array([Vector2(bx, y_wall + 18), Vector2(bx + 3, y_wall + 15), Vector2(bx + 6, y_wall + 18)]), banner)
		_rect(img, bx + 2, y_wall + 6, 2, 5, Color("#ffd23f"))
		_rect(img, bx - 1, y_wall + 2, 8, 1, Color("#cfc9bb"))
	# Door in the middle, with steps.
	_door(ctx, x0 + w / 2 - 4, ground - 13, 8, 13, Color("#4a3322"))
	_rect(img, x0 + w / 2 - 7, ground - 2, 14, 2, Color("#a09a8c"))
	if extras.has("columns"):
		for cx in [x0 + w / 2 - 12, x0 + w / 2 + 10]:
			_rect(img, cx, y_wall + 4, 3, body_h - 4, Color("#e8e2d0"))
			_rect(img, cx, y_wall + 4, 1, body_h - 4, Color("#ffffff"))
			_rect(img, cx - 1, y_wall + 3, 5, 2, Color("#cfc9bb"))
			_rect(img, cx - 1, ground - 2, 5, 2, Color("#cfc9bb"))
	if extras.has("trophy"):
		var tx := x0 + w / 2
		_rect(img, tx - 3, apex - 7, 7, 4, Color("#ffd23f"))
		_rect(img, tx - 1, apex - 3, 3, 3, Color("#ffd23f"))
		_rect(img, tx - 4, apex - 6, 1, 2, Color("#ffd23f"))
		_rect(img, tx + 4, apex - 6, 1, 2, Color("#ffd23f"))
		_rect(img, tx - 3, apex - 7, 2, 1, Color("#fff1a8"))
	_emblem_spot(ctx, x0 + w / 2 - 6, y_wall + 2, 12)
	ctx.info.glow = Color(0.6, 0.8, 1.0)
	var fx := x0 + 3
	_rect(img, fx, ground - int(h * 0.78) - 12, 1, 9, Color("#cfc9bb"))
	ctx.info.flag = Vector2i(fx + 1, ground - int(h * 0.78) - 12)


static func _market(ctx: Dictionary) -> void:
	var img: Image = ctx.img
	var w: int = ctx.w
	var h: int = ctx.h
	var x0: int = ctx.x0
	var ground: int = ctx.ground
	var wall: Color = ctx.wall
	var roof: Color = ctx.roof
	var s: int = ctx.seed
	var back_top := ground - int(h * 0.58)
	_side(img, x0 + w, back_top, ground, wall, "plank", s)
	_wall(img, Rect2i(x0 + 2, back_top, w - 4, ground - back_top), wall.darkened(0.2), "plank", s)
	# Stripes of the awning slope.
	var top := ground - int(h * 0.95)
	for i in w + DEPTH:
		var stripe := roof if (i / 4) % 2 == 0 else Color("#f4f1e6")
		var depth_i := maxi(0, i - w)
		var y_a := top + 4 - depth_i / 2
		var y_b := top + int(h * 0.3) - depth_i / 2
		for y in range(y_a, y_b):
			var shade := stripe if i < w else stripe.darkened(0.2)
			_px(img, x0 + i, y, shade.lightened(0.1) if y < y_a + 3 else shade)
		# Scalloped hem.
		if (i / 4) % 1 == 0:
			var scallop := 2 if i % 4 in [1, 2] else 1
			for k in scallop:
				_px(img, x0 + i, y_b + k, stripe.darkened(0.15 if i < w else 0.35))
	# Posts.
	_rect(img, x0, top + 4, 2, ground - top - 4, Color("#5b4630"))
	_rect(img, x0 + w - 2, top + 4, 2, ground - top - 4, Color("#5b4630"))
	# The counter with goods.
	var counter_y := ground - int(h * 0.3)
	_rect(img, x0 + 2, counter_y, w - 4, ground - counter_y, Color("#8a5a2b"))
	_rect(img, x0 + 2, counter_y, w - 4, 2, Color("#c9a56a"))
	for i in range(0, w - 6, 5):
		_rect(img, x0 + 4 + i, counter_y + 4, 1, ground - counter_y - 4, Color("#5b4630"))
	for k in 8:
		var gx := x0 + 4 + k * ((w - 10) / 7)
		var colors := [Color("#e0484f"), Color("#ffd23f"), Color("#5fcf6a"), Color("#b65cff")]
		var gc: Color = colors[k % 4]
		_rect(img, gx, counter_y - 3, 3, 3, gc)
		_px(img, gx, counter_y - 3, gc.lightened(0.35))
	# A barrel and crates.
	_rect(img, x0 - 7, ground - 8, 6, 8, Color("#6b4423"))
	_rect(img, x0 - 7, ground - 6, 6, 1, Color("#3a2416"))
	_rect(img, x0 - 7, ground - 3, 6, 1, Color("#3a2416"))
	_rect(img, x0 - 7, ground - 8, 6, 1, Color("#a07a48"))
	_emblem_spot(ctx, x0 + w / 2 - 6, back_top - 14, 12)
	_lamp(ctx, x0 + w + 3, ground - 18)


static func _gate(ctx: Dictionary) -> void:
	var img: Image = ctx.img
	var w: int = ctx.w
	var h: int = ctx.h
	var x0: int = ctx.x0
	var ground: int = ctx.ground
	var wall: Color = ctx.wall
	var roof: Color = ctx.roof
	var s: int = ctx.seed
	var tower_w := 13
	var top := ground - h
	_side(img, x0 + w, top + 8, ground, wall, "stone", s)
	_wall(img, Rect2i(x0, top + 8, w, ground - top - 8), wall, "stone", s)
	for tx in [x0, x0 + w - tower_w]:
		_wall(img, Rect2i(tx, top, tower_w, ground - top), wall.lightened(0.05), "stone", s + 4)
		for i in range(tx, tx + tower_w, 4):
			_rect(img, i, top - 3, 3, 3, wall.darkened(0.1))
		_rect(img, tx - 1, top, tower_w + 2, 2, wall.darkened(0.25))
		_window(ctx, tx + 5, top + 8, 3, 6, Color(0, 0, 0, 0))
		_poly(img, PackedVector2Array([Vector2(tx + 1, top - 3), Vector2(tx + tower_w / 2.0 + 0.5, top - 12), Vector2(tx + tower_w, top - 3)]), roof)
	# The arch and the portcullis.
	var ax := x0 + tower_w
	var aw := w - tower_w * 2
	var ah := int(h * 0.62)
	_rect(img, ax, ground - ah, aw, ah, Color("#14110e"))
	for i in aw:
		var t := float(i) / aw
		var arch_y := ground - ah + int(pow(absf(t - 0.5) * 2.0, 2.5) * 7.0)
		_rect(img, ax + i, ground - ah, 1, arch_y - (ground - ah), wall.darkened(0.1))
	for i in range(1, aw, 3):
		_rect(img, ax + i, ground - ah + 7, 1, ah - 7 - 6, Color("#6b6560"))
	for j in range(ground - ah + 9, ground - 6, 6):
		_rect(img, ax, j, aw, 1, Color("#6b6560"))
	for i in range(1, aw, 3):
		_poly(img, PackedVector2Array([Vector2(ax + i - 0.5, ground - 6), Vector2(ax + i + 0.5, ground - 6), Vector2(ax + i, ground - 3)]), Color("#8a8680"))
	# A torch on each side.
	_lamp(ctx, ax - 2, ground - ah - 1 + ah / 2)
	_lamp(ctx, ax + aw + 1, ground - ah - 1 + ah / 2)
	_emblem_spot(ctx, ax + aw / 2 - 6, ground - ah - 14, 12)
	ctx.info.door = Rect2i(ax, ground - ah, aw, ah)


static func _barn(ctx: Dictionary) -> void:
	var img: Image = ctx.img
	var w: int = ctx.w
	var h: int = ctx.h
	var x0: int = ctx.x0
	var ground: int = ctx.ground
	var wall: Color = ctx.wall
	var roof: Color = ctx.roof
	var s: int = ctx.seed
	var body_h := int(h * 0.58)
	var y_wall := ground - body_h
	var apex := ground - h
	_side(img, x0 + w, y_wall, ground, wall, "plank", s)
	_wall(img, Rect2i(x0, y_wall, w, body_h), wall, "plank", s)
	_gable_roof(ctx, x0, x0 + w, y_wall - 1, apex, wall, roof, 3)
	# Big double doors with cross braces.
	var dw := int(w * 0.5)
	var dx := x0 + (w - dw) / 2
	var dh := body_h - 2
	_rect(img, dx - 1, ground - dh - 1, dw + 2, dh + 1, Color("#3a2416"))
	_rect(img, dx, ground - dh, dw / 2, dh, wall.darkened(0.15))
	_rect(img, dx + dw / 2, ground - dh, dw - dw / 2, dh, wall.darkened(0.1))
	_rect(img, dx + dw / 2, ground - dh, 1, dh, Color("#3a2416"))
	for half in 2:
		var hx := dx + half * (dw / 2)
		_line(img, Vector2i(hx + 1, ground - dh + 1), Vector2i(hx + dw / 2 - 2, ground - 2), Color("#f0e6cf"))
		_line(img, Vector2i(hx + dw / 2 - 2, ground - dh + 1), Vector2i(hx + 1, ground - 2), Color("#f0e6cf"))
	ctx.info.door = Rect2i(dx, ground - dh, dw, dh)
	# The hay loft.
	_window(ctx, x0 + w / 2 - 3, y_wall - int((y_wall - apex) * 0.5), 6, 5, Color(0, 0, 0, 0))
	_rect(img, x0 + w / 2 - 5, y_wall - int((y_wall - apex) * 0.5) - 3, 10, 1, Color("#5b4630"))
	# Hay bales and a trough.
	for k in 2:
		_rect(img, x0 - 9 + k * 3, ground - 5 - k * 4, 8, 5, Color("#d8b84a"))
		_rect(img, x0 - 9 + k * 3, ground - 5 - k * 4, 8, 1, Color("#f2d870"))
		_rect(img, x0 - 7 + k * 3, ground - 3 - k * 4, 1, 3, Color("#a88a30"))
	_rect(img, x0 + w - 8, ground - 4, 12, 4, Color("#6b4423"))
	_rect(img, x0 + w - 7, ground - 4, 10, 1, Color("#3e7fb8"))
	# A horseshoe over the door.
	_px(img, x0 + w / 2 - 1, y_wall + 1, Color("#cfc9bb"))
	_px(img, x0 + w / 2 + 1, y_wall + 1, Color("#cfc9bb"))
	_px(img, x0 + w / 2, y_wall + 2, Color("#cfc9bb"))
	_emblem_spot(ctx, x0 + w / 2 - 6, y_wall - 14, 12)
	_lamp(ctx, x0 + w + 3, ground - 18)


static func _dome(ctx: Dictionary) -> void:
	var img: Image = ctx.img
	var w: int = ctx.w
	var h: int = ctx.h
	var x0: int = ctx.x0
	var ground: int = ctx.ground
	var wall: Color = ctx.wall
	var roof: Color = ctx.roof
	var s: int = ctx.seed
	var body_h := int(h * 0.5)
	var y_wall := ground - body_h
	_side(img, x0 + w, y_wall, ground, wall, "stone", s)
	_wall(img, Rect2i(x0, y_wall, w, body_h), wall, "stone", s)
	# The dome: a half ellipse with shading and a gold finial.
	var cx := x0 + w / 2.0
	var rx := w / 2.0 + 3.0
	var ry := h * 0.42
	for y in range(int(y_wall - ry), y_wall + 1):
		var dy := (y_wall - y) / ry
		var half := rx * sqrt(maxf(0.0, 1.0 - dy * dy))
		for x in range(roundi(cx - half), roundi(cx + half) + 1):
			var nx := (x - cx) / rx
			var light := clampf(-nx * 0.7 + (1.0 - dy) * 0.0 + dy * 0.5, -1.0, 1.0)
			var c := roof.lightened(0.28 * light) if light > 0.0 else roof.darkened(-0.35 * light)
			if (int(y + x) % 7) == 0:
				c = c.darkened(0.08)
			_px(img, x, y, c)
	_rect(img, roundi(cx) - 1, int(y_wall - ry) - 5, 2, 5, Color("#ffd23f"))
	_rect(img, roundi(cx) - 2, int(y_wall - ry) - 7, 4, 3, Color("#ffd23f"))
	_px(img, roundi(cx) - 1, int(y_wall - ry) - 7, Color("#fff1a8"))
	_rect(img, x0 - 3, y_wall, w + 6, 3, wall.darkened(0.25))
	# A round window, the door and gem-shaped signs.
	_door(ctx, x0 + w / 2 - 4, ground - 11, 8, 11, Color("#3a2f5a"))
	_window(ctx, x0 + 4, y_wall + 6, 5, 6, Color("#b65cff"))
	_window(ctx, x0 + w - 10, y_wall + 6, 5, 6, Color("#b65cff"))
	for gem in [[x0 + w / 2 - 14, ground - 8, Color("#4fb8ff")], [x0 + w / 2 + 11, ground - 8, Color("#e0484f")]]:
		var gc: Color = gem[2]
		_poly(img, PackedVector2Array([Vector2(gem[0] + 2, gem[1]), Vector2(gem[0] + 5, gem[1] + 2), Vector2(gem[0] + 2.5, gem[1] + 6), Vector2(gem[0], gem[1] + 2)]), gc)
		_px(img, gem[0] + 2, gem[1] + 1, gc.lightened(0.5))
	_emblem_spot(ctx, x0 + w / 2 - 6, y_wall + 3, 12)
	ctx.info.glow = Color(0.8, 0.5, 1.0)


static func _den(ctx: Dictionary) -> void:
	var img: Image = ctx.img
	var w: int = ctx.w
	var h: int = ctx.h
	var x0: int = ctx.x0
	var ground: int = ctx.ground
	var wall: Color = ctx.wall
	var roof: Color = ctx.roof
	var s: int = ctx.seed
	var body_h := int(h * 0.62)
	var y_wall := ground - body_h
	var apex := ground - h
	_side(img, x0 + w, y_wall, ground, wall, "stone", s)
	_wall(img, Rect2i(x0, y_wall, w, body_h), wall, "stone", s)
	_gable_roof(ctx, x0 + 2, x0 + w - 2, y_wall - 1, apex, wall, roof, 3)
	# Spikes on the roof corners.
	for sx in [x0 - 1, x0 + w, x0 + w / 2]:
		var sy := y_wall - 2 if sx != x0 + w / 2 else apex
		_poly(img, PackedVector2Array([Vector2(sx, sy), Vector2(sx + 1.5, sy - 7), Vector2(sx + 3, sy)]), Color("#cfc9bb"))
	# A big skull over the door and a red-lit entrance.
	var skull := Color("#e8e2d0")
	var kx := x0 + w / 2 - 5
	var ky := y_wall + 2
	_rect(img, kx + 1, ky, 8, 7, skull)
	_rect(img, kx, ky + 1, 10, 5, skull)
	_rect(img, kx + 2, ky + 2, 2, 2, Color("#1a0808"))
	_rect(img, kx + 6, ky + 2, 2, 2, Color("#1a0808"))
	_px(img, kx + 3, ky + 3, Color("#ff3b30"))
	_px(img, kx + 7, ky + 3, Color("#ff3b30"))
	_rect(img, kx + 2, ky + 7, 6, 2, skull)
	for i in range(3, 8, 2):
		_rect(img, kx + i, ky + 7, 1, 2, Color("#1a0808"))
	_door(ctx, x0 + w / 2 - 5, ground - 12, 10, 12, Color("#2a0f0f"))
	_rect(img, x0 + w / 2 - 4, ground - 11, 8, 10, Color("#5a0f0f"))
	for k in 4:
		_rect(img, x0 + w / 2 - 3 + k * 2, ground - 9 + (k % 2), 1, 6, Color("#ff6a3a"))
	for wx in [x0 + 4, x0 + w - 9]:
		_window(ctx, wx, y_wall + 10, 4, 6, Color("#4a0a0a"))
	_emblem_spot(ctx, x0 + w / 2 - 6, y_wall + 12, 12)
	ctx.info.glow = Color(1.0, 0.25, 0.15)
	_lamp(ctx, x0 + w + 3, ground - 18)
	# Bones by the door.
	_rect(img, x0 - 6, ground - 2, 5, 1, Color("#e8e2d0"))
	_rect(img, x0 - 7, ground - 3, 1, 1, Color("#e8e2d0"))


## Little things next to a building: bushes and flowers on the ground.
static func _props(ctx: Dictionary) -> void:
	var img: Image = ctx.img
	var ground: int = ctx.ground
	var x0: int = ctx.x0
	var w: int = ctx.w
	var s: int = ctx.seed
	for k in 3:
		var bx := x0 - 2 + int(_hash(k, 1, s) * (w + DEPTH))
		var by := ground - 1
		if img.get_pixel(clampi(bx, 0, img.get_width() - 1), clampi(by, 0, img.get_height() - 1)).a > 0.0:
			continue
		var green := Color("#3f8a46") if _hash(k, 2, s) > 0.4 else Color("#4f9a4a")
		_rect(img, bx, by - 2, 4, 3, green)
		_rect(img, bx + 1, by - 3, 2, 1, green.lightened(0.15))
		_px(img, bx + 1, by - 2, [Color("#ff7aa8"), Color("#ffd23f"), Color("#ffffff")][k % 3])
	# Soft ground shadow.
	for i in w + DEPTH:
		var c := img.get_pixel(clampi(x0 + i, 0, img.get_width() - 1), ground)
		if c.a == 0.0:
			_px(img, x0 + i, ground, Color(0, 0, 0, 0.0))


static func _outline(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src := img.duplicate() as Image
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and src.get_pixel(nx, ny).a > 0.0:
					img.set_pixel(x, y, OUTLINE)
					break


static func _silhouette(img: Image, ring_only: bool) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			if not ring_only:
				out.set_pixel(x, y, Color(1, 1, 1, 1))
			elif c.is_equal_approx(OUTLINE):
				out.set_pixel(x, y, Color(1, 1, 1, 1))
	return out


## Flips the places of animated details after the image was mirrored.
static func _mirror(info: Dictionary, width: int) -> void:
	var fixed: Array = []
	for r: Rect2i in info.windows:
		fixed.append(Rect2i(width - r.position.x - r.size.x, r.position.y, r.size.x, r.size.y))
	info.windows = fixed
	for key: String in ["door", "emblem"]:
		var r: Rect2i = info[key]
		info[key] = Rect2i(width - r.position.x - r.size.x, r.position.y, r.size.x, r.size.y)
	for key: String in ["chimney", "flag"]:
		var v: Vector2i = info[key]
		if v.x >= 0:
			info[key] = Vector2i(width - 1 - v.x, v.y)
	var lamps: Array = []
	for v: Vector2i in info.lamps:
		lamps.append(Vector2i(width - 1 - v.x, v.y))
	info.lamps = lamps
	info.flipped = true
