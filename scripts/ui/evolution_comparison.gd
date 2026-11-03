class_name EvolutionComparison
extends RefCounted

## The before/after stat lines shown when a turret is offered an evolution form (read from committed stats, never mutating the actor).
static func text(turret: TurretActor, form: String) -> String:
	var before := turret.resolve_attack_view()
	var after := turret.resolve_attack_view(false, form)
	var lines := PackedStringArray()
	var utility := TurretRegistry.is_no_attack(turret.turret_type)
	if utility:
		lines.append("Drop every   %.1f → %.1f s     Lands within   %.2f → %.2f m" % [before.cooldown_seconds, after.cooldown_seconds, before.range_metres, after.range_metres])
		lines.append(TurretEvolution.scrap_press_pattern_text(form))
	else:
		lines.append("Damage per hit   %.1f → %.1f" % [before.damage, after.damage])
		if turret.turret_type == "melee":
			lines.append("Sweep speed   %.0f → %.0f°/s" % [before.rotation_rate, after.rotation_rate])
		else:
			lines.append("Base firing rate   %.2f → %.2f/s" % [before.fire_rate, after.fire_rate])
		var area := TurretRegistry.get_fire_mode(turret.turret_type) in [TurretRegistry.FIRE_PULSE, TurretRegistry.FIRE_FLAME]
		lines.append("Reach   %.2f → %.2f m" % [before.range_metres * (before.area_size if area else 1.0), after.range_metres * (after.area_size if area else 1.0)])
	if turret.turret_type == "sniper":
		lines.append("Pierce   %s → %s" % [TurretEvolution.pierce_text(before.pierce), TurretEvolution.pierce_text(after.pierce)])
	if turret.turret_type == "quake":
		lines.append("Knockback   %.2f → %.2f m     Stagger   %.1f s" % [before.knockback_metres, after.knockback_metres, after.stagger_seconds])
		lines.append(TurretEvolution.quake_pattern_text(form))
	if turret.turret_type == "decoy":
		lines.append("Taunt radius   %.2f → %.2f m     Knockback   %.2f → %.2f m" % [before.taunt_metres, after.taunt_metres, before.knockback_metres, after.knockback_metres])
		lines.append(TurretEvolution.decoy_pattern_text(form))
	if turret.turret_type == "mine_layer":
		var limpets := bool(TurretEvolution.param(form, "limpet", false))
		lines.append("%s out at once   %d → %d%s" % ["Limpets" if limpets else "Mines", int(before.values.get("max_mines", 0)), int(after.values.get("max_mines", 0)),
			"" if limpets else "     Set off within   %.2f → %.2f m" % [float(before.values.get("proximity_radius", 0.0)) * WorldGeometry.METRES_PER_PIXEL, float(after.values.get("proximity_radius", 0.0)) * WorldGeometry.METRES_PER_PIXEL]])
		lines.append(TurretEvolution.mine_layer_pattern_text(form))
	if turret.turret_type == "laser":
		lines.append("Damage per tick   %.1f → %.1f     Ticks per second   %.1f → %.1f" % [before.damage, after.damage, before.fire_rate, after.fire_rate])
		lines.append(TurretEvolution.laser_pattern_text(form))
	if turret.turret_type == "drone_bay":
		lines.append("Drones   %d → %d     Shots per second each   %.1f → %.1f" % [int(before.values.get("drone_count", 2)), int(after.values.get("drone_count", 2)), before.fire_rate, after.fire_rate])
		lines.append(TurretEvolution.drone_bay_pattern_text(form))
	if after.aoe_radius_metres > 0:
		lines.append("Blast radius   %.2f → %.2f m" % [before.aoe_radius_metres, after.aoe_radius_metres])
	if form == "stormblade":
		var gun := turret.resolve_attack_view(true, form)
		lines.append("Gun: %.1f damage · %.2f m · %d shot(s) per burst" % [gun.damage, gun.range_metres, TurretEvolution.barrel_burst(form)])
	return "
".join(lines)
