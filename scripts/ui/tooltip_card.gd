## A panel (e.g. an item card) that opens a rich tooltip when hovered.
## `tooltip_builder` returns the tooltip Control; tooltip_text must be set.
extends PanelContainer

var tooltip_builder: Callable


func _make_custom_tooltip(_for_text: String) -> Object:
	if tooltip_builder.is_valid():
		return tooltip_builder.call()
	return null
