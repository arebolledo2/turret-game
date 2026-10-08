extends GutTest

func test_reads_registry_stats_in_metres() -> void:
	var config := DifficultyService.get_difficulty_config()
	var raw := EnemyRegistry.get_stats_for_wave("basic", 2, config)
	var stats := EnemyStats.for_wave("basic", 2, config)
	assert_eq(stats.health, float(raw["health"]))
	assert_almost_eq(stats.speed_metres, float(raw["speed"]) * WorldGeometry.METRES_PER_PIXEL, .0001)
	assert_eq(stats.scrap_value, int(raw["scrap_value"]))
	assert_eq(stats.contact_damage, float(raw["contact_damage"]))

func test_explosion_defaults_to_zero() -> void:
	var stats := EnemyStats.new({"health": 1.0, "speed": 1.0, "contact_damage": 1.0, "mass": 1.0, "scrap_value": 1})
	assert_eq(stats.explosion_radius_metres, 0.0)
	assert_eq(stats.explosion_damage, 0.0)
