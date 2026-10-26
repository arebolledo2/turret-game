class_name CombatShot3D
extends RefCounted

## Snapshot of a shot at firing time; all distances/speeds are already in metres.
var travel_distance: float = 0.0
var attack_targets: Dictionary = {}
var critical: bool = false
var damage: float = 0.0
var speed: float = 0.0
var radius: float = .075
var visual_key: String = ""
var visual_scale: float = 1.0
var lifetime: float = 3.0
var splash_radius: float = 0.0
var knockback: float = 0.0
var slow_intensity: float = 0.0
var slow_duration: float = 0.0
var stagger_duration: float = 0.0
var stagger_cap: float = 0.0
var damage_type: GameEnums.DamageType = GameEnums.DamageType.PHYSICAL
var source_id: int = 0
var attack_families: Array[String] = []
## Extra enemies a non-splash projectile passes through after its first hit.
var pierce: int = 0
var ricochets: int = 0
var ricochet_range: float = 2.5

static func from_stats(stats: Dictionary, type: GameEnums.DamageType = GameEnums.DamageType.PHYSICAL) -> CombatShot3D:
	var view := TurretStats.new(stats)
	var shot := CombatShot3D.new()
	shot.damage = view.damage
	shot.speed = view.projectile_speed_metres
	shot.splash_radius = view.aoe_radius_metres
	shot.knockback = view.knockback_metres
	shot.damage_type = type
	shot.slow_intensity = view.slow_intensity
	shot.slow_duration = view.slow_duration
	shot.stagger_duration = view.stagger_seconds
	shot.pierce = view.pierce
	return shot

func copy() -> CombatShot3D:
	var shot := CombatShot3D.new()
	shot.damage = damage
	shot.critical = critical
	shot.speed = speed
	shot.radius = radius
	shot.visual_key = visual_key
	shot.visual_scale = visual_scale
	shot.lifetime = lifetime
	shot.splash_radius = splash_radius
	shot.knockback = knockback
	shot.damage_type = damage_type
	shot.slow_intensity = slow_intensity
	shot.slow_duration = slow_duration
	shot.stagger_duration = stagger_duration
	shot.stagger_cap = stagger_cap
	shot.source_id = source_id
	shot.attack_families = attack_families.duplicate()
	shot.ricochets = ricochets
	shot.ricochet_range = ricochet_range
	shot.pierce = pierce
	return shot
