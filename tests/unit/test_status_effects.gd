extends GutTest

# =============================================================================
# Unit tests for StatusEffect
# Tests DoT damage, duration, ticking, and comparison
# =============================================================================


# =============================================================================
# INITIALIZATION
# =============================================================================

func test_init_sets_damage_type():
	var effect = StatusEffect.new(Globals.DamageType.FIRE, 5.0, 3.0)
	assert_eq(effect.damage_type, Globals.DamageType.FIRE, "Damage type should be set")


func test_init_sets_dot_damage():
	var effect = StatusEffect.new(Globals.DamageType.FIRE, 5.0, 3.0)
	assert_eq(effect.dot_damage, 5.0, "DoT damage should be set")


func test_init_sets_duration():
	var effect = StatusEffect.new(Globals.DamageType.FIRE, 5.0, 3.0)
	assert_eq(effect.dot_duration, 3.0, "Duration should be set")


func test_init_sets_time_remaining():
	var effect = StatusEffect.new(Globals.DamageType.FIRE, 5.0, 3.0)
	assert_eq(effect.time_remaining, 3.0, "Time remaining should equal duration")


func test_init_sets_tick_rate():
	var effect = StatusEffect.new(Globals.DamageType.FIRE, 5.0, 3.0, 2.0)
	assert_eq(effect.dot_tick_rate, 2.0, "Tick rate should be set")


func test_init_default_tick_rate():
	var effect = StatusEffect.new(Globals.DamageType.FIRE, 5.0, 3.0)
	assert_eq(effect.dot_tick_rate, 1.0, "Default tick rate should be 1.0")


func test_init_sets_slow_intensity():
	var effect = StatusEffect.new(Globals.DamageType.ELECTRIC, 5.0, 3.0, 1.0, 0.3)
	assert_eq(effect.slow_intensity, 0.3, "Slow intensity should be set")


func test_init_default_slow_intensity():
	var effect = StatusEffect.new(Globals.DamageType.FIRE, 5.0, 3.0)
	assert_eq(effect.slow_intensity, 0.0, "Default slow intensity should be 0")


func test_init_tick_timer_starts_at_zero():
	var effect = StatusEffect.new(Globals.DamageType.FIRE, 5.0, 3.0)
	assert_eq(effect.tick_timer, 0.0, "Tick timer should start at 0")


# =============================================================================
# PROCESS AND TICKING
# =============================================================================

func test_process_decreases_time_remaining():
	var effect = StatusEffect.new(Globals.DamageType.FIRE, 5.0, 3.0)

	effect.process(0.5)

	assert_almost_eq(effect.time_remaining, 2.5, 0.01, "Time remaining should decrease")


func test_process_increases_tick_timer():
	var effect = StatusEffect.new(Globals.DamageType.FIRE, 5.0, 3.0)

	effect.process(0.5)

	assert_almost_eq(effect.tick_timer, 0.5, 0.01, "Tick timer should increase")


func test_process_returns_zero_before_tick():
	var effect = StatusEffect.new(Globals.DamageType.FIRE, 5.0, 3.0, 1.0)  # 1 tick/sec

	var damage = effect.process(0.5)  # Not enough time for tick

	assert_eq(damage, 0.0, "Should return 0 before tick interval reached")


func test_process_returns_damage_on_tick():
	var effect = StatusEffect.new(Globals.DamageType.FIRE, 5.0, 3.0, 1.0)  # 1 tick/sec

	effect.process(0.5)  # Half way
	var damage = effect.process(0.5)  # Now at 1 second

	assert_eq(damage, 5.0, "Should return dot_damage on tick")


func test_process_resets_tick_timer():
	var effect = StatusEffect.new(Globals.DamageType.FIRE, 5.0, 3.0, 1.0)

	effect.process(1.0)  # Trigger tick

	assert_lt(effect.tick_timer, 1.0, "Tick timer should reset after tick")


func test_process_returns_zero_when_expired():
	var effect = StatusEffect.new(Globals.DamageType.FIRE, 5.0, 1.0, 1.0)

	effect.process(1.5)  # Expire the effect
	var damage = effect.process(1.0)  # Try to tick

	assert_eq(damage, 0.0, "Expired effect should return 0 damage")


func test_faster_tick_rate():
	var effect = StatusEffect.new(Globals.DamageType.FIRE, 5.0, 3.0, 2.0)  # 2 ticks/sec

	var damage = effect.process(0.5)  # 0.5 sec = 1 tick at 2/sec

	assert_eq(damage, 5.0, "Faster tick rate should tick sooner")


func test_slower_tick_rate():
	var effect = StatusEffect.new(Globals.DamageType.FIRE, 5.0, 3.0, 0.5)  # 0.5 ticks/sec

	var damage = effect.process(1.0)  # 1 sec, needs 2 sec for tick

	assert_eq(damage, 0.0, "Slower tick rate should not tick yet")


# =============================================================================
# EXPIRATION
# =============================================================================

func test_is_expired_false_initially():
	var effect = StatusEffect.new(Globals.DamageType.FIRE, 5.0, 3.0)

	assert_false(effect.is_expired(), "New effect should not be expired")


func test_is_expired_true_after_duration():
	var effect = StatusEffect.new(Globals.DamageType.FIRE, 5.0, 1.0)

	effect.process(1.5)

	assert_true(effect.is_expired(), "Effect should be expired after duration")


func test_is_expired_false_during_duration():
	var effect = StatusEffect.new(Globals.DamageType.FIRE, 5.0, 3.0)

	effect.process(2.0)

	assert_false(effect.is_expired(), "Effect should not be expired before duration ends")


# =============================================================================
# COMPARISON (is_stronger_than)
# =============================================================================

func test_is_stronger_than_null():
	var effect = StatusEffect.new(Globals.DamageType.FIRE, 5.0, 3.0)

	assert_true(effect.is_stronger_than(null), "Any effect is stronger than null")


func test_is_stronger_than_weaker_damage():
	var strong = StatusEffect.new(Globals.DamageType.FIRE, 10.0, 3.0)
	var weak = StatusEffect.new(Globals.DamageType.FIRE, 5.0, 3.0)

	assert_true(strong.is_stronger_than(weak), "Higher damage is stronger")


func test_is_stronger_than_equal_damage():
	var e1 = StatusEffect.new(Globals.DamageType.FIRE, 5.0, 3.0)
	var e2 = StatusEffect.new(Globals.DamageType.FIRE, 5.0, 3.0)

	assert_false(e1.is_stronger_than(e2), "Equal damage is not stronger")


func test_is_stronger_than_higher_damage():
	var weak = StatusEffect.new(Globals.DamageType.FIRE, 5.0, 3.0)
	var strong = StatusEffect.new(Globals.DamageType.FIRE, 10.0, 3.0)

	assert_false(weak.is_stronger_than(strong), "Lower damage is not stronger")


func test_is_stronger_than_compares_slow_for_slow_effects():
	var strong_slow = StatusEffect.new(Globals.DamageType.ELECTRIC, 5.0, 3.0, 1.0, 0.5)
	var weak_slow = StatusEffect.new(Globals.DamageType.ELECTRIC, 10.0, 3.0, 1.0, 0.3)

	# Both have slow_intensity > 0, so compare slow, not damage
	assert_true(strong_slow.is_stronger_than(weak_slow),
		"Higher slow intensity is stronger for slow effects")


func test_is_stronger_than_damage_when_no_slow():
	var high_damage = StatusEffect.new(Globals.DamageType.FIRE, 10.0, 3.0, 1.0, 0.0)
	var low_damage = StatusEffect.new(Globals.DamageType.FIRE, 5.0, 3.0, 1.0, 0.0)

	# Neither has slow, compare damage
	assert_true(high_damage.is_stronger_than(low_damage),
		"Higher damage is stronger when no slow")


# =============================================================================
# REFRESH
# =============================================================================

func test_refresh_resets_time_remaining():
	var effect = StatusEffect.new(Globals.DamageType.FIRE, 5.0, 3.0)
	effect.process(2.0)  # 1.0 remaining

	effect.refresh(5.0, 4.0)

	assert_eq(effect.time_remaining, 4.0, "Refresh should reset time remaining")


func test_refresh_updates_duration():
	var effect = StatusEffect.new(Globals.DamageType.FIRE, 5.0, 3.0)

	effect.refresh(5.0, 5.0)

	assert_eq(effect.dot_duration, 5.0, "Refresh should update duration")


func test_refresh_upgrades_damage_if_higher():
	var effect = StatusEffect.new(Globals.DamageType.FIRE, 5.0, 3.0)

	effect.refresh(10.0, 3.0)

	assert_eq(effect.dot_damage, 10.0, "Refresh should upgrade damage if higher")


func test_refresh_keeps_damage_if_lower():
	var effect = StatusEffect.new(Globals.DamageType.FIRE, 10.0, 3.0)

	effect.refresh(5.0, 3.0)

	assert_eq(effect.dot_damage, 10.0, "Refresh should keep damage if new is lower")


func test_refresh_upgrades_slow_if_higher():
	var effect = StatusEffect.new(Globals.DamageType.ELECTRIC, 5.0, 3.0, 1.0, 0.2)

	effect.refresh(5.0, 3.0, 0.4)

	assert_eq(effect.slow_intensity, 0.4, "Refresh should upgrade slow if higher")


func test_refresh_keeps_slow_if_lower():
	var effect = StatusEffect.new(Globals.DamageType.ELECTRIC, 5.0, 3.0, 1.0, 0.4)

	effect.refresh(5.0, 3.0, 0.2)

	assert_eq(effect.slow_intensity, 0.4, "Refresh should keep slow if new is lower")


# =============================================================================
# TYPE NAMES
# =============================================================================

func test_get_type_name_fire():
	var effect = StatusEffect.new(Globals.DamageType.FIRE, 5.0, 3.0)
	assert_eq(effect.get_type_name(), "Burning", "Fire type name should be Burning")


func test_get_type_name_electric():
	var effect = StatusEffect.new(Globals.DamageType.ELECTRIC, 5.0, 3.0)
	assert_eq(effect.get_type_name(), "Shocked", "Electric type name should be Shocked")


func test_get_type_name_plasma():
	var effect = StatusEffect.new(Globals.DamageType.PLASMA, 5.0, 3.0)
	assert_eq(effect.get_type_name(), "Irradiated", "Plasma type name should be Irradiated")


func test_get_type_name_physical():
	var effect = StatusEffect.new(Globals.DamageType.PHYSICAL, 5.0, 3.0)
	assert_eq(effect.get_type_name(), "Bleeding", "Physical type name should be Bleeding")
