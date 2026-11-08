class_name Combat3D
extends RefCounted

## Run-owned 3D combat boundary. Commands apply damage; signals notify presentation.
## No autoload/scene queries, and no 3D values enter the legacy 2D event bus.
signal hit_applied(target: Node3D, hit: CombatHit3D, actual_damage: float)
signal explosion(position: Vector3, radius: float)
signal shock_pulse(position: Vector3, radius: float)
signal chain_arc(from: Vector3, to: Vector3, hop: int)
signal actor_defeated(actor: Node3D, position: Vector3)

func apply_hit(target: CombatActor, hit: CombatHit3D) -> float:
	if not is_instance_valid(target) or target.dead:
		return 0.0
	var original_damage := hit.damage
	var burn := target.world.item_effects.before_hit(target, hit)
	var applied := target.receive_hit(hit)
	target.world.item_effects.after_hit(target, hit, applied, burn)
	if applied > 0.0:
		hit_applied.emit(target, hit, applied)
		if target.dead:
			actor_defeated.emit(target, target.position)
	hit.damage = original_damage
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
		if apply_hit(target, hit_from_shot(target, at, heading, shot)) > 0.0:
			hits += 1
	if shot.splash_radius > 0.0:
		if shot.damage_type == GameEnums.DamageType.ELECTRIC:
			shock_pulse.emit(WorldGeometry.planar(at), shot.splash_radius)
		else:
			explosion.emit(WorldGeometry.planar(at), shot.splash_radius)
	return hits

## The hit `shot` deals to `target` when it lands at `at`. Knockback pushes away from `at`, or along `heading` when the
## target sits exactly on it. Turret effects that resolve their own targets (the Quake's rings and fissures) build their
## hits here so a shot's damage, slow, stagger, crit and attribution travel the same way as for `impact`.
func hit_from_shot(target: CombatActor, at: Vector3, heading: Vector3, shot: CombatShot3D) -> CombatHit3D:
	var away := WorldGeometry.planar(target.position - at).normalized()
	if away.is_zero_approx():
		away = WorldGeometry.planar(heading).normalized()
	var hit := CombatHit3D.new(shot.damage, at, away * shot.knockback, shot.damage_type)
	hit.travel_distance = shot.travel_distance
	hit.attack_targets = shot.attack_targets
	hit.critical = shot.critical
	hit.slow_intensity = shot.slow_intensity
	hit.slow_duration = shot.slow_duration
	hit.stagger_duration = shot.stagger_duration
	hit.stagger_cap = shot.stagger_cap
	hit.source_id = shot.source_id
	hit.attack_families = shot.attack_families.duplicate()
	hit.source_area_radius = shot.splash_radius
	return hit

## Instant chain lightning: hits `primary`, then jumps to the nearest unhit living enemy within
## `jump_range`, up to `jumps` more times, each hit scaled by `decay`.
func chain(origin: Vector3, primary: CombatActor, shot: CombatShot3D, jumps: int, jump_range: float,
		decay: float, candidates: Array[CombatActor], shared_struck: Array[CombatActor] = []) -> int:
	# `shared_struck` lets a forked chain skip what a sibling branch already hit.
	var struck: Array[CombatActor] = shared_struck
	var current := primary
	var from := origin
	var damage := shot.damage
	var hits: int = 0
	for step in range(jumps + 1):
		if not is_instance_valid(current) or current.dead:
			break
		var link := _chain_link(current, from, damage, shot, step, jumps, jump_range, struck, candidates)
		hits += int(link["hit"])
		from = link["to"]
		damage *= decay
		current = link["next"]
	return hits

## Forked chain lightning (the Tesla's Forked Coil and Storm Network): hits `primary`, then the `forks` nearest unhit enemies
## each start a branch that jumps on, all branches taking their turn jump by jump so no branch starves another of targets.
## Each branch makes `jumps_each` more hits after its own first (a fork's first hit counts as its first jump). No enemy is struck
## twice. Returns the number of hits that landed.
func chain_forked(origin: Vector3, primary: CombatActor, shot: CombatShot3D, jumps_each: int, jump_range: float,
		decay: float, candidates: Array[CombatActor], forks: int = 2) -> int:
	var struck: Array[CombatActor] = []
	var hits := chain(origin, primary, shot, 0, 0.0, decay, candidates, struck)
	var heads: Array[CombatActor] = []
	var taken: Array[CombatActor] = struck.duplicate()
	for fork in forks:
		var next := _nearest_unstruck(primary.position, jump_range, taken, candidates)
		if not next:
			break
		heads.append(next)
		taken.append(next)
	# Both heads count as struck before either branch runs, so neither steps onto the other's head.
	struck.append_array(heads)
	var froms: Array[Vector3] = []
	var damages: Array[float] = []
	for head in heads:
		froms.append(primary.position + Vector3(0, .45, 0))
		damages.append(shot.damage * decay)
	for step in range(jumps_each):
		for index in heads.size():
			var current := heads[index]
			if not is_instance_valid(current) or current.dead:
				heads[index] = null
				continue
			var link := _chain_link(current, froms[index], damages[index], shot, step + 1, jumps_each - 1, jump_range, struck, candidates)
			hits += int(link["hit"])
			froms[index] = link["to"]
			damages[index] *= decay
			heads[index] = link["next"]
			if heads[index] != null:
				struck.append(heads[index])
	return hits

## One strike of a chain: the arc to `current`, the hit it takes, and the next enemy to jump to (null at the end).
func _chain_link(current: CombatActor, from: Vector3, damage: float, shot: CombatShot3D, step: int, jumps: int,
		jump_range: float, struck: Array[CombatActor], candidates: Array[CombatActor]) -> Dictionary:
	var to := current.position + Vector3(0, .45, 0)
	chain_arc.emit(from, to, step)
	struck.append(current)
	var next := _nearest_unstruck(current.position, jump_range, struck, candidates)
	var insurance := 1.0
	if not next and current.world.item_effects.owns("arc_insurance"):
		insurance += minf(.24, .08 * float(jumps - step))
	var jump_hit := CombatHit3D.new(damage * insurance, from, Vector3.ZERO, shot.damage_type)
	jump_hit.critical = shot.critical
	jump_hit.source_id = shot.source_id
	jump_hit.attack_families = shot.attack_families.duplicate()
	jump_hit.slow_intensity = shot.slow_intensity
	jump_hit.slow_duration = shot.slow_duration
	return {"hit": apply_hit(current, jump_hit) > 0.0, "to": to, "next": next}

## The nearest living enemy within `jump_range` of `at` that is not in `struck`, or null.
func nearest_unstruck(at: Vector3, jump_range: float, struck: Array[CombatActor], candidates: Array[CombatActor]) -> CombatActor:
	return _nearest_unstruck(at, jump_range, struck, candidates)

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
