class_name CoreObjective
extends Node3D

## The reactor core that enemies try to destroy in core mode. A fixed, static target: it takes hits from enemy
## contact and blasts, is repaired in the shop, and ends the run when it reaches zero.
var max_health: float = 75.0
var health: float = 75.0
var radius: float = GameConstants.CORE_RADIUS
var dead: bool = false
var crystal: MeshInstance3D
var crystal_material: StandardMaterial3D
var flash_time: float = 0.0
var pulse: float = 0.0

const FLASH_DURATION: float = .2
const HEALTHY := Color("58ece1")
const CRITICAL := Color("ff5a4a")
const BASE_COLOR := Color("1c3b47")

func _ready() -> void:
	var base_material := WorldGeometry.material(BASE_COLOR)
	base_material.metallic = .6
	var plinth := MeshInstance3D.new()
	var plinth_mesh := CylinderMesh.new()
	plinth_mesh.top_radius = radius * .8
	plinth_mesh.bottom_radius = radius
	plinth_mesh.height = .35
	plinth.mesh = plinth_mesh
	plinth.material_override = base_material
	plinth.position.y = .175
	add_child(plinth)
	WorldGeometry.ring(self, radius, HEALTHY).position.y = .04
	WorldGeometry.ring(self, radius + GameConstants.CORE_PLACEMENT_CLEARANCE, Color("2b5963")).position.y = .03
	crystal_material = WorldGeometry.material(HEALTHY, true)
	crystal_material.emission_energy_multiplier = 2.5
	crystal = WorldGeometry.sphere(self, radius * .5, Vector3(0, .35 + radius * .6, 0), crystal_material)
	crystal.scale = Vector3(1.0, 1.4, 1.0)
	var light := OmniLight3D.new()
	light.light_color = HEALTHY
	light.omni_range = 2.5 + radius * 2.0
	light.light_energy = 1.2
	light.position.y = 1.2
	light.shadow_enabled = false
	add_child(light)

func reset(new_max: float) -> void:
	max_health = new_max
	health = new_max
	dead = false
	flash_time = 0.0
	_refresh_colour()

func fraction() -> float:
	return clampf(health / maxf(max_health, .001), 0.0, 1.0)

## Applies damage and returns how much was actually taken.
func take_hit(amount: float) -> float:
	if dead or amount <= 0.0:
		return 0.0
	var applied := minf(health, amount)
	health -= applied
	flash_time = FLASH_DURATION
	if health <= 0.0:
		dead = true
	_refresh_colour()
	return applied

func repair(amount: float) -> float:
	if dead:
		return 0.0
	var applied := minf(amount, max_health - health)
	health += applied
	_refresh_colour()
	return applied

func _refresh_colour() -> void:
	if not crystal_material:
		return
	var colour := CRITICAL.lerp(HEALTHY, fraction())
	crystal_material.albedo_color = colour
	crystal_material.emission = colour

func _process(delta: float) -> void:
	if not crystal_material:
		return
	flash_time = maxf(0.0, flash_time - delta)
	pulse += delta * (2.0 + (1.0 - fraction()) * 4.0)
	var reduced := FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION)
	var beat := 0.0 if reduced else sin(pulse) * .25
	crystal_material.emission_energy_multiplier = 2.5 + beat + (6.0 if flash_time > 0.0 and not reduced else 0.0)
