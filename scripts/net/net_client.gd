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
## False stops reconnecting (tests, offline play).
var enabled := true

var _ws: WebSocketPeer
var _retry := 0.0
var _ping := 0.0
var _invite_after_room := ""
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
	_send({"t": "create"})


func join_room(code: String) -> void:
	code = code.strip_edges().to_upper()
	if code.length() != 5:
		notice.emit("Oda kodu 5 harf olmalı.")
		return
	_drop_invite(code)
	_send({"t": "join", "code": code})


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
		if not msg.t in ["game", "who", "online_list", "save"]:
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
			online_list_updated.emit()
		"room":
			room = {"code": str(msg.code), "host": int(msg.host), "members": []}
			for m: Dictionary in msg.members:
				(room.members as Array).append({"id": int(m.id), "name": str(m.name)})
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
			who_updated.emit()
		"game":
			if msg.d is Dictionary:
				game_message.emit(int(msg.from), msg.d)
		"error":
			_invite_after_room = ""
			notice.emit(str(msg.msg))


func _on_auth(msg: Dictionary) -> void:
	if bool(msg.get("ok", false)):
		account = str(msg.name)
		_creds = {"mode": "resume", "name": account, "token": str(msg.token)}
		_set_status("online")
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


func _drop_invite(code: String) -> void:
	for i in range(invites.size() - 1, -1, -1):
		if str(invites[i].code) == code:
			invites.remove_at(i)
