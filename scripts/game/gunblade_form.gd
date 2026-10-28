class_name GunbladeForm
extends SweepForm

## Melee / Stormblade: the spinning bat also carries a rotating barrel that shoots along its visible bore.
## Blade and bullet bonuses stay separate, so the barrel has its own resolved stats.
var gun_stats := TurretStats.new()
var burst := ShotBurst.new(.065)

func has_barrel() -> bool:
	return true

func estimate_dps(stats: TurretStats) -> float:
	var gun := actor.resolve_attack_view(true)
	var shots := TurretEvolution.barrel_burst(form_id)
	return base_dps(actor, stats) + gun.damage * float(shots) / (gun.cooldown_seconds + burst.interval * (shots - 1))

func clear() -> void:
	burst.cancel()

func rebuilt() -> void:
	super()
	burst.cancel()

func refresh_stats() -> void:
	gun_stats = actor.resolve_attack_view(true)

func tick_sweep(delta: float) -> void:
	tick_burst(delta)
	fire()

func fire() -> void:
	if actor.cooldown > 0.0 or burst.left > 0:
		return
	var muzzle := actor.muzzle
	var position := actor.position
	var heading := WorldGeometry.planar(-muzzle.global_basis.z).normalized()
	for enemy in actor.world.crowd.query_radius(position, gun_stats.range_metres, true):
		if not enemy.overlaps_attack_range(position, gun_stats.range_metres):
			continue
		var offset := WorldGeometry.planar(enemy.position - muzzle.global_position)
		if offset.dot(heading) <= 0.0 or not TurretActor.cone_overlaps_body(offset, heading, gun_stats.range_metres, deg_to_rad(5), enemy.hurtbox_radius()):
			continue
		var shot := CombatShot3D.from_stats(gun_stats.values, GameEnums.DamageType.PHYSICAL)
		shot.attack_families.assign(["projectile"])
		shot.source_id = actor.turret_id
		if TurretStatsService.roll_turret_crit():
			shot.critical = true
			shot.damage = TurretStatsService.calculate_turret_crit_damage(shot.damage)
		actor.world.fire_direction(muzzle.global_position, heading, shot)
		burst.start(TurretEvolution.barrel_burst(form_id) - 1, shot, burst.interval)
		actor.cooldown = gun_stats.cooldown_seconds
		return

## Follow-up shots leave the moving barrel instead of aiming invisibly away from the blade.
func tick_burst(delta: float) -> void:
	if burst.left <= 0:
		return
	burst.advance(delta)
	var exits := actor.gun_muzzles
	while burst.is_due():
		var exit := exits[clampi(exits.size() - burst.left, 0, exits.size() - 1)]
		var heading := WorldGeometry.planar(-exit.global_basis.z).normalized()
		actor.world.fire_direction(exit.global_position, heading, burst.shot)
		burst.consume()
		actor.cooldown = gun_stats.cooldown_seconds
