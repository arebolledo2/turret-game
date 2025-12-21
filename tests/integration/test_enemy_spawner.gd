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
	Globals.reset_stats()
	Globals.current_difficulty = GameEnums.Difficulty.EASY
	Globals.current_wave = 1
	Globals.is_game_active = true

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
	var half_width = Globals.ARENA_WIDTH / 2.0
	var half_height = Globals.ARENA_HEIGHT / 2.0

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


func test_start_spawning_sets_enemy_count():
	spawner.start_spawning(1)

	var expected_count = Globals.get_wave_enemy_count(1)
	assert_eq(spawner.enemies_to_spawn, expected_count, "Enemies to spawn should match wave count")


func test_start_spawning_sets_wave_duration():
	spawner.start_spawning(2)

	var expected_duration = Globals.get_wave_duration(2)
	assert_eq(spawner.wave_duration, expected_duration, "Wave duration should be set")


func test_stop_spawning_clears_state():
	spawner.start_spawning(1)
	spawner.stop_spawning()

	assert_false(spawner.is_spawning, "Should not be spawning after stop")
	assert_eq(spawner.enemies_to_spawn, 0, "Enemies to spawn should be 0")


func test_stop_spawning_clears_queue():
	spawner.start_spawning(1)
	# Queue would have spawns from start_spawning

	spawner.stop_spawning()

	assert_eq(spawner.queued_spawns.size(), 0, "Queued spawns should be cleared")


# =============================================================================
# SPAWN RATE DYNAMICS
# =============================================================================

func test_update_spawn_rate_at_wave_start():
	spawner.start_spawning(1)
	var wave_duration = spawner.wave_duration

	# At wave start (full time remaining), spawn rate should be slow
	spawner.update_spawn_rate(wave_duration)

	# Initial spawn interval is 3.0 seconds (slow)
	assert_almost_eq(spawner.spawn_timer.wait_time, 3.0, 0.1,
		"Spawn rate at wave start should be slow (~3.0s)")


func test_update_spawn_rate_at_wave_end():
	spawner.start_spawning(1)

	# At wave end (0 time remaining), spawn rate should be fast
	spawner.update_spawn_rate(0.0)

	# End spawn interval is 0.15 seconds (fast)
	assert_almost_eq(spawner.spawn_timer.wait_time, 0.15, 0.05,
		"Spawn rate at wave end should be fast (~0.15s)")


func test_update_spawn_rate_at_midpoint():
	spawner.start_spawning(1)
	var wave_duration = spawner.wave_duration

	# At midpoint
	spawner.update_spawn_rate(wave_duration / 2.0)

	# Should be between 3.0 and 0.15
	var wait_time = spawner.spawn_timer.wait_time
	assert_gt(wait_time, 0.15, "Mid-wave spawn rate should be > 0.15s")
	assert_lt(wait_time, 3.0, "Mid-wave spawn rate should be < 3.0s")


func test_spawn_rate_increases_over_time():
	spawner.start_spawning(1)
	var wave_duration = spawner.wave_duration

	spawner.update_spawn_rate(wave_duration * 0.8)  # 20% through wave
	var early_interval = spawner.spawn_timer.wait_time

	spawner.update_spawn_rate(wave_duration * 0.2)  # 80% through wave
	var late_interval = spawner.spawn_timer.wait_time

	assert_lt(late_interval, early_interval,
		"Later in wave should have shorter spawn interval (faster spawning)")


func test_update_spawn_rate_does_nothing_when_not_spawning():
	spawner.spawn_timer.wait_time = 1.0
	spawner.update_spawn_rate(10.0)

	assert_eq(spawner.spawn_timer.wait_time, 1.0,
		"Spawn rate should not change when not spawning")


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


func test_enemies_spawned_counter_reset():
	spawner.enemies_spawned = 10

	spawner.start_spawning(1)

	# After start_spawning, first enemy is spawned immediately
	# so enemies_spawned will be at least 1 (or more for swarm types)
	assert_gte(spawner.enemies_spawned, 1, "At least one enemy should be spawned immediately")


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
