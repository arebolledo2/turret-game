class_name CoreReactorVisual
extends Node3D

## Singleton reactor decoration. Gameplay and collision remain on CoreObjective.
const ORB_SHADER: Shader = preload("res://assets/shaders/core_orb.gdshader")
var rings: Array[Node3D] = []
var orb_material: ShaderMaterial
var light: OmniLight3D
var phase: float = 0.0
var angles := Vector3.ZERO

func _ready() -> void:
	var model := ClockworkModels.instantiate("core")
	add_child(model)
	for part: String in ["Ring_Outer", "Ring_Middle", "Ring_Inner"]:
		rings.append(model.find_child(part, true, false) as Node3D)
	var orb := model.find_child("Orb", true, false) as MeshInstance3D
	orb_material = ShaderMaterial.new()
	orb_material.shader = ORB_SHADER
	orb.material_override = orb_material
	light = OmniLight3D.new()
	light.position = Vector3(0, .9, 0)
	light.omni_range = 2.8
	light.light_energy = .8
	light.shadow_enabled = false
	add_child(light)

func tick(delta: float, health_fraction: float, destroyed: bool, flash: float, reduced: bool) -> void:
	if not reduced and not destroyed:
		phase = fmod(phase + delta * .8, TAU * 10.0)
		angles += Vector3(.48, -.76, 1.06) * delta
		for i in range(3):
			angles[i] = fposmod(angles[i], TAU)
		# Apply absolute rotations to avoid incremental basis drift during long convoy runs.
		rings[0].rotation = Vector3(0, angles.x, 0)
		rings[1].rotation = Vector3(angles.y, 0, 0)
		rings[2].rotation = Vector3(0, 0, angles.z)
	var tint := CoreObjective.CRITICAL.lerp(CoreObjective.HEALTHY, health_fraction)
	var power := .07 if destroyed else 1.0
	orb_material.set_shader_parameter("phase", phase)
	orb_material.set_shader_parameter("energy_color", tint)
	orb_material.set_shader_parameter("power", power)
	orb_material.set_shader_parameter("hit", 0.0 if reduced or destroyed else flash * 1.2)
	light.light_color = tint
	light.light_energy = 0.0 if destroyed else .8 + (.0 if reduced else sin(phase * 2.0) * .08)
