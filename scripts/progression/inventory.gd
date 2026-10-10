## The account's characters and its shared backpack (items and chests).
## Every character of the account uses the same backpack; each character
## wears its own items (equipment maps slot -> item uid).
extends RefCounted

const Config := preload("res://scripts/core/config.gd")
const Gear := preload("res://scripts/progression/gear.gd")

var profile: Dictionary
var store: RefCounted
var gear := Gear.new()
var classes: Dictionary


## Dyes and outfits (set by the game; null = none).
var cosmetics: RefCounted


func _init(p_profile: Dictionary, p_store: RefCounted) -> void:
	profile = p_profile
	store = p_store
	classes = Config.load_json("res://data/classes.json")


func save() -> void:
	store.call("save_to_disk")


func _new_uid() -> int:
	var uid := int(profile.nextUid)
	profile.nextUid = uid + 1
	return uid


# --- Characters -------------------------------------------------------------

func characters() -> Array:
	return profile.characters


func max_characters() -> int:
	return int(gear.drops.maxCharacters)


func character(id: int) -> Dictionary:
	for c: Dictionary in characters():
		if int(c.id) == id:
			return c
	return {}


func active_character() -> Dictionary:
	return character(int(profile.activeCharacter))


## Creates a character and makes it active. Returns {} if the name is too short,
## the class is unknown or all character slots are used.
func create_character(char_name: String, class_id: String) -> Dictionary:
	char_name = char_name.strip_edges()
	if char_name.length() < 2 or not classes.has(class_id) or characters().size() >= max_characters():
		return {}
	var c := {"id": _new_uid(), "name": char_name, "class": class_id, "equipment": {}, "bestLevel": 0}
	characters().append(c)
	profile.activeCharacter = c.id
	save()
	return c


## Deletes a character. The items it wore stay in the shared backpack.
## Another character becomes active if it was the active one.
func delete_character(id: int) -> bool:
	var c := character(id)
	if c.is_empty():
		return false
	characters().erase(c)
	if int(profile.activeCharacter) == id:
		profile.activeCharacter = int(characters()[0].id) if not characters().is_empty() else -1
	save()
	return true


func set_active(id: int) -> void:
	if not character(id).is_empty():
		profile.activeCharacter = id
		save()


func class_info(class_id: String) -> Dictionary:
	return classes.get(class_id, classes.archer)


## Look of a character for PlayerModel.build: class colors, plus each worn
## piece of gear drawn in its rarity color (weapons get more detailed by tier).
func character_look(c: Dictionary) -> Dictionary:
	var info := class_info(str(c.get("class", "archer")))
	var look := {"class": str(c.get("class", "archer")), "tunic": info.tunic, "hair": info.hair, "weapon_tier": -1}
	var weapon := equipped(c, "weapon")
	if not weapon.is_empty():
		look.weapon_tier = gear.tier(int(weapon.rarity))
		look.weapon_color = info.color if int(weapon.rarity) == 0 else str(gear.rarity(int(weapon.rarity)).color)
	for slot: String in ["helmet", "armor", "gloves", "boots"]:
		var it := equipped(c, slot)
		if not it.is_empty():
			look[slot + "_color"] = str(gear.rarity(int(it.rarity)).color)
			look[slot + "_tier"] = gear.tier(int(it.rarity))
	if cosmetics:
		cosmetics.apply(c, look)
	return look


# --- Items ------------------------------------------------------------------

func items() -> Array:
	return profile.stash


func item(uid: int) -> Dictionary:
	for it: Dictionary in items():
		if int(it.uid) == uid:
			return it
	return {}


func stash_full() -> bool:
	return items().size() >= gear.stash_limit()


## Adds a new random item of `rarity_index` to the backpack. Returns {} if full.
func add_random_item(rarity_index: int) -> Dictionary:
	if stash_full():
		return {}
	var it := gear.roll_item(rarity_index, _new_uid())
	items().append(it)
	return it


## The character wearing this item, or {}.
func wearer(uid: int) -> Dictionary:
	for c: Dictionary in characters():
		for slot: String in c.equipment:
			if int(c.equipment[slot]) == uid:
				return c
	return {}


func can_wear(c: Dictionary, it: Dictionary) -> bool:
	var cls := gear.item_class(it)
	return not c.is_empty() and not it.is_empty() and (cls == "" or cls == str(c["class"]))


## Puts the item on the character (taking it off whoever wore it before).
func equip(char_id: int, uid: int) -> bool:
	var c := character(char_id)
	var it := item(uid)
	if not can_wear(c, it):
		return false
	var other := wearer(uid)
	if not other.is_empty():
		(other.equipment as Dictionary).erase(gear.item_slot(it))
	c.equipment[gear.item_slot(it)] = uid
	save()
	return true


func unequip(char_id: int, slot_id: String) -> void:
	var c := character(char_id)
	if not c.is_empty():
		(c.equipment as Dictionary).erase(slot_id)
		save()


func equipped(c: Dictionary, slot_id: String) -> Dictionary:
	var worn: Dictionary = c.get("equipment", {})
	if not worn.has(slot_id):
		return {}
	return item(int(worn[slot_id]))


## Sum of one stat over everything the character wears.
func gear_total(c: Dictionary, stat: String) -> float:
	var total := 0.0
	if c.is_empty():
		return total
	for slot: String in c.equipment:
		var it := item(int(c.equipment[slot]))
		if not it.is_empty():
			total += float(it.stats.get(stat, 0.0)) + gear.gem_total(it, stat)
	return total


## Upgrades an item at the blacksmith for gold. Returns false when it is at
## the top, missing or too expensive.
func upgrade(uid: int) -> bool:
	var it := item(uid)
	if it.is_empty():
		return false
	var cost := gear.upgrade_cost(it)
	if cost <= 0 or int(profile.gold) < cost:
		return false
	it.stats = gear.upgraded_stats(it)
	it.plus = gear.plus(it) + 1
	profile.gold = int(profile.gold) - cost
	save()
	return true


## Sells an item (it is taken off first). Returns the gold received.
func sell(uid: int) -> int:
	var it := item(uid)
	if it.is_empty():
		return 0
	var c := wearer(uid)
	if not c.is_empty():
		(c.equipment as Dictionary).erase(gear.item_slot(it))
	items().erase(it)
	var price := gear.sell_price(it)
	profile.gold = int(profile.gold) + price
	save()
	return price


## Takes an item out of the backpack to give it away (a trade). Returns it, or {}.
func take_item(uid: int) -> Dictionary:
	var it := item(uid)
	if it.is_empty():
		return {}
	var c := wearer(uid)
	if not c.is_empty():
		(c.equipment as Dictionary).erase(gear.item_slot(it))
	items().erase(it)
	return it


## Puts an item from someone else (a trade) in the backpack with a new uid.
## Unknown bases, rarities or stats are refused. Returns the stored item or {}.
func receive_item(it: Variant) -> Dictionary:
	if not it is Dictionary or stash_full():
		return {}
	var d: Dictionary = it
	if gear.base(str(d.get("base", ""))).is_empty() or not d.get("stats") is Dictionary:
		return {}
	var stats := {}
	for stat: String in d.stats:
		var v := float(d.stats[stat])
		if is_finite(v):
			stats[stat] = clampf(v, -1000.0, 1000.0)
	var stored := {"uid": _new_uid(), "base": str(d.base), "rarity": clampi(int(d.get("rarity", 0)), 0, gear.rarities.size() - 1), "stats": stats}
	if int(d.get("plus", 0)) > 0:
		stored.plus = gear.plus(d)
	items().append(stored)
	return stored


# --- Chests -----------------------------------------------------------------

func chests() -> Array:
	return profile.chests


func add_chest(tier: int) -> Dictionary:
	var ch := {"uid": _new_uid(), "tier": clampi(tier, 0, gear.chests.size() - 1)}
	chests().append(ch)
	return ch


func chest_by_uid(uid: int) -> Dictionary:
	for ch: Dictionary in chests():
		if int(ch.uid) == uid:
			return ch
	return {}


## Opens a chest: removes it and puts the rolled item in the backpack.
## Returns the item, or {} if the chest is unknown or the backpack is full.
func open_chest(uid: int) -> Dictionary:
	var ch := chest_by_uid(uid)
	if ch.is_empty() or stash_full():
		return {}
	var it := gear.roll_chest_item(int(ch.tier), _new_uid())
	if gear.rng.randf() < 0.25:
		add_gem(random_gem_id())
	chests().erase(ch)
	items().append(it)
	save()
	return it


## Gems in the backpack: id -> count.
func gem_stock() -> Dictionary:
	if not profile.has("gems"):
		profile.gems = {}
	return profile.gems


func gem_count(id: String) -> int:
	return int(gem_stock().get(id, 0))


func add_gem(id: String, amount := 1) -> void:
	gem_stock()[id] = gem_count(id) + amount
	save()


## A random gem (drops from bosses and chests).
func random_gem_id() -> String:
	return str(gear.gems[gear.rng.randi() % gear.gems.size()].id)


func buy_gem(id: String) -> bool:
	if gear.gem(id).is_empty() or int(profile.gold) < gear.gem_price:
		return false
	profile.gold = int(profile.gold) - gear.gem_price
	add_gem(id)
	return true


## Sets a gem from the backpack into socket `index` of an item (an old gem
## there is lost).
func socket_gem(uid: int, index: int, id: String) -> bool:
	var it := item(uid)
	if it.is_empty() or index < 0 or index >= gear.sockets(it) or gem_count(id) <= 0 or gear.gem(id).is_empty():
		return false
	var set_in: Array = gear.item_gems(it)
	set_in[index] = id
	it.gems = set_in
	gem_stock()[id] = gem_count(id) - 1
	save()
	return true


func buy_chest(tier: int) -> bool:
	var price := gear.chest_price(tier)
	if int(profile.gold) < price:
		return false
	profile.gold = int(profile.gold) - price
	add_chest(tier)
	save()
	return true
