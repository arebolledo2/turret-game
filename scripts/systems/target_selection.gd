class_name TargetSelection
extends RefCounted

## No scene queries or services: all candidates and policy come from the caller.
static func select(origin: Vector2, candidates: Array, range_limit: float = INF, farthest: bool = false, excluded: Array = []) -> Node2D:
	var best: Node2D = null
	var best_distance: float = -1.0 if farthest else INF
	var range_squared := range_limit * range_limit
	for candidate in candidates:
		if not is_instance_valid(candidate) or candidate.is_queued_for_deletion() or candidate in excluded:
			continue
		var distance: float = origin.distance_squared_to(candidate.global_position)
		if distance > range_squared:
			continue
		if best == null or (farthest and distance > best_distance) or (not farthest and distance < best_distance):
			best = candidate
			best_distance = distance
	return best
