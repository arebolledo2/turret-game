class_name CombatHit3D
extends RefCounted

## Damage is unitless; impulse is metres/second on the ground plane.
var is_dot: bool = false
var burn_transferred: bool = false
var travel_distance: float = 0.0
var attack_targets: Dictionary = {}
var critical: bool = false
var damage: float = 0.0
var damage_type: GameEnums.DamageType = GameEnums.DamageType.PHYSICAL
var origin: Vector3 = Vector3.ZERO
var impulse: Vector3 = Vector3.ZERO
var slow_intensity: float = 0.0
var slow_duration: float = 0.0
## Seconds of stagger this hit applies (0 for none). With a positive `stagger_cap` the time is added to what the enemy
## already has, up to the cap (`StatusEffects3D.extend_stagger`); otherwise it only refreshes to the longer time.
var stagger_duration: float = 0.0
var stagger_cap: float = 0.0
var burn_dps: float = 0.0
var burn_duration: float = 0.0
## Turret that produced the hit (`TurretActor.turret_id`); 0 for the player, blasts and contact damage.
var source_id: int = 0
var attack_families: Array[String] = []
var source_area_radius: float = 0.0
## How many Reactor Overload detonations led to this hit (caps chain reactions).
var blast_depth: int = 0

func _init(amount: float = 0.0, from: Vector3 = Vector3.ZERO, push: Vector3 = Vector3.ZERO,
		type: GameEnums.DamageType = GameEnums.DamageType.PHYSICAL) -> void:
	damage = maxf(amount, 0.0)
	origin = from
	impulse = WorldGeometry.planar(push)
	damage_type = type
