## Daily quests and the daily login reward (data/quests.json).
## Every day three quests are picked from the pool ("kill 150 monsters",
## "beat a boss"...). Progress is how much a counter (the same ones the
## achievements use) grew since the quests were picked. A finished quest
## gives its gold (and sometimes a chest) when claimed on the Görevler page.
## Logging in on following days builds a streak; the 7-day reward calendar
## starts over after the 7th day or when a day is missed.
## Kept in profile.daily: {day, quests: [{id, base, claimed, told}],
## loginDay, loginStreak}.
extends RefCounted

const Config := preload("res://scripts/core/config.gd")

## A quest just reached its goal (its data dictionary).
signal completed(def: Dictionary)

var pool: Array = []
var login_rewards: Array = []
var per_day := 3
var profile: Dictionary
## The achievements (their value() reads the counters).
var achievements: RefCounted
## Hands out a reward {gold?, chest?} (set by the game).
var grant: Callable
## The date used as "today" (tests set it; empty = the real date).
var forced_day := ""


func _init(p_profile: Dictionary, p_achievements: RefCounted) -> void:
	profile = p_profile
	achievements = p_achievements
	var data := Config.load_json("res://data/quests.json")
	pool = data.get("quests", [])
	login_rewards = data.get("login", [])
	per_day = int(data.get("perDay", 3))
	if not profile.has("daily") or not (profile.daily is Dictionary):
		profile.daily = {}
	refresh()


func today() -> String:
	return forced_day if forced_day != "" else Time.get_date_string_from_system()


## Picks new quests when the day changed.
func refresh() -> void:
	var d: Dictionary = profile.daily
	if str(d.get("day", "")) == today() and d.get("quests") is Array:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(today() + str(profile.get("name", "")))
	var ids: Array = pool.map(func(q: Dictionary) -> String: return str(q.id))
	var picked: Array = []
	while picked.size() < mini(per_day, ids.size()):
		var id: String = ids[rng.randi() % ids.size()]
		if _def(id).is_empty() or picked.any(func(q: Dictionary) -> bool: return str(_def(str(q.id)).stat) == str(_def(id).stat)):
			ids.erase(id)
			continue
		picked.append({"id": id, "base": achievements.call("value", str(_def(id).stat)), "claimed": false, "told": false})
		ids.erase(id)
	d.day = today()
	d.quests = picked


## Today's quests: [{def, progress, goal, done, claimed}].
func quests() -> Array:
	refresh()
	var out: Array = []
	for q: Dictionary in profile.daily.quests:
		var def := _def(str(q.id))
		if def.is_empty():
			continue
		var goal := float(def.goal)
		var now := clampf(float(achievements.call("value", str(def.stat))) - float(q.base), 0.0, goal)
		out.append({"def": def, "progress": now, "goal": goal, "done": now >= goal, "claimed": bool(q.claimed)})
	return out


## Tells (once) about quests that just reached their goal.
func check() -> void:
	var list := quests()
	for i in list.size():
		var q: Dictionary = profile.daily.quests[i]
		if bool(list[i].done) and not bool(q.get("told", false)):
			q.told = true
			completed.emit(list[i].def)


func ready_count() -> int:
	return quests().filter(func(q: Dictionary) -> bool: return bool(q.done) and not bool(q.claimed)).size() + (1 if login_ready() else 0)


## Claims quest number `index`; returns its reward (empty if not ready).
func claim(index: int) -> Dictionary:
	var list := quests()
	if index < 0 or index >= list.size() or not bool(list[index].done) or bool(list[index].claimed):
		return {}
	profile.daily.quests[index].claimed = true
	var def: Dictionary = list[index].def
	var reward := {"gold": int(def.get("gold", 0))}
	if def.has("chest"):
		reward.chest = int(def.chest)
	_give(reward)
	return reward


func login_ready() -> bool:
	return str(profile.daily.get("loginDay", "")) != today()


## Which day of the 7-day calendar the next login reward is (0-6).
func login_index() -> int:
	var streak := int(profile.daily.get("loginStreak", 0))
	if not login_ready():
		return (streak - 1) % login_rewards.size()
	if str(profile.daily.get("loginDay", "")) != _yesterday():
		return 0
	return streak % login_rewards.size()


func claim_login() -> Dictionary:
	if not login_ready() or login_rewards.is_empty():
		return {}
	var index := login_index()
	profile.daily.loginStreak = index + 1
	profile.daily.loginDay = today()
	var reward: Dictionary = (login_rewards[index] as Dictionary).duplicate()
	_give(reward)
	return reward


## "150 altın + Sıradan Kasa".
static func reward_text(reward: Dictionary, chest_names: Array) -> String:
	var parts: Array = []
	if int(reward.get("gold", 0)) > 0:
		parts.append("%d altın" % int(reward.gold))
	if reward.has("chest"):
		parts.append(str(chest_names[clampi(int(reward.chest), 0, chest_names.size() - 1)]))
	return " + ".join(parts)


func _give(reward: Dictionary) -> void:
	if grant.is_valid():
		grant.call(reward)


func _def(id: String) -> Dictionary:
	for q: Dictionary in pool:
		if str(q.id) == id:
			return q
	return {}


func _yesterday() -> String:
	var t := Time.get_unix_time_from_datetime_string(today() + "T12:00:00")
	return Time.get_date_string_from_unix_time(t - 86400)
