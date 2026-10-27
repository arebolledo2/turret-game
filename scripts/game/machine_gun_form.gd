class_name MachineGunForm
extends TurretForm

## Normal / Machine Gun and Cyclone Gatling: the Gatling's rotor spools up while tracking a target and shortens the cooldown.
## A form spools only when its row sets a `spool` ceiling (the Gatling's 1.5); the Machine Gun's rotor never does.
var spool: float = 0.0

func rebuilt() -> void:
	spool = 0.0

func cooldown_divisor() -> float:
	return 1.0 + spool if _spools() else 1.0

func estimate_dps(stats: TurretStats) -> float:
	return stats.damage * stats.fire_rate * cooldown_divisor()

func tick_mechanisms(delta: float, tracking: bool) -> void:
	if not _spools():
		return
	var ceiling := float(param("spool", 0.0))
	spool = move_toward(spool, ceiling if tracking else 0.0, delta * (ceiling if tracking else 2.0))
	var rotor := actor.rotor
	if rotor:
		var rate := GameConstants.REDUCED_MOTION_SPEED if FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION) else 1.0
		rotor.rotate_object_local(Vector3.FORWARD, delta * spool * 18.0 * rate)
		actor.muzzle.position = rotor.position + rotor.basis * (actor.muzzle_rest - rotor.position)

func _spools() -> bool:
	return float(param("spool", 0.0)) > 0.0
