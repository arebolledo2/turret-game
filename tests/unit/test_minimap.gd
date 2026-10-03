extends GutTest

func test_world_corners_and_centre_map_to_the_minimap_rectangle() -> void:
	var half := WorldGeometry.HALF_ARENA
	assert_eq(Minimap.world_to_map(Vector3.ZERO), Minimap.MAP_SIZE * 0.5)
	assert_eq(Minimap.world_to_map(Vector3(-half.x, 0, -half.y)), Vector2.ZERO, "top-left is world -X, -Z (screen up)")
	assert_eq(Minimap.world_to_map(Vector3(half.x, 0, half.y)), Minimap.MAP_SIZE)

func test_positions_outside_the_arena_are_clamped_onto_the_map() -> void:
	var mapped := Minimap.world_to_map(Vector3(500, 0, -500))
	assert_eq(mapped, Vector2(Minimap.MAP_SIZE.x, 0.0))

func test_map_has_the_same_aspect_as_the_arena() -> void:
	assert_almost_eq(Minimap.MAP_SIZE.x / Minimap.MAP_SIZE.y, WorldGeometry.HALF_ARENA.x / WorldGeometry.HALF_ARENA.y, .001)

func test_every_spawnable_enemy_type_has_a_minimap_colour() -> void:
	for wave in range(1, 7):
		for index in 40:
			var type_id := EnemyVariants.pick_type(wave, index)
			assert_true(Minimap.ENEMY_COLORS.has(type_id), "missing colour for %s" % type_id)
