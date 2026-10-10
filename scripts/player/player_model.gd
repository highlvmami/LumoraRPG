## Blocky character built from boxes. Faces +Z. The look depends on the class
## (tunic, hair, held weapon) and on the equipped gear: better weapon rarities
## get bigger, more detailed and glowing weapons, and a helmet shows when worn.
## Animates legs/arms from movement speed, plays the class attack, blinks when hurt.
extends Node3D

const Toon := preload("res://scripts/core/toon.gd")

const SKIN := Color("#f1c27d")
const PANTS := Color("#3b2f2a")
const EYES := Color("#1a1a1a")
const WOOD := Color("#8a5a2b")
const STEEL := Color("#c9d4e0")
const ATTACK_TIME := 0.28

var _visual: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _phase := 0.0
var _flash_time := 0.0
var _attack_time := 0.0
var _class := "archer"
## Seated (the tavern): legs forward, hands resting on the table.
var sitting := false
## Dancing (the tavern's dance floor): arms up, a bounce in the step.
var dancing := false


func _ready() -> void:
	if _visual == null:
		build({})


## Rebuilds the character. `look` keys (all optional):
##   class ("warrior"/"archer"/"mage"/"rogue"), tunic, hair (colors as strings),
##   weapon_tier (0-2, -1 = nothing equipped), weapon_color (rarity color),
##   helmet_color / armor_color / gloves_color / boots_color (worn gear, in its
##   rarity color; missing = not worn) and the matching *_tier (0-2) for detail.
func build(look: Dictionary) -> void:
	if _visual:
		_visual.queue_free()
	_class = str(look.get("class", "archer"))
	var tunic := Color(str(look.get("tunic", "#3a6ea5")))
	var hair := Color(str(look.get("hair", "#5a3820")))
	var tier := int(look.get("weapon_tier", -1))
	var glow := Color(str(look.get("weapon_color", "#ffffff")))
	var helmet := str(look.get("helmet_color", ""))

	_visual = Node3D.new()
	add_child(_visual)
	_box(_visual, Vector3(0.7, 0.75, 0.4), Vector3(0, 1.1, 0), tunic)
	_box(_visual, Vector3(0.74, 0.1, 0.44), Vector3(0, 0.8, 0), tunic.darkened(0.45))
	_box(_visual, Vector3(0.5, 0.5, 0.5), Vector3(0, 1.75, 0), SKIN)
	_box(_visual, Vector3(0.08, 0.08, 0.02), Vector3(-0.12, 1.78, 0.26), EYES)
	_box(_visual, Vector3(0.08, 0.08, 0.02), Vector3(0.12, 1.78, 0.26), EYES)
	if helmet != "":
		var hc := Color(helmet)
		var helmet_tier := int(look.get("helmet_tier", 0))
		_box(_visual, Vector3(0.58, 0.24, 0.58), Vector3(0, 2.0, 0), hc.darkened(0.15))
		_box(_visual, Vector3(0.6, 0.06, 0.6), Vector3(0, 1.9, 0), hc.darkened(0.45))
		if helmet_tier >= 1:
			# Crest on top.
			_glow(_box(_visual, Vector3(0.08, 0.16, 0.5), Vector3(0, 2.18, -0.02), hc), hc, 0.4)
		if helmet_tier >= 2:
			# Horns.
			var horn_l := _box(_visual, Vector3(0.08, 0.3, 0.08), Vector3(-0.32, 2.15, 0), Color("#f4f1e6"))
			horn_l.rotation.z = 0.5
			var horn_r := _box(_visual, Vector3(0.08, 0.3, 0.08), Vector3(0.32, 2.15, 0), Color("#f4f1e6"))
			horn_r.rotation.z = -0.5
	elif _class == "rogue":
		# Hood with a shadowed face opening.
		_box(_visual, Vector3(0.62, 0.34, 0.62), Vector3(0, 2.05, 0.0), tunic.darkened(0.15))
		_box(_visual, Vector3(0.66, 0.1, 0.66), Vector3(0, 1.9, 0.02), tunic.darkened(0.3))
		_box(_visual, Vector3(0.4, 0.2, 0.06), Vector3(0, 1.76, -0.3), Color("#101820"))
	elif _class == "mage":
		# Pointed wizard hat.
		_box(_visual, Vector3(0.7, 0.06, 0.7), Vector3(0, 2.02, 0), tunic.darkened(0.2))
		_box(_visual, Vector3(0.42, 0.3, 0.42), Vector3(0, 2.18, 0), tunic.darkened(0.2))
		var tip := _box(_visual, Vector3(0.22, 0.28, 0.22), Vector3(0, 2.42, -0.06), tunic.darkened(0.2))
		tip.rotation.x = -0.35
	else:
		_box(_visual, Vector3(0.54, 0.16, 0.54), Vector3(0, 2.02, -0.02), hair)
	if _class == "mage":
		# Robe skirt and a beard.
		_box(_visual, Vector3(0.74, 0.4, 0.44), Vector3(0, 0.6, 0), tunic.darkened(0.1))
		_box(_visual, Vector3(0.3, 0.2, 0.06), Vector3(0, 1.55, 0.26), hair)
	elif _class == "rogue":
		# Scarf and a belt of knives.
		_box(_visual, Vector3(0.44, 0.14, 0.4), Vector3(0, 1.62, 0.0), Color("#3fd0c0").darkened(0.2))
		_box(_visual, Vector3(0.78, 0.08, 0.48), Vector3(0, 0.98, 0), STEEL.darkened(0.55))
	elif _class == "warrior":
		# Shoulder plates.
		_box(_visual, Vector3(0.3, 0.14, 0.34), Vector3(-0.47, 1.5, 0), STEEL)
		_box(_visual, Vector3(0.3, 0.14, 0.34), Vector3(0.47, 1.5, 0), STEEL)

	_leg_l = _limb(Vector3(-0.17, 0.72, 0), Vector3(0.24, 0.72, 0.26), PANTS)
	_leg_r = _limb(Vector3(0.17, 0.72, 0), Vector3(0.24, 0.72, 0.26), PANTS)
	_arm_l = _limb(Vector3(-0.47, 1.45, 0), Vector3(0.2, 0.65, 0.22), tunic)
	_arm_r = _limb(Vector3(0.47, 1.45, 0), Vector3(0.2, 0.65, 0.22), tunic)
	_build_gear(look)
	match _class:
		"warrior":
			_build_sword(tier, glow)
		"mage":
			_build_staff(tier, glow)
		"rogue":
			_build_daggers(tier, glow)
		_:
			_build_bow(tier, glow)


## Worn armor, gloves and boots drawn over the body in their rarity color.
func _build_gear(look: Dictionary) -> void:
	var armor := str(look.get("armor_color", ""))
	if armor != "":
		var ac := Color(armor)
		var armor_tier := int(look.get("armor_tier", 0))
		_box(_visual, Vector3(0.74, 0.5, 0.44), Vector3(0, 1.22, 0), ac.darkened(0.25))
		_box(_visual, Vector3(0.12, 0.42, 0.46), Vector3(0, 1.22, 0), ac.darkened(0.5))
		if armor_tier >= 1:
			_box(_visual, Vector3(0.32, 0.12, 0.38), Vector3(-0.48, 1.52, 0), ac)
			_box(_visual, Vector3(0.32, 0.12, 0.38), Vector3(0.48, 1.52, 0), ac)
		if armor_tier >= 2:
			_glow(_box(_visual, Vector3(0.14, 0.14, 0.04), Vector3(0, 1.3, 0.23), ac), ac, 1.4)
	var gloves := str(look.get("gloves_color", ""))
	if gloves != "":
		var gc := Color(gloves)
		for arm: Node3D in [_arm_l, _arm_r]:
			_box(arm, Vector3(0.26, 0.2, 0.28), Vector3(0, -0.56, 0), gc.darkened(0.2))
			if int(look.get("gloves_tier", 0)) >= 2:
				_glow(_box(arm, Vector3(0.28, 0.05, 0.3), Vector3(0, -0.44, 0), gc), gc, 0.8)
	var boots := str(look.get("boots_color", ""))
	if boots != "":
		var bc := Color(boots)
		for leg: Node3D in [_leg_l, _leg_r]:
			_box(leg, Vector3(0.28, 0.24, 0.34), Vector3(0, -0.6, 0.03), bc.darkened(0.3))
			if int(look.get("boots_tier", 0)) >= 2:
				var wing := _box(leg, Vector3(0.04, 0.16, 0.22), Vector3(0.16 if leg == _leg_r else -0.16, -0.5, -0.08), bc)
				_glow(wing, bc, 0.9)


## Sword in the right hand. Tier 1 adds a cross guard and a longer blade,
## tier 2 a wide glowing blade and a gem.
func _build_sword(tier: int, glow: Color) -> void:
	var hand := Node3D.new()
	hand.position = Vector3(0, -0.62, 0.05)
	_arm_r.add_child(hand)
	var length := 0.8 + 0.2 * maxi(tier, 0)
	var width := 0.1 + (0.05 if tier >= 2 else 0.0)
	_box(hand, Vector3(0.06, 0.2, 0.06), Vector3(0, 0, 0), WOOD)
	_box(hand, Vector3(0.3 if tier >= 1 else 0.2, 0.06, 0.08), Vector3(0, 0.12, 0), STEEL.darkened(0.3) if tier < 1 else glow)
	var blade := _box(hand, Vector3(width, length, 0.04), Vector3(0, 0.15 + length * 0.5, 0), STEEL)
	if tier >= 1:
		_glow(blade, glow, 0.25 if tier == 1 else 0.7)
	if tier >= 2:
		_glow(_box(hand, Vector3(0.1, 0.1, 0.1), Vector3(0, 0.12, 0.05), glow), glow, 1.5)


## Bow in the left hand. Higher tiers: longer limbs, colored tips, a glowing string.
func _build_bow(tier: int, glow: Color) -> void:
	var bow := Node3D.new()
	bow.position = Vector3(0, -0.62, 0.08)
	_arm_l.add_child(bow)
	var wood := WOOD if tier < 2 else glow.darkened(0.4)
	var tip_len := 0.3 + 0.08 * maxi(tier, 0)
	_box(bow, Vector3(0.06, 0.5, 0.06), Vector3(0, 0, 0.12), wood)
	var tip_top := _box(bow, Vector3(0.06, tip_len, 0.06), Vector3(0, 0.36, 0.04), wood)
	tip_top.rotation.x = -0.5
	var tip_bottom := _box(bow, Vector3(0.06, tip_len, 0.06), Vector3(0, -0.36, 0.04), wood)
	tip_bottom.rotation.x = 0.5
	var string := _box(bow, Vector3(0.02, 0.95 + 0.1 * maxi(tier, 0), 0.02), Vector3(0, 0, -0.04), Color("#e8e2d0"))
	if tier >= 1:
		_glow(_box(bow, Vector3(0.1, 0.1, 0.1), Vector3(0, 0.5, -0.04), glow), glow, 0.8)
		_glow(_box(bow, Vector3(0.1, 0.1, 0.1), Vector3(0, -0.5, -0.04), glow), glow, 0.8)
	if tier >= 2:
		_glow(string, glow, 1.2)


## Staff in the right hand with an orb on top; the orb grows and glows with the tier.
func _build_staff(tier: int, glow: Color) -> void:
	var hand := Node3D.new()
	hand.position = Vector3(0, -0.62, 0.05)
	_arm_r.add_child(hand)
	var orb_color := Color("#b98cff") if tier < 0 else glow
	_box(hand, Vector3(0.07, 1.5, 0.07), Vector3(0, 0.3, 0), WOOD)
	var orb_size := 0.18 + 0.06 * maxi(tier, 0)
	_glow(_box(hand, Vector3.ONE * orb_size, Vector3(0, 1.1, 0), orb_color), orb_color, 0.6 + 0.5 * maxi(tier, 0))
	if tier >= 1:
		# Prongs holding the orb.
		_box(hand, Vector3(0.05, 0.25, 0.05), Vector3(-0.12, 1.05, 0), STEEL)
		_box(hand, Vector3(0.05, 0.25, 0.05), Vector3(0.12, 1.05, 0), STEEL)
	if tier >= 2:
		var ring := _box(hand, Vector3(0.5, 0.04, 0.5), Vector3(0, 1.1, 0), glow)
		ring.rotation.y = 0.78
		_glow(ring, glow, 1.2)


## A dagger in each hand. Higher tiers: longer, glowing blades.
func _build_daggers(tier: int, glow: Color) -> void:
	for arm: Node3D in [_arm_r, _arm_l]:
		var hand := Node3D.new()
		hand.position = Vector3(0, -0.62, 0.05)
		arm.add_child(hand)
		var length := 0.45 + 0.1 * maxi(tier, 0)
		_box(hand, Vector3(0.06, 0.16, 0.06), Vector3(0, 0, 0), WOOD)
		_box(hand, Vector3(0.18, 0.05, 0.08), Vector3(0, 0.1, 0), STEEL.darkened(0.3))
		var blade := _box(hand, Vector3(0.07, length, 0.03), Vector3(0, 0.12 + length * 0.5, 0), STEEL)
		if tier >= 1:
			_glow(blade, glow, 0.3 if tier == 1 else 0.8)


## Called every frame by the player with its current movement state.
func animate(delta: float, speed: float, on_floor: bool) -> void:
	if dancing and not sitting:
		_phase += delta * 9.0
		var beat := sin(_phase)
		_leg_l.rotation.x = beat * 0.7
		_leg_r.rotation.x = -beat * 0.7
		_arm_l.rotation.x = -2.5 + sin(_phase * 0.5) * 0.5
		_arm_r.rotation.x = -2.5 - sin(_phase * 0.5) * 0.5
		_arm_r.rotation.z = 0.0
		_arm_r.position.z = 0.0
		_visual.rotation.x = 0.0
		_visual.rotation.z = sin(_phase * 0.5) * 0.12
		_visual.position.y = absf(beat) * 0.12
		return
	_visual.rotation.z = 0.0
	_visual.position.y = 0.0
	if sitting:
		_phase += delta
		_leg_l.rotation.x = -1.5
		_leg_r.rotation.x = -1.5
		_arm_l.rotation.x = -0.75 + sin(_phase * 1.3) * 0.05
		_arm_r.rotation.x = -0.75 - sin(_phase * 1.1 + 1.0) * 0.08
		_arm_r.rotation.z = 0.0
		_arm_r.position.z = 0.0
		_visual.rotation.x = sin(_phase * 0.8) * 0.03
		return
	var amount := clampf(speed / 9.0, 0.0, 1.0)
	_phase += delta * (4.0 + speed * 0.9)
	var swing := sin(_phase) * 0.9 * amount
	if not on_floor:
		swing = 0.0
	var leg_tuck := 0.0 if on_floor else 0.6
	_leg_l.rotation.x = swing - leg_tuck
	_leg_r.rotation.x = -swing - leg_tuck * 0.4
	_arm_l.rotation.x = -swing
	_arm_r.rotation.x = swing
	_arm_r.rotation.z = 0.0
	_arm_r.position.z = 0.0
	_visual.rotation.x = 0.0

	_attack_time = maxf(0.0, _attack_time - delta)
	if _attack_time > 0.0:
		var t := 1.0 - _attack_time / ATTACK_TIME
		var pull := sin(t * PI)
		match _class:
			"warrior":
				# Overhead swing across the body.
				_arm_r.rotation.x = lerpf(-2.6, -0.4, t)
				_arm_r.rotation.z = lerpf(0.4, -0.6, t)
				_visual.rotation.x = 0.12 * pull
			"rogue":
				# Quick cross-slash with both hands.
				_arm_r.rotation.x = lerpf(-2.2, -0.6, t)
				_arm_l.rotation.x = lerpf(-0.6, -2.2, t)
				_visual.rotation.x = 0.08 * pull
			"mage":
				# Thrust the staff forward.
				_arm_r.rotation.x = -1.3 - 0.3 * pull
				_visual.rotation.x = -0.05 * pull
			_:
				# Bow shot: raise the bow arm, pull the string arm back, release.
				_arm_l.rotation.x = -1.5
				_arm_r.rotation.x = -1.5 + pull * 0.5
				_arm_r.position.z = -0.25 * pull
				_visual.rotation.x = -0.08 * pull

	# Blink while invulnerable after taking a hit.
	_flash_time = maxf(0.0, _flash_time - delta)
	_visual.visible = _flash_time <= 0.0 or fmod(_flash_time, 0.1) < 0.05


func flash() -> void:
	_flash_time = 0.5


func attack() -> void:
	_attack_time = ATTACK_TIME


func _glow(instance: MeshInstance3D, color: Color, energy: float) -> void:
	var mat := instance.material_override as StandardMaterial3D
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy


func _box(parent: Node3D, box_size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = Toon.material(color)
	instance.position = pos
	parent.add_child(instance)
	return instance


## A limb pivots at its top (hip or shoulder).
func _limb(pivot_pos: Vector3, box_size: Vector3, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_pos
	_visual.add_child(pivot)
	_box(pivot, box_size, Vector3(0, -box_size.y * 0.5, 0), color)
	return pivot
