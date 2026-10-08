## Market and backpack logic: items are bought once with gold, kept in the
## profile's backpack, and every owned item gives its bonus at the start of a run.
extends RefCounted

const Config := preload("res://scripts/core/config.gd")

var items: Dictionary
var profile: Dictionary
var store: RefCounted


func _init(p_profile: Dictionary, p_store: RefCounted) -> void:
	profile = p_profile
	store = p_store
	items = Config.load_json("res://data/items.json")


func owns(id: String) -> bool:
	return (profile.items as Array).has(id)


func price(id: String) -> int:
	return int(items[id].price)


func can_buy(id: String) -> bool:
	return items.has(id) and not owns(id) and int(profile.gold) >= price(id)


## Returns true if the item was bought.
func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	profile.gold = int(profile.gold) - price(id)
	(profile.items as Array).append(id)
	store.call("save_to_disk")
	return true


## Sum of one bonus field over every owned item (e.g. "damageBonus").
func bonus(field: String) -> float:
	var total := 0.0
	for id: String in profile.items:
		if items.has(id):
			total += float(items[id].get(field, 0.0))
	return total
