## The hub tavern in the game: enter it from the menu to walk around a big
## tavern with everyone else online. Use things with E: sit on chairs,
## stools and benches, swing on the swings, dance on the dance floor, poke
## the fire, chat with Bora the barkeeper. Walk out of the door into the
## evening meadow: wish at the well, fish from the dock, sit by the campfire.
## Enter opens the chat, Esc leaves.
## Where you are and what you do is sent to the server about 15 times a
## second; the others show up as HubGuest characters.
extends Node

const HubWorld := preload("res://scripts/world/hub_world.gd")
const HubGuest := preload("res://scripts/world/hub_guest.gd")
const HubOverlay := preload("res://scripts/ui/hub_overlay.gd")

const STATE_TIME := 1.0 / 15.0
## A state goes out at least this often so newcomers see everyone.
const HEARTBEAT := 1.0
## Walking is slower than in a run.
const WALK_SCALE := 0.75
const MountModel := preload("res://scripts/world/mount_model.gd")
const GameAnim := preload("res://scripts/world/hub_game_anim.gd")
## Guests closer than this can be asked for a dice or card game.
const GAME_REACH := 6.0
var _mount_node: Node3D
## A calm evening: deep blue sky, soft moonlight, a light haze over the
## meadow (same keys as data/maps.json).
const ENVIRONMENT := {
	"sky": ["#141a33", "#5a4566", "#10131c"], "ambient": "#e0c4a8", "ambientEnergy": 0.5,
	"fog": "#2c2f45", "fogDensity": 0.011, "sun": "#a8b8ff", "sunEnergy": 0.38,
}

## What the wishing well, the fishing dock and Bora the barkeeper say.
const WISHES := [
	"Kuyuya bir bozuk para attın. Dileğin tutsun!",
	"Para suya düşerken hafif bir ışık parladı.",
	"Kuyudan yankılanan bir ses: \"Şans seninle olsun...\"",
	"Bir dilek tuttun ve içine bir huzur doldu.",
]
const CATCHES := [
	"Küçük bir sazan yakaladın ve geri saldın.",
	"Oltan biraz titredi ama balık kaçtı.",
	"Parlak pullu bir balık! Gölete geri bıraktın.",
	"Bir nilüfer yaprağı çıktı. Bugün balıklar uykuda.",
	"Ördekler oltanı merakla izliyor.",
]
const RUMORS := [
	"Hoş geldin yolcu! Ateşin başı bu akşam pek sıcak.",
	"Ormanın derinlerinde dev bir örümceğin dolaştığını duydum.",
	"Kuyuya dilek tutan şanslı olurmuş, dene istersen.",
	"Göletteki ördekler benim, onlara iyi davran.",
	"Çantanı dolu tut, macera insanı her an bulur.",
	"Kedimiz Tarçın şöminenin başından hiç kalkmaz.",
]

## The player is in the tavern.
signal entered
signal left

var active := false
var tavern: HubWorld
var overlay: HubOverlay

var _main: Node
var _net: Node
var _guests := {}
## What the player does: "", "sit", "swing" or "dance", and with which thing.
var _action := ""
var _object := -1
var _state_timer := 0.0
var _heartbeat := 0.0
var _sent := ""
var _was_captured := false
var _releasing := false
var _bubble: Label3D
var _want_board := false
## The rider got off for the parkour run (back on after it).
var _dismounted := false


func setup(p_main: Node, p_net: Node) -> void:
	_main = p_main
	_net = p_net
	_net.hub_changed.connect(_on_hub_changed)
	_net.hub_state_received.connect(_on_state)
	_net.hub_chat_received.connect(_on_chat)
	_net.status_changed.connect(_on_status)
	_net.game_changed.connect(_refresh_invite)
	_net.game_played.connect(_on_game_played)


## Walks into the tavern (the menu hides, the character appears at the door).
func enter() -> void:
	if active:
		return
	if tavern == null:
		tavern = HubWorld.new()
		tavern.name = "Tavern"
		_main.world.add_child(tavern)
		tavern.build()
		overlay = HubOverlay.new()
		overlay.name = "HubOverlay"
		overlay.visible = false
		overlay.chat_submitted.connect(_on_chat_submitted)
		overlay.chat_closed.connect(_on_chat_closed)
		overlay.leave_confirmed.connect(_on_leave_confirmed)
		overlay.leave_cancelled.connect(_on_chat_closed)
		overlay.panel_closed.connect(_on_chat_closed)
		overlay.game_challenge.connect(_on_game_challenge)
		overlay.game_answered.connect(_on_game_answered)
		tavern.parkour.finished.connect(_on_parkour_finished)
		tavern.parkour.fell.connect(func(n: int) -> void: overlay.add_note("Düştün! Son kontrol noktasına döndün (%d düşme)." % n))
		tavern.parkour.checkpoint_reached.connect(func(_i: int) -> void: overlay.add_note("Kontrol noktası!"))
		tavern.parkour.started.connect(_on_parkour_started)
		_net.parkour_board_received.connect(_on_parkour_board)
		_main.add_child(overlay)
	active = true
	_main.main_menu.visible = false
	_main.main_menu.close_confirm()
	_main.apply_environment(ENVIRONMENT)
	var player: CharacterBody3D = _main.player
	var character: Dictionary = _main.call("_ensure_character")
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.visible = true
	player.call("set_look", _main.call("character_look", character))
	player.call("reset", 100.0)
	player.global_position = tavern.spawn_point(_my_spot())
	player.set("speed_multiplier", WALK_SCALE * float(_main.mounts.speed()))
	_ride(player)
	player.set("controls_enabled", true)
	player.call("set_pose", false, false)
	_main.camera_rig.yaw = 0.0
	_main.camera_rig.pitch = deg_to_rad(-18.0)
	_main.camera_rig.capture_enabled = true
	_main.camera_rig.camera.current = true
	_bubble = HubGuest.make_bubble()
	_bubble.visible = false
	player.add_child(_bubble)
	_action = ""
	_object = -1
	_sent = ""
	_heartbeat = 0.0
	overlay.visible = true
	overlay.set_prompt("")
	_net.join_hub()
	tavern.set_guild(_net.guild)
	_on_hub_changed()
	entered.emit()


## Puts the ridden mount (if any) under the player.
func _ride(player: CharacterBody3D) -> void:
	_dismounted = false
	if _mount_node:
		_mount_node.queue_free()
		_mount_node = null
	var d: Dictionary = _main.mounts.def(_main.mounts.active())
	if not d.is_empty():
		_mount_node = MountModel.new()
		_mount_node.build(d)
		player.add_child(_mount_node)
	player.set("ride_height", _mount_node.seat_height() if _mount_node else 0.0)
	player.set("riding", _mount_node != null)
	player.call("set_pose", false, false)


## The mount turns with the rider and runs while the rider moves; sitting on a
## chair (or dancing) sets the rider down beside it.
func _move_mount(delta: float, player: CharacterBody3D) -> void:
	if _mount_node == null:
		return
	if _dismounted and not tavern.parkour.running:
		_set_riding(true)
	_mount_node.visible = _action == "" and not _dismounted
	if _dismounted:
		return
	_mount_node.rotation.y = float(player.get("facing"))
	var speed := float(player.call("horizontal_speed")) / maxf(WALK_SCALE, 0.01)
	_mount_node.animate(delta, speed)
	var model: Node3D = player.get("_model")
	model.set("ride_bob", absf(sin(float(_mount_node.get("_phase")))) * 0.07 * clampf(speed / 6.0, 0.0, 1.0))


## The parkour is run on foot: the rider gets off when the clock starts.
func _on_parkour_started() -> void:
	overlay.add_note("Parkur başladı! Süre işliyor.")
	if _mount_node != null and not _dismounted:
		_set_riding(false)
		overlay.add_note("Parkur yaya koşulur: bineğinden indin.")


## Gets on or off the mount (the parkour needs both feet on the ground).
func _set_riding(on: bool) -> void:
	_dismounted = not on
	var player: CharacterBody3D = _main.player
	player.set("riding", on and _mount_node != null)
	player.set("ride_height", _mount_node.seat_height() if on and _mount_node != null else 0.0)
	player.set("speed_multiplier", WALK_SCALE * (float(_main.mounts.speed()) if on else 1.0))
	player.call("set_pose", false, false)


## Walks out (back to the menu is the caller's job).
func leave() -> void:
	if not active:
		return
	active = false
	_stand_up(false)
	tavern.parkour.cancel()
	overlay.set_run("")
	overlay.close_chat()
	overlay.visible = false
	var player: CharacterBody3D = _main.player
	player.set("speed_multiplier", 1.0)
	player.set("controls_enabled", true)
	if _mount_node:
		_mount_node.queue_free()
		_mount_node = null
	_dismounted = false
	player.set("ride_height", 0.0)
	player.set("riding", false)
	player.call("set_pose", false, false)
	if _bubble:
		_bubble.queue_free()
		_bubble = null
	for id: int in _guests.keys():
		(_guests[id] as Node).queue_free()
	_guests.clear()
	_net.leave_hub()
	_main.apply_environment(_main.maps[_main.map_id])
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_was_captured = false
	left.emit()


## The visitor character of someone else in the tavern (null if not there).
func guest(id: int) -> Node3D:
	return _guests.get(id)


func guest_count() -> int:
	return _guests.size()


## What the player is doing: "", "sit", "swing" or "dance".
func action() -> String:
	return _action


## Uses the thing in reach (or gets up from what the player is using).
func interact() -> void:
	if not active or overlay.is_typing():
		return
	if _action != "":
		_stand_up(true)
		return
	var player: CharacterBody3D = _main.player
	var index := tavern.nearest(player.global_position)
	if index < 0:
		return
	var thing: Dictionary = tavern.interactables[index]
	match str(thing.kind):
		"sit", "swing":
			if _occupied(index):
				overlay.add_note("Burada biri oturuyor.")
				return
			_sit(index, str(thing.kind))
		"dance":
			_action = "dance"
			_object = -1
			player.call("set_pose", false, true)
		"fire":
			tavern.poke_fire(int(thing.get("which", 0)))
			overlay.add_note("Ateşe bir odun attın, alevler yükseldi.")
		"well":
			overlay.add_note(WISHES.pick_random())
		"fish":
			_fish()
		"talk":
			overlay.add_note("Bora: " + RUMORS.pick_random())
		"pk_board":
			_want_board = true
			_net.ask_parkour_board()


## Casts the rod at the dock: a fish for the kitchen, or some junk.
func _fish() -> void:
	var food: RefCounted = _main.food
	if food.wait_left() > 0.0:
		overlay.add_note("Oltan hâlâ suyun içinde, biraz bekle.")
		return
	var k: Dictionary = food.cast()
	if k.is_empty():
		overlay.add_note(CATCHES.pick_random())
	elif k.has("junkGold"):
		overlay.add_note("Oltana %s takıldı! Satıp %d altın kazandın." % [k.name, int(k.junkGold)])
	else:
		overlay.add_note("%s yakaladın! Menüde Taverna sayfasından pişirip yiyebilirsin." % k.name)


## Sits on chair, stool, bench or swing number `index`.
func sit_on(index: int) -> void:
	_sit(index, str(tavern.interactables[index].kind))


func _sit(index: int, kind: String) -> void:
	var player: CharacterBody3D = _main.player
	_action = kind
	_object = index
	player.call("set_pose", true, false)
	player.velocity = Vector3.ZERO
	player.global_position = tavern.origin_of(index)
	player.set("facing", tavern.facing_of(index))
	_send_state(true)


func _stand_up(send: bool) -> void:
	if _action == "":
		return
	var player: CharacterBody3D = _main.player
	var was_seated := _object >= 0
	if was_seated:
		player.global_position = tavern.exit_point(_object)
		player.velocity = Vector3.ZERO
	_action = ""
	_object = -1
	player.call("set_pose", false, false)
	if send:
		_send_state(true)


func _occupied(index: int) -> bool:
	for g: Node in _guests.values():
		if g.is_seated() and int(g.object) == index:
			return true
	return false


func _my_spot() -> int:
	for m: Dictionary in _net.hub_members:
		if int(m.id) == _net.my_id:
			return maxi(0, int(m.seat))
	return randi() % 20


# --- Frame ----------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).keycode
	if event.is_action_pressed("interact"):
		interact()
		get_viewport().set_input_as_handled()
	elif (key == KEY_ENTER or key == KEY_KP_ENTER) and not overlay.is_typing():
		_open_chat()
		get_viewport().set_input_as_handled()
	elif key == KEY_G and not overlay.is_typing() and not overlay.is_asking_leave():
		_open_games()
		get_viewport().set_input_as_handled()
	elif (key == KEY_Y or key == KEY_N) and overlay.has_invite() and not overlay.is_typing():
		overlay.answer_invite(key == KEY_Y)
		get_viewport().set_input_as_handled()
	elif key == KEY_ESCAPE:
		if overlay.is_games_open():
			overlay.close_games()
		elif overlay.is_panel_open():
			overlay.close_panel()
		elif overlay.is_asking_leave():
			overlay.close_leave()
		else:
			_ask_leave()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if not active:
		return
	var player: CharacterBody3D = _main.player
	# Moving or jumping gets the player up from a chair or off the dance floor.
	if _action != "" and not overlay.is_typing():
		var raw := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if raw.length() > 0.4 or Input.is_action_just_pressed("jump"):
			_stand_up(true)
	if _action == "swing" or _action == "sit":
		player.global_position = tavern.origin_of(_object)
	_move_mount(delta, player)
	# Swings swing while someone is on them.
	var used := {}
	if _action == "swing":
		used[int(tavern.interactables[_object].swing)] = true
	for g: Node in _guests.values():
		if g.is_seated() and str(g.action) == "swing":
			used[int(tavern.interactables[int(g.object)].swing)] = true
	for k in 2:
		tavern.set_swing_occupied(k, used.has(k))
	if _action == "":
		tavern.parkour.update(delta, player)
	overlay.set_run(tavern.parkour.status_text())
	_update_prompt(player)
	_state_timer -= delta
	_heartbeat += delta
	if _state_timer <= 0.0:
		_state_timer = STATE_TIME
		_send_state(false)
	# Losing the mouse (Esc in a browser) while walking leaves the tavern.
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _was_captured and not captured and not overlay.is_typing() and not _releasing:
		_ask_leave()
	_was_captured = captured


func _update_prompt(player: CharacterBody3D) -> void:
	if overlay.is_typing():
		overlay.set_prompt("")
	elif _action == "sit" or _action == "swing":
		overlay.set_prompt("Kalk")
	elif _action == "dance":
		overlay.set_prompt("Dansı bırak")
	else:
		var index := tavern.nearest(player.global_position)
		overlay.set_prompt(str(tavern.interactables[index].label) if index >= 0 and not (_occupied(index) and tavern.interactables[index].kind != "dance") else "")


func _send_state(force: bool) -> void:
	var player: CharacterBody3D = _main.player
	var local: Vector3 = player.global_position - HubWorld.ORIGIN
	var state := {
		"p": [snappedf(local.x, 0.01), snappedf(local.y, 0.01), snappedf(local.z, 0.01)],
		"f": snappedf(float(player.get("facing")), 0.01),
		"s": snappedf(float(player.call("horizontal_speed")), 0.1),
		"a": _action,
		"o": _object,
	}
	var json := JSON.stringify(state)
	if not force and json == _sent and _heartbeat < HEARTBEAT:
		return
	_sent = json
	_heartbeat = 0.0
	_net.send_hub_state(state)


# --- Others ---------------------------------------------------------------------

func _on_hub_changed() -> void:
	if not active:
		return
	var present := {}
	for m: Dictionary in _net.hub_members:
		var id := int(m.id)
		if id == _net.my_id:
			continue
		present[id] = true
		var g: Node3D = _guests.get(id)
		if g == null:
			g = HubGuest.new()
			g.name = "Guest%d" % id
			tavern.add_child(g)
			g.call("setup", id, _tagged(m), int(m.get("level", 0)), tavern)
			_guests[id] = g
			# A newcomer should see where we are right away.
			_send_state(true)
		g.call("set_info", _tagged(m), int(m.get("level", 0)))
		if m.get("look") is Dictionary and not (m.look as Dictionary).is_empty():
			g.call("set_look", m.look)
	for id: int in _guests.keys():
		if not present.has(id):
			(_guests[id] as Node).queue_free()
			_guests.erase(id)
	overlay.set_count(_net.hub_members.size())


## "[GK] mami" for a guild member, else just the name.
static func _tagged(m: Dictionary) -> String:
	var tag := str(m.get("guild", ""))
	return ("[%s] " % tag if tag != "" else "") + str(m.name)


func _on_state(from: int, state: Dictionary) -> void:
	if active and _guests.has(from):
		_guests[from].call("apply_state", state)


# --- Chat -----------------------------------------------------------------------

func _open_chat() -> void:
	_releasing = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_main.player.set("controls_enabled", false)
	overlay.open_chat()


## Esc asks first; the mouse is freed so the buttons can be clicked.
func _ask_leave() -> void:
	if overlay.is_typing():
		return
	_releasing = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_main.player.set("controls_enabled", false)
	overlay.ask_leave()


func _on_leave_confirmed() -> void:
	_releasing = false
	_main.leave_hub()


## The run reached the finish: the server records it (and pays) when online.
func _on_parkour_finished(ms: int, falls: int) -> void:
	overlay.add_note("Parkuru %s sürede bitirdin! (%d düşme)" % [time_text(ms), falls])
	_net.finish_parkour(ms, falls)


static func time_text(ms: int) -> String:
	return "%d:%04.1f" % [ms / 60000, fmod(ms / 1000.0, 60.0)]


## Shows the rankings on a panel (when asked for at the notice post).
func _on_parkour_board(data: Dictionary) -> void:
	if not active or not _want_board:
		return
	_want_board = false
	var lines := PackedStringArray(["PARKUR SIRALAMASI", ""])
	var rank := 1
	for row: Dictionary in data.get("top", []):
		lines.append("%d. %s   %s   (%d bitiriş)" % [rank, row.name, time_text(int(row.best)), int(row.runs)])
		rank += 1
	if rank == 1:
		lines.append("Henüz kimse bitirmedi. İlk sen ol!")
	var mine: Variant = data.get("mine")
	lines.append("")
	if mine is Dictionary:
		lines.append("Senin en iyi: %s  ·  Sıran: %d  ·  %d bitiriş  ·  %d düşme" % [time_text(int(mine.best)), int(mine.rank), int(mine.runs), int(mine.falls)])
	else:
		lines.append("Henüz parkuru bitirmedin.")
	lines.append("Toplam %d bitiriş, %d oyuncu sıralamada." % [int(data.get("total", 0)), int(data.get("players", 0))])
	_releasing = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_main.player.set("controls_enabled", false)
	overlay.show_panel("\n".join(lines))


# --- Dice and card games ----------------------------------------------------------

## G: the guests within reach can be asked for a game.
func _open_games() -> void:
	if not _net.is_online():
		overlay.add_note("Zar ve kart için sunucuya bağlı olmalısın.")
		return
	var player: CharacterBody3D = _main.player
	var names: Array = []
	for g: Node in _guests.values():
		var node := g as Node3D
		if node.visible and node.global_position.distance_to(player.global_position) <= GAME_REACH:
			names.append(str(g.get("player_name")))
	_releasing = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.set("controls_enabled", false)
	overlay.open_games(names, int(_main.progression.profile.gold))


func _on_game_challenge(target: String, kind: String, bet: int) -> void:
	_net.challenge_game(target, kind, bet)
	overlay.add_note("%s oyuncusuna %d altınlık %s daveti gönderildi." % [target, bet, "zar" if kind == "dice" else "kart"])


func _on_game_answered(from_name: String, accept: bool) -> void:
	_net.answer_game(from_name, accept)
	if not accept:
		overlay.add_note("%s davetini reddettin." % from_name)


## Shows the first waiting invitation (or hides the box).
func _refresh_invite() -> void:
	if not active:
		return
	var invites: Array = _net.game_invites
	if invites.is_empty():
		overlay.hide_invite()
		return
	var inv: Dictionary = invites[0]
	overlay.show_invite(str(inv.from), str(inv.kind), int(inv.bet), int(_main.progression.profile.gold) >= int(inv.bet))
	overlay.add_note("%s seni oyuna çağırıyor (Y kabul, N reddet)." % str(inv.from))


## The server rolled a game this player is in: dice or cards fly over the
## middle between the two.
func _on_game_played(result: Dictionary) -> void:
	if not active:
		return
	var player: CharacterBody3D = _main.player
	var me := str(_net.account).to_lower()
	var pos := {}
	for i in 2:
		var side: Dictionary = result.a if i == 0 else result.b
		var who := str(side.name)
		var at: Vector3 = player.global_position
		if who.to_lower() != me:
			for g: Node in _guests.values():
				if str(g.get("player_name")).to_lower() == who.to_lower():
					at = (g as Node3D).global_position
		pos[i] = at
	var anim: Node3D = GameAnim.new()
	tavern.add_child(anim)
	var mid: Vector3 = ((pos[0] as Vector3) + (pos[1] as Vector3)) * 0.5
	if (pos[0] as Vector3).distance_to(pos[1] as Vector3) < 0.5:
		mid = player.global_position + Vector3(0, 0, 1.5)
	anim.global_position = Vector3(mid.x, player.global_position.y, mid.z)
	anim.call("setup", result, str(_net.account), pos[0], pos[1])
	var winner := int(result.winner)
	var won: bool = str((result.a if winner == 0 else result.b).name).to_lower() == me
	overlay.add_note("%s: %s %s, %s %s. %s" % ["Zar" if str(result.kind) == "dice" else "Kart", str(result.a.name), _hand_text(result, result.a), str(result.b.name), _hand_text(result, result.b), ("Kazandın! +%d altın" if won else "Kaybettin. -%d altın") % int(result.bet)])


func _hand_text(result: Dictionary, side: Dictionary) -> String:
	if str(result.kind) == "dice":
		return "%d" % int(side.total)
	return GameAnim._card_name(int(side.v[0]), int(side.v[1]))


func _on_chat_closed() -> void:
	if not active:
		return
	_main.player.set("controls_enabled", true)
	_releasing = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_was_captured = true


func _on_chat_submitted(text: String) -> void:
	_net.send_chat(text)


func _on_chat(from: int, from_name: String, text: String) -> void:
	if not active:
		return
	var mine: bool = from == _net.my_id
	overlay.add_line(from_name, text, mine)
	if mine:
		if _bubble:
			_bubble.text = text
			_bubble.visible = true
			get_tree().create_timer(HubGuest.BUBBLE_TIME).timeout.connect(func() -> void:
				if _bubble and _bubble.text == text:
					_bubble.visible = false)
	elif _guests.has(from):
		_guests[from].call("say", text)


## The connection dropped: nobody to meet, back to the menu.
func _on_status(status: String) -> void:
	if active and status != "online":
		_main.leave_hub()
		_main.main_menu.notify("Sunucu bağlantısı koptu, tavernadan çıktın.")
