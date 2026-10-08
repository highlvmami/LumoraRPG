## Two kinds of level:
## - character level: starts at 1 every run, grows fast, makes you stronger this run;
## - account level: kept forever in the profile, grows slowly from all exp you earn.
extends RefCounted

const Config := preload("res://scripts/core/config.gd")
const ProfileStore := preload("res://scripts/progression/profile_store.gd")

signal exp_gained(amount: int)
signal level_up(level: int)
signal account_level_up(level: int)

var store: ProfileStore
var profile: Dictionary
var level := 1
var level_exp := 0

var _cfg: Dictionary


func _init(p_store: ProfileStore, p_profile: Dictionary) -> void:
	store = p_store
	profile = p_profile
	_cfg = Config.load_json("res://data/progression.json")


func exp_to_next_level() -> int:
	var c: Dictionary = _cfg.character
	return int(c.baseExp) + int(c.expPerLevel) * (level - 1)


func account_level() -> int:
	return int(profile.accountLevel)


func account_exp() -> int:
	return int(profile.accountExp)


func exp_to_next_account_level() -> int:
	var a: Dictionary = _cfg.account
	return int(a.baseExp) + int(a.expPerLevel) * (account_level() - 1)


func damage_multiplier() -> float:
	return 1.0 + float(_cfg.character.damageBonusPerLevel) * (level - 1)


func max_hp_bonus() -> float:
	return float(_cfg.character.maxHpBonusPerLevel) * (level - 1)


func start_run() -> void:
	level = 1
	level_exp = 0


func add_exp(amount: int) -> void:
	level_exp += amount
	while level_exp >= exp_to_next_level():
		level_exp -= exp_to_next_level()
		level += 1
		level_up.emit(level)
		store.save_to_disk()

	profile.accountExp = account_exp() + amount
	while account_exp() >= exp_to_next_account_level():
		profile.accountExp = account_exp() - exp_to_next_account_level()
		profile.accountLevel = account_level() + 1
		account_level_up.emit(account_level())
		store.save_to_disk()
	exp_gained.emit(amount)


## Records the finished run in the profile and saves it.
func end_run(kills: int) -> void:
	profile.runs = int(profile.get("runs", 0)) + 1
	profile.totalKills = int(profile.get("totalKills", 0)) + kills
	profile.bestLevel = maxi(int(profile.get("bestLevel", 0)), level)
	store.save_to_disk()
