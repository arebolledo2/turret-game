class_name BlastEffects
extends RefCounted

## Area blasts that follow a kill: the Reactor Overload item and boom-bot explosions.
## `ArenaWorld` owns the actors; this helper only decides who is hit and applies the hits through `Combat3D`.
var world: ArenaWorld

## Reactor Overload: plasma kills detonate for a fraction of the killing hit, and those kills can chain (depth capped).
func reactor_overload(victim: CombatActor, hit: CombatHit3D) -> void:
	if hit.damage_type != GameEnums.DamageType.PLASMA or hit.blast_depth >= GameConstants.REACTOR_MAX_CHAIN_DEPTH:
		return
	if ModifierService.apply_modifiers_to_stat(0.0, "reactor_overload") <= 0.0:
		return
	var stats := TurretStatsService.get_turret_stats("plasma", float(world.difficulty_config["turret_damage_mult"]))
	var radius := TurretStats.new(stats).aoe_radius_metres * GameConstants.REACTOR_BLAST_RADIUS_FRACTION
	if radius <= 0.0:
		return
	var at := victim.position
	var victims := _enemies_within(at, radius, victim)
	world.combat.explosion.emit(WorldGeometry.planar(at), radius)
	for other in victims:
		var blast := CombatHit3D.new(hit.damage * GameConstants.REACTOR_BLAST_DAMAGE_FRACTION, at, Vector3.ZERO, GameEnums.DamageType.PLASMA)
		blast.source_id = hit.source_id
		blast.blast_depth = hit.blast_depth + 1
		world.combat.apply_hit(other, blast)

## Boom bot blast: hurts the player and every other enemy in range (chains are allowed and finite).
func detonate(source: CombatActor) -> void:
	var at := source.position
	var radius_squared := source.explosion_radius * source.explosion_radius
	var victims := _enemies_within(at, source.explosion_radius, null)
	world.combat.explosion.emit(WorldGeometry.planar(at), source.explosion_radius)
	for victim in victims:
		world.combat.apply_hit(victim, CombatHit3D.new(source.explosion_damage, at))
	if WorldGeometry.planar(world.player.position - at).length_squared() <= radius_squared:
		world.combat.apply_hit(world.player, CombatHit3D.new(source.explosion_damage, at))
	var core := world.core
	if core and not core.dead:
		var core_reach := source.explosion_radius + core.radius
		if WorldGeometry.planar(core.position - at).length_squared() <= core_reach * core_reach:
			world.damage_core(source.explosion_damage * GameConstants.CORE_DAMAGE_FRACTION)

## Snapshot of the living enemies in range, taken before any hit lands so death notifications cannot change the set.
func _enemies_within(at: Vector3, radius: float, excluding: CombatActor) -> Array[CombatActor]:
	var found: Array[CombatActor] = []
	var radius_squared := radius * radius
	for other in world.enemies:
		if other != excluding and is_instance_valid(other) and not other.dead \
				and WorldGeometry.planar(other.position - at).length_squared() <= radius_squared:
			found.append(other)
	return found
