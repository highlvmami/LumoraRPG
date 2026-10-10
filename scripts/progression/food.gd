## Fishing and meals (data/food.json). Casting the rod at the tavern's
## fishing dock catches a fish (or some junk that is sold on the spot).
## In the menu a caught fish can be cooked and eaten: the meal gives a
## bonus for the next run only and is used up when that run ends.
## Kept in profile.fish ({fish id: count}) and profile.meal (fish id or "").
extends RefCounted

const Config := preload("res://scripts/core/config.gd")

## A fish was caught: its kind (the data dictionary).
signal caught(kind: Dictionary)

var kinds: Array = []
var cooldown := 3.0
var profile: Dictionary
## Counters for achievements (set by the game).
var achievements: RefCounted
## Gives gold (set by the game).
var pay: Callable
var rng := RandomNumberGenerator.new()

var _ready_at := 0.0


func _init(p_profile: Dictionary, p_achievements: RefCounted = null) -> void:
	profile = p_profile
	achievements = p_achievements
	var data := Config.load_json("res://data/food.json")
	kinds = data.get("fish", [])
	cooldown = float(data.get("cooldown", 3.0))
	rng.randomize()
	if not (profile.get("fish") is Dictionary):
		profile.fish = {}
	if not profile.has("meal"):
		profile.meal = ""


func kind(id: String) -> Dictionary:
	for k: Dictionary in kinds:
		if str(k.id) == id:
			return k
	return {}


## Seconds left before the rod can be cast again.
func wait_left() -> float:
	return maxf(0.0, _ready_at - Time.get_ticks_msec() / 1000.0)


## Casts the rod. Returns the kind caught, or {} when the rod is still
## resting. `pick` forces a kind (tests).
func cast(pick := "") -> Dictionary:
	if wait_left() > 0.0:
		return {}
	_ready_at = Time.get_ticks_msec() / 1000.0 + cooldown
	var k := kind(pick) if pick != "" else _roll()
	if k.is_empty():
		return {}
	if k.has("junkGold"):
		if pay.is_valid():
			pay.call(int(k.junkGold))
	else:
		var fish: Dictionary = profile.fish
		fish[str(k.id)] = int(fish.get(str(k.id), 0)) + 1
		if achievements:
			achievements.call("add", "fishCaught", 1.0)
	caught.emit(k)
	return k


func _roll() -> Dictionary:
	var total := 0
	for k: Dictionary in kinds:
		total += int(k.weight)
	var at := rng.randi() % maxi(total, 1)
	for k: Dictionary in kinds:
		at -= int(k.weight)
		if at < 0:
			return k
	return {}


## Caught fish you can cook: [{kind, count}].
func stock() -> Array:
	var out: Array = []
	for k: Dictionary in kinds:
		var count := int((profile.fish as Dictionary).get(str(k.id), 0))
		if count > 0 and k.has("meal"):
			out.append({"kind": k, "count": count})
	return out


## Cooks and eats one fish: its meal replaces the current one.
func eat(id: String) -> bool:
	var k := kind(id)
	var fish: Dictionary = profile.fish
	if k.is_empty() or not k.has("meal") or int(fish.get(id, 0)) <= 0:
		return false
	fish[id] = int(fish[id]) - 1
	profile.meal = id
	return true


## The meal waiting for the next run (its data), or {}.
func meal() -> Dictionary:
	return kind(str(profile.get("meal", "")))


## Used up when a run ends.
func clear_meal() -> void:
	profile.meal = ""


## The meal's bonus for a stat.
func total(stat: String) -> float:
	var m := meal()
	if m.is_empty():
		return 0.0
	return float((m.meal.stats as Dictionary).get(stat, 0.0))
