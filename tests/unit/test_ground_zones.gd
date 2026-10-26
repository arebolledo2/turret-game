extends GutTest

## S7 enemy-only ground zones: shapes, the enemy slow, expiry, the active cap and the pooled visuals. (The hero staying
## unaffected and the world-level cleanup are covered in test_quake_turret.gd, which has a full arena.)

var zones: GroundZones

func before_each() -> void:
	zones = GroundZones.new()
	add_child_autofree(zones)
	zones.set_physics_process(false)

func _enemy(at: Vector3) -> CombatActor:
	var actor := autofree(EnemyActor.new()) as CombatActor
	actor.position = at
	return actor

# --- Shapes ---

func test_a_circle_contains_points_within_its_radius_plus_the_margin() -> void:
	var zone := zones.add_circle(Vector3(2, 0, -1), 1.5, 3.0, .4)
	assert_true(zone.contains(Vector3(2, 0, -1)))
	assert_true(zone.contains(Vector3(3.4, 0, -1)))
	assert_false(zone.contains(Vector3(3.6, 0, -1)))
	assert_true(zone.contains(Vector3(3.6, 0, -1), .2), "A body of radius 0.2 touching the edge counts")
	assert_true(zone.contains(Vector3(2, 5, -1)), "Height is ignored")

func test_a_line_is_an_oriented_rectangle_with_flat_ends() -> void:
	var zone := zones.add_line(Vector3(0, 0, 0), Vector3(4, 0, 0), .5, 3.0, .4)
	assert_eq(zone.shape, GroundZone.Shape.LINE)
	assert_almost_eq(zone.half_length, 2.0, .0001)
	assert_almost_eq(zone.centre.x, 2.0, .0001)
	assert_true(zone.contains(Vector3(2, 0, .45)))
	assert_false(zone.contains(Vector3(2, 0, .6)), "Beyond the half width")
	assert_true(zone.contains(Vector3(2, 0, .6), .2))
	assert_true(zone.contains(Vector3(3.9, 0, 0)))
	assert_false(zone.contains(Vector3(4.2, 0, 0)), "Flat end, not rounded")
	assert_false(zone.contains(Vector3(-.3, 0, 0)))
	var diagonal := zones.add_line(Vector3(0, 0, 0), Vector3(3, 0, 3), .4, 3.0)
	assert_true(diagonal.contains(Vector3(1.5, 0, 1.5)))
	assert_true(diagonal.contains(Vector3(1.6, 0, 1.4)), "Within the half width of a 45 degree line")
	assert_false(diagonal.contains(Vector3(1.5, 0, 0.8)), "Well off the diagonal")
	assert_false(diagonal.contains(Vector3(3.5, 0, 3.5)), "Past the end")

func test_closest_point_on_a_line_stays_on_its_axis() -> void:
	var zone := zones.add_line(Vector3(0, 0, 0), Vector3(4, 0, 0), .5, 3.0)
	assert_eq(zone.closest_point(Vector3(1, 0, 3)), Vector3(1, 0, 0))
	assert_eq(zone.closest_point(Vector3(9, 0, 3)), Vector3(4, 0, 0), "Clamped to the end")
	assert_eq(zones.add_circle(Vector3(1, 0, 1), 1.0, 1.0).closest_point(Vector3(5, 0, 5)), Vector3(1, 0, 1))

# --- Slow ---

func test_enemies_inside_are_slowed_and_outside_are_not() -> void:
	zones.add_circle(Vector3.ZERO, 2.0, 3.0, .4)
	assert_almost_eq(zones.speed_factor_at(Vector3(1, 0, 0)), .6, .0001)
	assert_eq(zones.speed_factor_at(Vector3(5, 0, 0)), 1.0)
	assert_almost_eq(zones.speed_factor_at(Vector3(2.3, 0, 0), .4), .6, .0001, "The body radius counts")

func test_overlapping_zones_do_not_stack_the_strongest_wins() -> void:
	zones.add_circle(Vector3.ZERO, 2.0, 3.0, .3)
	zones.add_circle(Vector3.ZERO, 2.0, 3.0, .5)
	zones.add_line(Vector3(-2, 0, 0), Vector3(2, 0, 0), .5, 3.0, .4)
	assert_almost_eq(zones.speed_factor_at(Vector3(.2, 0, 0)), .5, .0001, "0.3, 0.5 and 0.4 overlap: only 0.5 applies")
	assert_eq(zones.covering(Vector3(.2, 0, 0)).size(), 3)

func test_the_slow_is_capped_at_ninety_percent() -> void:
	var zone := zones.add_circle(Vector3.ZERO, 2.0, 3.0, 2.5)
	assert_almost_eq(zone.slow, GameConstants.GROUND_ZONE_MAX_SLOW, .0001)
	assert_almost_eq(zones.speed_factor_at(Vector3.ZERO), .1, .0001)
	assert_eq(zones.add_circle(Vector3.ZERO, 1.0, 1.0, -.5).slow, 0.0, "A negative slow is no slow")

func test_a_zone_with_no_slow_changes_nothing() -> void:
	zones.add_circle(Vector3.ZERO, 2.0, 3.0)
	assert_eq(zones.speed_factor_at(Vector3.ZERO), 1.0)

func test_enemies_in_lists_only_living_enemies_standing_in_the_zone() -> void:
	var zone := zones.add_line(Vector3(0, 0, 0), Vector3(4, 0, 0), .5, 3.0, .4)
	var inside := _enemy(Vector3(2, 0, 0))
	var edge := _enemy(Vector3(2, 0, .8))
	var outside := _enemy(Vector3(2, 0, 2))
	var dead := _enemy(Vector3(1, 0, 0))
	dead.dead = true
	var all: Array[CombatActor] = [inside, edge, outside, dead]
	var found := zones.enemies_in(zone, all)
	assert_has(found, inside)
	assert_has(found, edge, "A basic enemy is about 0.36 m wide, so its body overlaps the 0.5 m half width at 0.8 m")
	assert_does_not_have(found, outside)
	assert_does_not_have(found, dead)

# --- Expiry, cap, pooling ---

func test_a_zone_expires_after_its_duration() -> void:
	zones.add_circle(Vector3.ZERO, 2.0, 3.0, .4)
	zones.tick(1.0)
	assert_eq(zones.count(), 1)
	assert_almost_eq(zones.zones[0].remaining(), 2.0, .0001)
	zones.tick(1.9)
	assert_eq(zones.count(), 1)
	zones.tick(.2)
	assert_eq(zones.count(), 0)
	assert_false(zones.has_zones())
	assert_eq(zones.speed_factor_at(Vector3.ZERO), 1.0, "Expired zones no longer slow anything")

func test_zones_expire_independently() -> void:
	zones.add_circle(Vector3.ZERO, 1.0, 1.0, .4)
	zones.add_circle(Vector3(5, 0, 0), 1.0, 3.0, .4)
	zones.tick(1.5)
	assert_eq(zones.count(), 1)
	assert_eq(zones.speed_factor_at(Vector3.ZERO), 1.0)
	assert_almost_eq(zones.speed_factor_at(Vector3(5, 0, 0)), .6, .0001)

func test_the_number_of_active_zones_is_capped_and_the_closest_to_expiring_is_recycled() -> void:
	var cap := GameConstants.GROUND_ZONE_MAX
	var first := zones.add_circle(Vector3.ZERO, 1.0, 1.0, .4)
	for index in range(1, cap):
		zones.add_circle(Vector3(index * 3, 0, 0), 1.0, 3.0, .4)
	assert_eq(zones.count(), cap)
	var extra := zones.add_circle(Vector3(0, 0, 30), 1.0, 3.0, .4)
	assert_eq(zones.count(), cap, "Adding past the cap never grows the list")
	assert_does_not_have(zones.zones, first, "The one with the least time left was recycled")
	assert_has(zones.zones, extra)
	for burst in 40:
		zones.add_circle(Vector3(burst, 0, -30), 1.0, 3.0, .4)
	assert_eq(zones.count(), cap)
	assert_lte(zones.nodes.size(), cap, "Visuals are pooled up to the cap")

func test_visuals_are_pooled_and_hidden_when_a_zone_ends() -> void:
	var zone := zones.add_line(Vector3.ZERO, Vector3(0, 0, -4), .5, 1.0, .4)
	var node := zone.node
	assert_not_null(node)
	assert_true(node.visible)
	assert_eq(zones.nodes.size(), 1)
	zones.tick(1.5)
	assert_false(node.visible, "Hidden when the zone ends")
	assert_null(zone.node)
	var next := zones.add_circle(Vector3(3, 0, 3), 1.0, 1.0)
	assert_same(next.node, node, "The same quad is reused")
	assert_eq(zones.nodes.size(), 1)

func test_clear_drops_every_zone_and_hides_every_visual() -> void:
	for index in 5:
		zones.add_circle(Vector3(index * 3, 0, 0), 1.0, 3.0, .4)
	zones.clear()
	assert_eq(zones.count(), 0)
	for node in zones.nodes:
		assert_false(node.visible)
	assert_eq(zones.speed_factor_at(Vector3.ZERO), 1.0)

func test_a_line_visual_is_placed_over_its_axis() -> void:
	var zone := zones.add_line(Vector3(0, 0, 0), Vector3(0, 0, -4), .5, 3.0, .4)
	assert_almost_eq(zone.node.position.z, -2.0, .0001)
	assert_almost_eq(zone.node.scale.z, 4.0 + 2.0 * GroundZones.MARGIN, .0001, "Length plus a margin either end")
	assert_almost_eq(zone.node.scale.x, 1.0 + 2.0 * GroundZones.MARGIN, .0001, "Width plus a margin either side")
	assert_almost_eq(absf(zone.node.rotation.y), 0.0, .0001, "A line running along -Z needs no turn")
	var across := zones.add_line(Vector3(0, 0, 0), Vector3(4, 0, 0), .5, 3.0, .4)
	assert_almost_eq(absf(across.node.rotation.y), PI * .5, .0001)

func test_the_clock_only_runs_in_combat_when_the_zones_belong_to_a_world() -> void:
	# Without a world the zones simply tick; the arena-level cleanup is tested in test_quake_turret.gd.
	zones.add_circle(Vector3.ZERO, 1.0, .5, .4)
	zones._physics_process(.6)
	assert_eq(zones.count(), 0)
