extends GutTest

func test_defaults_apply_when_keys_are_missing() -> void:
	var stats := TurretStats.new({})
	assert_eq(stats.damage, 0.0)
	assert_eq(stats.fire_rate, TurretStats.DEFAULT_FIRE_RATE)
	assert_almost_eq(stats.range_metres, TurretStats.DEFAULT_RANGE * WorldGeometry.METRES_PER_PIXEL, .0001)
	assert_eq(stats.chain_count, 0)
	assert_eq(stats.chain_decay, 1.0)
	assert_eq(stats.rotation_rate, TurretStats.DEFAULT_ROTATION_RATE)

func test_distances_convert_to_metres() -> void:
	var stats := TurretStats.new({"range": 100.0, "aoe_radius": 50.0, "knockback_force": 80.0, "chain_range": 200.0, "projectile_speed": 700.0})
	assert_almost_eq(stats.range_metres, 100.0 * WorldGeometry.METRES_PER_PIXEL, .0001)
	assert_almost_eq(stats.aoe_radius_metres, 50.0 * WorldGeometry.METRES_PER_PIXEL, .0001)
	assert_almost_eq(stats.knockback_metres, 80.0 * WorldGeometry.METRES_PER_PIXEL, .0001)
	assert_almost_eq(stats.chain_range_metres, 200.0 * WorldGeometry.METRES_PER_PIXEL, .0001)
	assert_almost_eq(stats.projectile_speed_metres, 700.0 * WorldGeometry.METRES_PER_PIXEL, .0001)

func test_values_are_clamped() -> void:
	var stats := TurretStats.new({"damage": -5.0, "slow_intensity": 3.0, "slow_duration": -1.0, "pierce": -2, "rehit_delay": 0.0, "fire_rate": 0.0})
	assert_eq(stats.damage, 0.0)
	assert_eq(stats.slow_intensity, TurretStats.MAX_SLOW_INTENSITY)
	assert_eq(stats.slow_duration, 0.0)
	assert_eq(stats.pierce, 0)
	assert_eq(stats.rehit_delay, .05)
	assert_almost_eq(stats.cooldown_seconds, 1.0 / TurretStats.MIN_FIRE_RATE, .001)

func test_registry_base_stats_read_through() -> void:
	var stats := TurretStats.new(TurretRegistry.get_base_stats("tesla"))
	assert_eq(stats.chain_count, 3)
	assert_almost_eq(stats.chain_decay, .7, .0001)
	assert_almost_eq(stats.cooldown_seconds, 1.0 / 1.2, .0001)
