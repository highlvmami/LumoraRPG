## Market upgrades: permanent, account-wide stat bonuses bought level by level
## with gold. Each level adds a small amount (e.g. +1% damage) and costs more
## than the last (data/items.json). Levels are kept in profile.upgrades.
extends RefCounted

const Config := preload("res://scripts/core/config.gd")

## Old one-off market items (before levelled upgrades) and what they cost;
## their gold is given back once.
const LEGACY_PRICES := {"sharp_arrows": 40, "leather_armor": 60, "swift_boots": 80, "quick_string": 100, "eagle_eye": 150}

var items: Dictionary
var profile: Dictionary
var store: RefCounted


func _init(p_profile: Dictionary, p_store: RefCounted) -> void:
	profile = p_profile
	store = p_store
	items = Config.load_json("res://data/items.json")
	if not profile.has("upgrades"):
		profile.upgrades = {}
	var old: Array = profile.get("items", [])
	if not old.is_empty():
		for id: String in old:
			profile.gold = int(profile.gold) + int(LEGACY_PRICES.get(id, 0))
		profile.items = []
		store.call("save_to_disk")


func level(id: String) -> int:
	return int((profile.upgrades as Dictionary).get(id, 0))


func max_level(id: String) -> int:
	return int(items[id].maxLevel)


func is_maxed(id: String) -> bool:
	return level(id) >= max_level(id)


## Price of the next level.
func price(id: String) -> int:
	var d: Dictionary = items[id]
	return roundi(float(d.price) * pow(float(d.priceGrowth), level(id)))


func can_buy(id: String) -> bool:
	return items.has(id) and not is_maxed(id) and int(profile.gold) >= price(id)


## Buys the next level. Returns true if it was bought.
func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	profile.gold = int(profile.gold) - price(id)
	profile.upgrades[id] = level(id) + 1
	store.call("save_to_disk")
	return true


## Total bonus of every upgrade for a stat (same stat names as gear, e.g. "damage").
func total(stat: String) -> float:
	var sum := 0.0
	for id: String in items:
		if str(items[id].stat) == stat:
			sum += float(items[id].per) * level(id)
	return sum


## "+1% hasar" style text for `levels` levels of an upgrade.
func effect_text(id: String, levels: int) -> String:
	var d: Dictionary = items[id]
	var v := float(d.per) * levels
	match str(d.format):
		"percent":
			return "+%%%s %s" % [_number(v * 100.0), d.label]
		"perSecond":
			return "+%s/sn %s" % [_number(v), d.label]
		_:
			return "+%s %s" % [_number(v), d.label]


static func _number(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(roundi(v))
	return "%.2f" % v if absf(v * 10.0 - roundf(v * 10.0)) > 0.001 else "%.1f" % v
