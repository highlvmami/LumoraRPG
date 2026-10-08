## Full screen on or off (F11, the settings page or the menu button).
## The choice is kept per device in user://display.cfg and comes back on
## the next start on desktop; a browser only allows it after a click.
extends RefCounted

const PATH := "user://display.cfg"


static func is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


static func set_fullscreen(on: bool) -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("display", "fullscreen", on)
	cfg.save(PATH)


static func toggle() -> void:
	set_fullscreen(not is_fullscreen())


## The last choice on this device (false if never set).
static func saved() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return false
	return bool(cfg.get_value("display", "fullscreen", false))


## Opens in full screen at start if the player left it that way (desktop only).
static func restore() -> void:
	if saved() and not OS.has_feature("web") and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
