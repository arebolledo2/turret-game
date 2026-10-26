class_name ScatterForm
extends TurretForm

## Normal / Omnifire: one shot from every radial exit.
func fire_projectile(stats: TurretStats, _heading: Vector3) -> bool:
	for exit: Node3D in actor.crossfire_muzzles:
		actor.world.fire_direction(exit.global_position, -exit.global_basis.z, actor._new_shot(stats))
	return true
