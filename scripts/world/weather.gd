## Day and night over a run, plus rain and fog now and then. Evening falls
## every few minutes; at night enemies hit harder (`enemies.night`).
extends Node

const CYCLE := 300.0
const SPELL := 80.0
const SEQUENCE := ["clear", "rain", "clear", "fog", "clear", "storm"]
const NIGHT_SKY := [Color("#05081c"), Color("#1a1f45"), Color("#05060e")]
const NIGHT_AMBIENT := Color("#5a68b0")

var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var follow: Node3D
## 0 = day, 1 = deep night; and how strong the rain / fog is (0..1).
var night := 0.0
var rain := 0.0
var haze := 0.0
var kind := "clear"

var _base: Dictionary = {}
var _indoor := false
var _rain_node: GPUParticles3D


func setup(p_env: Environment, p_sky: ProceduralSkyMaterial, p_sun: DirectionalLight3D, p_follow: Node3D) -> void:
	env = p_env
	sky_mat = p_sky
	sun = p_sun
	follow = p_follow
	_rain_node = GPUParticles3D.new()
	_rain_node.amount = 700
	_rain_node.lifetime = 0.9
	_rain_node.emitting = false
	_rain_node.visibility_aabb = AABB(Vector3(-30, -20, -30), Vector3(60, 40, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(22, 0.5, 22)
	pm.direction = Vector3(0.15, -1, 0.05)
	pm.initial_velocity_min = 24.0
	pm.initial_velocity_max = 30.0
	pm.gravity = Vector3(0, -9, 0)
	_rain_node.process_material = pm
	var drop := QuadMesh.new()
	drop.size = Vector2(0.025, 0.55)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.75, 0.85, 1.0, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	drop.material = mat
	_rain_node.draw_pass_1 = drop
	add_child(_rain_node)


## The map's own look (the day look). Indoor maps have no weather.
func set_base(m: Dictionary) -> void:
	_base = {"sky": [Color(str(m.sky[0])), Color(str(m.sky[1])), Color(str(m.sky[2]))], "ambient": Color(str(m.ambient)),
		"ambient_e": float(m.ambientEnergy), "fog": Color(str(m.fog)), "fog_d": float(m.fogDensity),
		"sun": Color(str(m.sun)), "sun_e": float(m.sunEnergy)}
	_indoor = bool(m.get("indoor", false)) or str(m.get("props", "")) == "dungeon"
	night = 0.0
	rain = 0.0
	haze = 0.0
	kind = "clear"
	if _rain_node:
		_rain_node.emitting = false


## Night level (0..1) at a run time: day, dusk, night, dawn.
static func night_at(t: float) -> float:
	var p := fposmod(t, CYCLE) / CYCLE
	if p < 0.4:
		return 0.0
	if p < 0.55:
		return smoothstep(0.4, 0.55, p)
	if p < 0.85:
		return 1.0
	return 1.0 - smoothstep(0.85, 1.0, p)


## Weather of the spell the time falls in.
static func kind_at(t: float) -> String:
	if t < SPELL:
		return "clear"
	return str(SEQUENCE[int(t / SPELL) % SEQUENCE.size()])


func update(delta: float, t: float) -> void:
	if _base.is_empty() or env == null:
		return
	if _indoor:
		return
	kind = kind_at(t)
	night = night_at(t)
	var want_rain := 1.0 if kind == "rain" else (1.4 if kind == "storm" else 0.0)
	var want_haze := 1.0 if kind == "fog" else (0.4 if kind == "rain" or kind == "storm" else 0.0)
	rain = move_toward(rain, want_rain, delta * 0.5)
	haze = move_toward(haze, want_haze, delta * 0.4)
	_apply()
	if follow and _rain_node:
		_rain_node.global_position = follow.global_position + Vector3(0, 14, 0)
		_rain_node.emitting = rain > 0.05
		_rain_node.amount_ratio = clampf(rain, 0.05, 1.0)


func _apply() -> void:
	var dark := 1.0 - 0.35 * clampf(rain, 0.0, 1.0) - 0.25 * haze
	var sky_base: Array = _base.sky
	sky_mat.sky_top_color = (sky_base[0] as Color).lerp(NIGHT_SKY[0], night) * dark
	sky_mat.sky_horizon_color = (sky_base[1] as Color).lerp(NIGHT_SKY[1], night) * dark
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color.darkened(0.1)
	sky_mat.ground_bottom_color = (sky_base[2] as Color).lerp(NIGHT_SKY[2], night)
	env.ambient_light_color = (_base.ambient as Color).lerp(NIGHT_AMBIENT, night)
	env.ambient_light_energy = lerpf(float(_base.ambient_e), float(_base.ambient_e) * 0.8, night) * dark
	env.fog_light_color = (_base.fog as Color).lerp(NIGHT_SKY[1], night * 0.8)
	env.fog_density = float(_base.fog_d) * (1.0 + 4.0 * haze + 0.6 * night)
	sun.light_color = (_base.sun as Color).lerp(Color("#8fa4ff"), night)
	sun.light_energy = float(_base.sun_e) * lerpf(1.0, 0.25, night) * dark


## Back to the plain day look (menu).
func clear() -> void:
	if _base.is_empty() or env == null:
		return
	night = 0.0
	rain = 0.0
	haze = 0.0
	_apply()
	if _rain_node:
		_rain_node.emitting = false


## The tag shown in the HUD, "" when it's a clear day.
func label() -> String:
	var parts: Array[String] = []
	if night > 0.6:
		parts.append("Gece")
	elif night > 0.15:
		parts.append("Akşam")
	if kind == "rain" and rain > 0.3:
		parts.append("Yağmur")
	elif kind == "storm" and rain > 0.3:
		parts.append("Fırtına")
	elif kind == "fog" and haze > 0.3:
		parts.append("Sis")
	return " · ".join(parts)
