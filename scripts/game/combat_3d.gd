class_name Combat3D
extends RefCounted

## Run-owned 3D combat boundary. Commands apply damage; signals notify presentation.
## No autoload/scene queries, and no 3D values enter the legacy 2D event bus.
signal hit_applied(target: Node3D, hit: CombatHit3D, actual_damage: float)
signal explosion(position: Vector3, radius: float)
signal shock_pulse(position: Vector3, radius: float)
signal chain_arc(from: Vector3, to: Vector3)
signal actor_defeated(actor: Node3D, position: Vector3)

func apply_hit(target: CombatActor, hit: CombatHit3D) -> float:
	if not is_instance_valid(target) or target.dead:
		return 0.0
	var applied := target.receive_hit(hit)
	if applied > 0.0:
		hit_applied.emit(target, hit, applied)
		if target.dead:
			actor_defeated.emit(target, target.position)
	return applied

func impact(primary: CombatActor, at: Vector3, heading: Vector3, shot: CombatShot3D, candidates: Array[CombatActor]) -> int:
	var targets: Array[CombatActor] = []
	# Copy eligible targets before death notifications remove actors from the world.
	if shot.splash_radius > 0.0:
		for candidate in candidates:
			if is_instance_valid(candidate) and not candidate.dead and not targets.has(candidate):
				if candidate.overlaps_attack_range(at, shot.splash_radius):
					targets.append(candidate)
	if is_instance_valid(primary) and not primary.dead and not targets.has(primary):
		targets.append(primary)
	var hits: int = 0
	for target in targets:
		var away := WorldGeometry.planar(target.position - at).normalized()
		if away.is_zero_approx():
			away = WorldGeometry.planar(heading).normalized()
		var hit := CombatHit3D.new(shot.damage, at, away * shot.knockback, shot.damage_type)
		hit.slow_intensity = shot.slow_intensity
		hit.slow_duration = shot.slow_duration
		hit.source_id = shot.source_id
		hit.attack_families = shot.attack_families.duplicate()
		hit.source_area_radius = shot.splash_radius
		if apply_hit(target, hit) > 0.0:
			hits += 1
	if shot.splash_radius > 0.0:
		if shot.damage_type == GameEnums.DamageType.ELECTRIC:
			shock_pulse.emit(WorldGeometry.planar(at), shot.splash_radius)
		else:
			explosion.emit(WorldGeometry.planar(at), shot.splash_radius)
	return hits

## Instant chain lightning: hits `primary`, then jumps to the nearest unhit living enemy within
## `jump_range`, up to `jumps` more times, each hit scaled by `decay`.
func chain(origin: Vector3, primary: CombatActor, shot: CombatShot3D, jumps: int, jump_range: float,
		decay: float, candidates: Array[CombatActor]) -> int:
	var struck: Array[CombatActor] = []
	var current := primary
	var from := origin
	var damage := shot.damage
	var hits: int = 0
	for step in range(jumps + 1):
		if not is_instance_valid(current) or current.dead:
			break
		var to := current.position + Vector3(0, .45, 0)
		chain_arc.emit(from, to)
		struck.append(current)
		var jump_hit := CombatHit3D.new(damage, from, Vector3.ZERO, shot.damage_type)
		jump_hit.source_id = shot.source_id
		jump_hit.attack_families = shot.attack_families.duplicate()
		jump_hit.slow_intensity = shot.slow_intensity
		jump_hit.slow_duration = shot.slow_duration
		if apply_hit(current, jump_hit) > 0.0:
			hits += 1
		from = to
		damage *= decay
		current = _nearest_unstruck(current.position, jump_range, struck, candidates)
	return hits

func _nearest_unstruck(at: Vector3, jump_range: float, struck: Array[CombatActor], candidates: Array[CombatActor]) -> CombatActor:
	var best: CombatActor = null
	var best_distance := jump_range * jump_range + .000001
	for candidate in candidates:
		if not is_instance_valid(candidate) or candidate.dead or struck.has(candidate):
			continue
		var distance := WorldGeometry.planar(candidate.position - at).length_squared()
		if distance <= best_distance:
			best = candidate
			best_distance = distance
	return best

func select_target(origin: Vector3, range_metres: float, candidates: Array[CombatActor], cluster_radius: float = 0.0, grid: CrowdGrid3D = null) -> CombatActor:
	var best: CombatActor = null
	var best_count: int = -1
	var best_distance: float = INF
	for candidate in candidates:
		if not is_instance_valid(candidate) or candidate.dead:
			continue
		var distance := WorldGeometry.planar(candidate.position - origin).length_squared()
		if not candidate.overlaps_attack_range(origin, range_metres):
			continue
		var count: int = 0
		if cluster_radius > 0.0 and grid and grid.positions.has(candidate.get_instance_id()):
			count = grid.count_near(candidate, cluster_radius)
		elif cluster_radius > 0.0:
			for neighbor in candidates:
				if is_instance_valid(neighbor) and not neighbor.dead and WorldGeometry.planar(neighbor.position - candidate.position).length_squared() <= cluster_radius * cluster_radius:
					count += 1
		if count > best_count or (count == best_count and distance < best_distance):
			best = candidate
			best_count = count
			best_distance = distance
	return best
