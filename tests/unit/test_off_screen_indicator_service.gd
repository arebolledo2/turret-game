extends GutTest

# =============================================================================
# Unit tests for OffScreenIndicatorService
# Tests sector calculation, entity tracking, color lookups, and display names
# =============================================================================

var service: Node


func before_all() -> void:
	service = get_node("/root/OffScreenIndicatorService")


func before_each() -> void:
	service.tracked_entities.clear()


# =============================================================================
# CONSTANTS
# =============================================================================

func test_sector_count_is_8() -> void:
	assert_eq(OffScreenIndicatorService.SECTOR_COUNT, 8,
		"Should have 8 directional sectors")


func test_indicator_inset_margin_is_positive() -> void:
	assert_gt(OffScreenIndicatorService.INDICATOR_INSET_MARGIN, 0.0,
		"Indicator inset margin should be positive")


# =============================================================================
# COLOR CONSTANTS
# =============================================================================

func test_enemy_color_is_red_toned() -> void:
	assert_gt(OffScreenIndicatorService.COLOR_ENEMY.r, 0.5,
		"Enemy color should have strong red component")


func test_spawn_color_is_orange_toned() -> void:
	assert_gt(OffScreenIndicatorService.COLOR_SPAWN.r, 0.5,
		"Spawn color should have strong red component")
	assert_gt(OffScreenIndicatorService.COLOR_SPAWN.g, 0.3,
		"Spawn color should have green component")


func test_tech_drop_color_is_purple_toned() -> void:
	assert_gt(OffScreenIndicatorService.COLOR_TECH_DROP.r, 0.5,
		"Tech drop color should have red component")
	assert_gt(OffScreenIndicatorService.COLOR_TECH_DROP.b, 0.5,
		"Tech drop color should have blue component")


func test_turret_color_is_green_toned() -> void:
	assert_gt(OffScreenIndicatorService.COLOR_TURRET.g, 0.5,
		"Turret color should have strong green component")


# =============================================================================
# GET_SECTOR - Direction to sector mapping
# =============================================================================

func test_sector_east() -> void:
	var sector = service.get_sector(Vector2.RIGHT)
	assert_eq(sector, 0, "East direction should map to sector 0")


func test_sector_south() -> void:
	var sector = service.get_sector(Vector2.DOWN)
	assert_eq(sector, 2, "South direction should map to sector 2")


func test_sector_west() -> void:
	var sector = service.get_sector(Vector2.LEFT)
	assert_eq(sector, 4, "West direction should map to sector 4")


func test_sector_north() -> void:
	var sector = service.get_sector(Vector2.UP)
	assert_eq(sector, 6, "North direction should map to sector 6")


func test_sector_southeast() -> void:
	var sector = service.get_sector(Vector2(1, 1).normalized())
	assert_eq(sector, 1, "Southeast direction should map to sector 1")


func test_sector_northeast() -> void:
	var sector = service.get_sector(Vector2(1, -1).normalized())
	assert_eq(sector, 7, "Northeast direction should map to sector 7")


func test_sector_always_in_valid_range() -> void:
	# Test many random directions
	for i in range(100):
		var angle := randf() * TAU
		var dir := Vector2(cos(angle), sin(angle))
		var sector = service.get_sector(dir)
		assert_gte(sector, 0, "Sector should be >= 0")
		assert_lt(sector, 8, "Sector should be < 8")


# =============================================================================
# GET_CATEGORY_COLOR
# =============================================================================

func test_get_category_color_enemy() -> void:
	var color = service.get_category_color("enemy")
	assert_eq(color, OffScreenIndicatorService.COLOR_ENEMY,
		"Enemy category should return COLOR_ENEMY")


func test_get_category_color_spawn() -> void:
	var color = service.get_category_color("spawn")
	assert_eq(color, OffScreenIndicatorService.COLOR_SPAWN,
		"Spawn category should return COLOR_SPAWN")


func test_get_category_color_tech_drop() -> void:
	var color = service.get_category_color("tech_drop")
	assert_eq(color, OffScreenIndicatorService.COLOR_TECH_DROP,
		"Tech drop category should return COLOR_TECH_DROP")


func test_get_category_color_turret() -> void:
	var color = service.get_category_color("turret")
	assert_eq(color, OffScreenIndicatorService.COLOR_TURRET,
		"Turret category should return COLOR_TURRET")


func test_get_category_color_unknown_returns_white() -> void:
	var color = service.get_category_color("unknown")
	assert_eq(color, Color.WHITE,
		"Unknown category should return white")


# =============================================================================
# GET_ENTITY_DISPLAY_NAME
# =============================================================================

func test_display_name_strips_enemy_prefix() -> void:
	var name = service.get_entity_display_name("enemy_spider_drone")
	assert_false(name.begins_with("enemy_"),
		"Display name should strip enemy_ prefix")


func test_display_name_strips_spawn_prefix() -> void:
	var name = service.get_entity_display_name("spawn_tank")
	assert_false(name.begins_with("spawn_"),
		"Display name should strip spawn_ prefix")


func test_display_name_strips_turret_prefix() -> void:
	var name = service.get_entity_display_name("turret_normal")
	assert_false(name.begins_with("turret_"),
		"Display name should strip turret_ prefix")


func test_display_name_capitalizes() -> void:
	var name = service.get_entity_display_name("enemy_basic")
	# Should be capitalized (first letter uppercase)
	assert_eq(name, name.capitalize(),
		"Display name should be capitalized")


func test_display_name_tech_drop_unchanged() -> void:
	var name = service.get_entity_display_name("tech_drop")
	assert_true(name.length() > 0,
		"Tech drop should have a non-empty display name")


# =============================================================================
# ENTITY TRACKING
# =============================================================================

func test_tracked_entities_starts_empty_after_reset() -> void:
	assert_eq(service.tracked_entities.size(), 0,
		"Tracked entities should be empty after clear")


func test_on_enemy_spawned_adds_tracking() -> void:
	var mock_enemy := Node2D.new()
	mock_enemy.global_position = Vector2(500, 500)
	add_child_autofree(mock_enemy)

	service._on_enemy_spawned(mock_enemy)
	assert_eq(service.tracked_entities.size(), 1,
		"Should track one enemy after spawn")
	assert_eq(service.tracked_entities[0].category, "enemy",
		"Tracked entity should have 'enemy' category")


func test_on_enemy_killed_removes_tracking() -> void:
	var mock_enemy := Node2D.new()
	mock_enemy.global_position = Vector2(500, 500)
	add_child_autofree(mock_enemy)

	service._on_enemy_spawned(mock_enemy)
	assert_eq(service.tracked_entities.size(), 1)

	service._on_enemy_killed(mock_enemy, Vector2.ZERO)
	assert_eq(service.tracked_entities.size(), 0,
		"Should remove enemy from tracking on kill")


func test_on_enemy_spawned_null_ignored() -> void:
	service._on_enemy_spawned(null)
	assert_eq(service.tracked_entities.size(), 0,
		"Null enemy should not be tracked")


func test_on_tech_drop_spawned_adds_tracking() -> void:
	var mock_drop := Node2D.new()
	mock_drop.global_position = Vector2(300, 300)
	add_child_autofree(mock_drop)

	service._on_tech_drop_spawned(mock_drop, Vector2(300, 300))
	assert_eq(service.tracked_entities.size(), 1,
		"Should track tech drop")
	assert_eq(service.tracked_entities[0].category, "tech_drop",
		"Should have tech_drop category")


func test_on_tech_drop_destroyed_removes_tracking() -> void:
	var mock_drop := Node2D.new()
	mock_drop.global_position = Vector2(300, 300)
	add_child_autofree(mock_drop)

	service._on_tech_drop_spawned(mock_drop, Vector2(300, 300))
	service._on_tech_drop_destroyed(mock_drop, Vector2(300, 300))
	assert_eq(service.tracked_entities.size(), 0,
		"Should remove tech drop from tracking on destroy")


func test_on_turret_spawned_adds_tracking() -> void:
	var mock_turret := Node2D.new()
	mock_turret.global_position = Vector2(100, 100)
	add_child_autofree(mock_turret)

	service._on_turret_spawned(mock_turret, Vector2(100, 100))
	assert_eq(service.tracked_entities.size(), 1,
		"Should track turret")
	assert_eq(service.tracked_entities[0].category, "turret",
		"Should have turret category")


func test_on_turret_picked_up_removes_tracking() -> void:
	var mock_turret := Node2D.new()
	mock_turret.global_position = Vector2(100, 100)
	add_child_autofree(mock_turret)

	service._on_turret_spawned(mock_turret, Vector2(100, 100))
	service._on_turret_picked_up(mock_turret)
	assert_eq(service.tracked_entities.size(), 0,
		"Should remove turret from tracking on pickup")


func test_multiple_entities_tracked() -> void:
	var enemy1 := Node2D.new()
	var enemy2 := Node2D.new()
	var turret := Node2D.new()
	add_child_autofree(enemy1)
	add_child_autofree(enemy2)
	add_child_autofree(turret)

	service._on_enemy_spawned(enemy1)
	service._on_enemy_spawned(enemy2)
	service._on_turret_spawned(turret, Vector2.ZERO)
	assert_eq(service.tracked_entities.size(), 3,
		"Should track all three entities")


func test_removing_one_entity_preserves_others() -> void:
	var enemy1 := Node2D.new()
	var enemy2 := Node2D.new()
	add_child_autofree(enemy1)
	add_child_autofree(enemy2)

	service._on_enemy_spawned(enemy1)
	service._on_enemy_spawned(enemy2)
	service._on_enemy_killed(enemy1, Vector2.ZERO)

	assert_eq(service.tracked_entities.size(), 1,
		"Should preserve other entities after removing one")
	assert_eq(service.tracked_entities[0].node, enemy2,
		"Remaining entity should be enemy2")


# =============================================================================
# TRACKED ENTITY CLASS
# =============================================================================

func test_tracked_entity_init() -> void:
	var mock := Node2D.new()
	mock.global_position = Vector2(42, 84)
	add_child_autofree(mock)

	var entity := OffScreenIndicatorService.TrackedEntity.new(mock, "enemy_basic", "enemy")
	assert_eq(entity.node, mock, "Node should be set")
	assert_eq(entity.type, "enemy_basic", "Type should be set")
	assert_eq(entity.category, "enemy", "Category should be set")
	assert_eq(entity.position, Vector2(42, 84), "Position should match node")
	assert_true(entity.is_valid, "Should be valid by default")


func test_tracked_entity_null_node() -> void:
	var entity := OffScreenIndicatorService.TrackedEntity.new(null, "spawn_basic", "spawn")
	assert_null(entity.node, "Node should be null")
	assert_eq(entity.position, Vector2.ZERO, "Position should be zero for null node")
