class_name LanceForm
extends TurretForm

## Shock / Thunder Spear: one bolt at the nearest enemy that also strikes everything in line behind it.
func fire_pulse(stats: TurretStats, range_metres: float, target: CombatActor) -> void:
	fire(stats, range_metres, target)

func fire(stats: TurretStats, range_metres: float, struck: CombatActor) -> void:
	var world := actor.world
	var position := actor.position
	var stage := TurretEvolution.legacy_stage(actor.progression.evolution_form)
	var heading := WorldGeometry.planar(struck.position - position).normalized()
	var shot := actor._new_shot(stats)
	var victims: Array[CombatActor] = [struck]
	if stage >= 3:
		for enemy: CombatActor in world.enemies:
			if not is_instance_valid(enemy) or enemy.dead or enemy == struck:
				continue
			var offset := WorldGeometry.planar(enemy.position - position)
			var along := offset.dot(heading)
			if along > 0.0 and along <= range_metres and absf(offset.cross(heading).y) <= TurretEvolution.LANCE_LANE_HALF_WIDTH:
				victims.append(enemy)
	var tip := position + heading * (range_metres if stage >= 3 else WorldGeometry.planar(struck.position - position).length())
	world.combat.chain_arc.emit(actor.muzzle.global_position, tip + Vector3(0, .45, 0), 0)
	for victim in victims:
		var bolt := shot.copy()
		bolt.critical = shot.critical
		world.combat.impact(victim, victim.position, heading, bolt, [] as Array[CombatActor])
	actor._reset_cooldown(stats)
