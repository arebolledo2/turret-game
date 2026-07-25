class_name ProjectilePool
extends RefCounted

## Shared reuse pool for projectiles.
##
## Turrets, the player and ranged enemies all spawn res://scenes/projectile.tscn,
## so they share one pool rather than each churning instantiate()/queue_free().
## Projectiles return themselves via the `pool_release` Callable that NodePool
## assigns; see Projectile._despawn().
##
## The pool is rebuilt whenever it is asked for a different parent, which covers
## scene reloads freeing everything pooled under the old scene.
##
## Not thread-safe; call from the main thread only.

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectile.tscn")

static var _pool: NodePool = null
static var _parent: Node = null


## Take a projectile parented under `parent`. Returns null if `parent` is
## unusable. Callers must still position it and call setup()/setup_extended().
static func acquire(parent: Node) -> Node2D:
	if parent == null or not is_instance_valid(parent):
		return null

	if _pool == null or parent != _parent or not is_instance_valid(_parent):
		_parent = parent
		# No prewarm: the first shot of a run should behave exactly as before.
		_pool = NodePool.new(PROJECTILE_SCENE, parent, 0, 128)

	return _pool.acquire() as Node2D


## Number of projectiles currently in flight.
static func active_count() -> int:
	return _pool.active_count if _pool != null else 0


## Drop the pool. Static state outlives scene reloads, so tests call this to
## stay isolated from each other.
static func reset_state() -> void:
	if _pool != null:
		_pool.clear()
	_pool = null
	_parent = null
