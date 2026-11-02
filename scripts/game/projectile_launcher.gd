class_name ProjectileLauncher
extends RefCounted

## Fires turret shots: reuses an idle `Projectile3D` from the world's pool or makes one, then plays the muzzle cue and flash.
## `ArenaWorld` owns the pool (`projectiles`) and exposes `fire*` as forwards to this.
var world: ArenaWorld

func fire(origin: Vector3, target: CombatActor, damage: float, speed: float) -> Projectile3D:
	var spec := CombatShot3D.new()
	spec.damage = damage
	spec.speed = speed
	return fire_shot(origin, target, spec)

func fire_shot(origin: Vector3, target: CombatActor, spec: CombatShot3D) -> Projectile3D:
	return fire_direction(origin, target.position - origin, spec)

func fire_direction(origin: Vector3, heading: Vector3, spec: CombatShot3D) -> Projectile3D:
	var shot: Projectile3D = null
	for projectile in world.projectiles:
		if not projectile.active:
			shot = projectile
			break
	if not shot:
		shot = Projectile3D.new()
		shot.world = world
		world.actor_root.add_child(shot)
		world.projectiles.append(shot)
	shot.acquire_shot(origin, heading, spec)
	world.audio.play_cue("plasma" if spec.damage_type == GameEnums.DamageType.PLASMA else "ion", origin)
	world.effects.show_muzzle(origin, spec.damage_type)
	return shot
