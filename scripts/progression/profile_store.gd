## Saves account profiles on this device (user://profiles.json).
## In the browser build, user:// is kept in the browser's storage.
## Online accounts (Supabase) replace this later; the data shape stays the same.
extends RefCounted

const SAVE_VERSION := 1

var path := "user://profiles.json"
var _data := {"version": SAVE_VERSION, "last": "", "profiles": {}}


func load_from_disk() -> void:
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) == TYPE_DICTIONARY and (parsed as Dictionary).has("profiles"):
		_data = parsed


func save_to_disk() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not save profiles: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(_data, "\t"))


func last_name() -> String:
	return str(_data.get("last", ""))


## Returns the profile for `name`, creating it on first login.
func login(name: String) -> Dictionary:
	var profiles: Dictionary = _data.profiles
	if not profiles.has(name):
		profiles[name] = {
			"name": name,
			"accountLevel": 1,
			"accountExp": 0,
			"bestLevel": 0,
			"totalKills": 0,
			"runs": 0,
			"createdAt": Time.get_datetime_string_from_system(true),
		}
	_data.last = name
	save_to_disk()
	return profiles[name]
