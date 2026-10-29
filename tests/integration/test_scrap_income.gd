extends GutTest

## Engine piece S5: scrap that does not come from a kill (`ScrapIncome`), the direct-XP tally in `WaveSalvage`, and the
## wave-end hook. The Scrap Press that uses it is in `test_scrap_press_turret.gd`.

var rig: TurretTestRig
var world: ArenaWorld

func before_each() -> void:
	rig = TurretTestRig.start(self)
	world = rig.world

func after_each() -> void:
	TestHelpers.reset_flags()

func _pickups() -> Array[ScrapPickup]:
	var result: Array[ScrapPickup] = []
	for node in world.pickup_root.get_children():
		if node is ScrapPickup and not node.is_queued_for_deletion():
			result.append(node)
	return result

# --- Pure rules ---

func test_a_drop_is_worth_more_every_few_waves() -> void:
	assert_eq(ScrapIncome.drop_value(0), 1)
	assert_eq(ScrapIncome.drop_value(1), 1)
	assert_eq(ScrapIncome.drop_value(5), 1)
	assert_eq(ScrapIncome.drop_value(6), 2)
	assert_eq(ScrapIncome.drop_value(10), 2)
	assert_eq(ScrapIncome.drop_value(11), 3)
	assert_eq(ScrapIncome.drop_value(21), 5)

func test_stacking_presses_yield_less_and_the_tail_stays_flat() -> void:
	assert_eq(ScrapIncome.stack_yield(0), 1.0)
	assert_eq(ScrapIncome.stack_yield(1), .6)
	assert_eq(ScrapIncome.stack_yield(2), .4)
	assert_eq(ScrapIncome.stack_yield(3), .4)
	assert_eq(ScrapIncome.stack_yield(9), .4)
	assert_eq(ScrapIncome.stack_yield(-1), 1.0, "A negative rank is the first press")

func test_interest_is_one_per_block_held_capped_and_scaled() -> void:
	assert_eq(ScrapIncome.interest_for(0, 10, 5, 1.0), 0)
	assert_eq(ScrapIncome.interest_for(9, 10, 5, 1.0), 0)
	assert_eq(ScrapIncome.interest_for(10, 10, 5, 1.0), 1)
	assert_eq(ScrapIncome.interest_for(37, 10, 5, 1.0), 3)
	assert_eq(ScrapIncome.interest_for(500, 10, 5, 1.0), 5, "Capped")
	assert_eq(ScrapIncome.interest_for(500, 10, 5, .6), 3)
	assert_eq(ScrapIncome.interest_for(500, 0, 5, 1.0), 0, "A zero block pays nothing instead of dividing by zero")

# --- Exits ---

func test_a_deposit_reaches_the_wallet_and_is_counted() -> void:
	EconomyService.total_scrap = 10
	assert_eq(world.scrap_income.deposit(5), 5)
	assert_eq(EconomyService.total_scrap, 15)
	assert_eq(world.scrap_income.cash_deposited, 5)
	assert_eq(world.scrap_income.deposit(0), 0)
	assert_eq(world.scrap_income.deposit(-3), 0)
	assert_eq(EconomyService.total_scrap, 15)

func test_a_laid_pickup_is_a_real_pickup_inside_the_arena_and_counts_as_a_drop() -> void:
	var dropped_before := world.session.state.wave_scrap_dropped
	var pickup := world.scrap_income.lay_pickup(Vector3(2, 0, 3), 1.5, 3)
	assert_not_null(pickup)
	assert_eq(pickup.amount, 3)
	assert_true(pickup.get_parent() == world.pickup_root)
	assert_lte(WorldGeometry.planar(pickup.position - Vector3(2, 0, 3)).length(), 1.5 + .001, "Within reach of where it was laid")
	assert_eq(world.session.state.wave_scrap_dropped - dropped_before, 3, "It is part of the wave's drops, like scrap from a kill")
	assert_eq(world.scrap_income.pickups_laid, 1)
	assert_null(world.scrap_income.lay_pickup(Vector3.ZERO, 1.5, 0), "Nothing to lay")

func test_a_clearance_keeps_pickups_off_the_turrets_body() -> void:
	for i in 60:
		var pickup := world.scrap_income.lay_pickup(Vector3.ZERO, 1.5, 1, 1.0)
		var distance := WorldGeometry.planar(pickup.position).length()
		assert_gte(distance, 1.0 - .001, "Never inside the clearance ring")
		assert_lte(distance, 1.5 + .001, "Still within reach")
	var squeezed := world.scrap_income.lay_pickup(Vector3.ZERO, .5, 1, 1.0)
	assert_gte(WorldGeometry.planar(squeezed.position).length(), 1.0 - .001, "A reach inside the clearance is stretched past it")

func test_a_pickup_laid_at_the_wall_stays_in_the_arena() -> void:
	var edge := Vector3(WorldGeometry.HALF_ARENA.x, 0, WorldGeometry.HALF_ARENA.y)
	for i in 30:
		var pickup := world.scrap_income.lay_pickup(edge, 2.0, 1)
		assert_lte(absf(pickup.position.x), WorldGeometry.HALF_ARENA.x)
		assert_lte(absf(pickup.position.z), WorldGeometry.HALF_ARENA.y)

func test_laying_is_reproducible_from_the_run_seed() -> void:
	world.scrap_income.reset(1234)
	var first := world.scrap_income.lay_pickup(Vector3.ZERO, 2.0, 1).position
	world.scrap_income.reset(1234)
	var second := world.scrap_income.lay_pickup(Vector3.ZERO, 2.0, 1).position
	assert_eq(first, second)
	assert_eq(world.scrap_income.pickups_laid, 1, "Reset zeroes the counters")

func test_turrets_near_lists_placed_turrets_within_the_radius_only() -> void:
	var near := rig.turret("normal", [], Vector3(3, 0, 0))
	var far := rig.turret("normal", [], Vector3(9, 0, 0))
	var carried := rig.turret("normal", [], Vector3(1, 0, 0))
	carried.carried = true
	var found := world.scrap_income.turrets_near(Vector3.ZERO, 6.0)
	assert_has(found, near)
	assert_does_not_have(found, far)
	assert_does_not_have(found, carried, "A carried turret is not placed")

# --- Direct XP and the salvage ledger ---

func test_direct_xp_levels_the_turret_now_and_is_tallied_for_the_wave() -> void:
	var turret := rig.turret("normal", [], Vector3(3, 0, 0))
	var given := world.scrap_income.award_xp([turret] as Array[TurretActor], 25)
	assert_eq(given, 25)
	assert_eq(turret.progression.total_xp, 25)
	assert_eq(turret.progression.level, 2, "Level 1 needs 20, so 25 XP levels it at once")
	assert_eq(world.salvage.direct[turret.turret_id]["xp"], 25)
	assert_eq(world.salvage.direct[turret.turret_id]["before"]["level"], 1, "The snapshot is from before the first award")
	world.scrap_income.award_xp([turret] as Array[TurretActor], 5)
	assert_eq(world.salvage.direct[turret.turret_id]["xp"], 30)
	assert_eq(world.salvage.direct[turret.turret_id]["before"]["total_xp"], 0, "A second award keeps the first snapshot")
	assert_eq(world.scrap_income.xp_awarded, 30)

func test_direct_xp_needs_turret_progression() -> void:
	world.session.state.turret_progression_enabled = false
	var turret := rig.turret("normal")
	assert_eq(world.scrap_income.award_xp([turret] as Array[TurretActor], 25), 0)
	assert_eq(turret.progression.total_xp, 0)
	assert_true(world.salvage.direct.is_empty())

func test_settlement_reports_direct_and_salvage_xp_together() -> void:
	var turret := rig.turret("normal", [], Vector3(0, 0, 0))
	world.scrap_income.award_xp([turret] as Array[TurretActor], 10)
	var pickup := ScrapPickup.new()
	pickup.world = world
	pickup.amount = 4
	pickup.position = Vector3(0.5, 0, 0)
	world.pickup_root.add_child(pickup)
	GameStateMachine.force_transition(GameStateMachine.GameState.WAVE_END)
	var starting := world.turrets[0]
	assert_true(world.salvage.settle(1))
	var ledger := world.salvage.last_settlement
	var change: Dictionary = ledger["changes"][turret.turret_id]
	assert_eq(change["before"]["total_xp"], 0, "The report starts from before the wave's first award")
	assert_eq(change["after"]["total_xp"], turret.progression.total_xp)
	var salvage_xp: int = turret.progression.total_xp - 10
	assert_eq(change["xp_awarded"], 10 + salvage_xp)
	assert_gt(salvage_xp, -1)
	var expected := 0
	for id: int in ledger["changes"]:
		expected += int(ledger["changes"][id]["xp_awarded"])
	assert_eq(ledger["xp_awarded"], expected, "The ledger total is the sum of what each turret was reported")
	assert_true(world.salvage.direct.is_empty(), "The tally is consumed")
	assert_not_null(starting)

func test_a_turret_that_only_got_direct_xp_still_appears_in_the_report() -> void:
	var turret := rig.turret("normal", [], Vector3(3, 0, 0))
	world.scrap_income.award_xp([turret] as Array[TurretActor], 12)
	GameStateMachine.force_transition(GameStateMachine.GameState.WAVE_END)
	assert_true(world.salvage.settle(1))
	var change: Dictionary = world.salvage.last_settlement["changes"][turret.turret_id]
	assert_eq(change["xp_awarded"], 12)
	assert_eq(change["after"]["total_xp"] - change["before"]["total_xp"], 12)
	assert_gte(world.salvage.last_settlement["xp_awarded"], 12)

func test_the_wave_reports_replay_cleanly_in_the_presentation() -> void:
	var turret := rig.turret("normal", [], Vector3(3, 0, 0))
	world.scrap_income.award_xp([turret] as Array[TurretActor], 30)
	GameStateMachine.force_transition(GameStateMachine.GameState.WAVE_END)
	assert_true(world.salvage.settle(1))
	var replay := TurretProgression.new()
	var change: Dictionary = world.salvage.last_settlement["changes"][turret.turret_id]
	replay.level = int(change["before"]["level"])
	replay.xp = int(change["before"]["xp"])
	replay.award(int(change["xp_awarded"]))
	assert_eq(replay.level, int(change["after"]["level"]), "Replaying the reported XP from the reported start lands on the reported level")
	assert_eq(replay.xp, int(change["after"]["xp"]))

# --- Cleanup ---

func test_the_tally_is_dropped_when_the_field_is_cleared_and_on_a_new_run() -> void:
	var turret := rig.turret("normal")
	world.scrap_income.award_xp([turret] as Array[TurretActor], 12)
	assert_false(world.salvage.direct.is_empty())
	world.clear_field(false)
	assert_true(world.salvage.direct.is_empty(), "Clearing the field without a settlement drops the tally")
	assert_eq(turret.progression.total_xp, 12, "The XP already awarded stays awarded")
	world.scrap_income.award_xp([turret] as Array[TurretActor], 3)
	world.scrap_income.deposit(2)
	# `start_run` resets both, with the run's seed.
	world.salvage.reset(99)
	world.scrap_income.reset(99)
	assert_true(world.salvage.direct.is_empty())
	assert_eq(world.scrap_income.xp_awarded, 0)
	assert_eq(world.scrap_income.cash_deposited, 0)

func test_laid_pickups_are_cleared_with_the_field_like_any_other() -> void:
	world.scrap_income.lay_pickup(Vector3.ZERO, 1.0, 2)
	world.scrap_income.lay_pickup(Vector3.ZERO, 1.0, 2)
	assert_eq(_pickups().size(), 2)
	world.clear_field(false)
	await wait_process_frames(2)
	assert_eq(_pickups().size(), 0)

# --- Wave end ---

func test_nothing_is_paid_at_wave_end_when_no_form_pays() -> void:
	rig.turret("normal")
	EconomyService.total_scrap = 100
	assert_eq(world.scrap_income.pay_interest(), 0)
	assert_eq(EconomyService.total_scrap, 100)

func test_finishing_a_wave_clears_the_direct_tally_and_still_gives_the_wave_bonus() -> void:
	var turret := rig.turret("normal", [], Vector3(3, 0, 0))
	rig.combat()
	world.scrap_income.award_xp([turret] as Array[TurretActor], 12)
	EconomyService.total_scrap = 0
	GameStateService.current_wave = 1
	assert_true(world.finish_wave())
	assert_true(world.salvage.direct.is_empty())
	assert_gte(EconomyService.total_scrap, EconomyService.get_wave_scrap_base(1), "The wave bonus is still paid")
	assert_string_contains(world.message, "Wave secured")
	assert_eq(world.salvage.last_settlement["changes"][turret.turret_id]["xp_awarded"], 12)

func test_a_kill_still_drops_its_scrap_through_the_shared_spawner() -> void:
	rig.combat()
	var enemy := rig.enemy(Vector3(4, 0, 4), 1.0)
	enemy.scrap_value = 2
	enemy.take_damage(100)
	var found := _pickups()
	assert_eq(found.size(), 1)
	assert_eq(found[0].amount, 2)
