## Pets: account-wide companions that give stats while they sit in one of
## the 3 pet slots. Slots open at account levels 10, 25 and 50. Pets hatch
## from eggs bought in the Market (random rarity: common bear, rare
## minotaur, legendary phoenix); rarer pets give more stats and bigger
## values (data/pets.json). Kept in profile.pets [{uid, kind}] and
## profile.petSlots [uid or -1, ...].
extends RefCounted

const Config := preload("res://scripts/core/config.gd")

var cfg: Dictionary
var profile: Dictionary
var store: RefCounted
var _rng := RandomNumberGenerator.new()


func _init(p_profile: Dictionary, p_store: RefCounted) -> void:
	profile = p_profile
	store = p_store
	cfg = Config.load_json("res://data/pets.json")
	_rng.randomize()
	if not profile.has("pets"):
		profile.pets = []
	if not profile.has("petSlots") or (profile.petSlots as Array).size() != slot_count():
		profile.petSlots = [-1, -1, -1]


func slot_count() -> int:
	return (cfg.slotLevels as Array).size()


## Account level a slot opens at.
func slot_level(slot: int) -> int:
	return int(cfg.slotLevels[slot])


func is_slot_open(slot: int) -> bool:
	return int(profile.get("accountLevel", 1)) >= slot_level(slot)


func owned() -> Array:
	return profile.pets


func pet(uid: int) -> Dictionary:
	for p: Dictionary in owned():
		if int(p.uid) == uid:
			return p
	return {}


func kind(id: String) -> Dictionary:
	for k: Dictionary in cfg.kinds:
		if str(k.id) == id:
			return k
	return {}


func kinds() -> Array:
	return cfg.kinds


func rarity(index: int) -> Dictionary:
	return cfg.rarities[clampi(index, 0, (cfg.rarities as Array).size() - 1)]


## Kind data of an owned pet.
func info(p: Dictionary) -> Dictionary:
	return kind(str(p.kind))


## Pet in a slot ({} when empty).
func in_slot(slot: int) -> Dictionary:
	return pet(int(profile.petSlots[slot]))


func slot_of(uid: int) -> int:
	return (profile.petSlots as Array).find(uid)


## Adds a pet of a kind. Returns {} if the kind is unknown or there is no room.
func add(kind_id: String) -> Dictionary:
	if kind(kind_id).is_empty() or owned().size() >= int(cfg.maxPets):
		return {}
	var uid := int(profile.get("nextUid", 1))
	profile.nextUid = uid + 1
	var p := {"uid": uid, "kind": kind_id}
	owned().append(p)
	store.call("save_to_disk")
	return p


func egg_price() -> int:
	return int(cfg.egg.price)


## Buys an egg and hatches it: a random pet by the egg's rarity odds.
## Returns the pet, or {} without enough gold or room.
func hatch() -> Dictionary:
	if int(profile.gold) < egg_price() or owned().size() >= int(cfg.maxPets):
		return {}
	var odds: Array = cfg.egg.odds
	var total := 0.0
	for o in odds:
		total += float(o)
	var roll := _rng.randf() * total
	var r := 0
	for i in odds.size():
		roll -= float(odds[i])
		if roll <= 0.0:
			r = i
			break
	var pool: Array = kinds().filter(func(k: Dictionary) -> bool: return int(k.rarity) == r)
	if pool.is_empty():
		return {}
	profile.gold = int(profile.gold) - egg_price()
	return add(str(pool[_rng.randi() % pool.size()].id))


## Puts a pet in the first open, empty slot (or `slot`). Returns false if
## the pet is unknown, already out or no slot is free.
func equip(uid: int, slot := -1) -> bool:
	if pet(uid).is_empty() or slot_of(uid) >= 0:
		return false
	if slot < 0:
		for s in slot_count():
			if is_slot_open(s) and int(profile.petSlots[s]) < 0:
				slot = s
				break
	if slot < 0 or not is_slot_open(slot):
		return false
	profile.petSlots[slot] = uid
	store.call("save_to_disk")
	return true


func unequip(slot: int) -> void:
	profile.petSlots[slot] = -1
	store.call("save_to_disk")


## Lets a pet go for some gold. Returns the gold given (0 if unknown).
func release(uid: int) -> int:
	var p := pet(uid)
	if p.is_empty():
		return 0
	var s := slot_of(uid)
	if s >= 0:
		profile.petSlots[s] = -1
	owned().erase(p)
	var gold := int(rarity(int(info(p).rarity)).release)
	profile.gold = int(profile.gold) + gold
	store.call("save_to_disk")
	return gold


## Kind ids of the pets in open slots (they follow the player in a run).
func active_kinds() -> Array:
	var out: Array = []
	for s in slot_count():
		var p := in_slot(s)
		if not p.is_empty() and is_slot_open(s):
			out.append(str(p.kind))
	return out


## Total bonus of the pets in open slots for a stat (same names as gear).
func total(stat: String) -> float:
	var sum := 0.0
	for id: String in active_kinds():
		sum += float((kind(id).stats as Dictionary).get(stat, 0.0))
	return sum


## "+4% Savunma" style text.
func stat_text(stat: String, value: float) -> String:
	var d: Dictionary = (cfg.stats as Dictionary).get(stat, {"label": stat, "format": "flat"})
	match str(d.format):
		"percent":
			return "+%d%% %s" % [roundi(value * 100.0), d.label]
		"perSecond":
			return "+%.1f/sn %s" % [value, d.label]
		_:
			return "+%d %s" % [roundi(value), d.label]
