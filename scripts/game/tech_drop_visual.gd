class_name TechDropVisual
extends Node3D

## Cosmetic life for the Tech Vault model: the two core rings spin on their own axes and a
## cyan light beside the core breathes gently. Gameplay and hurtboxes stay on TechDropActor.
const RING_SPEEDS := Vector2(.9, -1.3) # rad/s: Ring_Outer about Y, Ring_Inner about X
var outer: Node3D
var inner: Node3D
var core: Node3D
var light: OmniLight3D
var angles := Vector2.ZERO
var phase: float = 0.0

func setup(model: Node3D) -> void:
	outer = model.find_child("Ring_Outer", true, false) as Node3D
	inner = model.find_child("Ring_Inner", true, false) as Node3D
	core = model.find_child("Core", true, false) as Node3D
	light = OmniLight3D.new()
	light.light_color = Color("5be6ff")
	light.omni_range = 2.2
	light.light_energy = .7
	light.shadow_enabled = false
	# Parented to the core empty so the light sits at the core wherever the model puts it.
	(core if core != null else self).add_child(light)
	model.add_child(self)

func _process(delta: float) -> void:
	var reduced := FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION)
	var speed := GameConstants.REDUCED_MOTION_SPEED if reduced else 1.0
	angles += RING_SPEEDS * delta * speed
	angles = Vector2(fposmod(angles.x, TAU), fposmod(angles.y, TAU))
	# Absolute rotations avoid incremental basis drift on long waves.
	if outer != null:
		outer.rotation = Vector3(0, angles.x, 0)
	if inner != null:
		inner.rotation = Vector3(angles.y, 0, 0)
	if not reduced:
		phase = fmod(phase + delta * 1.6, TAU)
	light.light_energy = .7 + (0.0 if reduced else sin(phase) * .15)
