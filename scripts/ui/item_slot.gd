## A button showing an item that opens a rich tooltip (drawing + all stats)
## when hovered. `tooltip_builder` returns the tooltip Control.
extends Button

var tooltip_builder: Callable


func _make_custom_tooltip(_for_text: String) -> Object:
	if tooltip_builder.is_valid():
		return tooltip_builder.call()
	return null
