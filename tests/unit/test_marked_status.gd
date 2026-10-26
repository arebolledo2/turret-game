extends GutTest

## The Marked status is separate from Exposed: its own multiplier, its own timer, turret hits only.

func _hit(damage: float, source: int, families: Array[String] = []) -> CombatHit3D:
	var hit := CombatHit3D.new(damage)
	hit.source_id = source
	hit.attack_families = families
	return hit

func test_unmarked_enemy_takes_normal_damage() -> void:
	var statuses := StatusEffects3D.new()
	assert_false(statuses.is_marked())
	assert_eq(statuses.mark_multiplier(_hit(10.0, 1)), 1.0)

func test_marked_enemy_takes_a_quarter_more_from_turret_hits() -> void:
	var statuses := StatusEffects3D.new()
	statuses.mark(6.0)
	assert_true(statuses.is_marked())
	assert_almost_eq(statuses.mark_multiplier(_hit(10.0, 3, ["projectile"])), 1.25, .0001)
	assert_almost_eq(statuses.mark_multiplier(_hit(10.0, 3, ["instant"])), 1.25, .0001, "Every attack family, not only Instant")

func test_mark_ignores_hits_without_a_turret_source() -> void:
	var statuses := StatusEffects3D.new()
	statuses.mark(6.0)
	assert_eq(statuses.mark_multiplier(_hit(10.0, 0)), 1.0, "Hero weapon, contact and unattributed blasts are not amplified")

func test_mark_is_independent_of_exposed_and_the_two_multiply() -> void:
	var statuses := StatusEffects3D.new()
	var instant := _hit(10.0, 2, ["instant"])
	statuses.expose(2.0)
	assert_almost_eq(statuses.exposure_multiplier(instant), 1.3, .0001)
	assert_eq(statuses.mark_multiplier(instant), 1.0, "Exposed does not mark")
	statuses.mark(2.0)
	assert_almost_eq(statuses.exposure_multiplier(instant) * statuses.mark_multiplier(instant), 1.625, .0001, "Stacking rule: 1.3 x 1.25")
	var projectile := _hit(10.0, 2, ["projectile"])
	assert_almost_eq(statuses.exposure_multiplier(projectile) * statuses.mark_multiplier(projectile), 1.25, .0001, "Exposed stays Instant-only")
	statuses.advance(5.0)
	assert_eq(statuses.exposed_remaining, 0.0)
	assert_true(statuses.is_marked(), "Exposed expiring does not end the mark: the mark runs on advance_mark")

func test_mark_timer_runs_on_advance_mark_and_expires() -> void:
	var statuses := StatusEffects3D.new()
	statuses.mark(6.0)
	statuses.advance_mark(2.5)
	assert_almost_eq(statuses.marked_remaining, 3.5, .0001)
	statuses.advance_mark(10.0)
	assert_eq(statuses.marked_remaining, 0.0)
	assert_false(statuses.is_marked())
	assert_eq(statuses.mark_multiplier(_hit(10.0, 1)), 1.0)

func test_marking_again_keeps_the_longer_timer_and_never_stacks() -> void:
	var statuses := StatusEffects3D.new()
	statuses.mark(6.0)
	statuses.advance_mark(4.0)
	statuses.mark(6.0)
	assert_almost_eq(statuses.marked_remaining, 6.0, .0001, "Refreshed")
	statuses.mark(1.0)
	assert_almost_eq(statuses.marked_remaining, 6.0, .0001, "A shorter mark cannot cut a longer one")
	assert_almost_eq(statuses.mark_multiplier(_hit(10.0, 1)), 1.25, .0001, "Still a single +25%")

func test_unmark_and_clear_end_the_mark() -> void:
	var statuses := StatusEffects3D.new()
	statuses.mark(6.0)
	statuses.unmark()
	assert_false(statuses.is_marked())
	statuses.mark(6.0)
	statuses.clear()
	assert_false(statuses.is_marked(), "clear() runs on death, wave end and defeat")
