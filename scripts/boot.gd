## Start-up scene. On desktop it keeps the game up to date by itself: it asks
## the "latest" GitHub release for its build number and, when that is newer
## than what this copy has, downloads the small game pack (code + data, no
## engine) and loads it before opening the game. Offline it uses the newest
## pack it already has. In the browser it just opens the game.
##
## version.txt holds "<build number>|<Godot version>"; CI writes it. A pack is
## only used when it was made with the same Godot version as this program.
extends Node

const RELEASE_URL := "https://github.com/highlvmami/LumoraRPG/releases/download/latest/"
const UPDATE_DIR := "user://update"
const PACK_PATH := "user://update/game.pck"
const PACK_VERSION_PATH := "user://update/version.txt"
const MAIN_SCENE := "res://scenes/main.tscn"

var _label: Label
var _http: HTTPRequest
var _remote := ""


func _ready() -> void:
	if not OS.has_feature("pc") or OS.has_feature("editor"):
		_start()
		return
	var layer := CanvasLayer.new()
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color("#10161d")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	_label = Label.new()
	_label.text = "Güncellemeler denetleniyor..."
	_label.add_theme_font_size_override("font_size", 28)
	_label.set_anchors_preset(Control.PRESET_CENTER)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	layer.add_child(_label)

	_http = HTTPRequest.new()
	_http.timeout = 6.0
	add_child(_http)
	_http.request_completed.connect(_on_version)
	if _http.request(RELEASE_URL + "version.txt") != OK:
		_start()


func _on_version(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_http.request_completed.disconnect(_on_version)
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		_remote = body.get_string_from_utf8().strip_edges()
	if _usable(_remote) and _build(_remote) > maxi(_build(_embedded()), _build(_cached())):
		_label.text = "Yeni sürüm indiriliyor..."
		DirAccess.make_dir_recursive_absolute(UPDATE_DIR)
		_http.timeout = 60.0
		_http.download_file = PACK_PATH + ".part"
		_http.request_completed.connect(_on_pack)
		if _http.request(RELEASE_URL + "game.pck") == OK:
			return
	_start()


func _on_pack(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	var part := PACK_PATH + ".part"
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and FileAccess.file_exists(part):
		DirAccess.remove_absolute(PACK_PATH)
		DirAccess.rename_absolute(part, PACK_PATH)
		var f := FileAccess.open(PACK_VERSION_PATH, FileAccess.WRITE)
		if f:
			f.store_string(_remote)
			f.close()
	_start()


## Loads the downloaded pack when it is newer than the built-in game, then opens the game.
func _start() -> void:
	var cached := _cached()
	if _usable(cached) and _build(cached) > _build(_embedded()) and FileAccess.file_exists(PACK_PATH):
		if not ProjectSettings.load_resource_pack(PACK_PATH):
			push_warning("Downloaded update could not be loaded; using the built-in game.")
	get_tree().change_scene_to_file.call_deferred(MAIN_SCENE)


func _embedded() -> String:
	return _read("res://version.txt")


func _cached() -> String:
	return _read(PACK_VERSION_PATH)


func _read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path).strip_edges()


## True when the version was built with this program's Godot version.
func _usable(version: String) -> bool:
	var parts := version.split("|")
	if parts.size() < 2:
		return false
	var info := Engine.get_version_info()
	return parts[1] == "%d.%d.%d" % [info.major, info.minor, info.patch]


func _build(version: String) -> int:
	return version.split("|")[0].to_int() if version != "" else 0
