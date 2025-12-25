extends GutTest

## Unit tests for ArenaBoundsService

# Get the service's fixed dimensions for testing
const FIXED_ARENA_WIDTH: int = 1920
const FIXED_ARENA_HEIGHT: int = 1080

func before_each() -> void:
	ArenaBoundsService.reset_state()

# =============================================================================
# RECTANGULAR BOUNDS TESTS
# =============================================================================

func test_rectangular_is_default_type() -> void:
	assert_eq(ArenaBoundsService.get_arena_type(), GameEnums.ArenaType.RECTANGULAR)

func test_rectangular_center_is_inside() -> void:
	ArenaBoundsService.set_arena_type(GameEnums.ArenaType.RECTANGULAR)
	assert_true(ArenaBoundsService.is_inside_arena(Vector2.ZERO))

func test_rectangular_near_edge_is_inside() -> void:
	var half_w: float = FIXED_ARENA_WIDTH / 2.0
	var half_h: float = FIXED_ARENA_HEIGHT / 2.0
	
	assert_true(ArenaBoundsService.is_inside_arena(Vector2(half_w - 50, 0)))
	assert_true(ArenaBoundsService.is_inside_arena(Vector2(-half_w + 50, 0)))
	assert_true(ArenaBoundsService.is_inside_arena(Vector2(0, half_h - 50)))
	assert_true(ArenaBoundsService.is_inside_arena(Vector2(0, -half_h + 50)))

func test_rectangular_outside_is_outside() -> void:
	var half_w: float = FIXED_ARENA_WIDTH / 2.0
	var half_h: float = FIXED_ARENA_HEIGHT / 2.0
	
	assert_false(ArenaBoundsService.is_inside_arena(Vector2(half_w + 50, 0)))
	assert_false(ArenaBoundsService.is_inside_arena(Vector2(-half_w - 50, 0)))
	assert_false(ArenaBoundsService.is_inside_arena(Vector2(0, half_h + 50)))
	assert_false(ArenaBoundsService.is_inside_arena(Vector2(0, -half_h - 50)))

func test_rectangular_clamp_inside_unchanged() -> void:
	var pos := Vector2(100, 50)
	var clamped := ArenaBoundsService.clamp_to_arena(pos)
	assert_eq(clamped, pos)

func test_rectangular_clamp_outside_to_edge() -> void:
	var half_w: float = FIXED_ARENA_WIDTH / 2.0
	var clamped := ArenaBoundsService.clamp_to_arena(Vector2(half_w + 100, 0))
	assert_eq(clamped.x, half_w, "Should clamp to right edge")
	assert_eq(clamped.y, 0.0, "Y should be unchanged")

# =============================================================================
# ISOMETRIC BOUNDS TESTS
# =============================================================================

func test_isometric_center_is_inside() -> void:
	ArenaBoundsService.set_arena_type(GameEnums.ArenaType.ISOMETRIC)
	assert_true(ArenaBoundsService.is_inside_arena(Vector2.ZERO))

func test_isometric_diamond_corners_are_inside() -> void:
	ArenaBoundsService.set_arena_type(GameEnums.ArenaType.ISOMETRIC)
	var half_w: float = FIXED_ARENA_WIDTH / 2.0
	var half_h: float = FIXED_ARENA_HEIGHT / 2.0
	
	# Diamond corners (on the edge, should be inside)
	assert_true(ArenaBoundsService.is_inside_arena(Vector2(half_w - 1, 0)))
	assert_true(ArenaBoundsService.is_inside_arena(Vector2(-half_w + 1, 0)))
	assert_true(ArenaBoundsService.is_inside_arena(Vector2(0, half_h - 1)))
	assert_true(ArenaBoundsService.is_inside_arena(Vector2(0, -half_h + 1)))

func test_isometric_rectangle_corners_are_outside() -> void:
	ArenaBoundsService.set_arena_type(GameEnums.ArenaType.ISOMETRIC)
	var half_w: float = FIXED_ARENA_WIDTH / 2.0
	var half_h: float = FIXED_ARENA_HEIGHT / 2.0
	
	# Rectangle corners are outside the diamond
	assert_false(ArenaBoundsService.is_inside_arena(Vector2(half_w, half_h)))
	assert_false(ArenaBoundsService.is_inside_arena(Vector2(-half_w, -half_h)))
	assert_false(ArenaBoundsService.is_inside_arena(Vector2(half_w, -half_h)))
	assert_false(ArenaBoundsService.is_inside_arena(Vector2(-half_w, half_h)))

func test_isometric_clamp_inside_unchanged() -> void:
	ArenaBoundsService.set_arena_type(GameEnums.ArenaType.ISOMETRIC)
	var pos := Vector2(50, 50) # Should be inside diamond
	var clamped := ArenaBoundsService.clamp_to_arena(pos)
	assert_eq(clamped, pos)

func test_isometric_clamp_corner_to_edge() -> void:
	ArenaBoundsService.set_arena_type(GameEnums.ArenaType.ISOMETRIC)
	
	# Get actual dimensions from service (isometric has different size)
	var half_dims := ArenaBoundsService.get_half_dimensions()
	var half_w: float = half_dims.x
	var half_h: float = half_dims.y
	
	# Point in top-right corner (outside diamond)
	var outside := Vector2(half_w, -half_h)
	var clamped := ArenaBoundsService.clamp_to_arena(outside)
	
	# Should be clamped to somewhere on the top-right edge
	assert_true(ArenaBoundsService.is_inside_arena(clamped), "Clamped point should be inside")
	
	# Check it's on or very near the edge (normalized_dist ~= 1)
	var normalized: float = abs(clamped.x) / half_w + abs(clamped.y) / half_h
	assert_almost_eq(normalized, 1.0, 0.01, "Clamped point should be on diamond edge")

# =============================================================================
# ARENA TYPE SWITCHING
# =============================================================================

func test_set_arena_type_changes_type() -> void:
	ArenaBoundsService.set_arena_type(GameEnums.ArenaType.ISOMETRIC)
	assert_eq(ArenaBoundsService.get_arena_type(), GameEnums.ArenaType.ISOMETRIC)
	
	ArenaBoundsService.set_arena_type(GameEnums.ArenaType.RECTANGULAR)
	assert_eq(ArenaBoundsService.get_arena_type(), GameEnums.ArenaType.RECTANGULAR)

func test_is_isometric_helper() -> void:
	ArenaBoundsService.set_arena_type(GameEnums.ArenaType.RECTANGULAR)
	assert_false(ArenaBoundsService.is_isometric())
	
	ArenaBoundsService.set_arena_type(GameEnums.ArenaType.ISOMETRIC)
	assert_true(ArenaBoundsService.is_isometric())

func test_reset_state_restores_rectangular() -> void:
	ArenaBoundsService.set_arena_type(GameEnums.ArenaType.ISOMETRIC)
	ArenaBoundsService.reset_state()
	assert_eq(ArenaBoundsService.get_arena_type(), GameEnums.ArenaType.RECTANGULAR)

# =============================================================================
# SPAWN POSITION TESTS
# =============================================================================

func test_random_arena_position_inside_rectangular() -> void:
	ArenaBoundsService.set_arena_type(GameEnums.ArenaType.RECTANGULAR)
	for _i in range(10):
		var pos := ArenaBoundsService.get_random_arena_position()
		assert_true(ArenaBoundsService.is_inside_arena(pos), "Random position should be inside")

func test_random_arena_position_inside_isometric() -> void:
	ArenaBoundsService.set_arena_type(GameEnums.ArenaType.ISOMETRIC)
	for _i in range(10):
		var pos := ArenaBoundsService.get_random_arena_position()
		assert_true(ArenaBoundsService.is_inside_arena(pos), "Random position should be inside diamond")

func test_edge_spawn_position_inside_rectangular() -> void:
	ArenaBoundsService.set_arena_type(GameEnums.ArenaType.RECTANGULAR)
	for _i in range(10):
		var pos := ArenaBoundsService.get_random_edge_spawn_position()
		assert_true(ArenaBoundsService.is_inside_arena(pos), "Edge spawn should be inside")

func test_edge_spawn_position_inside_isometric() -> void:
	ArenaBoundsService.set_arena_type(GameEnums.ArenaType.ISOMETRIC)
	for _i in range(10):
		var pos := ArenaBoundsService.get_random_edge_spawn_position()
		assert_true(ArenaBoundsService.is_inside_arena(pos), "Edge spawn should be inside diamond")
