## Mounts for walking around the tavern: bought at the stable, one is ridden.
## Saved in the profile: `mounts` (owned ids) and `mount` (the one in use).
extends RefCounted

const Config := preload("res://scripts/core/config.gd")

var profile: Dictionary
var store: RefCounted
var defs: Array


func _init(p_profile: Dictionary, p_store: RefCounted) -> void:
	profile = p_profile
	store = p_store
	defs = Config.load_json("res://data/mounts.json").mounts


func def(id: String) -> Dictionary:
	for d: Dictionary in defs:
		if d.id == id:
			return d
	return {}


func owned() -> Array:
	if not profile.has("mounts"):
		profile.mounts = []
	return profile.mounts


func has(id: String) -> bool:
	return owned().has(id)


func active() -> String:
	var id := str(profile.get("mount", ""))
	return id if has(id) else ""


## Walk speed multiplier of the ridden mount (1.0 without one).
func speed() -> float:
	var d := def(active())
	return float(d.get("speed", 1.0))


func buy(id: String) -> bool:
	var d := def(id)
	if d.is_empty() or has(id) or int(profile.gold) < int(d.price):
		return false
	profile.gold = int(profile.gold) - int(d.price)
	owned().append(id)
	profile.mount = id
	store.save_to_disk()
	return true


## Rides `id` ("" = on foot).
func ride(id: String) -> bool:
	if id != "" and not has(id):
		return false
	profile.mount = id
	store.save_to_disk()
	return true
