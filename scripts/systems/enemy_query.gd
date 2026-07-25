class_name EnemyQuery
extends RefCounted

## Frame-cached access to the "enemies" group.
##
## Turret targeting runs every physics frame for every turret, and
## SceneTree.get_nodes_in_group() builds a fresh Array on each call. With N
## turrets on screen that is N allocations per frame over identical data.
## This caches the result for the duration of one physics frame.
##
## Two contracts for callers:
##   1. Treat the returned Array as read-only. It is shared between callers.
##   2. Still guard each entry with is_instance_valid(). An enemy can be freed
##      part-way through a frame, after the cache was populated.

static var _cached_enemies: Array[Node] = []
static var _cached_frame: int = -1


## Return the current "enemies" group, rebuilding the cache at most once per
## physics frame.
static func get_enemies(tree: SceneTree) -> Array[Node]:
	var frame := Engine.get_physics_frames()
	if frame != _cached_frame:
		_cached_enemies = tree.get_nodes_in_group("enemies")
		_cached_frame = frame
	return _cached_enemies


## Drop the cache. Static state outlives scene reloads, so tests call this to
## stay isolated from each other.
static func reset_state() -> void:
	_cached_enemies = []
	_cached_frame = -1
