class_name MuzzleLights
extends RefCounted

## Short pooled omni flashes at turret muzzles. `CombatEffects3D` owns one and ticks it; the lights are children of `host`,
## the pool is capped and the oldest light is recycled when it is full.
const MAX_LIGHTS: int = 8
const LIFETIME: float = .09
const ENERGY: float = 2.2
const RANGE: float = 3.2
const REDUCED_MOTION_SCALE: float = .35
## Flash colour by damage type; callers may pass their own.
const COLORS: Dictionary = {
	GameEnums.DamageType.PHYSICAL: Color(1.0, .85, .55),
	GameEnums.DamageType.FIRE: Color(1.0, .55, .15),
	GameEnums.DamageType.ELECTRIC: Color(.5, .85, 1.0),
	GameEnums.DamageType.PLASMA: Color(.75, .4, 1.0),
}
var host: CombatEffects3D
var lights: Array[OmniLight3D] = []
var ages: Array[float] = []
var energies: Array[float] = []
var next_light: int = 0

func _init(owner: CombatEffects3D) -> void:
	host = owner

static func color_for(damage_type: int) -> Color:
	return COLORS.get(damage_type, COLORS[GameEnums.DamageType.PHYSICAL])

## Flashes a light at `at`; `strength` scales its energy (the Laser's sustained glow uses less).
func flash(at: Vector3, color: Color, strength: float = 1.0) -> void:
	var index := next_light
	if lights.size() < MAX_LIGHTS:
		index = lights.size()
		var light := OmniLight3D.new()
		light.omni_range = RANGE
		light.shadow_enabled = false
		light.visible = false
		host.add_child(light)
		lights.append(light)
		ages.append(-1.0)
		energies.append(0.0)
	else:
		next_light = (next_light + 1) % MAX_LIGHTS
	lights[index].position = at
	lights[index].light_color = color
	lights[index].light_energy = ENERGY * strength
	lights[index].visible = true
	energies[index] = ENERGY * strength
	ages[index] = 0.0

func update(delta: float) -> void:
	var scale := REDUCED_MOTION_SCALE if FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION) else 1.0
	for index in range(lights.size()):
		if ages[index] < 0.0:
			continue
		ages[index] += delta
		if ages[index] >= LIFETIME:
			ages[index] = -1.0
			lights[index].visible = false
			continue
		var remaining := 1.0 - ages[index] / LIFETIME
		lights[index].light_energy = energies[index] * scale * remaining * remaining

func reset() -> void:
	for index in range(lights.size()):
		ages[index] = -1.0
		lights[index].visible = false
