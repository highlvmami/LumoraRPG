## Gear rules from data/gear.json: rarities, item bases, random stats, chests.
## An item is a plain dictionary saved in the profile:
##   {"uid": 12, "base": "sword", "rarity": 3, "stats": {"damage": 0.2, ...}}
## Higher rarities get a stronger main stat and more (and stronger) extra stats.
## Account skills (the skill tree's Hazine branch) can widen the backpack,
## make chests luckier, lower market prices and raise sell prices.
extends RefCounted

const Config := preload("res://scripts/core/config.gd")

var rarities: Array
var slots: Array
var bases: Array
var affixes: Array
var chests: Array
var drops: Dictionary
var rng := RandomNumberGenerator.new()
## stat -> account bonus (the game sets the skill tree's `total`); unset = none.
var bonus := Callable()
## Market prices can't drop below this share of the list price.
const MIN_PRICE_SHARE := 0.5


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


## Account bonus for a stat (e.g. "stashSize"), 0 without one.
func extra(stat: String) -> float:
	return float(bonus.call(stat)) if bonus.is_valid() else 0.0


## How many items the backpack holds.
func stash_limit() -> int:
	return int(drops.stashLimit) + int(extra("stashSize"))


## A market price after the account's discount.
func discounted(price: int) -> int:
	return roundi(price * maxf(MIN_PRICE_SHARE, 1.0 - extra("shopDiscount")))


func chest_price(index: int) -> int:
	return discounted(int(chest(index).price))


## Rarity weights moved towards the rarer end by `luck` (0.1 = each rarer
## step weighs 10% more than the one before it would).
static func lucky(weights: Array, luck: float) -> Array:
	var out: Array = []
	for i in weights.size():
		out.append(float(weights[i]) * (1.0 + luck * i))
	return out


## A chest's odds per rarity in percent, with the account's chest luck.
func chest_odds(index: int) -> Array:
	var w := lucky(chest(index).odds, extra("chestLuck"))
	var total := 0.0
	for v in w:
		total += float(v)
	return w.map(func(v: float) -> float: return v / total * 100.0)

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
	return roundi(int(rarity(int(item.rarity)).sell) * (1.0 + extra("sellBonus")))


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
	return roll_item(roll_weighted(lucky(chest(chest_index).odds, extra("chestLuck"))), uid)


## "+12% Hasar" style lines for every stat on the item.
func stat_lines(item: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	for stat: String in item.stats:
		lines.append(stat_text(stat, float(item.stats[stat])))
	return lines


func stat_text(stat: String, value: float) -> String:
	return signed_text(stat, value)


## Like stat_text but with a minus sign for negative values ("-4% Hasar"),
## used to compare an item with the one worn.
func signed_text(stat: String, value: float) -> String:
	var prefix := "-" if value < 0.0 else "+"
	var v := absf(value)
	for a: Dictionary in affixes:
		if a.stat == stat:
			match str(a.format):
				"percent":
					return "%s%d%% %s" % [prefix, roundi(v * 100.0), a.label]
				"perSecond":
					return "%s%.1f/sn %s" % [prefix, v, a.label]
				_:
					if v >= 3.0:
						return "%s%d %s" % [prefix, roundi(v), a.label]
					return "%s%.1f %s" % [prefix, v, a.label]
	return "%s%.2f %s" % [prefix, v, stat]


## True when a stat difference is too small to show once rounded.
func is_tiny(stat: String, value: float) -> bool:
	for a: Dictionary in affixes:
		if a.stat == stat:
			match str(a.format):
				"percent":
					return roundi(absf(value) * 100.0) == 0
				"perSecond":
					return absf(value) < 0.05
				_:
					return absf(value) < 0.05
	return absf(value) < 0.005


func stat_label(stat: String) -> String:
	for a: Dictionary in affixes:
		if a.stat == stat:
			return str(a.label)
	return stat


## Stat ids in the order the affix list gives them (for tidy tooltips).
func stat_order() -> Array:
	var out: Array = []
	for a: Dictionary in affixes:
		out.append(str(a.stat))
	return out
