## Shared UI look. The UI is laid out at 1280x720 and scales with the window,
## so these sizes are in that space.
extends RefCounted

const TEXT := Color("#f4f1e6")
const MUTED := Color("#b8c2cc")
const ACCENT := Color("#ffd866")
const PANEL := Color(0.08, 0.1, 0.13, 0.92)
const BUTTON := Color("#2d3b4a")
const BUTTON_HOVER := Color("#3c5066")
const BUTTON_PRESSED := Color("#22303d")
const PRIMARY := Color("#4f9a3a")
const PRIMARY_HOVER := Color("#62b84a")

static var _theme: Theme


static func label_settings(size: int, color := TEXT, outline := 6) -> LabelSettings:
	var s := LabelSettings.new()
	s.font_size = size
	s.font_color = color
	s.outline_size = outline
	s.outline_color = Color(0, 0, 0, 0.85)
	return s


static func label(text: String, settings: LabelSettings) -> Label:
	var l := Label.new()
	l.text = text
	l.label_settings = settings
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func box(color: Color, radius := 8, padding := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(padding)
	return s


## Theme for buttons, inputs and panels; set it on the root Control of each screen.
static func theme() -> Theme:
	if _theme:
		return _theme
	_theme = Theme.new()
	_theme.default_font_size = 22
	_theme.set_stylebox("normal", "Button", box(BUTTON, 8, 10))
	_theme.set_stylebox("hover", "Button", box(BUTTON_HOVER, 8, 10))
	_theme.set_stylebox("pressed", "Button", box(BUTTON_PRESSED, 8, 10))
	_theme.set_stylebox("disabled", "Button", box(Color(0.2, 0.22, 0.25, 0.8), 8, 10))
	_theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	_theme.set_color("font_color", "Button", TEXT)
	_theme.set_color("font_hover_color", "Button", Color.WHITE)
	_theme.set_stylebox("normal", "LineEdit", box(Color(0, 0, 0, 0.55), 6, 10))
	_theme.set_stylebox("focus", "LineEdit", box(Color(0, 0, 0, 0.7), 6, 10))
	_theme.set_stylebox("panel", "PanelContainer", box(PANEL, 12, 18))
	_theme.set_color("font_color", "Label", TEXT)
	return _theme


## A big green call-to-action button.
static func primary_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_stylebox_override("normal", box(PRIMARY, 10, 14))
	b.add_theme_stylebox_override("hover", box(PRIMARY_HOVER, 10, 14))
	b.add_theme_stylebox_override("pressed", box(PRIMARY.darkened(0.2), 10, 14))
	b.add_theme_font_size_override("font_size", 34)
	return b
