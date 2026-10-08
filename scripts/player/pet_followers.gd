## The pets in the account's open slots follow the player around during a
## run: walking pets trot behind on the ground, flying pets (phoenix, owl,
## dragon) flutter above. They are small, so they stay cute next to you.
extends Node3D

const PetModel := preload("res://scripts/player/pet_model.gd")
const Terrain := preload("res://scripts/world/terrain.gd")

## Spots around the player (right, left, behind), in the player's facing;
## flying pets keep further out to the side so they don't block the view.
const OFFSETS := [Vector3(1.3, 0, -0.6), Vector3(-1.3, 0, -0.6), Vector3(0.5, 0, -1.7)]
const FLY_OFFSET := Vector3(1.6, 0, 0.3)
const FLY_HEIGHT := 2.3
## Size of the pets next to the player (the menu shows them full size).
const WALK_SCALE := 0.42
const FLY_SCALE := 0.45

var player: Node3D
var terrain: Terrain
var _pets: Array[PetModel] = []


func setup(p_player: Node3D, p_terrain: Terrain) -> void:
	player = p_player
	terrain = p_terrain


## Shows these pet kinds (ids from data/pets.json) next to the player.
func set_pets(kinds: Array) -> void:
	for p in _pets:
		p.queue_free()
	_pets.clear()
	for n in mini(kinds.size(), OFFSETS.size()):
		var pet := PetModel.new()
		pet.build(str(kinds[n]))
		pet.scale = Vector3.ONE * (FLY_SCALE if pet.flies else WALK_SCALE)
		add_child(pet)
		pet.global_position = _spot(n)
		_pets.append(pet)


func count() -> int:
	return _pets.size()


func _spot(n: int) -> Vector3:
	var facing := float(player.get("facing"))
	var flying := _pets.size() > n and _pets[n].flies
	var offset: Vector3 = FLY_OFFSET * Vector3(1.0 if n != 1 else -1.0, 1, 1) if flying else OFFSETS[n]
	var at := player.global_position + Basis(Vector3.UP, facing) * offset
	var ground := terrain.height_at(at.x, at.z)
	return Vector3(at.x, ground + (FLY_HEIGHT if flying else 0.0), at.z)


func _process(delta: float) -> void:
	if player == null or not visible:
		return
	for n in _pets.size():
		var pet := _pets[n]
		var goal := _spot(n)
		var before := pet.global_position
		var to := goal - before
		to.y = 0.0
		# Catch up faster when far behind; snap back when lost.
		var follow := minf(1.0, delta * (3.0 + to.length() * 0.6))
		var next := before.lerp(goal, follow)
		if to.length() > 25.0:
			next = goal
		pet.global_position = next
		var moved := Vector2(next.x - before.x, next.z - before.z)
		var speed := moved.length() / maxf(delta, 0.001)
		if moved.length() > 0.01:
			pet.rotation.y = lerp_angle(pet.rotation.y, atan2(moved.x, moved.y), minf(1.0, delta * 10.0))
		pet.animate(delta, speed, true)
