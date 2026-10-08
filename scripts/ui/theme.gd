## Shared text styles for the pixel UI (the whole UI is drawn at 480x270).
extends RefCounted


static func label_settings(size: int, color := Color("#f0f0e0"), outline := 3) -> LabelSettings:
	var s := LabelSettings.new()
	s.font_size = size
	s.font_color = color
	s.outline_size = outline
	s.outline_color = Color.BLACK
	return s


static func label(text: String, settings: LabelSettings) -> Label:
	var l := Label.new()
	l.text = text
	l.label_settings = settings
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
