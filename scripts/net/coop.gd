## Live co-op in a room. The room's host runs the run (enemies, bosses,
## spawns); every player sends where their character is, and the host sends
## a snapshot of the enemies about 10 times a second plus events (kills,
## bosses, attack warnings). Partners show those enemies as a mirror and send
## their hits to the host; the host sends back the damage partners take.
## Kills give EXP and gold to everyone in the run.
extends Node

const RemotePlayer := preload("res://scripts/net/remote_player.gd")
const STATE_TIME := 1.0 / 15.0
const SNAP_TIME := 1.0 / 10.0
const LOOK_TIME := 3.0

## A co-op run is going on (as host or partner).
var running := false
## This game is a partner's mirror of the host's run.
var guest_run := false
## A real-time duel: two players, no enemies; weapons aim at the other player.
var pvp := false
## How many snapshots this game sent / got (tests).
var snapshots_sent := 0
var snapshots_received := 0

var main: Node
var net: Node
var _puppets := {}
var _state_timer := 0.0
var _snap_timer := 0.0
var _look_timer := 0.0
var _attacks := 0
## Hits waiting to go to the host: uid, damage, push x, push z, ...
var _hits: Array = []


func setup(p_main: Node, p_net: Node) -> void:
	main = p_main
	net = p_net
	net.game_message.connect(_on_game)
	net.room_changed.connect(_on_room_changed)
	var enemies: Node = main.enemies
	enemies.enemy_killed.connect(func(at: Vector3, exp_amount: int, gold_amount: int) -> void:
		_host_event({"n": "kill", "a": [at.x, at.y, at.z], "x": exp_amount, "g": gold_amount}))
	enemies.kind_unlocked.connect(func(kind_name: String) -> void: _host_event({"n": "unlock", "s": kind_name}))
	enemies.boss_spawned.connect(func(boss_name: String) -> void: _host_event({"n": "boss", "s": boss_name}))
	enemies.boss_defeated.connect(func(boss_name: String) -> void: _host_event({"n": "bossdown", "s": boss_name}))
	enemies.boss_phase_changed.connect(func(boss_name: String, phase: int) -> void:
		_host_event({"n": "phase", "s": boss_name, "p": phase}))
	enemies.attacks.zone_added.connect(func(spec: Dictionary) -> void:
		if running and not guest_run:
			net.send_game({"k": "z", "z": spec}))
	enemies.remote_hit.connect(_on_remote_hit)
	main.ultimate.cast.connect(func(variant: String, at: Vector3) -> void:
		if running:
			net.send_game({"k": "ult", "v": variant, "p": [snappedf(at.x, 0.01), snappedf(at.y, 0.01), snappedf(at.z, 0.01)]}))
	main.weapons.attacked.connect(func(_dir: Vector3) -> void: _attacks += 1)
	main.bow.fired.connect(func(_dir: Vector3) -> void: _attacks += 1)


## Partners in the room (everyone but this player).
func partner_count() -> int:
	return maxi(0, net.members().size() - 1) if net.in_room() else 0


## The host starts a run for the whole room on `map_id`.
func start_as_host(map_id: String) -> void:
	_begin(false)
	net.send_game({"k": "start", "map": map_id})


func start_as_guest() -> void:
	_begin(true)


## The host starts a 1v1 duel with the other player in the room.
func start_duel_as_host() -> void:
	_begin(false)
	pvp = true
	net.send_game({"k": "start", "map": "dungeon", "pvp": true})


func start_duel_as_guest() -> void:
	_begin(true)
	pvp = true


func _begin(as_guest: bool) -> void:
	_clear_puppets()
	running = true
	guest_run = as_guest
	_hits.clear()
	_state_timer = 0.0
	_snap_timer = 0.0
	_look_timer = 0.0
	_send_state(true)


## This player leaves the run: a host ends it for everyone.
func leave() -> void:
	if not running:
		return
	net.send_game({"k": "end"} if not guest_run else {"k": "bye"})
	stop()


func stop() -> void:
	running = false
	pvp = false
	guest_run = false
	_hits.clear()
	_clear_puppets()


func puppet(id: int) -> Node3D:
	return _puppets.get(id)


func puppets() -> Array:
	return _puppets.values()


## The party for the HUD list: this player first, then the partners.
func party() -> Array:
	if not running:
		return []
	var names: Dictionary = main.main_menu.CLASS_NAMES
	var p: Node3D = main.player
	var out: Array = [{"name": str(main.inventory.active_character().get("name", "")), "account": str(main.progression.profile.name),
		"class": names.get(main.class_id(), ""), "hp": float(p.get("hp")), "max_hp": float(p.get("max_hp")), "dead": bool(p.get("dead")), "me": true}]
	for r: Node3D in _puppets.values():
		out.append({"name": r.character_name if r.character_name != "" else r.player_name, "account": r.player_name,
			"class": names.get(r.class_id, ""), "hp": r.hp, "max_hp": r.max_hp, "dead": r.dead})
	return out


func _process(delta: float) -> void:
	if not running:
		return
	_state_timer -= delta
	if _state_timer <= 0.0:
		_state_timer = STATE_TIME
		_look_timer -= STATE_TIME
		_send_state(_look_timer <= 0.0)
	if pvp:
		_pvp_tick()
		return
	if guest_run:
		if not _hits.is_empty():
			net.send_game({"k": "hits", "h": _hits}, int(net.room.get("host", 0)))
			_hits = []
		return
	_snap_timer -= delta
	if _snap_timer <= 0.0:
		_snap_timer = SNAP_TIME
		var snap: Dictionary = main.enemies.snapshot()
		snap.k = "s"
		net.send_game(snap)
		snapshots_sent += 1
	# Everybody fell: the run is over for the host too.
	if main.player.dead and main.enemies.active and main.enemies.alive_targets().is_empty():
		main.enemies.active = false


func _pvp_tick() -> void:
	if _puppets.is_empty():
		return
	var r: Node3D = _puppets.values()[0]
	main.enemies.set_duelist(r.global_position, 0.0, r.hp / r.max_hp)
	if r.dead and not main.player.dead:
		main.call("pvp_finished", true)


func _send_state(with_look: bool) -> void:
	var p: Node3D = main.player
	var d := {"k": "p", "p": [snappedf(p.global_position.x, 0.01), snappedf(p.global_position.y, 0.01), snappedf(p.global_position.z, 0.01)],
		"f": snappedf(float(p.get("facing")), 0.01), "s": snappedf(float(p.call("horizontal_speed")), 0.1),
		"hp": roundf(float(p.get("hp"))), "mh": roundf(float(p.get("max_hp"))), "d": bool(p.get("dead")), "a": _attacks,
		"cn": str(main.inventory.active_character().get("name", "")), "cl": str(main.class_id())}
	if with_look:
		_look_timer = LOOK_TIME
		d.lk = main.character_look(main.inventory.active_character())
	net.send_game(d)


func _host_event(d: Dictionary) -> void:
	if running and not guest_run:
		d.k = "ev"
		net.send_game(d)


func _on_remote_hit(uid: int, amount: float, push_dir: Vector3) -> void:
	if running and pvp:
		if not _puppets.is_empty():
			net.send_game({"k": "pvp", "a": snappedf(amount, 0.1)}, int(_puppets.keys()[0]))
		return
	if running and guest_run:
		_hits.append_array([uid, snappedf(amount, 0.1), snappedf(push_dir.x, 0.01), snappedf(push_dir.z, 0.01)])


func _on_game(from: int, d: Dictionary) -> void:
	var host := int(net.room.get("host", 0))
	match str(d.get("k", "")):
		"start":
			if from == host:
				main.call("join_coop_run", str(d.get("map", "forest")), bool(d.get("pvp", false)))
		"end":
			if from == host and running and guest_run:
				main.call("coop_host_ended")
		"bye":
			_remove_puppet(from)
		"p":
			if running:
				_puppet_for(from).apply_state(d)
		"s":
			if running and guest_run and from == host:
				snapshots_received += 1
				main.enemies.apply_snapshot(d)
		"ev":
			if running and guest_run and from == host:
				_replay_event(d)
		"z":
			if running and guest_run and from == host and d.get("z") is Dictionary:
				main.enemies.attacks.replay(d.z)
		"hits":
			if running and not guest_run:
				_apply_hits(d.get("h", []))
		"ult":
			# A partner's ultimate: show it here (their game sends the hits).
			if running:
				var p: Array = d.get("p", [0, 0, 0])
				main.ultimate.play(str(d.get("v", "")), Vector3(float(p[0]), float(p[1]), float(p[2])), false)
		"pvp":
			if running and pvp:
				main.player.take_damage(float(d.get("a", 0.0)))
		"hurt":
			if running and from == host:
				main.player.take_damage(float(d.get("a", 0.0)))


func _replay_event(d: Dictionary) -> void:
	var enemies: Node = main.enemies
	match str(d.get("n", "")):
		"kill":
			var a: Array = d.get("a", [0, 0, 0])
			enemies.enemy_killed.emit(Vector3(float(a[0]), float(a[1]), float(a[2])), int(d.get("x", 0)), int(d.get("g", 0)))
		"unlock":
			enemies.kind_unlocked.emit(str(d.get("s", "")))
		"boss":
			enemies.boss_spawned.emit(str(d.get("s", "")))
		"bossdown":
			enemies.boss_defeated.emit(str(d.get("s", "")))
		"phase":
			enemies.boss_phase_changed.emit(str(d.get("s", "")), int(d.get("p", 2)))


func _apply_hits(h: Array) -> void:
	var enemies: Node = main.enemies
	for j in h.size() / 4:
		var i: int = enemies.index_of_uid(int(h[j * 4]))
		if i >= 0:
			enemies.damage(i, float(h[j * 4 + 1]), Vector3(float(h[j * 4 + 2]), 0.0, float(h[j * 4 + 3])))


func _puppet_for(id: int) -> Node3D:
	if _puppets.has(id):
		return _puppets[id]
	var r := RemotePlayer.new()
	r.name = "Partner%d" % id
	main.world.add_child(r)
	r.setup(id, net.member_name(id))
	r.hurt.connect(func(amount: float) -> void: net.send_game({"k": "hurt", "a": snappedf(amount, 0.1)}, id))
	_puppets[id] = r
	if not guest_run:
		(main.enemies.targets as Array).append(r)
	return r


func _remove_puppet(id: int) -> void:
	var r: Node3D = _puppets.get(id)
	if r == null:
		return
	_puppets.erase(id)
	(main.enemies.targets as Array).erase(r)
	r.queue_free()


func _clear_puppets() -> void:
	for id: int in _puppets.keys():
		_remove_puppet(id)


func _on_room_changed() -> void:
	if not running:
		return
	if not net.in_room():
		if guest_run:
			main.call("coop_host_ended")
		else:
			stop()
		return
	# Partners who left the room leave the run.
	var ids := {}
	for m: Dictionary in net.members():
		ids[int(m.id)] = true
	for id: int in _puppets.keys():
		if not ids.has(id):
			_remove_puppet(id)
