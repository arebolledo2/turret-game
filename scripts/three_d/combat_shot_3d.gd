class_name CombatShot3D
extends RefCounted

## Snapshot of a shot at firing time; all distances/speeds are already in metres.
var damage: float = 0.0
var speed: float = 0.0
var splash_radius: float = 0.0
var knockback: float = 0.0
var slow_intensity: float = 0.0
var slow_duration: float = 0.0
var damage_type: GameEnums.DamageType = GameEnums.DamageType.PHYSICAL

static func from_stats(stats: Dictionary, type: GameEnums.DamageType = GameEnums.DamageType.PHYSICAL) -> CombatShot3D:
	var shot := CombatShot3D.new()
	shot.damage = maxf(float(stats.get("damage", 0.0)), 0.0)
	shot.speed = maxf(float(stats.get("projectile_speed", 0.0)), 0.0) * SliceGeometry.METRES_PER_PIXEL
	shot.splash_radius = maxf(float(stats.get("aoe_radius", 0.0)), 0.0) * SliceGeometry.METRES_PER_PIXEL
	shot.knockback = maxf(float(stats.get("knockback_force", 0.0)), 0.0) * SliceGeometry.METRES_PER_PIXEL
	shot.damage_type = type
	shot.slow_intensity = clampf(float(stats.get("slow_intensity", 0.0)), 0.0, .9)
	shot.slow_duration = maxf(float(stats.get("slow_duration", 0.0)), 0.0)
	return shot

func copy() -> CombatShot3D:
	var shot := CombatShot3D.new()
	shot.damage = damage
	shot.speed = speed
	shot.splash_radius = splash_radius
	shot.knockback = knockback
	shot.damage_type = damage_type
	shot.slow_intensity = slow_intensity
	shot.slow_duration = slow_duration
	return shot
