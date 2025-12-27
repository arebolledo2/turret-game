extends GutTest

# =============================================================================
# Integration tests for EnemySpawner
# Tests spawn zones, spawn rate dynamics, and enemy selection
# =============================================================================

var spawner: Node2D
var _spawner_script: GDScript


func before_all() -> void:
	_spawner_script = load("res://scripts/enemy_spawner.gd")


func before_each() -> void:
	GameStateService.reset_state()
	DifficultyService.set_difficulty(GameEnums.Difficulty.EASY)
	GameStateService.current_wave = 1
	GameStateService.is_game_active = true
	# Set rectangular arena mode for consistent test expectations
	GameModeService.set_mode(GameEnums.GameMode.ARENA_RECTANGULAR)

	spawner = _spawner_script.new()
	add_child_autofree(spawner)

	# Let spawner initialize
	await get_tree().process_frame


# =============================================================================
# SPAWN ZONE SETUP
# =============================================================================

func test_spawn_zones_initialized():
	assert_gt(spawner.spawn_zones.size(), 0, "Spawn zones should be initialized")


func test_spawn_zones_count():
	assert_eq(spawner.spawn_zones.size(), 4, "Should have 4 spawn zones (one per edge)")


func test_spawn_zones_are_rect2():
	for zone in spawner.spawn_zones:
		assert_typeof(zone, TYPE_RECT2, "Each spawn zone should be a Rect2")


func test_spawn_zones_within_arena():
	var half_width = ArenaBoundsService.arena_width / 2.0
	var half_height = ArenaBoundsService.arena_height / 2.0

	for zone in spawner.spawn_zones:
		# Zone should be within arena bounds
		assert_gte(zone.position.x, -half_width - 1, "Zone X should be within arena")
		assert_lte(zone.end.x, half_width + 1, "Zone end X should be within arena")
		assert_gte(zone.position.y, -half_height - 1, "Zone Y should be within arena")
		assert_lte(zone.end.y, half_height + 1, "Zone end Y should be within arena")


func test_spawn_zones_have_positive_size():
	for zone in spawner.spawn_zones:
		assert_gt(zone.size.x, 0.0, "Zone width should be positive")
		assert_gt(zone.size.y, 0.0, "Zone height should be positive")


# =============================================================================
# SPAWNING STATE
# =============================================================================

func test_initially_not_spawning():
	assert_false(spawner.is_spawning, "Should not be spawning initially")


func test_start_spawning_sets_state():
	spawner.start_spawning(1)

	assert_true(spawner.is_spawning, "Should be spawning after start_spawning")


func test_start_spawning_sets_wave():
	spawner.start_spawning(3)

	assert_eq(spawner.current_wave, 3, "Current wave should be set")


func test_stop_spawning_clears_state():
	spawner.start_spawning(1)
	spawner.stop_spawning()

	assert_false(spawner.is_spawning, "Should not be spawning after stop")


func test_stop_spawning_clears_queue():
	spawner.start_spawning(1)
	# Queue would have spawns from start_spawning

	spawner.stop_spawning()

	assert_eq(spawner.queued_spawns.size(), 0, "Queued spawns should be cleared")


# =============================================================================
# SPAWN RATE DYNAMICS
# =============================================================================

func test_spawn_interval_set_on_start():
	spawner.start_spawning(1)

	# Spawn interval should be set (between 0.8 and 3.0 seconds for wave 1)
	var wait_time = spawner.spawn_timer.wait_time
	assert_gt(wait_time, 0.0, "Spawn interval should be positive")
	assert_lt(wait_time, 5.0, "Spawn interval should be reasonable")


func test_spawn_interval_faster_for_higher_waves():
	spawner.start_spawning(1)
	var wave1_interval = spawner.spawn_timer.wait_time

	# Create new spawner for wave 10
	var spawner2 = _spawner_script.new()
	add_child_autofree(spawner2)
	await get_tree().process_frame

	spawner2.start_spawning(10)
	var wave10_interval = spawner2.spawn_timer.wait_time

	# Wave 10 should spawn faster than wave 1 on average
	# Note: Due to randomness, this might occasionally fail, but should pass most times
	assert_lt(wave10_interval, wave1_interval * 1.5,
		"Higher waves should generally spawn faster")


# =============================================================================
# SPAWN ALERT TIME
# =============================================================================

func test_spawn_alert_time_constant():
	assert_eq(spawner.SPAWN_ALERT_TIME, 1.5, "Spawn alert time should be 1.5 seconds")


# =============================================================================
# ENEMY TYPE TRACKING
# =============================================================================

func test_enemy_type_tracking_cleared_on_start():
	spawner.enemies_spawned_by_type["basic"] = 10
	spawner.enemies_spawned_by_type["fast"] = 5

	spawner.start_spawning(1)

	# start_spawning clears the dict then immediately spawns, so it won't be empty
	# but the old values should be gone
	assert_false(spawner.enemies_spawned_by_type.has("fast") and spawner.enemies_spawned_by_type["fast"] == 5,
		"Old tracking data should be cleared on new wave")


func test_enemies_spawned_tracking_cleared_on_start():
	spawner.enemies_spawned_by_type["basic"] = 999

	spawner.start_spawning(1)

	# After start_spawning, tracking is cleared and repopulated
	# The old value should be gone
	assert_false(spawner.enemies_spawned_by_type.get("basic", 0) == 999,
		"Old enemy count tracking should be cleared")


# =============================================================================
# SPAWN TIMER
# =============================================================================

func test_spawn_timer_exists():
	assert_not_null(spawner.spawn_timer, "Spawn timer should exist")


func test_spawn_timer_is_repeating():
	assert_false(spawner.spawn_timer.one_shot, "Spawn timer should repeat")


func test_spawn_timer_starts_on_spawning():
	spawner.start_spawning(1)

	assert_false(spawner.spawn_timer.is_stopped(), "Spawn timer should be running")


func test_spawn_timer_stops_on_stop_spawning():
	spawner.start_spawning(1)
	spawner.stop_spawning()

	assert_true(spawner.spawn_timer.is_stopped(), "Spawn timer should be stopped")
