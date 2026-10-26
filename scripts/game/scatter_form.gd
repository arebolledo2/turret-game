class_name ScatterForm
extends TurretForm

## Normal / Omnifire: one shot from every radial exit (the retired Scattershot's three-way spread stays as the fallback).
func fire_projectile(stats: TurretStats, heading: Vector3) -> bool:
	if TurretEvolution.legacy_stage(actor.progression.evolution_form) >= 2:
		for exit: Node3D in actor.crossfire_muzzles:
			actor.world.fire_direction(exit.global_position, -exit.global_basis.z, actor._new_shot(stats))
	else:
		for angle: float in [-12.0, 0.0, 12.0]:
			actor.world.fire_direction(actor.muzzle.global_position, heading.rotated(Vector3.UP, deg_to_rad(angle)), actor._new_shot(stats))
	return true
