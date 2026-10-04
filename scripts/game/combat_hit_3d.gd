class_name CombatHit3D
extends RefCounted

## Damage is unitless; impulse is metres/second on the ground plane.
var damage: float = 0.0
var damage_type: GameEnums.DamageType = GameEnums.DamageType.PHYSICAL
var origin: Vector3 = Vector3.ZERO
var impulse: Vector3 = Vector3.ZERO
var slow_intensity: float = 0.0
var slow_duration: float = 0.0
## Turret that produced the hit (`TurretActor.turret_id`); 0 for the player, blasts and contact damage.
var source_id: int = 0

func _init(amount: float = 0.0, from: Vector3 = Vector3.ZERO, push: Vector3 = Vector3.ZERO,
		type: GameEnums.DamageType = GameEnums.DamageType.PHYSICAL) -> void:
	damage = maxf(amount, 0.0)
	origin = from
	impulse = WorldGeometry.planar(push)
	damage_type = type
