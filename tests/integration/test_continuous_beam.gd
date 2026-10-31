extends GutTest

## Engine piece S11: `ContinuousBeam` (lock, heat, ramp, bounded ticks, crowd-grid queries) and `BeamLines` (the pooled drawn
## segments). The turrets built on it are tested in `test_laser_turret.gd`.

const STEP := 1.0 / 60.0

var rig: TurretTestRig
var world: ArenaWorld
var beam: ContinuousBeam

func before_each() -> void:
	rig = TurretTestRig.start(self)
	rig.disable_crits()
	world = rig.world
	beam = ContinuousBeam.new()
	rig.combat()

func after_each() -> void:
	TestHelpers.reset_flags()

func _crowd() -> CrowdGrid3D:
	world.crowd.rebuild(world.enemies)
	return world.crowd

# --- Ramp ---

func test_ramp_climbs_linearly_from_one_to_the_peak_and_holds() -> void:
	assert_almost_eq(ContinuousBeam.ramp(0.0, 3.0, 3.0), 1.0, .0001)
	assert_almost_eq(ContinuousBeam.ramp(1.5, 3.0, 3.0), 2.0, .0001)
	assert_almost_eq(ContinuousBeam.ramp(3.0, 3.0, 3.0), 3.0, .0001)
	assert_almost_eq(ContinuousBeam.ramp(30.0, 3.0, 3.0), 3.0, .0001, "Flat after full ramp")
	assert_almost_eq(ContinuousBeam.ramp(2.0, 4.0, 6.0), 3.5, .0001)
	assert_almost_eq(ContinuousBeam.ramp(5.0, 3.0, 1.0), 1.0, .0001, "A peak of one never ramps")
	assert_almost_eq(ContinuousBeam.ramp(5.0, 0.0, 3.0), 3.0, .0001, "A zero ramp time is full at once, not a divide by zero")

# --- Lock, heat and retargeting ---

func test_a_new_target_resets_the_heat_and_the_same_one_keeps_it() -> void:
	var first := rig.enemy(Vector3(2, 0, 0))
	var second := rig.enemy(Vector3(0, 0, 2))
	beam.lock(first)
	beam.advance(1.5, 10.0)
	assert_almost_eq(beam.heat, 1.5, .0001)
	beam.lock(first)
	assert_almost_eq(beam.heat, 1.5, .0001, "Locking the enemy it already holds changes nothing")
	beam.lock(second)
	assert_eq(beam.heat, 0.0, "Retargeting resets the ramp")
	assert_eq(beam.locks, 2)
	beam.release()
	assert_null(beam.target)
	assert_eq(beam.heat, 0.0)

func test_a_beam_with_no_single_target_can_be_engaged_and_released() -> void:
	assert_false(beam.engaged)
	beam.engage()
	assert_true(beam.engaged)
	assert_null(beam.target)
	assert_eq(beam.advance(STEP, 10.0), 1, "Its first tick is due at once")
	beam.advance(1.0, 10.0)
	var heat := beam.heat
	beam.engage()
	assert_eq(beam.heat, heat, "Engaging a running beam changes nothing")
	beam.release()
	assert_false(beam.engaged)
	assert_eq(beam.heat, 0.0)
	beam.lock(rig.enemy(Vector3(2, 0, 0)))
	assert_true(beam.engaged, "A lock engages too")

func test_holds_needs_a_living_target_in_reach() -> void:
	var enemy := rig.enemy(Vector3(2, 0, 0))
	assert_false(beam.holds(Vector3.ZERO, 3.0), "Nothing locked")
	beam.lock(enemy)
	assert_true(beam.holds(Vector3.ZERO, 3.0))
	assert_false(beam.holds(Vector3.ZERO, 1.0), "Out of reach")
	enemy.dead = true
	assert_false(beam.holds(Vector3.ZERO, 3.0), "Dead")
	enemy.dead = false
	enemy.free()
	assert_false(beam.holds(Vector3.ZERO, 3.0), "Freed")

# --- Ticks ---

func test_the_first_tick_lands_with_the_beam_and_then_one_per_interval() -> void:
	beam.lock(rig.enemy(Vector3(2, 0, 0)))
	assert_eq(beam.advance(STEP, 10.0), 1, "A tick the moment the beam lands")
	var total := 1
	for i in 59:
		total += beam.advance(STEP, 10.0)
	assert_eq(total, 11, "The landing tick plus ten in the next second at rate 10")

func test_a_slow_rate_waits_a_whole_interval_after_the_first_tick() -> void:
	beam.lock(rig.enemy(Vector3(2, 0, 0)))
	assert_eq(beam.advance(STEP, 0.5), 1)
	var more := 0
	for i in 110:
		more += beam.advance(STEP, 0.5)
	assert_eq(more, 0, "The second tick is 2 s away")
	for i in 20:
		more += beam.advance(STEP, 0.5)
	assert_eq(more, 1)

func test_a_step_never_yields_more_than_the_cap_and_a_stall_is_not_repaid() -> void:
	beam.lock(rig.enemy(Vector3(2, 0, 0)))
	beam.advance(STEP, 10.0)
	assert_eq(beam.advance(5.0, 10.0), ContinuousBeam.MAX_TICKS_PER_STEP, "A five second stall pays at most the cap")
	assert_lte(beam.advance(STEP, 10.0), 1, "and the backlog is gone")
	assert_eq(beam.advance(STEP, 1000.0), ContinuousBeam.MAX_TICKS_PER_STEP, "A huge rate is bounded by the cap too")

func test_a_zero_rate_does_not_divide_by_zero_or_tick() -> void:
	beam.lock(rig.enemy(Vector3(2, 0, 0)))
	beam.advance(STEP, 0.0)
	var ticks := 0
	for i in 600:
		ticks += beam.advance(STEP, 0.0)
	assert_eq(ticks, 0)

# --- Finding things (crowd grid, enemies only) ---

func test_nearest_picks_the_closest_enemy_body_in_reach() -> void:
	var near := rig.enemy(Vector3(1.5, 0, 0))
	rig.enemy(Vector3(0, 0, 2.5))
	assert_same(ContinuousBeam.nearest(_crowd(), Vector3.ZERO, 3.0), near)
	assert_null(ContinuousBeam.nearest(_crowd(), Vector3.ZERO, 0.5), "Nothing that close")
	assert_null(ContinuousBeam.nearest(_crowd(), Vector3(30, 0, 30), 3.0))

func test_nearest_skips_the_dead_and_ignores_the_hero_and_turrets() -> void:
	world.player.position = Vector3(0.5, 0, 0)
	var turret := rig.turret("normal", [], Vector3(0.6, 0, 0.6))
	var dead := rig.enemy(Vector3(1, 0, 0))
	var live := rig.enemy(Vector3(0, 0, 2))
	dead.dead = true
	assert_same(ContinuousBeam.nearest(_crowd(), Vector3.ZERO, 3.0), live)
	assert_not_same(ContinuousBeam.nearest(_crowd(), Vector3.ZERO, 3.0), world.player)
	assert_not_same(ContinuousBeam.nearest(_crowd(), Vector3.ZERO, 3.0), turret)

func test_touching_finds_what_a_segment_crosses_and_nothing_else() -> void:
	var on_line := rig.enemy(Vector3(2, 0, 0))
	var also := rig.enemy(Vector3(1, 0, 0.1))
	var beside := rig.enemy(Vector3(2, 0, 1.5))
	var behind := rig.enemy(Vector3(-1, 0, 0))
	var past := rig.enemy(Vector3(4.5, 0, 0))
	var found := ContinuousBeam.touching(_crowd(), Vector3.ZERO, [Vector3.RIGHT] as Array[Vector3], 3.0, .14)
	assert_has(found, on_line)
	assert_has(found, also)
	assert_does_not_have(found, beside)
	assert_does_not_have(found, behind)
	assert_does_not_have(found, past)

func test_touching_with_a_cross_hits_each_enemy_once_and_covers_all_four_arms() -> void:
	var arms: Array[Vector3] = [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD]
	var enemies: Array[CombatActor] = []
	for arm in arms:
		enemies.append(rig.enemy(arm * 2.0))
	rig.enemy(Vector3(1.6, 0, 1.6))
	var found := ContinuousBeam.touching(_crowd(), Vector3.ZERO, arms, 3.0, .14)
	assert_eq(found.size(), 4, "The four on the arms, the one on a diagonal missed")
	for enemy in enemies:
		assert_has(found, enemy)
	var doubled: Array[Vector3] = [Vector3.RIGHT, Vector3.RIGHT]
	assert_eq(ContinuousBeam.touching(_crowd(), Vector3.ZERO, doubled, 3.0, .14).size(), 1, "Two arms on one enemy still count it once")

func test_touching_never_returns_the_hero_or_a_turret_on_the_line() -> void:
	world.player.position = Vector3(1, 0, 0)
	rig.turret("normal", [], Vector3(2, 0, 0))
	var found := ContinuousBeam.touching(_crowd(), Vector3.ZERO, [Vector3.RIGHT] as Array[Vector3], 3.0, .14)
	assert_true(found.is_empty())

func test_touching_caps_the_result_keeping_the_nearest() -> void:
	for i in 6:
		rig.enemy(Vector3(1.0 + float(i) * .5, 0, 0))
	var found := ContinuousBeam.touching(_crowd(), Vector3.ZERO, [Vector3.RIGHT] as Array[Vector3], 4.0, .14, 3)
	assert_eq(found.size(), 3)
	for enemy in found:
		assert_lte(enemy.position.x, 2.01, "The three nearest")

# --- BeamLines ---

func test_beam_lines_pose_a_segment_between_two_points_and_hide_it() -> void:
	var lines := BeamLines.new(2)
	add_child_autofree(lines)
	lines.set_segment(0, Vector3(0, 1, 0), Vector3(0, 1, -4), .1)
	assert_true(lines.slots[0].visible)
	assert_false(lines.slots[1].visible, "Untouched slots stay hidden")
	assert_almost_eq(lines.slots[0].position.z, -2.0, .001, "Centred on the segment")
	assert_almost_eq(lines.slots[0].scale.z, 4.0, .001, "As long as the segment")
	assert_almost_eq(lines.slots[0].scale.x, .1, .001)
	lines.set_segment(0, Vector3(1, 1, 1), Vector3(1, 1, 1), .1)
	assert_false(lines.slots[0].visible, "A zero-length segment is not drawn")
	lines.set_segment(1, Vector3.ZERO, Vector3(3, 0, 0), .1, true)
	assert_eq(lines.visible_count(), 1)
	assert_same(lines.slots[1].material_override, BeamLines.flare_material)
	lines.hide_all()
	assert_eq(lines.visible_count(), 0)

func test_beam_lines_never_grow_and_free_cleanly() -> void:
	var lines := BeamLines.new(1)
	add_child_autofree(lines)
	var before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for i in 500:
		lines.set_segment(0, Vector3.ZERO, Vector3(i % 5 + 1, 0, 0), .1)
	lines.set_segment(7, Vector3.ZERO, Vector3.RIGHT, .1)
	assert_eq(lines.get_child_count(), 1, "Setting segments never adds nodes; an unknown slot is ignored")
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), before)
	lines.set_segment(0, Vector3.ZERO, Vector3.RIGHT, .1)
	lines.free_lines()
	lines.free_lines()
	assert_eq(lines.visible_count(), 0, "Hidden at once")
	assert_true(lines.is_queued_for_deletion())
	await wait_process_frames(2)
	assert_false(is_instance_valid(lines), "and freed")
