class_name MachineGunForm
extends TurretForm

## Normal / Machine Gun: from stage 2 the rotor spools up while tracking a target and shortens the cooldown.
var spool: float = 0.0

func rebuilt() -> void:
	spool = 0.0

func cooldown_divisor() -> float:
	return 1.0 + spool if actor.progression.evolution_stage >= 2 else 1.0

func tick_mechanisms(delta: float, tracking: bool) -> void:
	var stage := actor.progression.evolution_stage
	if stage < 2:
		return
	var ceiling := 1.5 if stage >= 3 else 1.0
	spool = move_toward(spool, ceiling if tracking else 0.0, delta * (ceiling if tracking else 2.0))
	var rotor := actor.rotor
	if rotor:
		var rate := GameConstants.REDUCED_MOTION_SPEED if FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION) else 1.0
		rotor.rotate_object_local(Vector3.FORWARD, delta * spool * 18.0 * rate)
		actor.muzzle.position = rotor.position + rotor.basis * (actor.muzzle_rest - rotor.position)
