## Boosts picked on level-up during one run (they reset when the run ends).
## Each boost adds `amount` to one stat per stack; see data/boosts.json.
extends RefCounted

const Config := preload("res://scripts/core/config.gd")

var defs: Array = []
var choices_per_level := 3
## Boost id -> number of times it was picked this run.
var stacks := {}


func _init() -> void:
	var cfg := Config.load_json("res://data/boosts.json")
	defs = cfg.boosts
	choices_per_level = int(cfg.choicesPerLevel)


func reset() -> void:
	stacks.clear()


func def(id: String) -> Dictionary:
	for d: Dictionary in defs:
		if d.id == id:
			return d
	return {}


func count(id: String) -> int:
	return int(stacks.get(id, 0))


func add(id: String) -> void:
	stacks[id] = count(id) + 1


## Sum of every picked boost that raises `stat`.
func total(stat: String) -> float:
	var sum := 0.0
	for d: Dictionary in defs:
		if d.stat == stat:
			sum += float(d.amount) * count(d.id)
	return sum


## Up to `choices_per_level` random boosts that are not maxed out yet.
func roll_choices() -> Array:
	var open: Array = defs.filter(func(d: Dictionary) -> bool: return count(d.id) < int(d.maxStacks))
	open.shuffle()
	return open.slice(0, choices_per_level)


## Picked boosts in pick-list order, as [def, stacks] pairs.
func picked() -> Array:
	var out: Array = []
	for d: Dictionary in defs:
		if count(d.id) > 0:
			out.append([d, count(d.id)])
	return out
