## Online test with the real server (server/index.js, needs node): two
## games in one process open online accounts (one through the login screen),
## one opens a room and invites the other, the host starts a run and both
## play it together; the game is saved on the server and comes back on
## another device.
## Run: godot --headless --path . -s res://tests/coop_test.gd
extends SceneTree

const PORT := 18090

var _failures := 0
var _server_pid := -1


func _initialize() -> void:
	_run()


func _run() -> void:
	OS.set_environment("PORT", str(PORT))
	_server_pid = OS.create_process("node", [ProjectSettings.globalize_path("res://server/index.js")])
	_check(_server_pid > 0, "the online server starts")
	await create_timer(1.5).timeout

	var host := await _game("coop_host", "EvSahibi")
	_check(await _until(func() -> bool: return host.net.is_online()), "an online account can be opened")

	# The second player signs up on the login screen.
	var guest := await _game("coop_guest", "")
	var screen: Node = guest.login_screen
	screen.set_mode("register")
	_check(await _until(func() -> bool: return guest.net.is_connected_to_server()), "the login screen connects to the server")
	_check(screen.submit_with("evsahibi", "sifre12", "sifre12") == "pending", "the login screen asks the server")
	_check(await _until(func() -> bool: return not screen.waiting) and screen.get("_error").text.contains("alınmış"),
		"a name taken online can't be registered again (any letter case)")
	screen.submit_with("Misafir", "sifre12", "sifre12")
	_check(await _until(func() -> bool: return guest.progression != null and guest.net.is_online()), "signing up on the login screen opens the game online")
	guest.inventory.create_character("Misafir", "archer")

	# Friends see each other online.
	host.net.ask_online_list()
	_check(await _until(func() -> bool: return Array(host.net.online_list).has("Misafir")), "online players are listed")
	host.progression.profile.friends.append("Misafir")
	host.net.ask_who(["Misafir", "kimse"])
	_check(await _until(func() -> bool: return host.net.is_name_online("Misafir") and not host.net.is_name_online("kimse")), "a friend shows as online")

	# Inviting opens a room and the friend gets the invite.
	host.main_menu.invite_friend("Misafir")
	_check(await _until(func() -> bool: return host.net.in_room() and guest.net.invites.size() == 1), "inviting opens a room and the friend gets the invite")
	_check(guest.main_menu.is_confirm_open(), "the invite asks the friend to join")
	guest.net.join_room(str(guest.net.invites[0].code))
	_check(await _until(func() -> bool: return host.net.members().size() == 2 and guest.net.in_room()), "the friend joins the room")
	_check(host.net.is_host() and not guest.net.is_host(), "the one who opened the room is the host")
	guest.main_menu.close_confirm()

	# The room is a tavern: both characters sit at the table.
	guest.main_menu.refresh()
	host.main_menu.open_section("friends")
	_check(await _until(func() -> bool: return host.main_menu.get("_tavern") != null and (host.main_menu.get("_tavern").seated() as Array).size() == 2),
		"the room shows as a tavern with both players at the table")
	_check(await _until(func() -> bool: return not (host.net.members()[1].get("look", {}) as Dictionary).is_empty()), "the friend's character look reaches the room")

	# Levels and leaderboards come from the saved games on the server (sent up a moment after a change).
	await create_timer(2.5).timeout
	host.main_menu.open_section("leaderboard")
	_check(await _until(func() -> bool:
		var board: Dictionary = (host.main_menu.get("_boards") as Dictionary).get("level", {})
		var names: Array = (board.get("rows", []) as Array).map(func(r: Dictionary) -> String: return str(r.name))
		return names.has("Misafir") and names.has("EvSahibi") and not (board.get("me", {}) as Dictionary).is_empty()), "the online leaderboard lists the players")
	host.net.ask_who(["Misafir"])
	_check(await _until(func() -> bool: return host.net.level_of("Misafir") >= 1), "a friend's account level comes from the server")

	# The hub tavern is a map: both walk in, see each other, sit, swing and chat.
	host.enter_hub()
	guest.enter_hub()
	_check(host.hub.active and guest.hub.active, "both walk into the hub tavern")
	_check(await _until(func() -> bool: return host.hub.guest_count() == 1 and guest.hub.guest_count() == 1), "they see each other in the tavern")
	var guest_id: int = guest.net.my_id
	var host_id: int = host.net.my_id
	var chair := 0
	for i in guest.hub.tavern.interactables.size():
		if str(guest.hub.tavern.interactables[i].kind) == "sit":
			chair = i
			break
	guest.hub.sit_on(chair)
	_check(await _until(func() -> bool: return host.hub.guest(guest_id).is_seated() and int(host.hub.guest(guest_id).object) == chair),
		"the other player sees them sit on the chair")
	guest.hub.interact()
	_check(await _until(func() -> bool: return not host.hub.guest(guest_id).is_seated()), "getting up shows for the other player too")
	var swing := 0
	for i in guest.hub.tavern.interactables.size():
		if str(guest.hub.tavern.interactables[i].kind) == "swing":
			swing = i
			break
	guest.hub.sit_on(swing)
	_check(await _until(func() -> bool: return str(host.hub.guest(guest_id).action) == "swing"), "the other player sees them on the swing")
	_check(await _until(func() -> bool: return float(host.hub.tavern._swings[int(host.hub.tavern.interactables[swing].swing)].amplitude) > 0.05),
		"the swing swings for the other player too")
	guest.hub.interact()
	guest.net.send_chat("Selam millet!")
	_check(await _until(func() -> bool: return str(host.hub.guest(guest_id).bubble_text()) == "Selam millet!"), "what they say shows over their head")
	_check(host.hub.overlay._log.get_parsed_text().contains("Selam millet!"), "and in the chat log")
	# Guilds: the host founds one, the friend joins; the tag shows in the tavern and the guild chat works.
	host.net.create_guild("Gece Kurtları", "GK")
	_check(await _until(func() -> bool: return host.net.in_guild() and host.net.is_guild_leader()), "a guild can be founded")
	guest.net.join_guild("Gece Kurtları")
	_check(await _until(func() -> bool: return guest.net.in_guild() and (host.net.guild.members as Array).size() == 2), "a friend joins the guild")
	_check(await _until(func() -> bool: return str(host.hub.guest(guest_id).player_name).begins_with("[GK]")), "guild tags show over heads in the tavern")
	guest.net.send_guild_chat("Lonca toplantısı!")
	_check(await _until(func() -> bool: return (host.net.guild.chat as Array).any(func(l: Dictionary) -> bool: return str(l.text) == "Lonca toplantısı!")), "guild chat reaches the members")
	host.main_menu.open_section("guild")
	_check(host._extra("goldGain") >= 0.05, "guild members earn a little more gold")
	guest.net.leave_guild()
	_check(await _until(func() -> bool: return not guest.net.in_guild() and (host.net.guild.members as Array).size() == 1), "leaving the guild")

	# Duel: the host challenges the friend, who accepts; both get the same replay and a result.
	host.net.challenge_duel(guest.net.account, host.duel_fighter())
	_check(await _until(func() -> bool: return (guest.net.duel_invites as Array).size() == 1), "a duel challenge reaches the friend")
	guest.net.answer_duel(host.net.account, true, guest.duel_fighter())
	var counted := func(m: Node) -> int:
		var st: Dictionary = m.progression.profile.stats
		return int(st.get("duelsWon", 0)) + int(st.get("duelsLost", 0))
	_check(await _until(func() -> bool: return counted.call(host) == 1 and counted.call(guest) == 1), "both fighters get the duel result")

	# Trade: the host sells an item to the friend for gold.
	var sold: Dictionary = host.inventory.add_random_item(3)
	host.progression.profile.gold = 0
	guest.progression.profile.gold = 500
	var guest_items: int = guest.inventory.items().size()
	host.main_menu.open_section("trade")
	host.net.offer_trade(guest.net.account, sold, 120)
	_check(await _until(func() -> bool: return guest.net.trade_offers(true).size() == 1 and host.net.offered_uids().has(int(sold.uid))), "a trade offer reaches the friend")
	guest.main_menu.open_section("trade")
	guest.net.answer_trade(int(guest.net.trade_offers(true)[0].id), true)
	_check(await _until(func() -> bool: return guest.inventory.items().size() == guest_items + 1 and host.inventory.item(int(sold.uid)).is_empty()), "the item moves to the buyer")
	# (+50 each for the first-trade achievement)
	_check(int(host.progression.profile.gold) == 120 + 50 and int(guest.progression.profile.gold) == 380 + 50, "the gold moves to the seller")
	_check(await _until(func() -> bool: return guest.net.trades.is_empty() and host.net.trades.is_empty()), "the offer is gone after the trade")
	host.leave_hub()
	_check(not host.hub.active and host.main_menu.visible, "leaving the tavern shows the menu")
	_check(await _until(func() -> bool: return guest.hub.guest_count() == 0), "the visitor who left is gone for the others")
	guest.leave_hub()
	host.main_menu.open_section("friends")

	# Only the host starts; the friend's game follows on the same map.
	guest.start_run()
	_check(not guest.in_run, "the friend can't start the run alone")
	host.start_run()
	_check(await _until(func() -> bool: return guest.in_run), "the host's start brings the friend into the run")
	_check(guest.map_id == host.map_id, "both play on the same map")
	_check(guest.enemies.mirror and not host.enemies.mirror, "the friend's game mirrors the host's enemies")
	_check(not host.pause_menu.freezes, "the pause menu doesn't stop a shared run")

	_check(await _until(func() -> bool: return host.coop.puppet(guest.net.my_id) != null and guest.coop.puppet(host.net.my_id) != null),
		"each sees the other's character")
	guest.player.global_position = Vector3(6, guest.terrain.height_at(6, 4) + 0.5, 4)
	var seen := await _until(func() -> bool: return host.coop.puppet(guest.net.my_id).global_position.distance_to(guest.player.global_position) < 1.0)
	if not seen:
		print("  host sees ", host.coop.puppet(guest.net.my_id).global_position, " friend is at ", guest.player.global_position)
	_check(seen, "the friend's moves show in the host's game")
	_check(host.enemies.targets.size() == 2, "enemies can chase both players")
	await _frames(3)
	var party: Control = host.hud.get("_party")
	_check(party.visible and party.get_child_count() == 2, "the party list shows both players")
	var rows: Array = host.hud.get("_party_rows")
	_check((rows[1][1] as Label).text == "Misafir" and (rows[1][3] as ProgressBar).max_value > 1.0, "the partner's character name and health show")

	# Enemies come from the host.
	host.enemies.kill_all_silently()
	host.enemies.spawn("slime", Vector3(10, 0, 10), true)
	var uid: int = host.enemies.uid_of(host.enemies.count() - 1)
	_check(await _until(func() -> bool: return guest.enemies.index_of_uid(uid) >= 0), "the friend sees the host's enemies")

	# The friend's hit kills it on the host; both get the reward.
	var host_exp := _xp(host)
	var guest_exp := _xp(guest)
	guest.enemies.damage(guest.enemies.index_of_uid(uid), 99999.0)
	_check(await _until(func() -> bool: return host.enemies.kills >= 1 and _xp(guest) > guest_exp),
		"the friend's hit kills the enemy and both get EXP")
	_check(_xp(host) > host_exp, "the host gets the EXP too")
	_check(await _until(func() -> bool: return guest.enemies.index_of_uid(uid) == -1), "the killed enemy disappears for the friend")

	# Damage to the friend comes from the host's game.
	var hp: float = guest.player.hp
	host.coop.puppet(guest.net.my_id).take_damage(10.0)
	_check(await _until(func() -> bool: return guest.player.hp < hp), "enemies on the host hurt the friend")

	# Boss attack warnings show for the friend.
	host.enemies.attacks.circle(Vector3(0, 0, 0), 3.0, 2.0, Color.RED)
	_check(await _until(func() -> bool: return guest.enemies.attacks.active_count() > 0), "boss attack warnings show for the friend")
	_check(guest.coop.snapshots_received > 3, "snapshots keep coming")

	# The host leaves: the run ends for the friend too.
	host.leave_run()
	_check(await _until(func() -> bool: return not guest.in_run), "the host leaving ends the run for the friend")

	# Real-time duel: weapons aim at the other player; hits hurt them.
	host.start_duel()
	_check(await _until(func() -> bool: return guest.in_run and guest.coop.pvp and host.coop.pvp), "the host starts a real-time duel and the friend joins")
	_check(await _until(func() -> bool: return host.coop.puppet(guest.net.my_id) != null and guest.enemies.count() == 1 and host.enemies.count() == 1), "each side gets the other as a target")
	var duel_hp: float = host.player.hp
	guest.enemies.damage(0, 5.0)
	_check(await _until(func() -> bool: return host.player.hp < duel_hp), "a hit on the opponent hurts them in their own game")
	var wins_before := int(guest.progression.profile.get("stats", {}).get("duelsWon", 0))
	await create_timer(1.5).timeout
	guest.enemies.damage(0, 99999.0)
	_check(await _until(func() -> bool: return host.player.dead), "the opponent falls")
	_check(await _until(func() -> bool: return int(guest.progression.profile.get("stats", {}).get("duelsWon", 0)) == wins_before + 1), "the winner gets a win and the loser a loss")
	_check(int(host.progression.profile.get("stats", {}).get("duelsLost", 0)) >= 1, "the loser's loss is counted")
	host.leave_run()
	_check(await _until(func() -> bool: return not guest.in_run), "the duel ends for both")
	guest.net.leave_room()
	_check(await _until(func() -> bool: return not host.net.members().size() == 2), "leaving the room shows for the host")

	# The game is kept on the server: another device signs in and gets it.
	host.progression.add_gold(777)
	var gold: int = host.progression.gold()
	host.store.save_to_disk()
	await create_timer(3.0).timeout
	var other := await _game("coop_other", "")
	other.net.sign_in("EVSAHIBI", "sifre12")
	var screen2: Node = other.login_screen
	screen2.set("waiting", true)
	_check(await _until(func() -> bool: return other.progression != null), "the account signs in on another device")
	_check(other.progression.gold() == gold and str(other.progression.profile.name) == "EvSahibi", "the saved game comes back on the other device")

	OS.kill(_server_pid)
	print("all checks passed" if _failures == 0 else "%d checks FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _game(save: String, account: String) -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	var path := "user://%s_profiles.json" % save
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	main.store.path = path
	main.store.load_from_disk()
	main.forced_map = "forest"
	main.net.stop()
	main.net.url = "ws://localhost:%d" % PORT
	main.net.enabled = true
	main.net.start()
	if account == "":
		return main
	if main.login_screen:
		main.login_screen.queue_free()
		main.login_screen = null
	main.login(account)
	main.inventory.create_character(account, "warrior")
	main.net.sign_in(account, "sifre12", true)
	return main


func _xp(game: Node) -> int:
	return int(game.progression.level) * 1000000 + int(game.progression.level_exp)


func _until(condition: Callable, seconds := 8.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		if condition.call():
			return true
		await process_frame
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(ok: bool, what: String) -> void:
	if ok:
		print("PASS ", what)
	else:
		_failures += 1
		print("FAIL ", what)
