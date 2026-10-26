extends GutTest

## Stagger: its own timer on StatusEffects3D. `stagger` refreshes to the longer time; `extend_stagger` adds, up to a cap.

func test_a_fresh_status_is_not_staggered() -> void:
	var statuses := StatusEffects3D.new()
	assert_false(statuses.is_staggered())
	assert_eq(statuses.staggered_remaining, 0.0)

func test_stagger_runs_down_and_ends() -> void:
	var statuses := StatusEffects3D.new()
	statuses.stagger(.4)
	assert_true(statuses.is_staggered())
	statuses.advance_stagger(.3)
	assert_almost_eq(statuses.staggered_remaining, .1, .0001)
	assert_true(statuses.is_staggered())
	statuses.advance_stagger(.3)
	assert_eq(statuses.staggered_remaining, 0.0, "The timer never goes below zero")
	assert_false(statuses.is_staggered())

func test_stagger_refreshes_to_the_longer_time_and_never_adds() -> void:
	var statuses := StatusEffects3D.new()
	statuses.stagger(.4)
	statuses.advance_stagger(.1)
	statuses.stagger(.4)
	assert_almost_eq(statuses.staggered_remaining, .4, .0001, "A fresh hit restores the time")
	statuses.stagger(.2)
	assert_almost_eq(statuses.staggered_remaining, .4, .0001, "A shorter stagger cannot cut a longer one")
	for hit in 20:
		statuses.stagger(.4)
	assert_almost_eq(statuses.staggered_remaining, .4, .0001, "Repeated plain staggers never accumulate")

func test_extend_stagger_adds_time_up_to_the_cap() -> void:
	var statuses := StatusEffects3D.new()
	statuses.extend_stagger(.4)
	assert_almost_eq(statuses.staggered_remaining, .4, .0001)
	statuses.extend_stagger(.4)
	assert_almost_eq(statuses.staggered_remaining, .8, .0001, "Cataclysm hits add up")
	statuses.extend_stagger(.4)
	statuses.extend_stagger(.4)
	assert_almost_eq(statuses.staggered_remaining, StatusEffects3D.STAGGER_CAP, .0001, "The default cap holds")
	for hit in 10:
		statuses.extend_stagger(.4)
	assert_almost_eq(statuses.staggered_remaining, StatusEffects3D.STAGGER_CAP, .0001, "However many hits land")

func test_extend_stagger_honours_a_custom_cap_and_never_shortens() -> void:
	var statuses := StatusEffects3D.new()
	statuses.extend_stagger(.4, .6)
	statuses.extend_stagger(.4, .6)
	assert_almost_eq(statuses.staggered_remaining, .6, .0001)
	statuses.stagger(1.2)
	statuses.extend_stagger(.4, .6)
	assert_almost_eq(statuses.staggered_remaining, 1.2, .0001, "A stagger already above the cap is left alone")

func test_clear_ends_the_stagger_with_the_other_statuses() -> void:
	var statuses := StatusEffects3D.new()
	statuses.stagger(1.0)
	statuses.mark(2.0)
	statuses.clear()
	assert_false(statuses.is_staggered())
	assert_false(statuses.is_marked())

func test_stagger_is_separate_from_slow_and_the_other_timers() -> void:
	var statuses := StatusEffects3D.new()
	statuses.stagger(1.0)
	assert_eq(statuses.speed_multiplier(), 1.0, "Stagger is not a slow")
	statuses.advance(2.0)
	assert_true(statuses.is_staggered(), "advance() does not run the stagger timer: it runs every tick via advance_stagger")

func test_stagger_stat_reads_through_the_stats_view() -> void:
	assert_eq(TurretStats.new({"stagger": .4}).stagger_seconds, .4)
	assert_eq(TurretStats.new({}).stagger_seconds, 0.0)
	assert_eq(TurretStats.new({"stagger": -1.0}).stagger_seconds, 0.0)
	var shot := CombatShot3D.from_stats({"damage": 5.0, "stagger": .4})
	assert_eq(shot.stagger_duration, .4)
	assert_eq(shot.copy().stagger_duration, .4)
	shot.stagger_cap = 1.5
	assert_eq(shot.copy().stagger_cap, 1.5)
