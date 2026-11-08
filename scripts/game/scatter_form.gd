class_name ScatterForm
extends TurretForm

## Normal / Scattershot: a three-way spread. Omnifire (it has crossfire exits) fires one shot from every radial exit.
func fire_projectile(stats: TurretStats, heading: Vector3) -> bool:
	if actor.crossfire_muzzles.is_empty():
		for angle: float in [-12.0, 0.0, 12.0]:
			actor.world.fire_direction(actor.muzzle.global_position, heading.rotated(Vector3.UP, deg_to_rad(angle)), actor._new_shot(stats))
		return true
	for exit: Node3D in actor.crossfire_muzzles:
		actor.world.fire_direction(exit.global_position, -exit.global_basis.z, actor._new_shot(stats))
	return true
