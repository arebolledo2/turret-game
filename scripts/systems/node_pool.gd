class_name NodePool
extends RefCounted

## A reuse pool for short-lived scene instances.
##
## Entities that spawn and die continuously - projectiles, damage numbers -
## otherwise churn instantiate()/queue_free() every frame, which is the main
## source of allocation pressure in this genre. Pooled nodes stay in the tree
## and are hidden and deprocessed while idle.
##
## Pooled scripts may implement either optional hook:
##   _pool_acquired() - called as the node is handed out, to set up per-use state
##   _pool_released() - called as it returns, to clear per-use state
##
## The pool assigns a `pool_release` Callable on any node that declares one, so
## self-expiring nodes can return themselves without knowing about the pool.
##
## Not thread-safe; call from the main thread only.

var _scene: PackedScene
var _parent: Node
var _idle: Array[Node] = []
var _max_idle: int

## Number of live (acquired, not yet released) nodes. Useful for leak checks.
var active_count: int = 0


## `parent` is where pooled nodes are added, and must outlive the pool.
## `max_idle` caps retained nodes so a one-off spike does not hold memory
## forever; releases beyond it are freed instead of retained.
func _init(scene: PackedScene, parent: Node, prewarm: int = 0, max_idle: int = 64) -> void:
	_scene = scene
	_parent = parent
	_max_idle = max_idle

	for i in range(prewarm):
		var node := _instantiate()
		if node == null:
			break
		_deactivate(node)
		_idle.append(node)


## Take a node from the pool, instantiating one if none are idle.
## Returns null only if the scene failed to instantiate.
func acquire() -> Node:
	var node: Node = null

	# Idle nodes can still be freed out from under us by a scene reload.
	while node == null and not _idle.is_empty():
		var candidate: Node = _idle.pop_back()
		if is_instance_valid(candidate) and not candidate.is_queued_for_deletion():
			node = candidate

	if node == null:
		node = _instantiate()
		if node == null:
			return null

	_activate(node)
	active_count += 1

	if node.has_method("_pool_acquired"):
		node.call("_pool_acquired")

	return node


## Return a node to the pool. Safe to call more than once on the same node;
## repeat calls are ignored.
func release(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node in _idle:
		return

	active_count = max(0, active_count - 1)

	if node.has_method("_pool_released"):
		node.call("_pool_released")

	# Past the cap, let it go rather than growing the pool without bound.
	if _idle.size() >= _max_idle:
		node.queue_free()
		return

	_deactivate(node)
	_idle.append(node)


## Deferred variant, for callers inside a physics callback where mutating a
## node's collision state immediately would fault the physics server.
func release_deferred(node: Node) -> void:
	release.call_deferred(node)


## Free every retained node and drop all references. Call on scene teardown and
## between tests.
func clear() -> void:
	for node in _idle:
		if is_instance_valid(node):
			node.queue_free()
	_idle.clear()
	active_count = 0


func _instantiate() -> Node:
	if _scene == null or _parent == null or not is_instance_valid(_parent):
		return null

	var node: Node = _scene.instantiate()
	if node == null:
		return null

	# Let self-expiring nodes return themselves without a pool reference.
	if "pool_release" in node:
		node.set("pool_release", release)

	_parent.add_child(node)
	return node


func _activate(node: Node) -> void:
	node.set_process(true)
	node.set_physics_process(true)
	if node is CanvasItem:
		node.visible = true


func _deactivate(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	if node is CanvasItem:
		node.visible = false
