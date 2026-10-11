extends GutTest

func burn(dps: float, duration: float, source: int) -> CombatHit3D:
	var hit := CombatHit3D.new(1.0)
	hit.burn_dps = dps
	hit.burn_duration = duration
	hit.source_id = source
	hit.attack_families.assign(["aoe"])
	return hit

func test_burn_total_is_independent_of_frame_size_and_preserves_source() -> void:
	for step: float in [.01, .1, .4, 2.0]:
		var status := StatusEffects3D.new()
		status.apply(burn(8.0, 1.1, 42))
		var damage := 0.0
		for frame in range(ceili(2.0 / step)):
			for hit in status.advance_burn(step):
				damage += hit.damage
				assert_eq(hit.source_id, 42)
				assert_eq(hit.burn_dps, 0.0, "Ticks cannot reapply themselves")
		assert_almost_eq(damage, 8.8, .001)
		assert_eq(status.burn_dps, 0.0)

func test_weaker_burn_does_not_stack_or_extend_stronger_source() -> void:
	var status := StatusEffects3D.new()
	status.apply(burn(10, 1, 12))
	status.advance_burn(.5)
	status.apply(burn(2, 10, 20))
	assert_eq(status.burn_source_id, 12)
	assert_eq(status.burn_remaining, .5)
	status.apply(burn(20, 1, 20))
	assert_eq(status.burn_source_id, 20)
	assert_eq(status.burn_dps, 20.0)
	status.clear()
	assert_true(status.advance_burn(1).is_empty())

func test_replacement_preserves_partial_damage_and_original_owner() -> void:
	var status := StatusEffects3D.new()
	status.apply(burn(10, 1, 12))
	assert_true(status.advance_burn(.1).is_empty())
	status.apply(burn(20, 1, 20))
	assert_true(status.advance_burn(0).is_empty(), "Paused time does not resolve hits")
	var hits := status.advance_burn(1)
	var totals: Dictionary = {}
	for hit in hits:
		totals[hit.source_id] = float(totals.get(hit.source_id, 0.0)) + hit.damage
	assert_almost_eq(float(totals[12]), 1.0, .001)
	assert_almost_eq(float(totals[20]), 20.0, .001)
	status.apply(burn(10, 1, 12))
	status.advance_burn(.1)
	status.apply(burn(20, 1, 20))
	status.clear()
	assert_true(status.advance_burn(1).is_empty(), "Reset discards queued partial ticks")
