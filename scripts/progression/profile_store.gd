## Saves account profiles on this device (user://profiles.json).
## In the browser build, user:// is kept in the browser's storage.
## Accounts have a password (only a salted hash is saved) and the device can
## remember the last account so the game logs straight in next time.
## Online accounts keep the same data on the server: every save of the
## signed-in account is stamped (savedAt) and sent up (`saved`), and a newer
## game from the server replaces this device's copy (adopt).
extends RefCounted

const SAVE_VERSION := 1

## The signed-in account's profile was saved (to send it to the server).
signal saved(profile: Dictionary)

var path := "user://profiles.json"
## The account playing now ("" before login).
var active := ""
var _data := {"version": SAVE_VERSION, "last": "", "profiles": {}}


func load_from_disk() -> void:
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) == TYPE_DICTIONARY and (parsed as Dictionary).has("profiles"):
		_data = parsed


func save_to_disk() -> void:
	var profile: Dictionary = (_data.profiles as Dictionary).get(active, {})
	if not profile.is_empty():
		profile.savedAt = Time.get_unix_time_from_system()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not save profiles: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(_data, "\t"))
	file.close()
	if not profile.is_empty():
		saved.emit(profile)


## Every other account saved on this device (for friend suggestions).
func other_profiles(name: String) -> Array:
	var out: Array = []
	for key: String in _data.profiles:
		if key != name:
			out.append(_data.profiles[key])
	return out


func last_name() -> String:
	return str(_data.get("last", ""))


func has_account(name: String) -> bool:
	return (_data.profiles as Dictionary).has(name)


## Account remembered on this device ("" if none or it no longer exists).
func remembered() -> String:
	var name := str(_data.get("remember", ""))
	return name if has_account(name) else ""


func set_remember(name: String) -> void:
	_data.remember = name
	if name == "":
		_data.erase("tokens")
	save_to_disk()


## Online sign-in token kept for the remembered account ("" if none).
func token_for(name: String) -> String:
	return str((_data.get("tokens", {}) as Dictionary).get(name, ""))


func set_token(name: String, token: String) -> void:
	_data.tokens = {name: token}
	save_to_disk()


## Takes the game saved on the server when it is newer than this device's
## (or the account is new here). The profile dictionary stays the same
## object, so everything holding it sees the new data. Returns true if taken.
func adopt(name: String, cloud: Dictionary, cloud_saved_at: float) -> bool:
	var fresh := not has_account(name)
	var profile := login(name) if fresh else _data.profiles[name] as Dictionary
	if cloud.is_empty() or (not fresh and cloud_saved_at <= float(profile.get("savedAt", 0.0))):
		return false
	var keep := {}
	for key: String in ["salt", "passwordHash"]:
		if profile.has(key):
			keep[key] = profile[key]
	profile.clear()
	profile.merge(cloud.duplicate(true))
	profile.merge(keep, true)
	profile.name = name
	_fill_defaults(profile)
	# Not a new change: keep the server's time so it isn't sent back up.
	profile.savedAt = cloud_saved_at
	_write()
	return true


func _write() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_data, "\t"))


## Creates an account. Returns an error message, or "" on success.
func register(name: String, password: String) -> String:
	name = name.strip_edges()
	if name.length() < 3:
		return "Kullanıcı adı en az 3 karakter olmalı."
	if has_account(name):
		return "Bu kullanıcı adı alınmış."
	if password.length() < 4:
		return "Şifre en az 4 karakter olmalı."
	login(name)
	set_password(name, password)
	return ""


## Checks the password. Old accounts made before passwords get this one.
## Returns an error message, or "" when it is right.
func check_login(name: String, password: String) -> String:
	name = name.strip_edges()
	if not has_account(name):
		return "Böyle bir hesap yok. Kayıt ol sekmesinden açabilirsin."
	var profile: Dictionary = _data.profiles[name]
	if not profile.has("passwordHash"):
		if password.length() < 4:
			return "Şifre en az 4 karakter olmalı."
		set_password(name, password)
		return ""
	if _hash(str(profile.get("salt", "")), password) != str(profile.passwordHash):
		return "Şifre yanlış."
	return ""


func set_password(name: String, password: String) -> void:
	var profile: Dictionary = _data.profiles[name]
	var salt := "%x%x" % [randi(), randi()]
	profile.salt = salt
	profile.passwordHash = _hash(salt, password)
	save_to_disk()


static func _hash(salt: String, password: String) -> String:
	return (salt + ":" + password).sha256_text()


## Wipes an account back to a fresh start (characters, items, gold, levels,
## skills, achievements). Keeps its name, password and settings.
func reset_profile(profile: Dictionary) -> void:
	var keep := {}
	for key: String in ["name", "createdAt", "salt", "passwordHash", "settings", "quality"]:
		if profile.has(key):
			keep[key] = profile[key]
	profile.clear()
	profile.merge(keep)
	_fill_defaults(profile)
	profile.upgrades = {}
	profile.achievements = {}
	profile.stats = {}
	profile.history = []
	save_to_disk()


## Returns the profile for `name`, creating it on first login.
func login(name: String) -> Dictionary:
	var profiles: Dictionary = _data.profiles
	if not profiles.has(name):
		profiles[name] = {
			"name": name,
			"createdAt": Time.get_datetime_string_from_system(true),
		}
	var profile: Dictionary = profiles[name]
	_fill_defaults(profile)
	_data.last = name
	active = name
	save_to_disk()
	return profile


## Adds fields that newer versions of the game expect, so old saves keep working.
static func _fill_defaults(profile: Dictionary) -> void:
	var defaults := {
		"accountLevel": 1,
		"accountExp": 0,
		"bestLevel": 0,
		"totalKills": 0,
		"runs": 0,
		"gold": 0,
		"items": [],
		"friends": [],
		"characters": [],
		"activeCharacter": -1,
		"stash": [],
		"chests": [],
		"nextUid": 1,
		"history": [],
		"settings": {},
		"pets": [],
		"petSlots": [-1, -1, -1],
		"petsSeen": [],
	}
	for key: String in defaults:
		if not profile.has(key):
			profile[key] = defaults[key]
