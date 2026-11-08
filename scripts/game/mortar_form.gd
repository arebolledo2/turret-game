class_name MortarForm
extends TurretForm

## Plasma / Mortar and Constellation: an indirect shell. The turret marks a ground circle under its target, and the shell
## lands there `delay` seconds later whether or not the enemy is still standing in it. The marker is a ring that fills over
## that time. No knockback (the rows set it to 0).
## Constellation lands a star instead of one blast: the centre plus `points` blasts on a ring of `star_radius` metres, and
## the whole star is repeated `repeats` more times, `repeat_delay` seconds apart. Every blast is a copy of one shot, so crit,
## item bonuses and kill credit are decided at launch and secondary blasts do not apply item modifiers again.
## Everything queued is dropped by `clear()` when combat stops, so nothing lands after a pause or at wave end.
const TINT: Color = Color("b56cff")

## Blasts waiting to land: {"left": seconds, "at": ground position, "shot": CombatShot3D}.
var blasts: Array[Dictionary] = []
## Shells launched and blasts landed since this form was created; tests and tools read them.
var shells_launched: int = 0
var blasts_landed: int = 0

func estimate_dps(stats: TurretStats) -> float:
	# Against a lone target only the star's centre reaches it, once per volley.
	return stats.damage * stats.fire_rate * float(1 + int(param("repeats", 0)))

func fire_projectile(stats: TurretStats, _heading: Vector3) -> bool:
	var focus := actor.target
	if not is_instance_valid(focus) or focus.dead:
		return true
	var world := actor.world
	var centre := WorldGeometry.planar(focus.position)
	var radius := stats.aoe_radius_metres
	var delay := float(param("delay", 1.1))
	var gap := float(param("repeat_delay", .5))
	var shot := actor._new_shot(stats)
	shot.splash_radius = radius
	var spots: Array[Vector3] = [centre]
	var points := int(param("points", 0))
	for index in points:
		spots.append(centre + Vector3.RIGHT.rotated(Vector3.UP, TAU * float(index) / float(points)) * float(param("star_radius", 1.7)) * stats.area_size)
	for volley in 1 + int(param("repeats", 0)):
		var lands := delay + gap * float(volley)
		for spot in spots:
			var blast := shot.copy()
			blast.critical = shot.critical
			blasts.append({"left": lands, "at": spot, "shot": blast})
			world.effects.show_wave(spot, radius, radius / lands, TINT)
	shells_launched += 1
	world.effects.show_muzzle(actor.muzzle.global_position, GameEnums.DamageType.PLASMA)
	world.audio.play_cue("plasma", actor.position)
	return true

func tick(delta: float) -> void:
	if blasts.is_empty():
		return
	var landing: Array[Dictionary] = []
	for blast in blasts:
		blast["left"] = float(blast["left"]) - delta
		if float(blast["left"]) <= 0.0:
			landing.append(blast)
	for blast in landing:
		blasts.erase(blast)
		blasts_landed += 1
		actor.world.combat.impact(null, blast["at"], Vector3.ZERO, blast["shot"], actor.world.enemies)

func clear() -> void:
	blasts.clear()

func removed() -> void:
	blasts.clear()
