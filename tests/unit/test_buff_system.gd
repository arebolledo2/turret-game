extends GutTest

# =============================================================================
# Unit tests for BuffSystem
# Tests buff application, stacking, expiration, and stat calculations
# =============================================================================

var buff_system: Node
var mock_turret: Node2D

func before_all() -> void:
	buff_system = get_node("/root/BuffSystem")

func before_each() -> void:
	buff_system.active_buffs.clear()
	# Create a mock turret for testing
	mock_turret = Node2D.new()
	add_child_autofree(mock_turret)


# =============================================================================
# BUFF CLASS
# =============================================================================

func test_buff_creation():
	var buff = buff_system.Buff.new("fire_rate", 1.1, "multiply", 2.0, 3)
	assert_eq(buff.stat, "fire_rate", "Should set stat")
	assert_eq(buff.value, 1.1, "Should set value")
	assert_eq(buff.operation, "multiply", "Should set operation")
	assert_eq(buff.duration, 2.0, "Should set duration")
	assert_eq(buff.time_remaining, 2.0, "Time remaining should equal duration")
	assert_eq(buff.stack_count, 1, "Should start with 1 stack")
	assert_eq(buff.max_stacks, 3, "Should set max stacks")


func test_buff_default_max_stacks():
	var buff = buff_system.Buff.new("damage", 10.0, "add", 1.0)
	assert_eq(buff.max_stacks, 1, "Should default to 1 max stack")


# =============================================================================
# APPLY BUFF - BASIC
# =============================================================================

func test_apply_buff_creates_entry():
	var buff = buff_system.Buff.new("fire_rate", 1.1, "multiply", 2.0, 1)
	buff_system.apply_buff(mock_turret, buff)

	var turret_id = mock_turret.get_instance_id()
	assert_true(buff_system.active_buffs.has(turret_id),
		"Should create entry for turret")
	assert_eq(buff_system.active_buffs[turret_id].size(), 1,
		"Should have 1 buff")


func test_apply_buff_stores_buff_data():
	var buff = buff_system.Buff.new("damage", 15.0, "add", 3.0, 1)
	buff_system.apply_buff(mock_turret, buff)

	var turret_id = mock_turret.get_instance_id()
	var stored_buff = buff_system.active_buffs[turret_id][0]

	assert_eq(stored_buff.stat, "damage", "Should store stat")
	assert_eq(stored_buff.value, 15.0, "Should store value")
	assert_eq(stored_buff.operation, "add", "Should store operation")
	assert_eq(stored_buff.duration, 3.0, "Should store duration")


func test_apply_multiple_different_buffs():
	var buff1 = buff_system.Buff.new("fire_rate", 1.1, "multiply", 2.0, 1)
	var buff2 = buff_system.Buff.new("damage", 10.0, "add", 1.0, 1)

	buff_system.apply_buff(mock_turret, buff1)
	buff_system.apply_buff(mock_turret, buff2)

	var turret_id = mock_turret.get_instance_id()
	assert_eq(buff_system.active_buffs[turret_id].size(), 2,
		"Should have 2 different buffs")


# =============================================================================
# BUFF STACKING
# =============================================================================

func test_apply_same_buff_stacks():
	var buff1 = buff_system.Buff.new("fire_rate", 1.08, "multiply", 2.0, 5)
	var buff2 = buff_system.Buff.new("fire_rate", 1.08, "multiply", 2.0, 5)

	buff_system.apply_buff(mock_turret, buff1)
	buff_system.apply_buff(mock_turret, buff2)

	var turret_id = mock_turret.get_instance_id()
	var buffs = buff_system.active_buffs[turret_id]

	assert_eq(buffs.size(), 1, "Should have only 1 buff entry")
	assert_eq(buffs[0].stack_count, 2, "Should stack to 2")


func test_buff_stacking_respects_max():
	var buff = buff_system.Buff.new("fire_rate", 1.08, "multiply", 2.0, 3)

	# Apply 5 times but max is 3
	for i in range(5):
		buff_system.apply_buff(mock_turret, buff)

	var turret_id = mock_turret.get_instance_id()
	var stored_buff = buff_system.active_buffs[turret_id][0]

	assert_eq(stored_buff.stack_count, 3,
		"Should not exceed max stacks")


func test_buff_stacking_refreshes_duration():
	var buff1 = buff_system.Buff.new("fire_rate", 1.1, "multiply", 2.0, 5)
	buff_system.apply_buff(mock_turret, buff1)

	var turret_id = mock_turret.get_instance_id()
	# Simulate time passing
	buff_system.active_buffs[turret_id][0].time_remaining = 0.5

	var buff2 = buff_system.Buff.new("fire_rate", 1.1, "multiply", 2.0, 5)
	buff_system.apply_buff(mock_turret, buff2)

	var stored_buff = buff_system.active_buffs[turret_id][0]
	assert_eq(stored_buff.time_remaining, 2.0,
		"Should refresh duration to full")


func test_buff_at_max_stacks_still_refreshes():
	var buff = buff_system.Buff.new("fire_rate", 1.08, "multiply", 2.0, 2)

	# Apply twice to hit max
	buff_system.apply_buff(mock_turret, buff)
	buff_system.apply_buff(mock_turret, buff)

	var turret_id = mock_turret.get_instance_id()
	buff_system.active_buffs[turret_id][0].time_remaining = 0.3

	# Apply again
	var buff3 = buff_system.Buff.new("fire_rate", 1.08, "multiply", 2.0, 2)
	buff_system.apply_buff(mock_turret, buff3)

	var stored_buff = buff_system.active_buffs[turret_id][0]
	assert_eq(stored_buff.stack_count, 2, "Should stay at max stacks")
	assert_eq(stored_buff.time_remaining, 2.0, "Should still refresh duration")


# =============================================================================
# BUFF EXPIRATION (_process)
# =============================================================================

func test_buff_expires_after_duration():
	var buff = buff_system.Buff.new("damage", 10.0, "add", 1.0, 1)
	buff_system.apply_buff(mock_turret, buff)

	# Simulate 1.5 seconds passing
	buff_system._process(1.5)

	var turret_id = mock_turret.get_instance_id()
	assert_false(buff_system.active_buffs.has(turret_id),
		"Buff should be expired and removed")


func test_buff_duration_decrements():
	var buff = buff_system.Buff.new("fire_rate", 1.1, "multiply", 3.0, 1)
	buff_system.apply_buff(mock_turret, buff)

	var turret_id = mock_turret.get_instance_id()
	var initial_time = buff_system.active_buffs[turret_id][0].time_remaining

	buff_system._process(1.0)

	var remaining = buff_system.active_buffs[turret_id][0].time_remaining
	assert_almost_eq(remaining, initial_time - 1.0, 0.01,
		"Should decrement time by delta")


func test_multiple_buffs_expire_independently():
	var buff1 = buff_system.Buff.new("fire_rate", 1.1, "multiply", 1.0, 1)
	var buff2 = buff_system.Buff.new("damage", 10.0, "add", 3.0, 1)

	buff_system.apply_buff(mock_turret, buff1)
	buff_system.apply_buff(mock_turret, buff2)

	# Expire first buff
	buff_system._process(1.5)

	var turret_id = mock_turret.get_instance_id()
	var buffs = buff_system.active_buffs[turret_id]

	assert_eq(buffs.size(), 1, "Should have 1 buff remaining")
	assert_eq(buffs[0].stat, "damage", "Damage buff should remain")


func test_empty_buff_array_removed():
	var buff = buff_system.Buff.new("range", 50.0, "add", 0.5, 1)
	buff_system.apply_buff(mock_turret, buff)

	var turret_id = mock_turret.get_instance_id()
	assert_true(buff_system.active_buffs.has(turret_id),
		"Should have turret entry")

	buff_system._process(1.0)

	assert_false(buff_system.active_buffs.has(turret_id),
		"Should remove empty turret entry")


# =============================================================================
# GET BUFF MULTIPLIER
# =============================================================================

func test_get_buff_multiplier_no_buffs():
	var mult = buff_system.get_buff_multiplier(mock_turret, "fire_rate")
	assert_eq(mult, 1.0, "Should return 1.0 with no buffs")


func test_get_buff_multiplier_single_buff():
	var buff = buff_system.Buff.new("fire_rate", 1.2, "multiply", 2.0, 1)
	buff_system.apply_buff(mock_turret, buff)

	var mult = buff_system.get_buff_multiplier(mock_turret, "fire_rate")
	assert_eq(mult, 1.2, "Should return buff value")


func test_get_buff_multiplier_with_stacks():
	var buff = buff_system.Buff.new("fire_rate", 1.08, "multiply", 2.0, 5)

	# Apply 3 times
	buff_system.apply_buff(mock_turret, buff)
	buff_system.apply_buff(mock_turret, buff)
	buff_system.apply_buff(mock_turret, buff)

	var mult = buff_system.get_buff_multiplier(mock_turret, "fire_rate")
	var expected = pow(1.08, 3)  # (1.08)^3
	assert_almost_eq(mult, expected, 0.001,
		"Should apply exponential stacking")


func test_get_buff_multiplier_max_stacks():
	# Chain Reaction: 1.08 fire rate, max 5 stacks
	var buff = buff_system.Buff.new("fire_rate", 1.08, "multiply", 2.0, 5)

	for i in range(5):
		buff_system.apply_buff(mock_turret, buff)

	var mult = buff_system.get_buff_multiplier(mock_turret, "fire_rate")
	var expected = pow(1.08, 5)  # (1.08)^5 ≈ 1.469
	assert_almost_eq(mult, expected, 0.001,
		"Should calculate max stack multiplier")


func test_get_buff_multiplier_wrong_stat():
	var buff = buff_system.Buff.new("fire_rate", 1.5, "multiply", 2.0, 1)
	buff_system.apply_buff(mock_turret, buff)

	var mult = buff_system.get_buff_multiplier(mock_turret, "damage")
	assert_eq(mult, 1.0, "Should return 1.0 for different stat")


func test_get_buff_multiplier_ignores_additive():
	var buff = buff_system.Buff.new("damage", 10.0, "add", 2.0, 1)
	buff_system.apply_buff(mock_turret, buff)

	var mult = buff_system.get_buff_multiplier(mock_turret, "damage")
	assert_eq(mult, 1.0, "Should ignore additive buffs")


func test_get_buff_multiplier_multiple_buffs():
	var buff1 = buff_system.Buff.new("range", 1.2, "multiply", 2.0, 1)
	var buff2 = buff_system.Buff.new("range", 1.3, "multiply", 2.0, 1)

	buff_system.apply_buff(mock_turret, buff1)
	buff_system.apply_buff(mock_turret, buff2)

	var mult = buff_system.get_buff_multiplier(mock_turret, "range")
	# Note: Both are separate buffs (different values), so both should apply
	# Current implementation would stack: pow(1.2, 1) * pow(1.3, 1)
	assert_gt(mult, 1.0, "Should have some multiplier")


# =============================================================================
# GET BUFF ADD VALUE
# =============================================================================

func test_get_buff_add_value_no_buffs():
	var add = buff_system.get_buff_add_value(mock_turret, "damage")
	assert_eq(add, 0.0, "Should return 0 with no buffs")


func test_get_buff_add_value_single_buff():
	var buff = buff_system.Buff.new("damage", 15.0, "add", 2.0, 1)
	buff_system.apply_buff(mock_turret, buff)

	var add = buff_system.get_buff_add_value(mock_turret, "damage")
	assert_eq(add, 15.0, "Should return buff value")


func test_get_buff_add_value_with_stacks():
	var buff = buff_system.Buff.new("damage", 5.0, "add", 2.0, 3)

	# Apply 3 times
	for i in range(3):
		buff_system.apply_buff(mock_turret, buff)

	var add = buff_system.get_buff_add_value(mock_turret, "damage")
	assert_eq(add, 5.0 * 3, "Should multiply by stack count")


func test_get_buff_add_value_wrong_stat():
	var buff = buff_system.Buff.new("damage", 10.0, "add", 2.0, 1)
	buff_system.apply_buff(mock_turret, buff)

	var add = buff_system.get_buff_add_value(mock_turret, "fire_rate")
	assert_eq(add, 0.0, "Should return 0 for different stat")


func test_get_buff_add_value_ignores_multiplicative():
	var buff = buff_system.Buff.new("range", 1.5, "multiply", 2.0, 1)
	buff_system.apply_buff(mock_turret, buff)

	var add = buff_system.get_buff_add_value(mock_turret, "range")
	assert_eq(add, 0.0, "Should ignore multiplicative buffs")


# =============================================================================
# MULTIPLE TURRETS
# =============================================================================

func test_buffs_independent_per_turret():
	var turret2 = Node2D.new()
	add_child_autofree(turret2)

	var buff1 = buff_system.Buff.new("fire_rate", 1.1, "multiply", 2.0, 1)
	var buff2 = buff_system.Buff.new("damage", 10.0, "add", 2.0, 1)

	buff_system.apply_buff(mock_turret, buff1)
	buff_system.apply_buff(turret2, buff2)

	var mult1 = buff_system.get_buff_multiplier(mock_turret, "fire_rate")
	var mult2 = buff_system.get_buff_multiplier(turret2, "fire_rate")
	var add1 = buff_system.get_buff_add_value(mock_turret, "damage")
	var add2 = buff_system.get_buff_add_value(turret2, "damage")

	assert_eq(mult1, 1.1, "Turret 1 should have fire rate buff")
	assert_eq(mult2, 1.0, "Turret 2 should not have fire rate buff")
	assert_eq(add1, 0.0, "Turret 1 should not have damage buff")
	assert_eq(add2, 10.0, "Turret 2 should have damage buff")


# =============================================================================
# EDGE CASES
# =============================================================================

func test_buff_with_zero_duration():
	var buff = buff_system.Buff.new("damage", 10.0, "add", 0.0, 1)
	buff_system.apply_buff(mock_turret, buff)

	buff_system._process(0.01)

	var turret_id = mock_turret.get_instance_id()
	assert_false(buff_system.active_buffs.has(turret_id),
		"Zero duration buff should expire immediately")


func test_buff_with_negative_duration():
	var buff = buff_system.Buff.new("fire_rate", 1.1, "multiply", -1.0, 1)
	buff_system.apply_buff(mock_turret, buff)

	var turret_id = mock_turret.get_instance_id()
	assert_eq(buff_system.active_buffs[turret_id][0].time_remaining, -1.0,
		"Should allow negative duration (will expire on first process)")


func test_large_stack_count():
	var buff = buff_system.Buff.new("fire_rate", 1.01, "multiply", 10.0, 100)

	for i in range(100):
		buff_system.apply_buff(mock_turret, buff)

	var mult = buff_system.get_buff_multiplier(mock_turret, "fire_rate")
	var expected = pow(1.01, 100)  # Very large multiplier
	assert_almost_eq(mult, expected, 0.01,
		"Should handle large stack counts")


func test_zero_value_multiplier():
	var buff = buff_system.Buff.new("damage", 0.0, "multiply", 2.0, 1)
	buff_system.apply_buff(mock_turret, buff)

	var mult = buff_system.get_buff_multiplier(mock_turret, "damage")
	assert_eq(mult, 0.0, "Should handle zero multiplier")


func test_find_matching_buff_returns_null_for_nonexistent():
	var turret_id = mock_turret.get_instance_id()
	var found = buff_system._find_matching_buff(turret_id, "fire_rate")
	assert_null(found, "Should return null when no buffs exist")
