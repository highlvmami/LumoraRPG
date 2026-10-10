## Headless smoke test: logs in, uses the main menu, drives the player with
## simulated input and checks movement, enemies, auto-attack, exp/gold/levels,
## level-up choices, weapons, the boss, the pause menu, enemy kinds, loot orbs,
## the cheat menu, saving and the death flow, characters and classes, items,
## equipment, chests and the chest wheel, the skill tree, item comparison
## tooltips and angry / enraged boss phases.
## Run: godot --headless --path . -s res://tests/smoke_test.gd
extends SceneTree

const TEST_SAVE := "user://smoke_test_profiles.json"

var _failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))

	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(10)

	var boot: GDScript = load("res://scripts/boot.gd")
	_check(boot != null and boot.can_instantiate(), "the self-updating start-up script loads")
	_check(str(ProjectSettings.get_setting("application/run/main_scene")) == "res://scenes/boot.tscn", "the game starts through the updater")
	# An updated game pack cannot add autoloads to an exe built before it.
	_check(not FileAccess.get_file_as_string("res://project.godot").contains("[autoload]"), "the project has no autoloads (downloaded updates could not add them)")
	_check(main.get("login_screen") != null, "login screen is shown")
	main.get("store").path = TEST_SAVE
	main.set("forced_map", "forest")

	# Accounts: register, password check, remember on this device.
	var st: RefCounted = main.get("store")
	_check(str(st.call("register", "yeni_oyuncu", "gizliSifre")) == "", "a new account can be registered")
	_check(str(st.call("register", "yeni_oyuncu", "gizliSifre")) != "", "a taken name cannot be registered again")
	_check(str(st.call("check_login", "yeni_oyuncu", "gizliSifre")) == "" and str(st.call("check_login", "yeni_oyuncu", "yanlis")) != "", "the password is checked")
	_check(not JSON.stringify(st.get("_data")).contains("gizliSifre"), "the password is not saved as plain text")
	st.call("set_remember", "yeni_oyuncu")
	_check(str(st.call("remembered")) == "yeni_oyuncu", "the device remembers the account")
	st.call("set_remember", "")
	var screen: CanvasLayer = load("res://scripts/ui/login_screen.gd").new()
	root.add_child(screen)
	screen.call("setup", st)
	screen.call("set_mode", "register")
	_check(str(screen.call("submit_with", "ikinci", "abcd", "abce")) != "", "registering asks for the same password twice")
	screen.call("set_mode", "login")
	_check(str(screen.call("submit_with", "yeni_oyuncu", "yanlis")) != "", "a wrong password does not log in")
	screen.queue_free()
	(st.get("_data").profiles as Dictionary).erase("yeni_oyuncu")
	main.get("login_screen").login("ci_test")
	await _frames(5)

	# Main menu: sections, friends and buying from the market.
	var menu: Node = main.get("main_menu")
	_check(menu != null and bool(menu.get("visible")), "main menu opens after login")
	for section_id: String in ["characters", "create", "equipment", "friends", "backpack", "market", "profile"]:
		menu.call("open_section", section_id)
		await _frames(1)
	_check(bool(menu.call("add_friend", "arkadas1")), "a friend can be added")
	var store_ref: RefCounted = main.get("store")
	(store_ref.get("_data").profiles as Dictionary)["komsu_oyuncu"] = {"name": "komsu_oyuncu", "accountLevel": 3, "friends": ["arkadas1"]}
	var suggested: Array = menu.call("friend_suggestions")
	_check(suggested.size() == 1 and str(suggested[0].name) == "komsu_oyuncu" and int(suggested[0].mutual) == 1, "other players on this device are suggested as friends")
	menu.call("open_section", "friends")
	menu.call("open_section", "achievements")
	await _frames(1)
	var ach: RefCounted = main.get("achievements")
	_check((ach.get("defs") as Array).size() >= 10, "there are many achievements")
	var shop: RefCounted = main.get("skill_tree")
	var profile0: Dictionary = main.get("progression").get("profile")
	profile0.accountLevel = 1
	_check(int(shop.call("points_left")) == 2, "a new account has skill points from its level")
	_check(not bool(menu.call("learn_skill", "power")), "a branch stays closed until the core skill in the middle is learned")
	_check(bool(menu.call("learn_skill", "heart")), "the core skill in the middle can be learned first")
	_check(bool(menu.call("learn_skill", "power")), "learning a skill level with points works")
	_check(int(shop.call("points_left")) == 0 and int(shop.call("level", "power")) == 1, "a point is spent and the skill gains a level")
	_check(is_equal_approx(float(shop.call("total", "damage")), 0.01), "one level gives a small bonus (+1% damage)")
	_check((shop.get("nodes") as Dictionary).size() >= 25 and (shop.get("branches") as Array).size() == 4, "the skill tree has four branches with many skills")
	_check(not bool(menu.call("learn_skill", "power")), "cannot learn without skill points")
	_check(int(shop.call("cost", "fury")) > int(shop.call("cost", "power")), "deeper skills cost more points")
	profile0.accountLevel = 30
	_check(int(shop.call("points_left")) == 58, "every account level gives more skill points")
	_check(not bool(shop.call("is_unlocked", "haste")) and not bool(menu.call("learn_skill", "haste")), "a skill below stays locked until the one above levels up")
	menu.call("learn_skill", "power")
	menu.call("learn_skill", "power")
	_check(bool(shop.call("is_unlocked", "haste")) and bool(menu.call("learn_skill", "haste")), "power level 3 opens the next skills")
	menu.call("open_section", "skills")
	await _frames(2)
	var skill_buttons := menu.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return b.get("tooltip_builder") is Callable and (b.get("tooltip_builder") as Callable).is_valid())
	_check(skill_buttons.size() == (shop.get("nodes") as Dictionary).size(), "the skill tree shows every skill (%d)" % skill_buttons.size())
	if not skill_buttons.is_empty():
		var skill_tip: Object = skill_buttons[0].call("_make_custom_tooltip", "")
		_check(skill_tip is Control, "hovering a skill shows what it gives")
		if skill_tip:
			skill_tip.free()
	var tree_view: Node = menu.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n.has_method("node_center")).front()
	_check(tree_view != null and (tree_view.call("node_center", "heart") as Vector2).distance_to((tree_view as Control).size * 0.5) < 1.0, "the core skill sits in the middle of the tree")
	if tree_view:
		var up: Vector2 = tree_view.call("node_center", "fury")
		var left: Vector2 = tree_view.call("node_center", "egg_whisper")
		var middle: Vector2 = (tree_view as Control).size * 0.5
		_check(up.y < middle.y - 150.0 and up.x < middle.x - 150.0 and left.x < middle.x - 200.0, "the branches grow outwards from the middle")
		_check(tree_view.call("node_color", "power") != tree_view.call("node_color", "vitality"), "each kind of skill has its own color")

	# Account skills (Hazine): backpack, chests, market, selling and eggs.
	var gear_ref: RefCounted = main.get("inventory").get("gear")
	var limit_before := int(gear_ref.call("stash_limit"))
	var odds_before: Array = gear_ref.call("chest_odds", 1)
	var price_before := int(gear_ref.call("chest_price", 1))
	var egg_before := int(main.get("pets").call("egg_price"))
	var egg_odds_before: Array = main.get("pets").call("egg_odds")
	var sample := {"rarity": 3, "base": "ring", "stats": {}}
	var sell_before := int(gear_ref.call("sell_price", sample))
	for pair: Array in [["big_bag", 2], ["bargain", 5], ["chest_luck", 5], ["merchant", 4], ["egg_whisper", 2]]:
		profile0.upgrades[pair[0]] = pair[1]
	_check(int(gear_ref.call("stash_limit")) == limit_before + 10, "Geniş Çanta makes the backpack bigger")
	_check(float((gear_ref.call("chest_odds", 1) as Array)[4]) > float(odds_before[4]) and float((gear_ref.call("chest_odds", 1) as Array)[0]) < float(odds_before[0]), "Kasa Şansı makes rare chest items likelier")
	_check(int(gear_ref.call("chest_price", 1)) < price_before and int(main.get("pets").call("egg_price")) < egg_before, "Pazarlıkçı lowers market prices")
	_check(int(gear_ref.call("sell_price", sample)) > sell_before, "Usta Tüccar raises sell prices")
	_check(float((main.get("pets").call("egg_odds") as Array)[3]) > float(egg_odds_before[3]), "Yumurta Fısıltısı makes rare pets likelier")
	menu.call("open_section", "market")
	await _frames(1)
	for pair: Array in [["big_bag", 2], ["bargain", 5], ["chest_luck", 5], ["merchant", 4], ["egg_whisper", 2]]:
		(profile0.upgrades as Dictionary).erase(pair[0])
	shop.call("reset")
	_check(int(shop.call("points_left")) == 60 and int(shop.call("level", "power")) == 0, "resetting the skill tree gives every point back")
	profile0.accountLevel = 1
	profile0.upgrades.power = 1
	var gold_keep := int(profile0.gold)

	# Pets: eggs from the market, 3 slots opening with the account level.
	var pets: RefCounted = main.get("pets")
	_check(menu.call("hatch_pet").is_empty(), "an egg can't be bought without gold")
	profile0.gold = 100000
	var pet: Dictionary = menu.call("hatch_pet")
	_check(not pet.is_empty() and (pets.call("owned") as Array).size() == 1, "an egg hatches a pet")
	menu.call("close_confirm")
	_check(not bool(menu.call("equip_pet", int(pet.uid))), "pet slots are locked at a low account level")
	profile0.accountLevel = 10
	_check(bool(menu.call("equip_pet", int(pet.uid))) and int(pets.call("slot_of", int(pet.uid))) == 0, "the first pet slot opens at account level 10")
	var phoenix: Dictionary = pets.call("add", "phoenix")
	var bear: Dictionary = pets.call("add", "bear")
	_check(not bool(menu.call("equip_pet", int(phoenix.uid))), "the second slot is still locked")
	profile0.accountLevel = 50
	_check(bool(menu.call("equip_pet", int(phoenix.uid))) and bool(menu.call("equip_pet", int(bear.uid))), "all 3 slots open by account level 50")
	_check(float(main.call("_extra", "attackSpeed")) >= 0.1 and float(main.call("_extra", "defense")) >= 0.04, "pets in slots give their stats")
	_check((pets.call("kind", "phoenix").stats as Dictionary).size() > (pets.call("kind", "bear").stats as Dictionary).size(), "rarer pets give more stats")
	menu.call("open_section", "pets")
	await _frames(2)
	var slot_views := menu.find_children("*", "SubViewportContainer", true, false)
	_check(slot_views.size() >= 3, "the pet page shows the pets in their slots")
	_check(slot_views.all(func(v: Node) -> bool: return not bool(v.get("_spin"))), "pets in slots stand still, turned a little to the side")
	_check((pets.call("kinds") as Array).size() >= 9, "there are many pets (%d)" % (pets.call("kinds") as Array).size())
	var missing: Array = (pets.call("kinds") as Array).filter(func(k: Dictionary) -> bool: return not (pets.call("owned") as Array).any(func(p: Dictionary) -> bool: return str(p.kind) == str(k.id)))
	_check(bool(pets.call("is_discovered", "phoenix")) and not missing.is_empty() and not bool(pets.call("is_discovered", str(missing[0].id))), "the collection knows which pets were found")
	var gray_pictures := menu.find_children("*", "TextureRect", true, false).filter(func(r: TextureRect) -> bool: return r.material is ShaderMaterial)
	_check(gray_pictures.size() == (pets.call("kinds") as Array).size() - int(pets.call("discovered_count")), "pets not found yet are gray in the collection (%d)" % gray_pictures.size())
	var by_rarity: Array = pets.call("kinds_by_rarity")
	_check(int(by_rarity[0].rarity) >= int(by_rarity[-1].rarity) and str(by_rarity[0].id) == "phoenix", "the collection is sorted by rarity")
	var sorted_pets: Array = pets.call("owned_sorted")
	_check(str(sorted_pets[0].kind) == "phoenix", "the account's pets are sorted by rarity")
	var followers: Node = main.get("pet_followers")
	followers.call("set_pets", ["bear", "owl"])
	_check(followers.get_children().all(func(p: Node3D) -> bool: return p.scale.x < 0.5), "pets next to the player are small")
	followers.call("set_pets", [])
	var gold_before_release := int(profile0.gold)
	_check(int(menu.call("release_pet", int(bear.uid))) > 0 and int(profile0.gold) > gold_before_release and int(pets.call("slot_of", int(bear.uid))) < 0, "a pet can be released for gold")
	for id: String in ["first_pet", "legend_friend", "companions", "farewell"]:
		_check(bool(ach.call("is_done", id)), "pet achievement %s unlocks" % id)
	_check(not bool(ach.call("is_done", "full_zoo")), "the full collection achievement waits for every pet kind")
	profile0.accountLevel = 1
	profile0.gold = gold_keep
	var migrated: RefCounted = load("res://scripts/progression/skill_tree.gd").new({"gold": 0, "upgrades": {"brutality": 4, "greed": 2}}, main.get("store"))
	_check(int(migrated.call("level", "brutality")) == 4 and bool(migrated.call("is_unlocked", "brutality")) and is_equal_approx(float(migrated.call("total", "goldGain")), 0.04), "old market upgrades carry over into the skill tree")

	# Leaderboards (offline: the accounts on this device) and friend levels.
	menu.call("open_section", "leaderboard")
	await _frames(1)
	var local: Dictionary = menu.call("local_board", "level")
	_check((local.rows as Array).size() >= 2 and str(local.rows[0].name) == "komsu_oyuncu" and int(local.me.rank) == 2, "the leaderboard ranks accounts by level")
	_check(str(menu.call("board_value", "bestTime", 485.0)) == "8:05" and str(menu.call("board_value", "kills", 12345.0)) == "12.345", "leaderboard numbers are easy to read")
	menu.call("on_leaderboard", "kills", [{"name": "uzak", "value": 900, "level": 40}], {"rank": 7, "value": 12})
	_check((menu.get("_boards") as Dictionary).has("kills"), "leaderboards from the server are kept")
	for entry: Array in menu.get("LEADERBOARDS"):
		menu.call("show_board", str(entry[0]))
	_check(int(menu.call("player_level", "komsu_oyuncu")) == 3, "a friend's account level is known")
	menu.call("add_friend", "komsu_oyuncu")
	menu.call("open_section", "friends")
	await _frames(1)
	var level_tags := menu.find_children("*", "Label", true, false).filter(func(l: Label) -> bool: return l.text == "Sv. 3")
	_check(not level_tags.is_empty() and (level_tags[0] as Label).label_settings.font_color.a < 0.8, "the account level shows small and faint next to the name")

	# The room's tavern: people sit at the table, newcomers walk in.
	var tavern: Control = load("res://scripts/ui/tavern_view.gd").new()
	root.add_child(tavern)
	tavern.call("setup", Vector2(800, 300))
	tavern.call("set_members", [{"id": 1, "name": "ev", "look": {"class": "mage"}, "host": true, "me": true}], false)
	_check((tavern.call("seated") as Array) == [1] and not bool(tavern.call("is_busy")), "people already in the room sit at the table")
	tavern.call("set_members", [{"id": 1, "name": "ev", "host": true}, {"id": 2, "name": "misafir", "look": {"class": "warrior"}}])
	_check(bool(tavern.call("is_busy")), "someone joining walks in through the door")
	for i in 60:
		await create_timer(0.1).timeout
		if not bool(tavern.call("is_busy")):
			break
	var guests: Dictionary = tavern.get("_guests")
	_check(not bool(tavern.call("is_busy")) and bool(guests[2].model.sitting), "the newcomer sits down at a free chair")
	tavern.call("set_members", [{"id": 1, "name": "ev"}, {"id": 2, "name": "misafir"}, {"id": 3, "name": "c"}, {"id": 4, "name": "d"}, {"id": 5, "name": "e"}], false)
	_check((tavern.call("seated") as Array).size() == 4, "the table has 4 chairs")
	tavern.call("set_members", [{"id": 1, "name": "ev"}])
	for i in 80:
		await create_timer(0.1).timeout
		if (guests as Dictionary).size() == 1:
			break
	_check((tavern.call("seated") as Array) == [1] and guests.size() == 1, "people who leave walk out")
	tavern.queue_free()

	# Characters: play asks for one first; up to 3, each with a class.
	var inv: RefCounted = main.get("inventory")
	menu.call("play")
	_check(str(menu.get("section")) == "create" and not bool(main.get("in_run")), "play without a character opens character creation")
	_check(not bool(menu.call("create_character", "x", "warrior")), "a too short name is refused")
	_check(bool(menu.call("create_character", "Kilicci", "warrior")), "a warrior can be created")
	_check(bool(menu.call("create_character", "Buyucu", "mage")), "a mage can be created")
	_check(bool(menu.call("create_character", "Okcu", "archer")), "an archer can be created")
	_check(not bool(menu.call("create_character", "Fazla", "archer")), "at most 3 characters")
	var archer: Dictionary = inv.call("active_character")
	_check(str(archer["class"]) == "archer", "the new character becomes active")
	var warrior: Dictionary = (inv.call("characters") as Array)[0]

	# Items: rarities, stats, equipping (class rules), selling.
	var divine: Dictionary = inv.call("add_random_item", 5)
	_check(int(divine.rarity) == 5 and (divine.stats as Dictionary).size() >= 6, "a divine item has many stats (%d)" % (divine.stats as Dictionary).size())
	var wearable: Dictionary = {}
	var bow_item: Dictionary = {}
	for i in 50:
		if not wearable.is_empty() and not bow_item.is_empty():
			break
		var it: Dictionary = inv.call("add_random_item", i % 6)
		var cls := str(inv.get("gear").call("item_class", it))
		if wearable.is_empty() and cls == "":
			wearable = it
		if bow_item.is_empty() and cls == "archer":
			bow_item = it
	_check(not wearable.is_empty() and not bow_item.is_empty(), "random items of every kind drop")
	_check(not bool(inv.call("can_wear", warrior, bow_item)), "a warrior cannot wear a bow")
	_check(bool(menu.call("equip", int(bow_item.uid))), "the archer can equip a bow")
	_check(int((inv.call("equipped", archer, "weapon") as Dictionary).get("uid", -1)) == int(bow_item.uid), "the bow is in the weapon slot")
	for section_id: String in ["characters", "equipment", "backpack"]:
		menu.call("select_item", int(bow_item.uid))
		menu.call("open_section", section_id)
		await _frames(1)
	menu.call("open_section", "equipment")
	await _frames(2)
	_check(menu.find_children("*", "SubViewportContainer", true, false).size() >= 1, "equipment shows the character in 3D")
	var slots := menu.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return b.get("tooltip_builder") is Callable and (b.get("tooltip_builder") as Callable).is_valid())
	_check(not slots.is_empty(), "equipped items sit in slots")
	if not slots.is_empty():
		var tip: Object = slots[0].call("_make_custom_tooltip", "")
		_check(tip is Control, "hovering a slot shows the item's stats")
		if tip:
			tip.free()
	menu.call("open_section", "backpack")
	await _frames(2)
	var cards := menu.find_children("*", "PanelContainer", true, false).filter(func(n: Node) -> bool: return n.get("tooltip_builder") is Callable)
	_check(not cards.is_empty(), "backpack shows item cards")
	if not cards.is_empty():
		var card_tip: Object = cards[0].call("_make_custom_tooltip", "")
		_check(card_tip is Control, "hovering an item card shows its stats")
		if card_tip:
			card_tip.free()
	var other_bow: Dictionary = {}
	for i in 60:
		var it2: Dictionary = inv.get("gear").call("roll_item", 4, -5)
		if str(it2.base) == "bow":
			other_bow = it2
			break
	if not other_bow.is_empty():
		var cmp: Dictionary = menu.call("compare_info", other_bow)
		_check(int((cmp.get("worn", {}) as Dictionary).get("uid", -1)) == int(bow_item.uid), "an item is compared with the one worn in its slot")
		var cmp_tip: Control = load("res://scripts/ui/item_art.gd").tooltip(inv.get("gear"), other_bow, {}, cmp)
		var arrows := cmp_tip.find_children("*", "Label", true, false).filter(func(l: Label) -> bool: return l.text.begins_with("▲") or l.text.begins_with("▼"))
		_check(not arrows.is_empty(), "the tooltip shows + / - differences to the worn item")
		cmp_tip.free()
	_check((menu.call("compare_info", bow_item) as Dictionary).is_empty(), "the worn item is not compared with itself")
	var look: Dictionary = main.call("character_look", archer)
	_check(int(look.weapon_tier) >= 0, "the equipped weapon changes the character look")
	inv.call("unequip", int(archer.id), "weapon")
	var stash_before := (inv.call("items") as Array).size()
	var gold_before_sell := int(profile0.gold)
	_check(int(menu.call("sell", int(wearable.uid))) > 0 and (inv.call("items") as Array).size() == stash_before - 1, "selling an item removes it")
	_check(int(profile0.gold) > gold_before_sell, "selling gives gold")

	# Backpack: always rarest first, other characters' items last, filters.
	var warrior_item: Dictionary = {}
	for it3: Dictionary in inv.call("items"):
		if bool(inv.call("can_wear", warrior, it3)) and (inv.call("wearer", int(it3.uid)) as Dictionary).is_empty() and int(it3.rarity) == 5:
			warrior_item = it3
			break
	if warrior_item.is_empty():
		warrior_item = inv.call("add_random_item", 5)
		while not bool(inv.call("can_wear", warrior, warrior_item)):
			inv.call("sell", int(warrior_item.uid))
			warrior_item = inv.call("add_random_item", 5)
	inv.call("equip", int(warrior.id), int(warrior_item.uid))
	var listed: Array = menu.call("backpack_items")
	_check(int(listed[-1].uid) == int(warrior_item.uid), "items another character wears go to the end of the backpack")
	var ranks := listed.slice(0, listed.size() - 1).map(func(it4: Dictionary) -> int: return int(it4.rarity))
	var in_order := true
	for k in range(1, ranks.size()):
		in_order = in_order and ranks[k] <= ranks[k - 1]
	_check(in_order, "the backpack is sorted by rarity")
	menu.call("filter_backpack", "ring")
	_check((menu.call("backpack_items") as Array).all(func(it5: Dictionary) -> bool: return str(inv.get("gear").call("item_slot", it5)) == "ring"), "the backpack can show one kind of item")
	menu.call("filter_backpack", "", 5)
	_check((menu.call("backpack_items") as Array).all(func(it6: Dictionary) -> bool: return int(it6.rarity) == 5) and not (menu.call("backpack_items") as Array).is_empty(), "the backpack can show one rarity")
	menu.call("open_section", "backpack")
	await _frames(1)
	menu.call("filter_backpack", "")
	inv.call("unequip", int(warrior.id), str(inv.get("gear").call("item_slot", warrior_item)))

	# Chests: buying and opening with the wheel.
	profile0.gold = int(profile0.gold) + 120
	_check(bool(menu.call("buy_chest", 0)), "a chest can be bought")
	var chest: Dictionary = (inv.call("chests") as Array)[0]
	stash_before = (inv.call("items") as Array).size()
	var prize: Dictionary = main.call("open_chest", int(chest.uid))
	var wheel: Node = main.get("chest_wheel")
	_check(not prize.is_empty() and bool(wheel.get("visible")) and bool(wheel.get("spinning")), "opening a chest spins the wheel")
	await _frames(20)
	wheel.call("finish")
	_check(not bool(wheel.get("spinning")) and (wheel.get("result") as Dictionary) == prize, "the wheel stops on the prize")
	wheel.call("close")
	_check((inv.call("chests") as Array).is_empty() and (inv.call("items") as Array).size() == stash_before + 1, "the prize is in the backpack")
	_check(not bool(wheel.get("visible")), "the wheel closes")

	menu.call("emit_signal", "play_pressed")
	await _frames(60)
	_check(not bool(menu.get("visible")), "play hides the main menu")
	var bow: Node = main.get("bow")
	_check(absf(float(bow.get("damage_multiplier")) - 1.01) < 0.001, "the market upgrade boosts damage (x%.2f)" % float(bow.get("damage_multiplier")))
	_check(absf(float(main.get("range_ring").get("radius")) - 10.0) < 0.001, "range ring matches the attack range")

	var player: CharacterBody3D = main.get("player")
	_check(player != null, "player is spawned")
	if player == null:
		_finish()
		return
	_check(player.is_on_floor(), "player lands on the terrain")
	_check(not InputMap.has_action("slide"), "slide action is removed")

	# Movement (rocks can be ~8 units from spawn, so phases stay near the origin).
	var start := player.global_position
	Input.action_press("move_forward")
	await _frames(35)
	Input.action_release("move_forward")
	var moved := Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
	_check(moved > 3.0, "running moves the player (moved %.2f)" % moved)
	await _frames(30)

	var ground_y := player.global_position.y
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	await _frames(10)
	_check(player.global_position.y > ground_y + 0.8, "jump lifts the player")
	await _frames(90)
	_check(player.is_on_floor(), "player lands after the jump")

	# Enemies spawn, walk in and get shot by the automatic bow.
	var enemies: Node = main.get("enemies")
	var progression: RefCounted = main.get("progression")
	var level_up: Node = main.get("level_up_screen")
	var boosts: RefCounted = main.get("boosts")
	var loot: Node = main.get("loot_orbs")
	var orbs_seen := 0
	for i in 1500:
		await physics_frame
		orbs_seen = maxi(orbs_seen, int(loot.call("count")))
		if bool(level_up.get("visible")):
			level_up.call("pick", 0)
		if int(enemies.get("kills")) >= 3:
			break
	_check(int(enemies.call("count")) + int(enemies.get("kills")) > 0, "enemies spawn")
	var kills := int(enemies.get("kills"))
	_check(kills >= 3, "auto bow kills enemies (%d kills)" % kills)
	var level := int(progression.get("level"))
	var level_exp := int(progression.get("level_exp"))
	_check(level > 1 or level_exp > 0, "kills give character exp (level %d, exp %d)" % [level, level_exp])
	var profile: Dictionary = progression.get("profile")
	_check(int(profile.accountExp) > 0 or int(profile.accountLevel) > 1, "kills give account exp")
	_check(int(profile.gold) > 60, "kills give gold (%d)" % int(profile.gold))
	_check(orbs_seen > 0, "killed enemies drop exp/gold orbs (%d seen)" % orbs_seen)

	# Level-up: the game pauses and offers 3 cards; picking one applies it.
	var weapons: Node = main.get("weapons")
	level_up.call("close")
	boosts.call("reset")
	weapons.call("reset")
	main.call("_apply_stats")
	var crit_before := float(bow.get("crit_chance"))
	progression.call("add_exp", int(progression.call("exp_to_next_level")))
	await _frames(1)
	_check(bool(level_up.get("visible")) and not paused, "level-up shows the choices and the game keeps running")
	var choices: Array = level_up.get("_choices")
	_check(choices.size() == 3, "three cards are offered (%d)" % choices.size())
	_check(choices.any(func(c: Dictionary) -> bool: return c.type == "weapon"), "a weapon card is offered")
	var crit_index := -1
	for c in choices.size():
		if choices[c].id == "crit_chance":
			crit_index = c
	var fallback := 0
	for c in choices.size():
		if choices[c].id != "move_speed":
			fallback = c
			break
	# (never the boost the evolution check below needs to be missing)
	level_up.call("pick", crit_index if crit_index >= 0 else fallback)
	await _frames(1)
	_check(not bool(level_up.get("visible")) and not paused, "picking a card closes the choices")
	var picked_count := (boosts.call("picked") as Array).size() + (weapons.call("owned") as Array).size()
	_check(picked_count == 1, "picked card is recorded")
	if crit_index >= 0:
		_check(float(bow.get("crit_chance")) > crit_before, "crit boost raises crit chance")
	# Weapon evolution: a maxed weapon plus its boost turns into a super weapon.
	var orbit_def: Dictionary = weapons.call("def", "orbit")
	for n in int(orbit_def.maxLevel):
		weapons.call("add", "orbit")
	_check(not (main.call("evolution_choices") as Array).any(func(c: Dictionary) -> bool: return c.id == "blade_storm"), "no evolution without its boost")
	boosts.call("add", "move_speed")
	var evo_cards: Array = (main.call("evolution_choices") as Array).filter(func(c: Dictionary) -> bool: return c.id == "blade_storm")
	_check(evo_cards.size() == 1 and (main.call("roll_level_up_choices") as Array)[0].type in ["evolve", "weapon", "boost"] and (main.call("roll_level_up_choices") as Array).any(func(c: Dictionary) -> bool: return c.type == "evolve"), "a maxed weapon with its boost offers an evolution card")
	var blades_before := int(orbit_def.count)
	main.call("apply_level_up_choice", evo_cards[0])
	var evolved_def: Dictionary = weapons.call("def", "orbit")
	_check(str(evolved_def.name) == "Kılıç Kasırgası" and int(evolved_def.count) == blades_before + 3 and float(evolved_def.damage) > float(orbit_def.damage) and (main.call("evolution_choices") as Array).is_empty(), "evolving makes the weapon stronger with a new name, only once")
	boosts.call("add", "crit_chance")
	boosts.call("add", "crit_chance")
	boosts.call("add", "crit_chance")
	var bow_evo: Array = (main.call("evolution_choices") as Array).filter(func(c: Dictionary) -> bool: return c.id == "eagle_bow")
	if main.call("class_id") == "archer":
		var arrow_damage := float(bow.call("hit_damage"))
		main.call("apply_level_up_choice", bow_evo[0])
		_check(bool(bow.call("is_evolved")) and float(bow.call("hit_damage")) > arrow_damage, "the archer's bow evolves into the eagle bow")
		bow.call("unevolve")
	boosts.call("reset")
	weapons.call("reset")
	main.call("_apply_stats")
	# Dungeon gates: walk in, a mini boss and its minions come out; beat it for gold and a chest.
	var dungeon: Node = main.get("dungeon")
	_check(bool(dungeon.get("active")), "dungeon gates are on in a solo run")
	dungeon.call("open_gate")
	_check(str(dungeon.get("state")) == "gate", "a dungeon gate opens near the player")
	(main.get("player") as Node3D).global_position = dungeon.call("center") + Vector3(0, 0.5, 0)
	for i in 3:
		await physics_frame
	var gate_enemies: Node = main.get("enemies")
	var guardian: int = gate_enemies.call("index_of_uid", int(dungeon.call("guardian_uid")))
	_check(str(dungeon.get("state")) == "fight" and guardian >= 0 and bool((gate_enemies.call("kind_of", guardian) as Dictionary).get("mini", false)), "walking into the gate starts a mini boss fight")
	var chests_before := (main.get("inventory").call("chests") as Array).size()
	var gate_gold := int(main.get("progression").call("gold"))
	gate_enemies.call("damage", guardian, 99999.0)
	_check(str(dungeon.get("state")) == "" and int(dungeon.get("cleared_count")) == 1 and int(main.get("progression").call("gold")) > gate_gold and (main.get("inventory").call("chests") as Array).size() == chests_before + 1, "beating the guardian gives gold and a chest")
	dungeon.call("open_gate")
	dungeon.call("start_fight")
	dungeon.set("time_left", 0.01)
	for i in 3:
		await physics_frame
	_check(str(dungeon.get("state")) == "" and gate_enemies.call("index_of_uid", int(dungeon.call("guardian_uid"))) < 0, "when time runs out the guardian leaves and the ring opens")
	var hud: Node = main.get("hud")
	_check((hud.get("_stat_values") as Array).size() == 9, "character panel shows 9 stats")

	# Pause menu: pauses, changes quality, resumes.
	var pause: Node = main.get("pause_menu")
	pause.call("open")
	await _frames(1)
	_check(bool(pause.get("visible")) and paused, "pause menu opens and pauses the game")
	pause.emit_signal("quality_selected", "low")
	_check(int(main.get("_world_view").get("stretch_shrink")) == 3 and str(profile.get("quality")) == "low", "low quality renders fewer pixels and is saved")
	pause.emit_signal("quality_selected", "medium")
	pause.call("resume")
	await _frames(1)
	_check(not bool(pause.get("visible")) and not paused, "resume closes the pause menu")

	# Every enemy kind can spawn; ranged goblins throw at the player.
	var cheats: Node = main.get("cheat_menu")
	cheats.call("_on_god_toggled", true)  # keep the player alive meanwhile
	var near := player.global_position
	for kind: String in ["wolf", "spider", "thrower"]:
		_check(bool(enemies.call("spawn", kind, near + Vector3(10, 0, 0))), "%s can spawn" % kind)
		_check(int(enemies.call("count_kind", kind)) >= 1, "%s is alive" % kind)
	for i in 300:
		await physics_frame
		if bool(level_up.get("visible")):
			level_up.call("pick", 0)
		if int(enemies.get("shots_fired")) > 0:
			break
	_check(int(enemies.get("shots_fired")) > 0, "goblin throws at the player")
	enemies.set("run_time", 95.0)
	await _frames(2)
	_check((enemies.get("_announced") as Dictionary).size() == (enemies.get("_kinds") as Array).filter(func(k: Dictionary) -> bool: return not k.has("map")).size(), "all enemy kinds unlock as time goes on")
	_check(float(enemies.call("growth", "hpGrowthPerMinute")) > 1.4, "enemies get tougher over time")

	# Every extra weapon damages enemies around the player.
	main.call("cheat", "clear")
	var offered: Array = (weapons.call("available_choices") as Array).map(func(d: Dictionary) -> String: return str(d.id))
	_check(offered.has("arrow_rain") and not offered.has("meteor") and not offered.has("shield_bash"), "only the archer's own class skill is offered")
	_check(not offered.has("fireball") and not offered.has("lightning"), "fireball and lightning are mage-only")
	for id: String in ["orbit", "fireball", "lightning", "aura", "arrow_rain"]:
		weapons.call("add", id)
	_check((weapons.call("owned") as Array).size() == 5, "all extra weapons and the class skill can be carried")
	var dealt: Dictionary = weapons.get("damage_dealt")
	for i in 400:
		if i % 40 == 0:
			for n in 6:
				var a := TAU * n / 6.0
				enemies.call("spawn", "slime", player.global_position + Vector3(cos(a), 0, sin(a)) * 4.0)
		await physics_frame
		if bool(level_up.get("visible")):
			level_up.call("pick", 0)
		if dealt.size() == 5:
			break
	for id: String in ["orbit", "fireball", "lightning", "aura", "arrow_rain"]:
		_check(float(dealt.get(id, 0.0)) > 0.0, "%s deals damage (%.0f)" % [id, float(dealt.get(id, 0.0))])

	# Double arrow: with full chance every shot fires two arrows.
	var fired_before := int(bow.get("arrows_fired"))
	bow.set("double_chance", 1.0)
	for i in 300:
		if i % 40 == 0:
			enemies.call("spawn", "slime", player.global_position + Vector3(5, 0, 0))
		await physics_frame
		if bool(level_up.get("visible")):
			level_up.call("pick", 0)
		if int(bow.get("arrows_fired")) != fired_before:
			break
	for k in 6:
		await physics_frame
	_check(int(bow.get("arrows_fired")) - fired_before == 2, "a double arrow shot fires two arrows (%d)" % (int(bow.get("arrows_fired")) - fired_before))
	bow.set("double_chance", 0.0)

	# Ultimate: R hits every enemy on the map with a big show; it then charges again.
	var ult: Node = main.get("ultimate")
	_check(float(ult.call("ratio")) > 0.0, "the ultimate charges during the run")
	ult.set("cooldown_left", 5.0)
	_check(not bool(ult.call("try_cast", "")), "the ultimate can't be cast while charging")
	ult.set("cooldown_left", 0.0)
	main.call("cheat", "clear")
	var far_uids: Array = []
	for n in 6:
		enemies.call("spawn", "slime", player.global_position + Vector3(25.0 + n * 3.0, 0, 30.0), true)
		far_uids.append(int(enemies.call("uid_of", int(enemies.call("count")) - 1)))
	var kills_before_ult := int(enemies.get("kills"))
	_check(bool(ult.call("try_cast", "meteor")) and float(ult.get("cooldown_left")) > 40.0, "the mage's meteor ultimate can be cast")
	_check(not bool(ult.call("try_cast", "")), "the ultimate can't be cast again right away")
	await _play_for(2.2, level_up)
	_check(int(enemies.get("kills")) - kills_before_ult >= 6, "the ultimate hits enemies anywhere on the map (%d)" % (int(enemies.get("kills")) - kills_before_ult))
	for variant: String in ["storm", "quake", "blades", "arrows", "stars"]:
		ult.set("cooldown_left", 0.0)
		for n in 4:
			enemies.call("spawn", "slime", player.global_position + Vector3(-20.0, 0, 10.0 + n * 3.0), true)
		var before_variant := int(enemies.get("kills"))
		ult.call("try_cast", variant)
		await _play_for(3.6, level_up)
		_check(int(enemies.get("kills")) - before_variant >= 4, "the %s ultimate hits every enemy" % variant)
	_check(main.find_child("Ultimate", true, false).get_child_count() < 400, "ultimate effects clean up after themselves")

	# Boss: spawns with a health bar and announces its defeat.
	var defeated: Array = []
	enemies.connect("boss_defeated", func(boss_name: String) -> void: defeated.append(boss_name))
	if bool(level_up.get("visible")):
		level_up.call("pick", 0)
	for n in 4:
		enemies.call("spawn", "slime", player.global_position + Vector3(6, 0, n))
	main.call("cheat", "boss")
	await _frames(2)
	await process_frame
	await process_frame
	var boss := int(enemies.call("boss_index"))
	_check(boss >= 0, "boss spawns")
	_check(bool(hud.get("_boss_box").get("visible")), "boss health bar is shown")
	await _frames(30)
	_check(int(enemies.call("count")) == 1, "the boss fights alone (other enemies leave, none spawn)")
	var hits_before := int(enemies.get("boss_attack_hits"))
	enemies.call("start_boss_attack", int(enemies.call("boss_index")), "meteor")
	_check(int(enemies.get("attacks").call("active_count")) > 0, "a boss attack first shows red warning zones")
	var meteor_hit := false
	for n in 150:
		await physics_frame
		if bool(level_up.get("visible")):
			level_up.call("pick", 0)
		if int(enemies.get("boss_attack_hits")) > hits_before:
			meteor_hit = true
			break
	_check(meteor_hit, "standing in the warning zone gets you hit")
	for attack: String in ["slam", "charge"]:
		enemies.call("start_boss_attack", int(enemies.call("boss_index")), attack)
		for n in 120:
			await physics_frame
			if bool(level_up.get("visible")):
				level_up.call("pick", 0)
	_check(int(enemies.get("boss_attacks_started")) >= 3, "the forest giant uses different attacks")
	boss = int(enemies.call("boss_index"))
	var tempo_start := float(enemies.call("boss_tempo"))
	_check(tempo_start >= 1.3, "bosses attack faster from the start (tempo %.2f)" % tempo_start)
	var phases: Array = []
	enemies.connect("boss_phase_changed", func(_n: String, ph: int) -> void: phases.append(ph))
	var boss_max := float((enemies.get("_max_hp") as PackedFloat32Array)[boss])
	enemies.call("damage", boss, boss_max * 0.45)
	await _frames(3)
	_check(int(enemies.call("boss_phase")) == 2 and phases == [2] and float(enemies.call("boss_tempo")) > tempo_start, "below 2/3 health the boss gets angry and attacks faster")
	_check(str(hud.get("_boss_name").text).contains("ÖFKELİ"), "the boss bar shows the boss is angry")
	for attack: String in ["quake", "nova"]:
		player.set("hp", float(player.get("max_hp")))
		var zones_before := int(enemies.get("attacks").call("active_count"))
		enemies.call("start_boss_attack", int(enemies.call("boss_index")), attack)
		_check(int(enemies.get("attacks").call("active_count")) > zones_before + 2, "the angry boss uses a new attack: %s" % attack)
		for n in 120:
			await physics_frame
			if bool(level_up.get("visible")):
				level_up.call("pick", 0)
	boss = int(enemies.call("boss_index"))
	# Down to 30% health (the weapons may have hit it meanwhile).
	enemies.call("damage", boss, float((enemies.get("_hp") as PackedFloat32Array)[boss]) - boss_max * 0.3)
	await _frames(3)
	_check(int(enemies.call("boss_phase")) == 3 and int(enemies.call("boss_style")) == 3 and phases == [2, 3], "below 1/3 health the boss is enraged")
	player.set("hp", float(player.get("max_hp")))
	var zones_cross := int(enemies.get("attacks").call("active_count"))
	enemies.call("start_boss_attack", int(enemies.call("boss_index")), "cross")
	_check(int(enemies.get("attacks").call("active_count")) >= zones_cross + 8, "the enraged boss fires a star of 8 beams")
	for n in 120:
		await physics_frame
		if bool(level_up.get("visible")):
			level_up.call("pick", 0)
	player.set("hp", float(player.get("max_hp")))
	boss = int(enemies.call("boss_index"))
	if boss >= 0:
		enemies.call("damage", boss, 1000000.0)
	await _frames(2)
	_check(defeated.size() == 1 and int(enemies.call("boss_index")) < 0, "boss can be defeated")
	_check((inv.call("chests") as Array).size() == 1 + int(main.get("dungeon").get("cleared_count")), "the boss drops a chest")
	main.call("cheat", "spider_boss")
	await _frames(2)
	var queen := int(enemies.call("boss_index"))
	_check(queen >= 0 and str(enemies.call("kind_name", queen)) == "Örümcek Kraliçe", "the spider queen boss spawns")
	if queen >= 0:
		var spot := player.global_position
		enemies.call("start_boss_attack", queen, "leap")
		for n in 140:
			await physics_frame
			if bool(level_up.get("visible")):
				level_up.call("pick", 0)
		queen = int(enemies.call("boss_index"))
		var landed := Vector2(spot.x, spot.z).distance_to(Vector2(enemies.call("position_of", queen).x, enemies.call("position_of", queen).z))
		_check(landed < 5.0, "the spider queen leaps onto the marked spot (%.1f m away)" % landed)
		enemies.call("start_boss_attack", queen, "web")
		for n in 90:
			await physics_frame
			if bool(level_up.get("visible")):
				level_up.call("pick", 0)
		queen = int(enemies.call("boss_index"))
		enemies.call("damage", queen, 1000000.0)
	await _frames(2)
	_check(defeated.size() == 2, "the spider queen can be defeated")
	_check(bool(ach.call("is_done", "giant_slayer")) and bool(ach.call("is_done", "first_blood")), "beating a boss and killing unlock achievements")
	var stash_now := (inv.call("items") as Array).size()
	main.call("_drop_item", 3)
	_check((inv.call("items") as Array).size() == stash_now + 1, "enemy item drops go to the backpack")

	# Developer cheat menu: stat bonuses, god mode, actions.
	var dmg_before := float(bow.get("damage_multiplier"))
	cheats.call("_step", "damage", 1)
	_check(absf(float(bow.get("damage_multiplier")) - dmg_before - 0.25) < 0.001, "cheat raises damage")
	cheats.call("_on_god_toggled", true)
	var hp_before := float(player.get("hp"))
	player.call("take_damage", 50.0)
	_check(float(player.get("hp")) == hp_before, "god mode ignores damage")
	var gold_before := int(profile.gold)
	main.call("cheat", "gold")
	_check(int(profile.gold) == gold_before + 100, "cheat gives gold")
	main.call("cheat", "clear")
	_check(int(enemies.call("count")) == 0, "cheat clears enemies")
	cheats.call("_step", "expGain", 1)
	cheats.call("_step", "goldGain", 1)
	var gold_mid := int(profile.gold)
	main.call("_on_enemy_killed", player.global_position, 0, 5)
	_check(int(profile.gold) == gold_mid + 10, "cheat gold multiplier doubles gold")
	_check(float(main.call("_extra", "expGain")) >= 1.0, "cheat exp multiplier is applied")
	cheats.call("reset_all")
	_check(not bool(player.get("god_mode")) and absf(float(bow.get("damage_multiplier")) - dmg_before) < 0.001, "cheat reset restores stats")

	# Death ends the run and saves the account; restarting resets the character.
	player.call("take_damage", 100000.0)
	await _frames(2)
	_check(bool(player.get("dead")), "player dies at 0 hp")
	_check(not bool(enemies.get("active")), "enemies stop after death")
	_check(FileAccess.file_exists(TEST_SAVE), "profile is saved")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE))
	var saved_runs := 0
	if typeof(saved) == TYPE_DICTIONARY and (saved as Dictionary).profiles.has("ci_test"):
		saved_runs = int(saved.profiles.ci_test.runs)
	_check(saved_runs == 1, "saved profile records the run (runs=%d)" % saved_runs)

	main.call("start_run")
	await _frames(2)
	_check(not bool(player.get("dead")), "restart revives the player")
	_check(int(progression.get("level")) == 1, "restart resets character level")
	_check(int(enemies.get("kills")) == 0, "restart clears enemies")

	_check((boosts.call("picked") as Array).is_empty(), "restart clears boosts")

	# Leaving a run from the pause menu counts the run and opens the main menu.
	pause.call("open")
	await _frames(1)
	pause.emit_signal("menu_requested")
	await _frames(2)
	_check(bool(menu.get("visible")) and not bool(main.get("in_run")) and not paused, "pause menu can go back to the main menu")
	_check(int(profile.runs) == 2, "leaving the run records it (runs=%d)" % int(profile.runs))

	# Warrior and mage start with their own weapon instead of the bow.
	for pair: Array in [[warrior, "slash"], [(inv.call("characters") as Array)[1], "magic"]]:
		menu.call("select_character", int(pair[0].id))
		main.call("start_run")
		await _frames(2)
		cheats.call("_on_god_toggled", true)
		var id: String = pair[1]
		_check(int(weapons.call("level", id)) == 1 and not bool(bow.get("active")), "%s starts with %s" % [str(pair[0]["class"]), id])
		var dealt_by: Dictionary = weapons.get("damage_dealt")
		for i in 300:
			if i % 40 == 0:
				for n in 4:
					var a := TAU * n / 4.0
					enemies.call("spawn", "slime", player.global_position + Vector3(cos(a), 0, sin(a)) * 2.5)
			await physics_frame
			if bool(level_up.get("visible")):
				level_up.call("pick", 0)
			if float(dealt_by.get(id, 0.0)) > 0.0:
				break
		_check(float(dealt_by.get(id, 0.0)) > 0.0, "%s deals damage" % id)
		# Worn gear adds its stats.
		var gear_item: Dictionary = inv.call("add_random_item", 4)
		var c: Dictionary = inv.call("active_character")
		if bool(inv.call("equip", int(c.id), int(gear_item.uid))):
			var stat: String = (gear_item.stats as Dictionary).keys()[0]
			_check(float(main.call("_extra", stat)) >= float(gear_item.stats[stat]) - 0.0001, "worn gear adds %s" % stat)
		cheats.call("reset_all")
		main.call("leave_run")
		await _frames(2)

	# Maps: every map builds, a run shows its name, played maps are counted.
	var terrain_node: Node = main.get("terrain")
	for map_id: String in ["beach", "dungeon", "snow", "forest"]:
		main.call("load_map", map_id)
		await _frames(2)
		_check(str(main.get("map_id")) == map_id and main.get_node("WorldView/WorldViewport/World/Props").get_child_count() > 5, "the %s map builds" % map_id)
		if map_id == "snow":
			var em: Node = main.get("enemies")
			var snowy := {}
			for k: Dictionary in em.get("_kinds"):
				if not k.get("mini", false) and not k.get("boss", false):
					snowy[str(k.id)] = str(k.get("map", "snow")) == "snow" and not (em.get("_replaced") as Dictionary).has(str(k.id))
			_check(snowy.get("snow_slime", false) and not snowy.get("slime", true) and snowy.get("yeti", false) and not snowy.get("spider", true), "the snow map has its own enemies")
			_check(main.get_node("WorldView/WorldViewport/World/Props").find_child("Snowfall", false, false) != null, "snow falls on the snow map")
	main.set("forced_map", "dungeon")
	main.call("start_run")
	await _frames(2)
	_check(str(main.get("map_id")) == "dungeon" and str(hud.get("_title").text) == "ÖLÜMCÜL ZİNDAN", "a run shows the map's name")
	var sound: Node = main.get("sound")
	_check(str(sound.get("current")) == "run", "runs have their own music")
	var track: AudioStreamWAV = sound.call("_make_track", "calm")
	_check(track.loop_mode == AudioStreamWAV.LOOP_FORWARD and track.get_length() > 10.0, "the music is a long loop")
	for sfx: String in ["shoot", "hit", "kill", "coin", "levelup", "boss", "chest", "click", "trade"]:
		_check(bool(sound.call("has_sound", sfx)), "the %s sound is made" % sfx)
	_check(float((profile.stats as Dictionary).get("mapsPlayed", 0)) >= 2, "played maps are counted")
	_check(float((profile.stats as Dictionary).get("damageDealt", 0)) > 0.0, "damage dealt is counted for achievements")
	var rig: Node = main.get("camera_rig")
	var zoom_before := float(rig.get("zoom"))
	rig.call("zoom_by", 2.0)
	_check(float(rig.get("zoom")) > zoom_before, "the mouse wheel moves the camera away")
	rig.call("zoom_by", -100.0)
	_check(is_equal_approx(float(rig.get("zoom")), 3.5), "the camera cannot come closer than the limit")
	main.call("leave_run")
	await _frames(2)
	_check(not (profile.history as Array).is_empty() and str(profile.history[0].map) == "Ölümcül Zindan", "finished runs are logged")
	_check(str(sound.get("current")) == "calm", "the menu plays the calm music")
	main.set("forced_map", "forest")

	# Daily quests and the login reward calendar.
	var daily: RefCounted = main.get("daily")
	daily.set("forced_day", "2030-01-01")
	var day_quests: Array = daily.call("quests")
	_check(day_quests.size() == 3 and day_quests.all(func(q: Dictionary) -> bool: return not bool(q.done)), "three new daily quests a day %s" % str(day_quests.map(func(q: Dictionary) -> String: return str(q.def.id))))
	var quest_gold := int(main.get("progression").call("gold"))
	var first_def: Dictionary = day_quests[0].def
	main.get("achievements").call("add", str(first_def.stat), float(first_def.goal))
	if str(first_def.stat) == "kills":
		main.get("progression").profile.totalKills = int(main.get("progression").profile.get("totalKills", 0)) + int(first_def.goal)
	if str(first_def.stat) == "runs":
		main.get("progression").profile.runs = int(main.get("progression").profile.get("runs", 0)) + int(first_def.goal)
	_check(bool((daily.call("quests") as Array)[0].done), "a quest is done once its counter grew enough")
	_check(not (daily.call("claim", 0) as Dictionary).is_empty() and int(main.get("progression").call("gold")) >= quest_gold + int(first_def.get("gold", 0)) and (daily.call("claim", 0) as Dictionary).is_empty(), "a done quest's reward is taken once")
	_check(int(daily.call("login_index")) == 0 and not (daily.call("claim_login") as Dictionary).is_empty() and not bool(daily.call("login_ready")), "the first login reward is day 1")
	daily.set("forced_day", "2030-01-02")
	_check(bool(daily.call("login_ready")) and int(daily.call("login_index")) == 1, "logging in the next day moves to day 2")
	daily.call("claim_login")
	daily.set("forced_day", "2030-01-05")
	_check(int(daily.call("login_index")) == 0 and (daily.call("quests") as Array).all(func(q: Dictionary) -> bool: return not bool(q.claimed)), "a missed day starts the calendar over and a new day brings new quests")
	menu.call("open_section", "quests")
	await _frames(2)
	daily.set("forced_day", "")

	# Menu pages: logs, versions, settings.
	for section_id: String in ["logs", "versions", "settings"]:
		menu.call("open_section", section_id)
		await _frames(1)
	# The hub tavern: a map to walk around in with things to use.
	var hub: Node = main.get("hub")
	menu.call("close_confirm")
	hub.call("enter")
	for i in 40:
		await physics_frame
	_check(bool(hub.get("active")) and not menu.visible and (main.get("player") as Node3D).visible, "entering the hub tavern shows the character and hides the menu")
	var hub_hall: Node3D = hub.get("tavern")
	var kinds := {}
	for thing: Dictionary in hub_hall.get("interactables"):
		kinds[thing.kind] = int(kinds.get(thing.kind, 0)) + 1
	_check(int(kinds.get("sit", 0)) >= 30 and int(kinds.get("swing", 0)) == 2 and kinds.has("dance") and kinds.has("fire"), "the hub_hall has chairs, swings, a dance floor and a fireplace %s" % str(kinds))
	var ply: CharacterBody3D = main.get("player")
	_check(ply.is_on_floor() and ply.global_position.y < 1.0, "the character stands on the hub_hall floor")
	var things: Array = hub_hall.get("interactables")
	var first_sit := 0
	var swing_index := 0
	var dance_index := 0
	for i in things.size():
		match str(things[i].kind):
			"swing":
				swing_index = i
			"dance":
				dance_index = i
	ply.global_position = hub_hall.call("origin_of", first_sit) + Vector3(0.5, 0.3, 0.5)
	hub.call("interact")
	_check(str(hub.call("action")) == "sit" and ply.seated, "E sits on a chair in reach")
	hub.call("interact")
	_check(str(hub.call("action")) == "" and not ply.seated, "E again gets up")
	hub.call("sit_on", swing_index)
	for i in 150:
		await physics_frame
	var swing_state: Dictionary = (hub_hall.get("_swings") as Array)[int(things[swing_index].swing)]
	_check(float(swing_state.amplitude) > 0.1 and ply.global_position.distance_to(hub_hall.call("origin_of", swing_index)) < 0.3, "a swing swings with the player on it")
	hub.call("interact")
	ply.global_position = (things[dance_index].pos as Vector3) + Vector3(0, 0.3, 0)
	hub.call("interact")
	_check(str(hub.call("action")) == "dance", "E on the dance floor starts dancing")
	hub.call("interact")
	_check(str(hub.call("action")) == "", "and stops it")
	# The door is open and the meadow outside has things to use too.
	var origin: Vector3 = hub_hall.global_position
	var ray := PhysicsRayQueryParameters3D.create(origin + Vector3(0, 1.2, 10.0), origin + Vector3(0, 1.2, 16.0))
	ray.exclude = [ply.get_rid()]
	_check(hub_hall.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "the tavern door is open to walk outside")
	var fires := 0
	for thing: Dictionary in things:
		if str(thing.kind) == "fire":
			fires += 1
	_check(kinds.has("well") and kinds.has("fish") and kinds.has("talk") and fires == 2 and int(kinds.get("sit", 0)) >= 45, "outside: a wishing well, a fishing dock, a campfire with seats; inside: the barkeeper %s" % str(kinds))
	for i in things.size():
		if str(things[i].kind) in ["well", "fish", "talk"] or (str(things[i].kind) == "fire" and int(things[i].get("which", 0)) == 1):
			ply.global_position = (things[i].pos as Vector3) + Vector3(0.3, 0.3, 0.3)
			hub.call("interact")
			if str(hub.call("action")) != "":
				hub.call("interact")
	_check(float((hub_hall.get("outside") as Node).get("_campfire_boost")) > 0.5, "throwing wood on the campfire makes it flare up")
	main.call("leave_hub")
	_check(not bool(hub.get("active")) and menu.visible and not ply.visible, "leaving the tavern shows the menu again")

	# Full screen is kept per device; the menu fits a 1280x720 window.
	var screen_script: GDScript = load("res://scripts/core/screen.gd")
	screen_script.call("set_fullscreen", true)
	_check(bool(screen_script.call("saved")), "turning on full screen is remembered on this device")
	screen_script.call("set_fullscreen", false)
	_check(not bool(screen_script.call("saved")), "turning off full screen is remembered too")
	var nav_buttons: Array = (menu.get("_tab_buttons") as Dictionary).values()
	_check(nav_buttons.all(func(b: Button) -> bool: return b.get_global_rect().end.y <= 720.0), "every menu button fits on a 720 tall screen")
	menu.call("open_section", "skills")
	await _frames(3)
	var fitted_tree: Control = menu.find_children("*", "Control", true, false).filter(func(c: Node) -> bool: return c.has_method("node_center"))[0]
	var page: Control = menu.get("_content").get_parent()
	_check(fitted_tree.get_global_rect().end.y <= page.get_global_rect().end.y + 1.0, "the skill tree shrinks to fit the page")
	menu.call("open_section", "versions")
	await _frames(2)
	var version_heads := menu.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return (b as Button).flat and b.get_parent() is VBoxContainer and b.get_child_count() > 0)
	_check(version_heads.size() >= 3 and bool(menu.call("is_version_open", "0.31")) and not bool(menu.call("is_version_open", "0.30")), "the versions page lists versions with only the newest open")
	if version_heads.size() >= 2:
		(version_heads[1] as Button).pressed.emit()
		await create_timer(0.5).timeout
		_check(bool(menu.call("is_version_open", "0.30")), "clicking a version slides its notes open")
	menu.call("set_setting", "cameraZoom", 11.0)
	menu.call("set_setting", "damageNumbers", false)
	_check(is_equal_approx(float(rig.get("zoom")), 11.0) and not bool(hud.get("show_damage_numbers")), "settings change the camera and the damage numbers")
	_check(bool(menu.call("change_password", "yeniSifre")) and str(store_ref.call("check_login", "ci_test", "yeniSifre")) == "", "the password can be changed")

	# Deleting a character asks first.
	var before_delete := (inv.call("characters") as Array).size()
	menu.call("ask_delete_character", int(warrior.id))
	_check(bool(menu.call("is_confirm_open")) and (inv.call("characters") as Array).size() == before_delete, "deleting a character asks for confirmation first")
	menu.call("close_confirm")
	_check(bool(menu.call("delete_character", int(warrior.id))) and (inv.call("characters") as Array).size() == before_delete - 1, "a character can be deleted")

	# Resetting the account wipes everything but the name.
	menu.call("ask_reset_account")
	_check(bool(menu.call("is_confirm_open")), "resetting the account asks for confirmation")
	menu.call("close_confirm")
	main.call("reset_account")
	_check((inv.call("characters") as Array).is_empty() and (inv.call("items") as Array).is_empty() and int(profile.gold) == 0
		and (profile.upgrades as Dictionary).is_empty() and (profile.achievements as Dictionary).is_empty() and str(profile.name) == "ci_test", "resetting the account wipes characters, items, gold, skills and achievements")

	_finish()


## Lets the run play for a while, taking the first card on level-ups.
func _play_for(seconds: float, level_up: Node) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
		if bool(level_up.get("visible")):
			level_up.call("pick", 0)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(ok: bool, what: String) -> void:
	if ok:
		print("PASS ", what)
	else:
		_failures += 1
		printerr("FAIL ", what)


func _finish() -> void:
	print("%d check(s) failed" % _failures if _failures else "all checks passed")
	quit(1 if _failures else 0)
