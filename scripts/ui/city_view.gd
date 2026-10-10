## The main menu's town: a street of buildings drawn in code. Each building
## has its name on a sign; hovering lifts it and clicking opens its menu.
extends Control

signal building_clicked(id: String)

const UiTheme := preload("res://scripts/ui/theme.gd")
const PixelIcons := preload("res://scripts/ui/pixel_icons.gd")
const SIGN_H := 28.0

## [id, sign text, style, wall color, roof color, emblem icon, row, column slot, tooltip]
const SLOTS := {
	"back": [0.14, 0.38, 0.62, 0.86],
	"front": [0.2, 0.5, 0.8],
}

var _buildings: Array[Control] = []


## `defs`: [{id, name, style, wall, roof, icon, row ("back"/"front"), slot, tip}].
func setup(defs: Array) -> void:
	for child in get_children():
		child.queue_free()
	_buildings.clear()
	for d: Dictionary in defs:
		var b := Building.new()
		b.info = d
		b.clicked.connect(func(id: String) -> void: building_clicked.emit(id))
		add_child(b)
		_buildings.append(b)
	_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	var w := size.x
	var h := size.y
	for b: Control in _buildings:
		var front: bool = str(b.info.row) == "front"
		var centre: float = float((SLOTS[b.info.row] as Array)[int(b.info.slot)]) * w
		var bw := minf(w * (0.23 if front else 0.2), 270.0 if front else 230.0)
		var bh := h * (0.42 if front else 0.36)
		var ground := h * (0.97 if front else 0.52)
		b.size = Vector2(bw, bh)
		b.position = Vector2(centre - bw * 0.5, ground - bh)
		b.base_position = b.position


func _draw() -> void:
	var w := size.x
	var h := size.y
	# Sky.
	var bands := 14
	for i in bands:
		var t := float(i) / bands
		draw_rect(Rect2(0, h * 0.5 * t, w, h * 0.5 / bands + 1.0), Color("#7fb8e8").lerp(Color("#f6e7c8"), t))
	draw_circle(Vector2(w * 0.9, h * 0.12), h * 0.07, Color("#fff4c2"))
	for c: Vector3 in [Vector3(0.12, 0.1, 1.0), Vector3(0.48, 0.06, 0.8), Vector3(0.74, 0.16, 0.9)]:
		var p := Vector2(w * c.x, h * c.y)
		for dx in [-26.0, 0.0, 28.0]:
			draw_circle(p + Vector2(dx * c.z, absf(dx) * -0.12), 20.0 * c.z, Color(1, 1, 1, 0.8))
	# Far hills and the town wall.
	var hills := PackedVector2Array([Vector2(0, h * 0.5)])
	for i in 13:
		hills.append(Vector2(w * i / 12.0, h * (0.36 + 0.06 * sin(i * 1.3) + 0.03 * cos(i * 2.7))))
	hills.append(Vector2(w, h * 0.5))
	draw_colored_polygon(hills, Color("#5a8f63"))
	# Ground: grass behind, a cobbled street in front.
	draw_rect(Rect2(0, h * 0.5, w, h * 0.5), Color("#6fae5a"))
	draw_rect(Rect2(0, h * 0.54, w, h * 0.03), Color("#8a7a5a"))
	draw_rect(Rect2(0, h * 0.545, w, h * 0.012), Color("#a3926d"))
	draw_rect(Rect2(0, h * 0.55, w, h * 0.45), Color("#b3a27e"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 90:
		var p := Vector2(rng.randf() * w, h * 0.57 + rng.randf() * h * 0.42)
		draw_rect(Rect2(p, Vector2(rng.randf_range(10.0, 26.0), 6.0)), Color(0.45, 0.4, 0.3, 0.25))
	# Flower beds and little bushes by the back row.
	for i in 10:
		var p := Vector2(w * (0.04 + i * 0.1), h * 0.53)
		draw_circle(p, 9.0, Color("#3f8a46"))
		draw_circle(p + Vector2(3, -4), 3.0, Color("#ff7aa8") if i % 2 == 0 else Color("#ffd23f"))


## One clickable building.
class Building extends Control:
	signal clicked(id: String)

	var info: Dictionary = {}
	var base_position := Vector2.ZERO
	var _hover := false
	var _sign: Label

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _ready() -> void:
		tooltip_text = str(info.get("tip", ""))
		_sign = UiTheme.label(UiTheme.upper(str(info.name)), UiTheme.label_settings(16, Color("#fff4d6"), 5))
		_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_sign)
		mouse_entered.connect(func() -> void:
			_hover = true
			queue_redraw())
		mouse_exited.connect(func() -> void:
			_hover = false
			queue_redraw())

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED and _sign:
			_sign.position = Vector2(0, 0)
			_sign.size = Vector2(size.x, 26.0)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(str(info.id))
			accept_event()

	func _draw() -> void:
		var wall := Color(str(info.wall))
		var roof := Color(str(info.roof))
		var lift := -6.0 if _hover else 0.0
		var top := SIGN_H + lift
		var w := size.x
		var h := size.y - lift * 0.0
		var body_top := top + (h - top) * 0.34
		var style := str(info.style)
		# Shadow on the ground.
		draw_rect(Rect2(6, h - 5, w - 6, 8), Color(0, 0, 0, 0.18))
		# The sign plank behind the label.
		draw_rect(Rect2(2, lift, w - 4, SIGN_H - 4), Color("#5a3a1c") if not _hover else Color("#7a4f26"))
		draw_rect(Rect2(2, lift, w - 4, 3), Color("#8a5a2b"))
		match style:
			"tower":
				var tw := w * 0.5
				var tx := (w - tw) * 0.5
				draw_rect(Rect2(tx, body_top - 18.0, tw, h - body_top + 18.0), wall)
				draw_colored_polygon(PackedVector2Array([Vector2(tx - 10, body_top - 18.0), Vector2(w * 0.5, top), Vector2(tx + tw + 10, body_top - 18.0)]), roof)
				_windows(Rect2(tx, body_top - 6.0, tw, h * 0.3), 1)
			"gate":
				draw_rect(Rect2(0, body_top - 10.0, w * 0.26, h - body_top + 10.0), wall)
				draw_rect(Rect2(w * 0.74, body_top - 10.0, w * 0.26, h - body_top + 10.0), wall)
				draw_rect(Rect2(0, body_top - 22.0, w * 0.26, 14.0), roof)
				draw_rect(Rect2(w * 0.74, body_top - 22.0, w * 0.26, 14.0), roof)
				draw_rect(Rect2(w * 0.2, body_top + 6.0, w * 0.6, h - body_top - 6.0), wall.darkened(0.15))
				draw_arc(Vector2(w * 0.5, h * 0.78), w * 0.24, PI, TAU, 18, Color("#2a2420"), 6.0)
				draw_rect(Rect2(w * 0.26, h * 0.78, w * 0.48, h * 0.22), Color("#1a1612"))
				for i in 5:
					draw_line(Vector2(w * (0.3 + i * 0.1), h * 0.62), Vector2(w * (0.3 + i * 0.1), h), Color("#6b6560"), 3.0)
			"market":
				draw_rect(Rect2(w * 0.08, body_top + 6.0, w * 0.84, h - body_top - 6.0), wall.darkened(0.2))
				for i in 6:
					draw_rect(Rect2(w * (0.04 + i * 0.15), top + 2.0, w * 0.15, (h - top) * 0.34), roof if i % 2 == 0 else Color("#f4f1e6"))
				draw_rect(Rect2(w * 0.08, h * 0.74, w * 0.84, 10), Color("#8a5a2b"))
				for i in 5:
					draw_circle(Vector2(w * (0.18 + i * 0.16), h * 0.72), 7.0, [Color("#e0484f"), Color("#ffd23f"), Color("#5fcf6a")][i % 3])
			_:
				draw_rect(Rect2(w * 0.06, body_top, w * 0.88, h - body_top), wall)
				draw_rect(Rect2(w * 0.06, h - 8.0, w * 0.88, 8.0), wall.darkened(0.25))
				var eave := 10.0 if style != "hall" else 14.0
				draw_colored_polygon(PackedVector2Array([Vector2(w * 0.06 - eave, body_top + 2.0), Vector2(w * 0.5, top), Vector2(w * 0.94 + eave, body_top + 2.0)]), roof)
				draw_colored_polygon(PackedVector2Array([Vector2(w * 0.06 - eave, body_top + 2.0), Vector2(w * 0.5, top), Vector2(w * 0.5, top + 4.0), Vector2(w * 0.06 - eave + 6.0, body_top + 2.0)]), roof.lightened(0.18))
				if style == "hall":
					# Two banners.
					for bx in [0.12, 0.8]:
						draw_rect(Rect2(w * bx, body_top + 6.0, w * 0.08, h * 0.2), Color("#3a5a9a"))
						draw_colored_polygon(PackedVector2Array([Vector2(w * bx, body_top + 6.0 + h * 0.2), Vector2(w * (bx + 0.04), body_top + 6.0 + h * 0.2 - 8.0), Vector2(w * (bx + 0.08), body_top + 6.0 + h * 0.2)]), Color("#3a5a9a"))
				_windows(Rect2(w * 0.12, body_top + 14.0, w * 0.76, h * 0.2), 2 if style != "hall" else 0)
		# Door.
		var door_w := w * (0.2 if style != "gate" else 0.0)
		if door_w > 0.0:
			draw_rect(Rect2((w - door_w) * 0.5, h - h * 0.2, door_w, h * 0.2), Color("#4a2e18"))
			draw_circle(Vector2((w + door_w) * 0.5 - 5.0, h - h * 0.1), 2.0, Color("#ffd23f"))
		# Emblem on the wall.
		var tex := PixelIcons.texture(str(info.icon), Color("#ffd23f"))
		var es := minf(w * 0.3, 54.0)
		draw_texture_rect(tex, Rect2((w - es) * 0.5, body_top + (h - body_top) * 0.18, es, es), false)
		if _hover:
			draw_rect(Rect2(0, lift, w, h - lift), Color(1, 0.95, 0.6, 0.12))
			draw_rect(Rect2(1, lift, w - 2, h - lift - 1), Color("#ffd23f"), false, 3.0)

	func _windows(area: Rect2, count: int) -> void:
		if count <= 0:
			return
		var ww := area.size.x / (count * 2.0 + 1.0)
		for i in count:
			var x := area.position.x + ww * (1 + i * 2)
			draw_rect(Rect2(x, area.position.y, ww, minf(area.size.y, ww * 1.4)), Color("#fff1a8") if not _hover else Color("#ffe066"))
			draw_rect(Rect2(x, area.position.y, ww, minf(area.size.y, ww * 1.4)), Color("#4a2e18"), false, 2.0)
