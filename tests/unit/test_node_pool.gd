extends GutTest

# =============================================================================
# Unit tests for NodePool
# Tests reuse, per-use hooks, idle cap, and defensive release behavior
# =============================================================================

var _parent: Node2D
var _scene: PackedScene


func before_each():
	TestHelpers.reset_all_services()
	_parent = Node2D.new()
	add_child_autofree(_parent)
	_scene = PackedScene.new()
	var fixture := preload("res://tests/helpers/pool_fixture.gd").new()
	_scene.pack(fixture)
	fixture.free()


# =============================================================================
# ACQUIRE / RELEASE
# =============================================================================

func test_acquire_returns_node_parented_to_pool_parent():
	var pool := NodePool.new(_scene, _parent)
	var node := pool.acquire()

	assert_not_null(node, "acquire() should return a node")
	assert_eq(node.get_parent(), _parent, "Pooled node should be parented to the pool parent")
	pool.clear()


func test_released_node_is_reused_not_reinstantiated():
	var pool := NodePool.new(_scene, _parent)

	var first := pool.acquire()
	var first_id := first.get_instance_id()
	pool.release(first)
	var second := pool.acquire()

	assert_eq(second.get_instance_id(), first_id, "Second acquire should reuse the released node")
	pool.clear()


func test_concurrent_acquires_return_distinct_nodes():
	var pool := NodePool.new(_scene, _parent)

	var a := pool.acquire()
	var b := pool.acquire()

	assert_ne(a.get_instance_id(), b.get_instance_id(), "Live nodes must not be handed out twice")
	pool.clear()


func test_active_count_tracks_live_nodes():
	var pool := NodePool.new(_scene, _parent)

	assert_eq(pool.active_count, 0, "New pool should have no active nodes")
	var a := pool.acquire()
	var b := pool.acquire()
	assert_eq(pool.active_count, 2, "active_count should rise on acquire")

	pool.release(a)
	assert_eq(pool.active_count, 1, "active_count should fall on release")
	pool.release(b)
	assert_eq(pool.active_count, 0, "active_count should return to zero")
	pool.clear()


func test_double_release_is_ignored():
	var pool := NodePool.new(_scene, _parent)

	var node := pool.acquire()
	pool.release(node)
	pool.release(node)

	# A node banked twice would later be handed to two owners at once.
	var a := pool.acquire()
	var b := pool.acquire()
	assert_ne(a.get_instance_id(), b.get_instance_id(), "Double release must not bank the node twice")
	pool.clear()


func test_release_of_null_is_safe():
	var pool := NodePool.new(_scene, _parent)
	pool.release(null)
	assert_eq(pool.active_count, 0, "Releasing null should not disturb the pool")
	pool.clear()


# =============================================================================
# ACTIVATION STATE
# =============================================================================

func test_released_node_is_hidden_and_reactivated_on_acquire():
	var pool := NodePool.new(_scene, _parent)

	var node := pool.acquire()
	pool.release(node)
	assert_false(node.visible, "Idle pooled node should be hidden")

	var reused := pool.acquire()
	assert_true(reused.visible, "Reacquired node should be visible again")
	pool.clear()


# =============================================================================
# PREWARM AND IDLE CAP
# =============================================================================

func test_prewarm_creates_hidden_nodes_up_front():
	var pool := NodePool.new(_scene, _parent, 4)

	assert_eq(_parent.get_child_count(), 4, "Prewarm should instantiate up front")
	assert_eq(pool.active_count, 0, "Prewarmed nodes should not count as active")
	for child in _parent.get_children():
		assert_false(child.visible, "Prewarmed nodes should start hidden")
	pool.clear()


func test_idle_cap_frees_rather_than_growing():
	var pool := NodePool.new(_scene, _parent, 0, 2)

	var nodes := []
	for i in range(5):
		nodes.append(pool.acquire())
	assert_eq(_parent.get_child_count(), 5, "All five should exist while active")

	for node in nodes:
		pool.release(node)

	# Past the cap, releases are freed instead of retained.
	await wait_process_frames(2)
	assert_eq(_parent.get_child_count(), 2, "Pool should retain only max_idle nodes")
	pool.clear()


# =============================================================================
# POOL HOOKS
# =============================================================================

func test_pool_release_callable_is_assigned_to_node():
	var pool := NodePool.new(_scene, _parent)
	var node := pool.acquire()

	assert_true(node.pool_release.is_valid(), "Pool should assign a valid pool_release Callable")
	pool.clear()


func test_pool_released_hook_clears_per_use_state():
	var pool := NodePool.new(_scene, _parent)

	var node := pool.acquire()
	node.scale = Vector2(1.4, 1.4) # what a crit does
	node.modulate = Color(1, 0, 0, 0.3)
	pool.release(node)

	assert_eq(node.scale, Vector2.ONE, "Crit scale should not survive into the next use")
	assert_eq(node.modulate, Color.WHITE, "Fade/tint should not survive into the next use")
	pool.clear()


# =============================================================================
# TEARDOWN
# =============================================================================

func test_clear_frees_idle_nodes():
	var pool := NodePool.new(_scene, _parent, 3)
	pool.clear()

	await wait_process_frames(2)
	assert_eq(_parent.get_child_count(), 0, "clear() should free every retained node")
