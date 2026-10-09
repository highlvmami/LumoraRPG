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


func setup(p_main: Node, p_net: Node) -> void:
	_main = p_main
	_net = p_net
	_net.hub_changed.connect(_on_hub_changed)
	_net.hub_state_received.connect(_on_state)
	_net.hub_chat_received.connect(_on_chat)
	_net.status_changed.connect(_on_status)


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
	player.set("speed_multiplier", WALK_SCALE)
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


## Walks out (back to the menu is the caller's job).
func leave() -> void:
	if not active:
		return
	active = false
	_stand_up(false)
	overlay.close_chat()
	overlay.visible = false
	var player: CharacterBody3D = _main.player
	player.set("speed_multiplier", 1.0)
	player.set("controls_enabled", true)
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
			overlay.add_note(CATCHES.pick_random())
		"talk":
			overlay.add_note("Bora: " + RUMORS.pick_random())


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
	elif key == KEY_ESCAPE:
		_main.leave_hub()
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
	# Swings swing while someone is on them.
	var used := {}
	if _action == "swing":
		used[int(tavern.interactables[_object].swing)] = true
	for g: Node in _guests.values():
		if g.is_seated() and str(g.action) == "swing":
			used[int(tavern.interactables[int(g.object)].swing)] = true
	for k in 2:
		tavern.set_swing_occupied(k, used.has(k))
	_update_prompt(player)
	_state_timer -= delta
	_heartbeat += delta
	if _state_timer <= 0.0:
		_state_timer = STATE_TIME
		_send_state(false)
	# Losing the mouse (Esc in a browser) while walking leaves the tavern.
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _was_captured and not captured and not overlay.is_typing() and not _releasing:
		_main.leave_hub()
		return
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
