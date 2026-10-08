## Achievements: goals like "kill 100 monsters" or "beat a boss", each with a
## gold reward (data/achievements.json). Progress comes from the profile, its
## counters in profile.stats and, during a run, the run's live numbers.
## Unlocked ids are kept in profile.achievements.
extends RefCounted

const Config := preload("res://scripts/core/config.gd")

## An achievement was just completed (its data dictionary).
signal unlocked(def: Dictionary)

var defs: Array = []
var profile: Dictionary
var store: RefCounted
## Numbers of the run in progress: "kills", "level", "time" (empty outside a run).
var live := {}
## Gives the reward gold (set by the game so the HUD updates too).
var reward_gold: Callable


func _init(p_profile: Dictionary, p_store: RefCounted) -> void:
	profile = p_profile
	store = p_store
	defs = Config.load_json("res://data/achievements.json").get("achievements", [])
	if not profile.has("achievements"):
		profile.achievements = {}
	if not profile.has("stats"):
		profile.stats = {}


## Adds to a counter in profile.stats (e.g. "bossKills").
func add(stat: String, amount := 1.0) -> void:
	profile.stats[stat] = float((profile.stats as Dictionary).get(stat, 0.0)) + amount


## Raises a counter in profile.stats to at least `value` (e.g. "bestTime").
func record_best(stat: String, value: float) -> void:
	profile.stats[stat] = maxf(float((profile.stats as Dictionary).get(stat, 0.0)), value)


func value(stat: String) -> float:
	var stats: Dictionary = profile.stats
	match stat:
		"kills":
			return float(profile.get("totalKills", 0)) + float(live.get("kills", 0))
		"runs":
			return float(profile.get("runs", 0))
		"bestLevel":
			return maxf(float(profile.get("bestLevel", 0)), float(live.get("level", 0)))
		"bestTime":
			return maxf(float(stats.get("bestTime", 0.0)), float(live.get("time", 0.0)))
		"accountLevel":
			return float(profile.get("accountLevel", 1))
		"friends":
			return float((profile.get("friends", []) as Array).size())
		"upgrades":
			var sum := 0.0
			for id: String in profile.get("upgrades", {}):
				sum += float(profile.upgrades[id])
			return sum
	return float(stats.get(stat, 0.0))


func is_done(id: String) -> bool:
	return (profile.achievements as Dictionary).has(id)


func done_count() -> int:
	return (profile.achievements as Dictionary).size()


## Completes every achievement whose goal is reached; returns the new ones.
func check() -> Array:
	var fresh: Array = []
	for d: Dictionary in defs:
		if is_done(str(d.id)) or value(str(d.stat)) < float(d.target):
			continue
		profile.achievements[d.id] = true
		if reward_gold.is_valid():
			reward_gold.call(int(d.reward))
		else:
			profile.gold = int(profile.gold) + int(d.reward)
		fresh.append(d)
	if not fresh.is_empty():
		store.call("save_to_disk")
		for d: Dictionary in fresh:
			unlocked.emit(d)
	return fresh
