class_name CombatEffects3D
extends Node3D

## Bounded, reusable cosmetic effects. Lifetime advances only with simulation.
const MAX_PULSES: int = 32
var pulses: Array[MeshInstance3D] = []
var ages: Array[float] = []
var radii: Array[float] = []
var world: Node
var plasma_material := WorldGeometry.material(Color("b56cff"), true)
var shock_material := WorldGeometry.material(Color("55dcff"), true)

func show_explosion(at: Vector3, radius: float) -> void:
	_show_pulse(at, radius, plasma_material)

func show_shock(at: Vector3, radius: float) -> void:
	_show_pulse(at, radius, shock_material)

func _show_pulse(at: Vector3, radius: float, material: Material) -> void:
	var index := ages.find(-1.0)
	if index < 0:
		if pulses.size() >= MAX_PULSES:
			return
		index = pulses.size()
		pulses.append(WorldGeometry.ring(self, 1.0, Color("b56cff")))
		ages.append(-1.0)
		radii.append(0.0)
	ages[index] = 0.0
	pulses[index].material_override = material
	radii[index] = radius
	pulses[index].position = WorldGeometry.planar(at) + Vector3(0, .045, 0)
	pulses[index].scale = Vector3(.12, .12, .12)
	pulses[index].visible = true
	if FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION):
		pulses[index].scale = Vector3(radius, .1, radius)

func _physics_process(delta: float) -> void:
	if not world.is_combat():
		return
	for index in range(pulses.size()):
		if ages[index] < 0:
			continue
		ages[index] += delta
		if ages[index] >= .3:
			ages[index] = -1.0
			pulses[index].visible = false
		else:
			var radius := lerpf(.12, radii[index], ages[index] / .3)
			if FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION):
				radius = radii[index]
			pulses[index].scale = Vector3(radius, .1, radius)

func reset() -> void:
	for index in range(pulses.size()):
		ages[index] = -1.0
		pulses[index].visible = false
