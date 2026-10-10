## Connection to the online server (server/index.js): online accounts
## (sign up, sign in, the game saved on the server), who is online, rooms
## with a short code, invites and the co-op messages of a room.
## Keeps trying to reconnect while the game runs; the free server sleeps when
## nobody plays, so the first connection can take up to a minute.
extends Node

## The live server (Render). `--server=ws://localhost:8080` overrides it.
const DEFAULT_URL := "wss://lumora-online.onrender.com"
const RETRY_TIME := 5.0
const PING_TIME := 25.0
const MAX_MEMBERS := 4
## Saves wait this long so a burst of changes goes up once.
const SAVE_DELAY := 2.0

## "offline", "connecting", "connected" (not signed in) or "online" (signed in).
signal status_changed(status: String)
## Signed in: the account's name as the server writes it, a token to sign in
## again without the password, and the game saved on the server (or empty).
signal signed_in(account_name: String, token: String, profile: Dictionary, saved_at: float)
signal sign_in_failed(code: String, message: String)
signal password_changed(ok: bool, message: String, token: String)
## The room changed (joined, left, someone came or went).
signal room_changed
signal invited(from_name: String, code: String)
## Co-op data from another member of the room (`from` is their id).
signal game_message(from: int, data: Dictionary)
## Something the player should read (a refused join or invite...).
signal notice(text: String)
signal who_updated
signal online_list_updated
## A leaderboard arrived: its category, the best rows [{name, value, level}]
## and this account's place ({rank, value}, or empty).
signal leaderboard_received(category: String, rows: Array, me: Dictionary)
## The hub tavern changed (someone sat down or left).
signal hub_changed
## Another visitor of the hub tavern moved or sat down: their id and state
## ({p: [x, y, z], f: facing, s: speed, a: action, o: object number}).
signal hub_state_received(from: int, state: Dictionary)
## A chat line in the hub tavern: who said it (id and name) and what.
signal hub_chat_received(from: int, from_name: String, text: String)
## Your guild changed (joined, left, members, online).
signal guild_changed
signal guild_list_received
signal guild_chat_received(from_name: String, text: String)
## Open trade offers (yours and the ones made to you) changed.
signal trades_changed
## A trade went through: {id, from, to, item, price}. The game moves the item and the gold.
signal trade_done(info: Dictionary)
## The weekly guild reward was granted by the server.
signal guild_reward(gold: int)

var url := DEFAULT_URL
var status := "offline"
var account := ""
var my_id := 0
## {code, host, members: [{id, name}]} or empty when not in a room.
var room: Dictionary = {}
## Invites not answered yet: [{from, code}].
var invites: Array = []
## Accounts found online by the last `who`.
var online_names: PackedStringArray = []
## Everybody online right now (last `ask_online_list`), not this account.
var online_list: PackedStringArray = []
## Account levels the server told us about, by lower-case name.
var levels := {}
## How this player's character looks (PlayerModel look), shown to the room.
var my_look: Dictionary = {}
## People in the hub tavern: [{id, name, look, seat, level}] (empty when not in it).
var hub_members: Array = []
## The last chat lines of the hub tavern: [{name, text}].
var hub_chat: Array = []
## Your guild: {name, tag, leader, members:[{name, level, online}], chat:[{name, text}]}, empty if none.
var guild: Dictionary = {}
## The biggest guilds: [{name, tag, members, leader}].
var guild_list: Array = []
## Open trade offers: [{id, from, to, item, price}].
var trades: Array = []
## False stops reconnecting (tests, offline play).
var enabled := true

var _ws: WebSocketPeer
var _retry := 0.0
var _ping := 0.0
var _invite_after_room := ""
## The player wants to be in the hub tavern (joins again after a reconnect).
var _want_hub := false
## How to sign in (again after a reconnect): {mode, name, pw | token, profile}.
var _creds: Dictionary = {}
var _save: Dictionary = {}
var _save_wait := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Headless runs (tests, CI) stay offline unless a server is given.
	enabled = DisplayServer.get_name() != "headless"
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--server="):
			url = arg.trim_prefix("--server=")
			enabled = true
		elif arg == "--offline":
			enabled = false


## Starts connecting (and keeps reconnecting).
func start() -> void:
	if enabled and _ws == null:
		_connect()


func stop() -> void:
	if _ws:
		_ws.close()
	_ws = null
	room = {}
	_set_status("offline")


## Signs in with a password (`register`: opens the account first). When the
## account doesn't exist online yet but `local_profile` is given (the player
## knows this device's password), the account is opened with that game.
func sign_in(account_name: String, password: String, register := false, local_profile := {}) -> void:
	_creds = {"mode": "register" if register else "login", "name": account_name, "pw": password, "profile": local_profile}
	_send_creds()


## Signs in with a remembered token.
func resume(account_name: String, token: String) -> void:
	_creds = {"mode": "resume", "name": account_name, "token": token}
	_send_creds()


func sign_out() -> void:
	_creds = {}
	account = ""
	stop()
	start()


## The server keeps the account's game (sent a moment later, newest wins).
func save_profile(profile: Dictionary) -> void:
	var copy := profile.duplicate(true)
	copy.erase("passwordHash")
	copy.erase("salt")
	_save = {"t": "save", "profile": copy, "at": float(profile.get("savedAt", Time.get_unix_time_from_system()))}
	_save_wait = SAVE_DELAY


func change_password(new_password: String) -> void:
	_send({"t": "password", "new": new_password})


func ask_online_list() -> void:
	if is_online():
		_send({"t": "online_list"})


## Signed in to an online account.
func is_online() -> bool:
	return status == "online"


## The socket is open (signed in or not).
func is_connected_to_server() -> bool:
	return status == "connected" or status == "online"


func in_room() -> bool:
	return not room.is_empty()


func is_host() -> bool:
	return in_room() and int(room.host) == my_id


func members() -> Array:
	return room.get("members", [])


## Name of a room member by id.
func member_name(id: int) -> String:
	for m: Dictionary in members():
		if int(m.id) == id:
			return str(m.name)
	return "?"


func create_room() -> void:
	_send({"t": "create", "look": my_look})


## The character this player shows in the room changed.
func set_look(look: Dictionary) -> void:
	my_look = look
	if in_room() or in_hub():
		_send({"t": "look", "look": look})


## Sits down in the hub tavern (everyone online can come and chat).
func join_hub() -> void:
	_want_hub = true
	if is_online():
		_send({"t": "hub_join", "look": my_look})


func leave_hub() -> void:
	if _want_hub and is_online():
		_send({"t": "hub_leave"})
	_want_hub = false
	hub_members = []
	hub_changed.emit()


## Tells the hub tavern where this player is and what they are doing.
func send_hub_state(state: Dictionary) -> void:
	if _want_hub and is_online():
		_send({"t": "hub_state", "d": state})


func in_hub() -> bool:
	return not hub_members.is_empty()


## Says something in the hub tavern. Returns false if it can't be sent.
func send_chat(text: String) -> bool:
	text = text.strip_edges()
	if text == "" or not in_hub():
		return false
	_send({"t": "chat", "text": text.left(200)})
	return true


## Offers an item from the backpack to an online player for `price` gold.
func offer_trade(to: String, item: Dictionary, price: int) -> void:
	if is_online():
		_send({"t": "trade_offer", "to": to.strip_edges(), "item": item, "price": maxi(price, 0)})


func answer_trade(id: int, accept: bool) -> void:
	if is_online():
		_send({"t": "trade_answer", "id": id, "accept": accept})


func cancel_trade(id: int) -> void:
	if is_online():
		_send({"t": "trade_cancel", "id": id})


## Offers made to this player (incoming = true) or by this player.
func trade_offers(incoming: bool) -> Array:
	var out: Array = []
	for o: Dictionary in trades:
		if (str(o.to).to_lower() == account.to_lower()) == incoming:
			out.append(o)
	return out


## The uids of your items that are in an open offer.
func offered_uids() -> Array:
	var out: Array = []
	for o: Dictionary in trade_offers(false):
		out.append(int((o.item as Dictionary).get("uid", -1)))
	return out


func in_guild() -> bool:
	return not guild.is_empty()


func is_guild_leader() -> bool:
	return in_guild() and str(guild.leader).to_lower() == account.to_lower()


func ask_guild_list() -> void:
	if is_online():
		_send({"t": "guild_list"})


func create_guild(guild_name: String, tag: String) -> void:
	if is_online():
		_send({"t": "guild_create", "name": guild_name.strip_edges(), "tag": tag.strip_edges()})


func join_guild(guild_name: String) -> void:
	if is_online():
		_send({"t": "guild_join", "name": guild_name})


func leave_guild() -> void:
	if is_online():
		_send({"t": "guild_leave"})


func kick_from_guild(member: String) -> void:
	if is_online():
		_send({"t": "guild_kick", "name": member})


## Tells the server how many monsters a run defeated (weekly guild goal).
func report_guild_kills(kills: int) -> void:
	if status == "online" and in_guild() and kills > 0:
		_send({"t": "guild_kills", "n": kills})


## Takes the weekly guild reward (the server checks the goal and the helper).
func claim_guild_reward() -> void:
	if status == "online" and in_guild():
		_send({"t": "guild_claim"})


## Says something to the guild. Returns false if it can't be sent.
func send_guild_chat(text: String) -> bool:
	text = text.strip_edges()
	if text == "" or not in_guild():
		return false
	_send({"t": "guild_chat", "text": text.left(200)})
	return true


## Asks for a leaderboard (answer: leaderboard_received).
func ask_leaderboard(category: String) -> void:
	if is_online():
		_send({"t": "leaderboard", "cat": category})


## Account level of a player the server told us about (0 if unknown).
func level_of(player_name: String) -> int:
	return int(levels.get(player_name.to_lower(), 0))


func join_room(code: String) -> void:
	code = code.strip_edges().to_upper()
	if code.length() != 5:
		notice.emit("Oda kodu 5 harf olmalı.")
		return
	_drop_invite(code)
	_send({"t": "join", "code": code, "look": my_look})


func leave_room() -> void:
	_send({"t": "leave"})
	room = {}
	room_changed.emit()


## Invites an online account; opens a room first when there is none.
func invite(to: String) -> void:
	to = to.strip_edges()
	if to == "":
		return
	if not in_room():
		_invite_after_room = to
		create_room()
		return
	_send({"t": "invite", "to": to})


func decline_invite(code: String) -> void:
	_drop_invite(code)


## Asks which of these accounts are online (answer: who_updated).
func ask_who(names: Array) -> void:
	if not names.is_empty():
		_send({"t": "who", "names": names})


func is_name_online(n: String) -> bool:
	for o in online_names:
		if o.to_lower() == n.to_lower():
			return true
	return false


## Co-op data to the whole room, or only to member `to`.
func send_game(data: Dictionary, to := -1) -> void:
	if not in_room():
		return
	var msg := {"t": "game", "d": data}
	if to >= 0:
		msg.to = to
	_send(msg)


func _send(msg: Dictionary) -> void:
	if _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		if not msg.t in ["game", "who", "online_list", "save", "leaderboard", "look", "hub_state", "chat"]:
			notice.emit("Sunucuya bağlı değilsin. Bağlanmayı bekle.")
		return
	_ws.send_text(JSON.stringify(msg))


func _send_creds() -> void:
	if _creds.is_empty() or not is_connected_to_server():
		return
	match str(_creds.mode):
		"resume":
			_send({"t": "resume", "name": _creds.name, "token": _creds.token})
		"register":
			var msg := {"t": "register", "name": _creds.name, "pw": _creds.pw}
			var local: Dictionary = _creds.get("profile", {})
			if not local.is_empty():
				var copy := local.duplicate(true)
				copy.erase("passwordHash")
				copy.erase("salt")
				msg.profile = copy
				msg.at = float(local.get("savedAt", 0.0))
			_send(msg)
		_:
			_send({"t": "login", "name": _creds.name, "pw": _creds.pw})


func _connect() -> void:
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = 1 << 20
	_ws.outbound_buffer_size = 1 << 20
	if _ws.connect_to_url(url) != OK:
		_ws = null
		_retry = RETRY_TIME
		_set_status("offline")
		return
	_set_status("connecting")


func _set_status(s: String) -> void:
	if s == status:
		return
	status = s
	if s != "online":
		trades.clear()
	status_changed.emit(s)


func _process(delta: float) -> void:
	if _ws == null:
		if enabled:
			_retry -= delta
			if _retry <= 0.0:
				_connect()
		return
	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			while _ws.get_available_packet_count() > 0:
				var parsed: Variant = JSON.parse_string(_ws.get_packet().get_string_from_utf8())
				if parsed is Dictionary:
					_handle(parsed)
			if not _save.is_empty() and is_online():
				_save_wait -= delta
				if _save_wait <= 0.0:
					_ws.send_text(JSON.stringify(_save))
					_save = {}
			_ping -= delta
			if _ping <= 0.0:
				_ping = PING_TIME
				_ws.send_text("{\"t\":\"ping\"}")
		WebSocketPeer.STATE_CLOSED:
			_ws = null
			_retry = RETRY_TIME
			var had_room := in_room()
			room = {}
			if in_hub():
				hub_members = []
				hub_changed.emit()
			_set_status("offline")
			if had_room:
				notice.emit("Sunucu bağlantısı koptu, odadan çıktın.")
				room_changed.emit()


func _handle(msg: Dictionary) -> void:
	match str(msg.get("t", "")):
		"welcome":
			my_id = int(msg.id)
			_set_status("connected")
			_send_creds()
		"auth":
			_on_auth(msg)
		"password":
			if bool(msg.get("ok", false)) and _creds.get("mode") == "resume":
				_creds.token = str(msg.token)
			password_changed.emit(bool(msg.get("ok", false)), str(msg.get("msg", "")), str(msg.get("token", "")))
		"online_list":
			online_list = PackedStringArray(msg.get("names", []))
			_take_levels(msg.get("levels"))
			online_list_updated.emit()
		"levels":
			_take_levels(msg.get("levels"))
			who_updated.emit()
		"leaderboard":
			var me: Variant = msg.get("me")
			leaderboard_received.emit(str(msg.get("cat", "")), msg.get("rows", []) if msg.get("rows") is Array else [], me if me is Dictionary else {})
		"room":
			room = {"code": str(msg.code), "host": int(msg.host), "members": []}
			for m: Dictionary in msg.members:
				var look: Variant = m.get("look")
				(room.members as Array).append({"id": int(m.id), "name": str(m.name), "look": look if look is Dictionary else {}})
			room_changed.emit()
			if _invite_after_room != "":
				var to := _invite_after_room
				_invite_after_room = ""
				invite(to)
		"room_closed":
			room = {}
			notice.emit(str(msg.get("reason", "Oda kapandı.")))
			room_changed.emit()
		"invited":
			_drop_invite(str(msg.code))
			invites.append({"from": str(msg.from), "code": str(msg.code)})
			invited.emit(str(msg.from), str(msg.code))
		"invite_sent":
			notice.emit("%s davet edildi." % msg.to)
		"who":
			online_names = PackedStringArray(msg.online)
			_take_levels(msg.get("levels"))
			who_updated.emit()
		"game":
			if msg.d is Dictionary:
				game_message.emit(int(msg.from), msg.d)
		"hub":
			if not _want_hub:
				return
			hub_members = []
			for m: Dictionary in msg.get("members", []):
				var look: Variant = m.get("look")
				hub_members.append({"id": int(m.id), "name": str(m.name), "look": look if look is Dictionary else {},
					"seat": int(m.get("seat", -1)), "level": int(m.get("level", 0)), "guild": str(m.get("guild", ""))})
			hub_chat = []
			for line: Dictionary in msg.get("chat", []):
				hub_chat.append({"name": str(line.name), "text": str(line.text)})
			hub_changed.emit()
		"hub_state":
			if _want_hub and msg.get("d") is Dictionary:
				hub_state_received.emit(int(msg.id), msg.d)
		"hub_chat":
			if not _want_hub:
				return
			hub_chat.append({"name": str(msg.name), "text": str(msg.text)})
			if hub_chat.size() > 40:
				hub_chat.pop_front()
			hub_chat_received.emit(int(msg.id), str(msg.name), str(msg.text))
		"guild":
			guild = {}
			if msg.get("guild") is Dictionary:
				var g: Dictionary = msg.guild
				guild = {"name": str(g.name), "tag": str(g.tag), "leader": str(g.leader), "members": [], "chat": [], "quest": {}}
				for m: Dictionary in g.get("members", []):
					(guild.members as Array).append({"name": str(m.name), "level": int(m.get("level", 1)), "online": bool(m.get("online", false))})
				var q: Dictionary = g.get("quest", {}) if g.get("quest") is Dictionary else {}
				if not q.is_empty():
					guild.quest = {"goal": int(q.get("goal", 1)), "progress": int(q.get("progress", 0)), "reward": int(q.get("reward", 0)),
						"claimed": (q.get("claimed", []) as Array).map(func(n: Variant) -> String: return str(n).to_lower()), "top": q.get("top", []), "endsIn": float(q.get("endsIn", 0.0))}
				for line: Dictionary in g.get("chat", []):
					(guild.chat as Array).append({"name": str(line.name), "text": str(line.text)})
			guild_changed.emit()
		"guild_list":
			guild_list = msg.get("guilds", []) if msg.get("guilds") is Array else []
			guild_list_received.emit()
		"guild_chat":
			if in_guild():
				(guild.chat as Array).append({"name": str(msg.name), "text": str(msg.text)})
				if (guild.chat as Array).size() > 40:
					(guild.chat as Array).pop_front()
				guild_chat_received.emit(str(msg.name), str(msg.text))
		"trades":
			trades.clear()
			if msg.get("offers") is Array:
				for o: Variant in msg.offers:
					if o is Dictionary and (o as Dictionary).get("item") is Dictionary:
						trades.append({"id": int(o.id), "from": str(o.from), "to": str(o.to), "item": o.item, "price": int(o.price)})
			trades_changed.emit()
		"trade_done":
			if msg.get("item") is Dictionary:
				trade_done.emit({"id": int(msg.id), "from": str(msg.from), "to": str(msg.to), "item": msg.item, "price": int(msg.price)})
		"guild_reward":
			guild_reward.emit(int(msg.get("gold", 0)))
		"trade_closed":
			notice.emit(str(msg.reason))
		"error":
			_invite_after_room = ""
			notice.emit(str(msg.msg))


func _on_auth(msg: Dictionary) -> void:
	if bool(msg.get("ok", false)):
		account = str(msg.name)
		_creds = {"mode": "resume", "name": account, "token": str(msg.token)}
		_set_status("online")
		if _want_hub:
			_send({"t": "hub_join", "look": my_look})
		_send({"t": "guild"})
		_send({"t": "trades"})
		var profile: Variant = msg.get("profile")
		signed_in.emit(account, str(msg.token), profile if profile is Dictionary else {}, float(msg.get("savedAt", 0.0)))
		return
	var code := str(msg.get("code", ""))
	if code == "no_account" and str(_creds.get("mode", "")) == "login" and not (_creds.get("profile", {}) as Dictionary).is_empty():
		# This device's account isn't online yet: open it with this game.
		_creds.mode = "register"
		_send_creds()
		return
	_creds = {}
	sign_in_failed.emit(code, str(msg.get("msg", "Giriş yapılamadı.")))


func _take_levels(data: Variant) -> void:
	if data is Dictionary:
		for n: String in data:
			levels[n.to_lower()] = int(data[n])


func _drop_invite(code: String) -> void:
	for i in range(invites.size() - 1, -1, -1):
		if str(invites[i].code) == code:
			invites.remove_at(i)
