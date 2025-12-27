extends GutTest

# =============================================================================
# Integration tests for defense_target.gd
# Tests defense target behavior, damage handling, and interactions
# =============================================================================

var defense_target_scene: PackedScene
var defense_target: Node
var tech_drop_scene: PackedScene


func before_all() -> void:
	defense_target_scene = load("res://scenes/defense_target.tscn")
	tech_drop_scene = load("res://scenes/tech_drop.tscn")


func before_each() -> void:
	Globals.reset_stats()
	Globals.current_difficulty = GameEnums.Difficulty.EASY
	Globals.is_game_active = true

	defense_target = defense_target_scene.instantiate()
	add_child_autofree(defense_target)


# =============================================================================
# INITIALIZATION TESTS
# =============================================================================

func test_defense_target_initializes_with_correct_health():
	var expected_hp = GameConstants.DEFENSE_TARGET_BASE_HEALTH
	assert_eq(defense_target.current_health, expected_hp, "Defense target should initialize with base health")


func test_defense_target_added_to_group():
	assert_true(defense_target.is_in_group("defense_targets"), "Defense target should be in 'defense_targets' group")


# =============================================================================
# TECH DROP COLLISION TESTS
# =============================================================================

func test_tech_drop_does_not_damage_defense_target():
	"""Test that tech drops spawning near the defense target don't cause damage."""
	var initial_health = defense_target.current_health

	# Create and position tech drop at center (where defense target is)
	var tech_drop = tech_drop_scene.instantiate()
	tech_drop.global_position = Vector2.ZERO
	tech_drop.initialize(1)
	add_child_autofree(tech_drop)

	# Wait for physics to process the collision
	await wait_frames(3)

	# Verify no damage was taken
	assert_eq(
		defense_target.current_health,
		initial_health,
		"Defense target should not take damage from spawning tech drop"
	)


func test_tech_drop_ignored_even_when_in_enemies_group():
	"""Verify tech drops are in enemies group but excluded from defense target damage."""
	var tech_drop = tech_drop_scene.instantiate()
	tech_drop.global_position = Vector2.ZERO
	add_child_autofree(tech_drop)

	# Verify tech drop is in both groups
	assert_true(tech_drop.is_in_group("tech_drops"), "Tech drop should be in tech_drops group")
	assert_true(tech_drop.is_in_group("enemies"), "Tech drop should be in enemies group for turret targeting")

	var initial_health = defense_target.current_health

	# Simulate the body_entered collision detection
	await wait_frames(3)

	# Verify defense target didn't take damage despite tech drop being in enemies group
	assert_eq(
		defense_target.current_health,
		initial_health,
		"Tech drop should be excluded from damage even though in enemies group"
	)


# =============================================================================
# ENEMY DAMAGE TESTS
# =============================================================================

func test_enemy_still_damages_defense_target():
	"""Verify that actual enemies still damage the defense target."""
	var initial_health = defense_target.current_health

	# Create an enemy
	var enemy_scene = load("res://scenes/enemy.tscn")
	var enemy = enemy_scene.instantiate()
	enemy.global_position = Vector2.ZERO
	enemy.initialize(1)
	add_child_autofree(enemy)

	# Wait for physics to process the collision
	await wait_frames(3)

	# Verify damage was taken from actual enemy
	assert_lt(
		defense_target.current_health,
		initial_health,
		"Defense target should take damage from actual enemies"
	)


# =============================================================================
# BARRIER TESTS
# =============================================================================

func test_barrier_activates_on_damage():
	"""Verify that the barrier activates automatically when taking damage."""
	# Create an enemy to damage the target
	var enemy_scene = load("res://scenes/enemy.tscn")
	var enemy = enemy_scene.instantiate()
	enemy.global_position = Vector2.ZERO
	enemy.initialize(1)
	add_child_autofree(enemy)

	# Wait for physics to process the collision and barrier activation
	await wait_frames(3)

	# Verify barrier is now active (activated on damage)
	assert_true(
		defense_target.barrier_active,
		"Barrier should activate automatically when target takes damage"
	)
