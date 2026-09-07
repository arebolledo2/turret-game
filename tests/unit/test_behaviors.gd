extends GutTest

# =============================================================================
# Unit tests for Enemy Behavior System
# Tests behavior base class and specific behavior implementations
# =============================================================================


# =============================================================================
# MOCK OBJECTS
# =============================================================================

class MockEnemy extends CharacterBody2D:
	var player = null  # Add this property to match Enemy class behavior
	# CharacterBody2D already has global_position and get_tree() from base class
	pass


# =============================================================================
# BASE BEHAVIOR
# =============================================================================

func test_enemy_behavior_base_class_exists():
	# Base class should exist and be instantiable
	var mock_enemy = CharacterBody2D.new()
	mock_enemy.set_script(load("res://tests/unit/mock_enemy_script.gd"))
	add_child_autofree(mock_enemy)
	
	var behavior = EnemyBehavior.new(mock_enemy, {})
	assert_not_null(behavior, "EnemyBehavior should be instantiable")
	assert_not_null(behavior.enemy, "Enemy reference should be set")


func test_enemy_behavior_stores_params():
	var mock_enemy = CharacterBody2D.new()
	mock_enemy.set_script(load("res://tests/unit/mock_enemy_script.gd"))
	add_child_autofree(mock_enemy)
	
	var test_params = {"test_key": "test_value", "number": 42}
	var behavior = EnemyBehavior.new(mock_enemy, test_params)
	
	assert_eq(behavior.params.get("test_key"), "test_value")
	assert_eq(behavior.params.get("number"), 42)


func test_enemy_behavior_default_params_empty():
	var defaults = EnemyBehavior.get_default_params()
	assert_eq(defaults.size(), 0, "Base class should have empty default params")


# =============================================================================
# CHASE BEHAVIOR
# =============================================================================

func test_chase_behavior_inherits_base():
	var mock_enemy = CharacterBody2D.new()
	mock_enemy.set_script(load("res://tests/unit/mock_enemy_script.gd"))
	add_child_autofree(mock_enemy)

	var behavior = ChaseBehavior.new(mock_enemy, {})
	assert_true(behavior is EnemyBehavior, "ChaseBehavior should extend EnemyBehavior")


func test_chase_behavior_returns_zero_without_player():
	var mock_enemy = CharacterBody2D.new()
	# Add player property manually using a script to ensure it's accessible via dot notation
	mock_enemy.set_script(load("res://tests/unit/mock_enemy_script.gd"))
	mock_enemy.set("player", null)
	add_child_autofree(mock_enemy)
	mock_enemy.global_position = Vector2(100, 100)
	
	var behavior = ChaseBehavior.new(mock_enemy, {})
	var direction = behavior.execute(0.1)
	
	assert_eq(direction, Vector2.ZERO, "Should return ZERO when no player exists")


# =============================================================================
# WANDER BEHAVIOR
# =============================================================================

func test_wander_behavior_has_default_params():
	var defaults = WanderBehavior.get_default_params()
	
	assert_has(defaults, "wander_pause_min", "Should have pause min param")
	assert_has(defaults, "wander_pause_max", "Should have pause max param")
	assert_has(defaults, "wander_move_min", "Should have move min param")
	assert_has(defaults, "wander_move_max", "Should have move max param")
	assert_has(defaults, "arrival_distance", "Should have arrival distance param")


func test_wander_behavior_default_param_values():
	var defaults = WanderBehavior.get_default_params()
	
	assert_eq(defaults["wander_pause_min"], 1.5)
	assert_eq(defaults["wander_pause_max"], 3.0)
	assert_eq(defaults["wander_move_min"], 2.0)
	assert_eq(defaults["wander_move_max"], 4.0)
	assert_eq(defaults["arrival_distance"], 20.0)


func test_wander_behavior_initializes_paused():
	var mock_enemy = MockEnemy.new()
	add_child_autofree(mock_enemy)
	
	var behavior = WanderBehavior.new(mock_enemy, {})
	behavior.enter()
	
	assert_false(behavior.is_wandering, "Should start in paused state")


func test_wander_behavior_returns_zero_when_paused():
	var mock_enemy = CharacterBody2D.new()
	mock_enemy.set_script(load("res://tests/unit/mock_enemy_script.gd"))
	add_child_autofree(mock_enemy)
	mock_enemy.global_position = Vector2.ZERO
	
	var behavior = WanderBehavior.new(mock_enemy, {})
	behavior.enter()
	behavior.is_wandering = false
	behavior.wander_timer = 5.0 # Don't let it expire
	
	var direction = behavior.execute(0.1)
	assert_eq(direction, Vector2.ZERO, "Should return ZERO when paused")


func test_wander_behavior_returns_direction_when_moving():
	var mock_enemy = MockEnemy.new()
	add_child_autofree(mock_enemy)
	mock_enemy.global_position = Vector2.ZERO
	
	var behavior = WanderBehavior.new(mock_enemy, {})
	behavior.enter()
	behavior.is_wandering = true
	behavior.wander_target = Vector2(100, 0)
	behavior.wander_timer = 5.0 # Don't let it expire
	
	var direction = behavior.execute(0.1)
	assert_ne(direction, Vector2.ZERO, "Should return non-zero direction when moving")
	assert_almost_eq(direction.x, 1.0, 0.01, "Direction should point toward target")


func test_wander_timer_decreases():
	var mock_enemy = MockEnemy.new()
	add_child_autofree(mock_enemy)
	mock_enemy.global_position = Vector2.ZERO
	
	var behavior = WanderBehavior.new(mock_enemy, {})
	behavior.enter()
	behavior.wander_timer = 5.0
	
	behavior.execute(1.0)
	
	assert_almost_eq(behavior.wander_timer, 4.0, 0.01, "Timer should decrease by delta")


func test_wander_switches_state_when_timer_expires():
	var mock_enemy = MockEnemy.new()
	add_child_autofree(mock_enemy)
	mock_enemy.global_position = Vector2.ZERO
	
	var behavior = WanderBehavior.new(mock_enemy, {})
	behavior.enter()
	behavior.is_wandering = false
	behavior.wander_timer = 0.1
	
	# Execute with enough time to trigger switch
	behavior.execute(0.2)
	
	assert_true(behavior.is_wandering, "Should switch to wandering when pause timer expires")


func before_each() -> void:
	TestHelpers.reset_all_services()
