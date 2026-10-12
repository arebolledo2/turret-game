class_name ItemCombatEffects
extends RefCounted

## Per-run situational effects. Timers advance only during combat; source 0 is the hero.
var world: ArenaWorld
var buffs: Dictionary = {}
var rescue_cooldown: float = 0.0
var battery_wave: int = -1

func owns(id: String) -> bool:
	return int(ItemTrackingService.item_counts.get(id, 0)) > 0

func reset() -> void:
	buffs.clear()
	rescue_cooldown = 0.0
	battery_wave = -1

func clear_wave() -> void:
	buffs.clear()
	rescue_cooldown = 0.0
	for turret in world.turrets:
		turret.invalidate_stats()

func tick(delta: float) -> void:
	if not world.is_combat():
		return
	rescue_cooldown = maxf(0.0, rescue_cooldown - delta)
	for source in buffs.keys():
		for id in buffs[source].keys():
			buffs[source][id].remaining -= delta
			if buffs[source][id].remaining <= 0.0:
				buffs[source].erase(id)
		if buffs[source].is_empty():
			buffs.erase(source)

func grant(source: int, id: String, cap: int = 1) -> void:
	if not buffs.has(source):
		buffs[source] = {}
	var count := mini(cap, int(buffs[source].get(id, {}).get("stacks", 0)) + 1)
	buffs[source][id] = {"stacks": count, "remaining": 2.0}
	for turret in world.turrets:
		if turret.turret_id == source:
			turret.invalidate_stats()

func stacks(source: int, id: String) -> int:
	return int(buffs.get(source, {}).get(id, {}).get("stacks", 0))

func partnered(source: int) -> bool:
	if not owns("close_partnership") or not is_instance_valid(world.player) or world.player.dead:
		return false
	for turret in world.turrets:
		if not turret.carried and (source == 0 or turret.turret_id == source) and WorldGeometry.planar(turret.position - world.player.position).length() <= 1.5:
			return true
	return false

func modify_stats(stats: Dictionary, source: int, kinetic: bool) -> void:
	if partnered(source):
		stats["damage"] = float(stats.get("damage", 0.0)) * 1.08
	var speed := .15 * stacks(source, "rescue_beacon")
	if kinetic:
		speed += .10 * stacks(source, "follow_through")
		stats["range"] = float(stats.get("range", 0.0)) * (1.0 + .10 * stacks(source, "victory_lap"))
	for key in ["fire_rate", "rotation_rate"]:
		if stats.has(key):
			stats[key] = float(stats[key]) * (1.0 + speed)

## Count deployed turret centres inside this turret's final attack reach, never itself.
func neighbours(turret: TurretActor, reach: float) -> int:
	if turret.carried: return 0
	var count := 0
	for other in world.turrets:
		if other != turret and not other.carried and WorldGeometry.planar(other.position - turret.position).length_squared() <= reach * reach + .000001:
			count += 1
	return count

func proximity_bonus(turret: TurretActor, reach: float) -> float:
	if turret.carried or not (owns("lone_sentry") or owns("crosslink_array")): return 0.0
	var count := neighbours(turret, reach)
	if count == 0: return .20 if owns("lone_sentry") else 0.0
	return .05 * count if owns("crosslink_array") else 0.0

func apply_proximity(stats: Dictionary, turret: TurretActor, reach: float) -> void:
	var bonus := proximity_bonus(turret, reach)
	for key in ["damage", "fire_rate", "rotation_rate"]:
		if stats.has(key): stats[key] = float(stats[key]) * (1.0 + bonus)

## Snapshot burn before death clears it. Do not apply on-hit procs to resolved DoT ticks.
func before_hit(target: CombatActor, hit: CombatHit3D) -> Dictionary:
	var burn := {"dps": target.statuses.burn_dps, "remaining": target.statuses.burn_remaining,
		"source": target.statuses.burn_source_id, "families": target.statuses.burn_families.duplicate(),
		"transferred": target.statuses.burn_transferred}
	if target.is_enemy and not hit.is_dot:
		if "projectile" in hit.attack_families:
			if owns("opening_salvo") and target.health >= target.max_health:
				hit.damage *= 1.25
			if owns("slipstream_fletching") and hit.travel_distance >= 2.0:
				hit.damage *= 1.20
		if "kinetic" in hit.attack_families and owns("counterweight") and target.mass > 1.0:
			hit.damage *= 1.20
	return burn

func after_hit(target: CombatActor, hit: CombatHit3D, applied: float, burn: Dictionary) -> void:
	if applied <= 0.0:
		return
	if not target.is_enemy:
		if not target.dead and owns("rescue_beacon") and rescue_cooldown <= 0.0:
			rescue_cooldown = 8.0
			grant(0, "rescue_beacon")
			for turret in world.turrets:
				if WorldGeometry.planar(turret.position - target.position).length() <= 3.0:
					grant(turret.turret_id, "rescue_beacon")
		return
	if not hit.is_dot and "kinetic" in hit.attack_families:
		if owns("follow_through") and not hit.attack_targets.has(target.get_instance_id()):
			hit.attack_targets[target.get_instance_id()] = true
			if hit.attack_targets.size() == 3:
				grant(hit.source_id, "follow_through", 5)
		if target.dead and owns("victory_lap"):
			grant(hit.source_id, "victory_lap", 5)
	if target.dead and owns("cinder_reserve") and float(burn.dps) > 0.0 and float(burn.remaining) > 0.0 and not bool(burn.transferred):
		var nearest: CombatActor
		var distance := 1.5 * 1.5 + .000001
		for enemy in world.enemies:
			if enemy == target or enemy.dead or enemy.stationary or enemy.statuses.burn_remaining > 0.0:
				continue
			var d := WorldGeometry.planar(enemy.position - target.position).length_squared()
			if d < distance:
				nearest = enemy
				distance = d
		if nearest:
			var transfer := CombatHit3D.new()
			transfer.burn_dps = float(burn.dps)
			transfer.burn_duration = minf(1.0, float(burn.remaining))
			transfer.burn_transferred = true
			transfer.source_id = int(burn.source)
			transfer.origin = target.position
			transfer.attack_families.assign(burn.families)
			nearest.statuses.apply(transfer)

func rescue_core() -> bool:
	if not world.core or not owns("reserve_battery") or battery_wave == GameStateService.current_wave:
		return false
	if world.core.health <= 0.0 or world.core.health >= world.core.max_health * .30:
		return false
	battery_wave = GameStateService.current_wave
	world.core.repair(world.core.max_health)
	world.message = "Reserve Battery: core fully restored!"
	world.audio.play_cue("purchase", world.core.position)
	return true

## Same data drives icons/tooltips and can be inspected in tests.
func visible_buffs(source: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in buffs.get(source, {}):
		var b: Dictionary = buffs[source][id]
		result.append({"id": id, "stacks": b.stacks, "fraction": float(b.remaining) / 2.0})
	if partnered(source):
		result.append({"id": "close_partnership", "stacks": 1, "fraction": 1.0})
	for turret in world.turrets:
		if turret.turret_id != source:
			continue
		if not turret.carried and (owns("lone_sentry") or owns("crosslink_array")):
			var reach := turret.effective_range(TurretStats.new(turret.resolve_attack_stats()))
			var count := neighbours(turret, reach)
			var bonus := proximity_bonus(turret, reach)
			if bonus > 0.0:
				result.append({"id": "lone_sentry" if count == 0 else "crosslink_array", "stacks": maxi(1, count), "fraction": 1.0, "tooltip": "+%.0f%% damage and attack speed · %d nearby turrets" % [bonus * 100, count]})
		if turret.entrench_stacks_cached > 0 and not turret.carried:
			result.append({"id": "concrete_footings", "stacks": turret.entrench_stacks_cached, "fraction": turret.entrench_progress(), "tooltip": "Entrenched: +%.0f%% damage, +%.0f%% attack speed" % [turret.entrench_damage_bonus() * 100, turret.entrench_fire_rate_bonus() * 100]})
		if owns("last_stand") and world.player.health < world.player.max_health * GameConstants.LAST_STAND_HULL_FRACTION:
			result.append({"id": "last_stand", "stacks": 1, "fraction": 1.0})
		if owns("storm_conductor") and "instant" in TurretRegistry.get_attack_families(turret.turret_type) and turret._has_instant_neighbour():
			result.append({"id": "storm_conductor", "stacks": 1, "fraction": 1.0})
	return result
