extends GutTest

## Owner-keyed timed statuses: a status is active while any owner's timer runs, and clearing one owner leaves the rest.

func test_two_owners_mark_one_clears_the_other_stays_marked() -> void:
	var statuses := StatusEffects3D.new()
	statuses.mark(6.0, 1)
	statuses.mark(4.0, 2)
	assert_almost_eq(statuses.marked_remaining, 6.0, .0001, "Effective remaining is the max across owners")
	statuses.unmark(1)
	assert_true(statuses.is_marked(), "Owner 2's mark survives owner 1 unmarking")
	assert_almost_eq(statuses.marked_remaining, 4.0, .0001)
	assert_almost_eq(statuses.marked_remaining_for(1), 0.0, .0001)
	statuses.unmark(2)
	assert_false(statuses.is_marked())

func test_mark_never_stacks_in_magnitude_across_owners() -> void:
	var statuses := StatusEffects3D.new()
	statuses.mark(6.0, 1)
	statuses.mark(6.0, 2)
	statuses.mark(6.0, 3)
	var hit := CombatHit3D.new(10.0)
	hit.source_id = 1
	assert_almost_eq(statuses.mark_multiplier(hit), 1.0 + StatusEffects3D.MARKED_BONUS, .0001)

func test_each_owner_refreshes_to_the_longer_time_only() -> void:
	var statuses := StatusEffects3D.new()
	statuses.mark(6.0, 1)
	statuses.advance_mark(4.0)
	statuses.mark(3.0, 1)
	assert_almost_eq(statuses.marked_remaining_for(1), 3.0, .0001, "Refreshed up from 2")
	statuses.mark(1.0, 1)
	assert_almost_eq(statuses.marked_remaining_for(1), 3.0, .0001, "A shorter mark cannot cut it")

func test_default_owner_is_zero_and_unmark_without_owner_only_clears_owner_zero() -> void:
	var statuses := StatusEffects3D.new()
	statuses.mark(5.0)
	statuses.mark(5.0, 7)
	statuses.unmark()
	assert_true(statuses.is_marked())
	assert_almost_eq(statuses.marked_remaining_for(0), 0.0, .0001)

func test_advance_expires_each_owner_independently() -> void:
	var statuses := StatusEffects3D.new()
	statuses.mark(2.0, 1)
	statuses.mark(5.0, 2)
	statuses.advance_mark(3.0)
	assert_true(statuses.is_marked())
	assert_almost_eq(statuses.marked_remaining, 2.0, .0001)
	statuses.advance_mark(3.0)
	assert_false(statuses.is_marked())

func test_exposed_active_while_any_owner_runs() -> void:
	var statuses := StatusEffects3D.new()
	statuses.expose(1.0, 1)
	statuses.expose(3.0, 2)
	var hit := CombatHit3D.new(10.0)
	hit.attack_families = ["instant"]
	statuses.clear_timed("exposed", 2)
	assert_almost_eq(statuses.exposure_multiplier(hit), 1.0 + StatusEffects3D.EXPOSED_BONUS, .0001)
	statuses.advance(2.0)
	assert_almost_eq(statuses.exposure_multiplier(hit), 1.0, .0001)

func test_stagger_refreshes_per_owner_and_extend_caps_per_owner() -> void:
	var statuses := StatusEffects3D.new()
	statuses.stagger(.4, 1)
	statuses.stagger(.2, 2)
	assert_almost_eq(statuses.staggered_remaining, .4, .0001)
	for i in 6:
		statuses.extend_stagger(.4, StatusEffects3D.STAGGER_CAP, 2)
	assert_almost_eq(statuses.remaining_for_owner("staggered", 2), StatusEffects3D.STAGGER_CAP, .0001)
	assert_almost_eq(statuses.staggered_remaining, StatusEffects3D.STAGGER_CAP, .0001, "Max across owners, not a sum")
	statuses.clear_timed("staggered", 2)
	assert_almost_eq(statuses.staggered_remaining, .4, .0001)

func test_generic_api_for_new_statuses() -> void:
	var statuses := StatusEffects3D.new()
	assert_false(statuses.is_active("hooked"))
	assert_eq(statuses.remaining("hooked"), 0.0)
	statuses.apply_timed("hooked", 3.0, 4)
	statuses.apply_timed("hooked", 5.0, 9)
	assert_true(statuses.is_active("hooked"))
	assert_almost_eq(statuses.remaining("hooked"), 5.0, .0001)
	statuses.clear_timed("hooked", 9)
	assert_almost_eq(statuses.remaining("hooked"), 3.0, .0001)
	statuses.advance_timed("hooked", 4.0)
	assert_false(statuses.is_active("hooked"))
	statuses.apply_timed("hooked", 3.0, 4)
	statuses.clear()
	assert_false(statuses.is_active("hooked"), "clear() drops every owner's timers")

func test_clear_timed_on_unknown_status_is_harmless() -> void:
	var statuses := StatusEffects3D.new()
	statuses.clear_timed("nothing", 1)
	statuses.advance_timed("nothing", 1.0)
	assert_false(statuses.is_active("nothing"))
