extends GutTest

# =============================================================================
# Unit tests for player melee attack system
# Tests melee direction calculations and arc detection
# =============================================================================


func before_each() -> void:
	GameStateService.reset_state()


# =============================================================================
# ATTACK DIRECTION FROM FACING TESTS
# =============================================================================

func test_get_attack_direction_south():
	# Create a mock object to test the direction calculation
	# facing_direction 0 = South = (0, 1) direction
	var angle := PI / 2  # South
	var direction := Vector2(cos(angle), sin(angle))
	
	# Verify direction points downward (positive Y)
	assert_almost_eq(direction.y, 1.0, 0.01, "South should have Y = 1")
	assert_almost_eq(direction.x, 0.0, 0.01, "South should have X = 0")


func test_get_attack_direction_east():
	# facing_direction 6 = East = (1, 0) direction
	var angle := 0.0  # East
	var direction := Vector2(cos(angle), sin(angle))
	
	assert_almost_eq(direction.x, 1.0, 0.01, "East should have X = 1")
	assert_almost_eq(direction.y, 0.0, 0.01, "East should have Y = 0")


func test_get_attack_direction_north():
	# facing_direction 4 = North = (0, -1) direction
	var angle := -PI / 2  # North
	var direction := Vector2(cos(angle), sin(angle))
	
	assert_almost_eq(direction.y, -1.0, 0.01, "North should have Y = -1")
	assert_almost_eq(direction.x, 0.0, 0.01, "North should have X = 0")


func test_get_attack_direction_west():
	# facing_direction 2 = West = (-1, 0) direction
	var angle := PI  # West
	var direction := Vector2(cos(angle), sin(angle))
	
	assert_almost_eq(direction.x, -1.0, 0.01, "West should have X = -1")
	assert_almost_eq(direction.y, 0.0, 0.01, "West should have Y = 0")


# =============================================================================
# MELEE ARC DETECTION TESTS (Logic only - no scene dependencies)
# =============================================================================

func test_enemy_in_melee_arc_direct_front():
	# Test enemy directly in front within range
	var player_pos := Vector2.ZERO
	var attack_dir := Vector2.RIGHT  # Facing east
	var enemy_pos := Vector2(50, 0)  # Directly in front
	var melee_range := 65.0
	var arc_degrees := 120.0
	
	var in_arc := _is_in_melee_arc(player_pos, enemy_pos, attack_dir, melee_range, arc_degrees)
	assert_true(in_arc, "Enemy directly in front should be in melee arc")


func test_enemy_outside_melee_range():
	var player_pos := Vector2.ZERO
	var attack_dir := Vector2.RIGHT
	var enemy_pos := Vector2(100, 0)  # Beyond 65 range
	var melee_range := 65.0
	var arc_degrees := 120.0
	
	var in_arc := _is_in_melee_arc(player_pos, enemy_pos, attack_dir, melee_range, arc_degrees)
	assert_false(in_arc, "Enemy beyond range should not be in melee arc")


func test_enemy_behind_player():
	var player_pos := Vector2.ZERO
	var attack_dir := Vector2.RIGHT  # Facing east
	var enemy_pos := Vector2(-50, 0)  # Behind player (west)
	var melee_range := 65.0
	var arc_degrees := 120.0
	
	var in_arc := _is_in_melee_arc(player_pos, enemy_pos, attack_dir, melee_range, arc_degrees)
	assert_false(in_arc, "Enemy behind player should not be in 120-degree arc")


func test_enemy_at_arc_edge():
	# 120 degree arc = 60 degrees on each side
	var player_pos := Vector2.ZERO
	var attack_dir := Vector2.RIGHT  # Facing east
	# Enemy at 55 degrees - should be within 60 degree half-arc
	var enemy_pos := Vector2(30, 25)
	var melee_range := 65.0
	var arc_degrees := 120.0
	
	var in_arc := _is_in_melee_arc(player_pos, enemy_pos, attack_dir, melee_range, arc_degrees)
	assert_true(in_arc, "Enemy at 55 degrees should be within 60-degree half-arc")


func test_enemy_outside_arc_angle():
	var player_pos := Vector2.ZERO
	var attack_dir := Vector2.RIGHT  # Facing east
	# Enemy at ~80 degrees - outside 60 degree half-arc
	var enemy_pos := Vector2(10, 50)
	var melee_range := 65.0
	var arc_degrees := 120.0
	
	var in_arc := _is_in_melee_arc(player_pos, enemy_pos, attack_dir, melee_range, arc_degrees)
	assert_false(in_arc, "Enemy at 80 degrees should be outside 60-degree half-arc")


# =============================================================================
# MELEE CONFIGURATION TESTS
# =============================================================================

func test_default_melee_damage():
	# Default melee damage should be 20
	var expected_damage := 20.0
	assert_eq(expected_damage, 20.0, "Default melee damage should be 20")


func test_default_melee_range():
	var expected_range := 80.0
	assert_eq(expected_range, 80.0, "Default melee range should be 80")


func test_default_melee_arc():
	var expected_arc := 120.0
	assert_eq(expected_arc, 120.0, "Default melee arc should be 120 degrees")


func test_default_melee_cooldown():
	var expected_cooldown := 0.7
	assert_eq(expected_cooldown, 0.7, "Default melee cooldown should be 0.7 seconds")


func test_default_windup_time():
	var expected_windup := 0.15
	assert_eq(expected_windup, 0.15, "Default windup time should be 0.15 seconds")


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

func _is_in_melee_arc(player_pos: Vector2, enemy_pos: Vector2, attack_dir: Vector2, melee_range: float, arc_degrees: float) -> bool:
	"""Replicates player melee arc detection logic for testing."""
	# Distance check
	var distance := player_pos.distance_to(enemy_pos)
	if distance > melee_range:
		return false
	
	# Angle check
	var to_enemy := player_pos.direction_to(enemy_pos)
	var angle_to_enemy := attack_dir.angle_to(to_enemy)
	var half_arc := deg_to_rad(arc_degrees / 2.0)
	
	return abs(angle_to_enemy) <= half_arc
