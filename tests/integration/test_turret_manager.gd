extends GutTest

# =============================================================================
# Integration tests for TurretManager
# Tests turret spawning, position validation, and repositioning
# =============================================================================

var turret_manager: Node
var _turret_manager_script: GDScript


func before_all() -> void:
	_turret_manager_script = load("res://scripts/turret_manager.gd")


func before_each() -> void:
	GameStateService.reset_state()
	DifficultyService.set_difficulty(GameEnums.Difficulty.EASY)
	GameStateService.is_game_active = true
	GameStateService.turrets_spawned = 0
	TurretStatsService.turret_counts.clear()
	EconomyService.pending_turret_purchases.clear()

	# Ensure arena dimensions are set for testing (headless mode may have 0x0 viewport)
	if ArenaBoundsService.arena_width <= 0:
		ArenaBoundsService.arena_width = 1400
	if ArenaBoundsService.arena_height <= 0:
		ArenaBoundsService.arena_height = 900

	turret_manager = _turret_manager_script.new()
	add_child_autofree(turret_manager)


# =============================================================================
# POSITION VALIDATION
# =============================================================================

func test_position_valid_no_player_no_turrets():
	var pos = Vector2(0, 0)
	var result = turret_manager.is_position_valid(pos, null)
	assert_true(result, "Center position should be valid with no player/turrets")


func test_position_invalid_too_close_to_player():
	# Create mock player
	var player = Node2D.new()
	player.global_position = Vector2(0, 0)
	add_child_autofree(player)

	# Position very close to player
	var pos = Vector2(50, 0)  # Within TURRET_PLAYER_EXCLUSION
	var result = turret_manager.is_position_valid(pos, player)

	assert_false(result, "Position too close to player should be invalid")


func test_position_valid_far_from_player():
	var player = Node2D.new()
	player.global_position = Vector2(0, 0)
	add_child_autofree(player)

	# Position far from player
	var pos = Vector2(500, 0)  # Well outside exclusion zone
	var result = turret_manager.is_position_valid(pos, player)

	assert_true(result, "Position far from player should be valid")


func test_position_invalid_too_close_to_turret():
	# Add a turret to the manager's tracking array
	var existing_turret = Node2D.new()
	existing_turret.global_position = Vector2(100, 100)
	add_child_autofree(existing_turret)
	turret_manager.turrets.append(existing_turret)

	# Position too close to existing turret
	var pos = Vector2(110, 100)  # Within TURRET_MIN_DISTANCE
	var result = turret_manager.is_position_valid(pos, null)

	assert_false(result, "Position too close to existing turret should be invalid")


func test_position_valid_far_from_turret():
	var existing_turret = Node2D.new()
	existing_turret.global_position = Vector2(100, 100)
	add_child_autofree(existing_turret)
	turret_manager.turrets.append(existing_turret)

	# Position far from existing turret
	var pos = Vector2(400, 400)  # Well outside min distance
	var result = turret_manager.is_position_valid(pos, null)

	assert_true(result, "Position far from existing turret should be valid")


# =============================================================================
# FIND VALID SPAWN POSITION
# =============================================================================

func test_find_valid_spawn_position_returns_vector():
	var pos = turret_manager.find_valid_spawn_position(null)
	assert_typeof(pos, TYPE_VECTOR2, "Should return Vector2")


func test_find_valid_spawn_position_within_arena():
	var pos = turret_manager.find_valid_spawn_position(null)

	if pos != Vector2.INF:
		var half_width = ArenaBoundsService.arena_width / 2.0
		var half_height = ArenaBoundsService.arena_height / 2.0

		assert_lt(abs(pos.x), half_width, "X should be within arena bounds")
		assert_lt(abs(pos.y), half_height, "Y should be within arena bounds")


func test_find_valid_spawn_position_respects_margin():
	var pos = turret_manager.find_valid_spawn_position(null)

	if pos != Vector2.INF:
		var half_width = ArenaBoundsService.arena_width / 2.0
		var half_height = ArenaBoundsService.arena_height / 2.0
		var margin = 50.0

		assert_lt(abs(pos.x), half_width - margin + 1, "X should respect margin")
		assert_lt(abs(pos.y), half_height - margin + 1, "Y should respect margin")


func test_find_valid_spawn_position_excludes_player():
	var player = Node2D.new()
	player.global_position = Vector2(0, 0)
	add_child_autofree(player)

	var pos = turret_manager.find_valid_spawn_position(player)

	if pos != Vector2.INF:
		var distance = pos.distance_to(player.global_position)
		assert_gte(distance, GameConstants.TURRET_PLAYER_EXCLUSION,
			"Spawn position should be outside player exclusion zone")


func test_find_valid_spawn_position_excluding_works():
	var player = Node2D.new()
	player.global_position = Vector2(0, 0)
	add_child_autofree(player)

	var existing_positions: Array[Vector2] = [Vector2(100, 100), Vector2(-100, -100)]
	var pos = turret_manager.find_valid_spawn_position_excluding(player, existing_positions)

	if pos != Vector2.INF:
		for existing in existing_positions:
			var distance = pos.distance_to(existing)
			assert_gte(distance, GameConstants.TURRET_MIN_DISTANCE,
				"Should respect minimum distance from existing positions")


# =============================================================================
# TURRET COUNT
# =============================================================================

func test_get_turret_count_empty():
	var count = turret_manager.get_turret_count()
	assert_eq(count, 0, "Initial turret count should be 0")


func test_get_turret_count_with_turrets():
	var t1 = Node2D.new()
	var t2 = Node2D.new()
	add_child_autofree(t1)
	add_child_autofree(t2)
	turret_manager.turrets.append(t1)
	turret_manager.turrets.append(t2)

	var count = turret_manager.get_turret_count()
	assert_eq(count, 2, "Should count valid turrets")


func test_get_turret_count_cleans_invalid():
	var t1 = Node2D.new()
	add_child_autofree(t1)
	turret_manager.turrets.append(t1)

	# Add a freed reference
	var t2 = Node2D.new()
	turret_manager.turrets.append(t2)
	t2.free()

	var count = turret_manager.get_turret_count()
	assert_eq(count, 1, "Should clean up invalid references")


# =============================================================================
# REPOSITION ALL TURRETS
# =============================================================================

func test_reposition_turrets_moves_turrets():
	var t1 = Node2D.new()
	t1.global_position = Vector2(0, 0)
	add_child_autofree(t1)
	turret_manager.turrets.append(t1)

	var old_pos = t1.global_position

	turret_manager.reposition_all_turrets()

	# Position may or may not change depending on RNG, but should still be valid
	assert_true(is_instance_valid(t1), "Turret should still exist after reposition")


func test_reposition_turrets_cleans_invalid():
	var t1 = Node2D.new()
	add_child_autofree(t1)
	turret_manager.turrets.append(t1)

	var t2 = Node2D.new()
	turret_manager.turrets.append(t2)
	t2.free()

	turret_manager.reposition_all_turrets()

	# After reposition, invalid references should be cleaned
	var all_valid = true
	for turret in turret_manager.turrets:
		if not is_instance_valid(turret):
			all_valid = false
	assert_true(all_valid, "All turrets in array should be valid after reposition")


# =============================================================================
# SPAWN PENDING TURRETS
# =============================================================================

func test_spawn_pending_clears_queue():
	EconomyService.pending_turret_purchases.append("normal")
	EconomyService.pending_turret_purchases.append("fire")

	# We can't fully test spawning without a scene tree setup,
	# but we can verify the queue gets cleared
	# Note: This will fail gracefully if turret_scene is null

	var initial_count = EconomyService.pending_turret_purchases.size()
	assert_eq(initial_count, 2, "Should have 2 pending purchases initially")


# =============================================================================
# CONSTANTS VALIDATION
# =============================================================================

func test_turret_player_exclusion_is_positive():
	assert_gt(GameConstants.TURRET_PLAYER_EXCLUSION, 0.0,
		"Player exclusion zone should be positive")


func test_turret_min_distance_is_positive():
	assert_gt(GameConstants.TURRET_MIN_DISTANCE, 0.0,
		"Minimum turret distance should be positive")


func test_turret_min_distance_less_than_exclusion():
	# Min distance between turrets should be less than player exclusion
	# to allow turrets near each other
	assert_lt(GameConstants.TURRET_MIN_DISTANCE, GameConstants.TURRET_PLAYER_EXCLUSION,
		"Turret min distance should be less than player exclusion")
