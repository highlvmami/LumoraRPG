## Looks only: dyes for the tunic and hair, and outfits (tunic colors, cape,
## crown). They give no power. Owned ids live in profile.cosmetics (account),
## what a character wears in its own dictionary (outfit, dyeTunic, dyeHair).
extends RefCounted

const Config := preload("res://scripts/core/config.gd")

var profile: Dictionary
var store: RefCounted
var tunic_dyes: Array
var hair_dyes: Array
var outfits: Array


func _init(p_profile: Dictionary, p_store: RefCounted) -> void:
	profile = p_profile
	store = p_store
	var cfg := Config.load_json("res://data/cosmetics.json")
	tunic_dyes = cfg.tunicDyes
	hair_dyes = cfg.hairDyes
	outfits = cfg.outfits


func entry(id: String) -> Dictionary:
	for list: Array in [tunic_dyes, hair_dyes, outfits]:
		for d: Dictionary in list:
			if d.id == id:
				return d
	return {}


func owned() -> Array:
	if not profile.has("cosmetics"):
		profile.cosmetics = []
	return profile.cosmetics


func has(id: String) -> bool:
	return owned().has(id)


func buy(id: String) -> bool:
	var d := entry(id)
	if d.is_empty() or has(id) or int(profile.gold) < int(d.price):
		return false
	profile.gold = int(profile.gold) - int(d.price)
	owned().append(id)
	store.save_to_disk()
	return true


## Makes a character wear an owned entry ("" in `kind` slot = take it off).
## `kind` is "outfit", "dyeTunic" or "dyeHair".
func wear(c: Dictionary, kind: String, id: String) -> bool:
	if c.is_empty() or not ["outfit", "dyeTunic", "dyeHair"].has(kind) or (id != "" and not has(id)):
		return false
	c[kind] = id
	store.save_to_disk()
	return true


## Changes a character's look dictionary (see PlayerModel.build) for what it wears.
func apply(c: Dictionary, look: Dictionary) -> void:
	var outfit := entry(str(c.get("outfit", "")))
	if not outfit.is_empty() and has(str(outfit.id)):
		look.tunic = outfit.tunic
		if str(outfit.hair) != "":
			look.hair = outfit.hair
		look.cape = outfit.cape
		look.crown = bool(outfit.crown)
	var tunic := entry(str(c.get("dyeTunic", "")))
	if not tunic.is_empty() and has(str(tunic.id)):
		look.tunic = tunic.color
	var hair := entry(str(c.get("dyeHair", "")))
	if not hair.is_empty() and has(str(hair.id)):
		look.hair = hair.color
