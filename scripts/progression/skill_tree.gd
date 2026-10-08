## Skill tree: permanent, account-wide stat bonuses learned level by level
## with gold. Nodes sit in branches (data/skills.json); a node opens once the
## nodes it needs reach the required level. Each level adds a small amount
## (e.g. +1% damage) and costs more than the last. Levels are kept in
## profile.upgrades (the same ids the old market upgrades used, so saves keep
## everything they bought).
extends RefCounted

const Config := preload("res://scripts/core/config.gd")

## Old one-off market items (before levelled upgrades) and what they cost;
## their gold is given back once.
const LEGACY_PRICES := {"sharp_arrows": 40, "leather_armor": 60, "swift_boots": 80, "quick_string": 100, "eagle_eye": 150}

var branches: Array
## Node id -> node data (branch, row, col, name, icon, stat, per, ...).
var nodes: Dictionary
var profile: Dictionary
var store: RefCounted


func _init(p_profile: Dictionary, p_store: RefCounted) -> void:
	profile = p_profile
	store = p_store
	var cfg := Config.load_json("res://data/skills.json")
	branches = cfg.branches
	nodes = cfg.nodes
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
	return int(nodes[id].maxLevel)


func is_maxed(id: String) -> bool:
	return level(id) >= max_level(id)


## Ids of the nodes in a branch.
func branch_nodes(branch_id: String) -> Array:
	var out: Array = []
	for id: String in nodes:
		if str(nodes[id].branch) == branch_id:
			out.append(id)
	return out


## True when every node this one needs has reached its required level (or
## the node was already learned before it needed anything).
func is_unlocked(id: String) -> bool:
	if level(id) > 0:
		return true
	var req: Dictionary = nodes[id].get("requires", {})
	for need: String in req:
		if level(need) < int(req[need]):
			return false
	return true


## "Güç Sv. 3, Vahşet Sv. 5" for what a locked node still needs.
func requirement_text(id: String) -> String:
	var parts := PackedStringArray()
	var req: Dictionary = nodes[id].get("requires", {})
	for need: String in req:
		if level(need) < int(req[need]):
			parts.append("%s Sv. %d" % [nodes[need].name, int(req[need])])
	return ", ".join(parts)


## Price of the next level.
func price(id: String) -> int:
	var d: Dictionary = nodes[id]
	return roundi(float(d.price) * pow(float(d.priceGrowth), level(id)))


func can_buy(id: String) -> bool:
	return nodes.has(id) and is_unlocked(id) and not is_maxed(id) and int(profile.gold) >= price(id)


## Learns the next level. Returns true if it was learned.
func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	profile.gold = int(profile.gold) - price(id)
	profile.upgrades[id] = level(id) + 1
	store.call("save_to_disk")
	return true


## Levels learned over the whole tree.
func points_spent() -> int:
	var sum := 0
	for id: String in nodes:
		sum += level(id)
	return sum


## Total bonus of every node for a stat (same stat names as gear, e.g. "damage").
func total(stat: String) -> float:
	var sum := 0.0
	for id: String in nodes:
		if str(nodes[id].stat) == stat:
			sum += float(nodes[id].per) * level(id)
	return sum


## "+1% hasar" style text for `levels` levels of a node.
func effect_text(id: String, levels: int) -> String:
	var d: Dictionary = nodes[id]
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
