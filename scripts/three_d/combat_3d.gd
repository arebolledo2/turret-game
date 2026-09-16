class_name Combat3D
extends RefCounted

## Run-owned 3D combat boundary. Commands apply damage; signals notify presentation.
## No autoload/scene queries, and no 3D values enter the legacy 2D event bus.
signal hit_applied(target: Node3D, hit: CombatHit3D, actual_damage: float)
signal explosion(position: Vector3, radius: float)
signal actor_defeated(actor: Node3D, position: Vector3)

func apply_hit(target: SliceActor, hit: CombatHit3D) -> float:
	if not is_instance_valid(target) or target.dead:
		return 0.0
	var applied := target.receive_hit(hit)
	if applied > 0.0:
		hit_applied.emit(target, hit, applied)
		if target.dead:
			actor_defeated.emit(target, target.position)
	return applied

func impact(primary: SliceActor, at: Vector3, heading: Vector3, shot: CombatShot3D, candidates: Array[SliceActor]) -> int:
	var targets: Array[SliceActor] = []
	# Copy eligible targets before death notifications remove actors from the world.
	if shot.splash_radius > 0.0:
		for candidate in candidates:
			if is_instance_valid(candidate) and not candidate.dead and not targets.has(candidate):
				if SliceGeometry.planar(candidate.position - at).length_squared() <= shot.splash_radius * shot.splash_radius:
					targets.append(candidate)
	if is_instance_valid(primary) and not primary.dead and not targets.has(primary):
		targets.append(primary)
	var hits: int = 0
	for target in targets:
		var away := SliceGeometry.planar(target.position - at).normalized()
		if away.is_zero_approx():
			away = SliceGeometry.planar(heading).normalized()
		var hit := CombatHit3D.new(shot.damage, at, away * shot.knockback, shot.damage_type)
		if apply_hit(target, hit) > 0.0:
			hits += 1
	if shot.splash_radius > 0.0:
		explosion.emit(SliceGeometry.planar(at), shot.splash_radius)
	return hits

func select_target(origin: Vector3, range_metres: float, candidates: Array[SliceActor], cluster_radius: float = 0.0, grid: CrowdGrid3D = null) -> SliceActor:
	var best: SliceActor = null
	var best_count: int = -1
	var best_distance: float = INF
	for candidate in candidates:
		if not is_instance_valid(candidate) or candidate.dead:
			continue
		var distance := SliceGeometry.planar(candidate.position - origin).length_squared()
		if distance > range_metres * range_metres:
			continue
		var count: int = 0
		if cluster_radius > 0.0 and grid and grid.positions.has(candidate.get_instance_id()):
			count = grid.count_near(candidate, cluster_radius)
		elif cluster_radius > 0.0:
			for neighbor in candidates:
				if is_instance_valid(neighbor) and not neighbor.dead and SliceGeometry.planar(neighbor.position - candidate.position).length_squared() <= cluster_radius * cluster_radius:
					count += 1
		if count > best_count or (count == best_count and distance < best_distance):
			best = candidate
			best_count = count
			best_distance = distance
	return best
