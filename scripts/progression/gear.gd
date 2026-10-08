## Gear rules from data/gear.json: rarities, item bases, random stats, chests.
## An item is a plain dictionary saved in the profile:
##   {"uid": 12, "base": "sword", "rarity": 3, "stats": {"damage": 0.2, ...}}
## Higher rarities get a stronger main stat and more (and stronger) extra stats.
extends RefCounted

const Config := preload("res://scripts/core/config.gd")

var rarities: Array
var slots: Array
var bases: Array
var affixes: Array
var chests: Array
var drops: Dictionary
var rng := RandomNumberGenerator.new()


func _init() -> void:
	var cfg := Config.load_json("res://data/gear.json")
	rarities = cfg.rarities
	slots = cfg.slots
	bases = cfg.bases
	affixes = cfg.affixes
	chests = cfg.chests
	drops = cfg.drops
	rng.randomize()


func base(id: String) -> Dictionary:
	for b: Dictionary in bases:
		if b.id == id:
			return b
	return {}


func rarity(index: int) -> Dictionary:
	return rarities[clampi(index, 0, rarities.size() - 1)]


func rarity_color(index: int) -> Color:
	return Color(str(rarity(index).color))


## Detail tier of an item's picture and model: 0 common/rare, 1 very rare/epic, 2 legendary/divine.
func tier(rarity_index: int) -> int:
	return 0 if rarity_index < 2 else (1 if rarity_index < 4 else 2)


func chest(index: int) -> Dictionary:
	return chests[clampi(index, 0, chests.size() - 1)]


func slot_name(slot_id: String) -> String:
	for s: Dictionary in slots:
		if s.id == slot_id:
			return str(s.name)
	return slot_id


func item_name(item: Dictionary) -> String:
	var names: Array = base(str(item.base)).names
	return str(names[clampi(int(item.rarity), 0, names.size() - 1)])


func item_slot(item: Dictionary) -> String:
	return str(base(str(item.base)).slot)


## Class that can wear the item, or "" if every class can.
func item_class(item: Dictionary) -> String:
	return str(base(str(item.base)).get("class", ""))


func item_icon(item: Dictionary) -> String:
	return str(base(str(item.base)).icon)


func sell_price(item: Dictionary) -> int:
	return int(rarity(int(item.rarity)).sell)


## Picks a rarity index using weights (one per rarity, or per chest tier).
func roll_weighted(weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += float(w)
	var roll := rng.randf() * total
	for i in weights.size():
		roll -= float(weights[i])
		if roll <= 0.0 and float(weights[i]) > 0.0:
			return i
	return weights.size() - 1


## A new random item of the given rarity. `uid` must be unique in the profile.
func roll_item(rarity_index: int, uid: int) -> Dictionary:
	var b: Dictionary = bases[rng.randi() % bases.size()]
	var r := rarity(rarity_index)
	var power := float(r.power)
	var stats := {}
	for stat: String in b.main:
		stats[stat] = float(b.main[stat]) * power
	var pool := affixes.duplicate()
	pool.shuffle()
	for a: Dictionary in pool.slice(0, int(r.affixes)):
		var value := rng.randf_range(float(a.min), float(a.max)) * power
		stats[a.stat] = float(stats.get(a.stat, 0.0)) + value
	return {"uid": uid, "base": b.id, "rarity": rarity_index, "stats": stats}


func roll_chest_item(chest_index: int, uid: int) -> Dictionary:
	return roll_item(roll_weighted(chest(chest_index).odds), uid)


## "+12% Hasar" style lines for every stat on the item.
func stat_lines(item: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	for stat: String in item.stats:
		lines.append(stat_text(stat, float(item.stats[stat])))
	return lines


func stat_text(stat: String, value: float) -> String:
	for a: Dictionary in affixes:
		if a.stat == stat:
			match str(a.format):
				"percent":
					return "+%d%% %s" % [roundi(value * 100.0), a.label]
				"perSecond":
					return "+%.1f/sn %s" % [value, a.label]
				_:
					if value >= 3.0:
						return "+%d %s" % [roundi(value), a.label]
					return "+%.1f %s" % [value, a.label]
	return "+%.2f %s" % [value, stat]
