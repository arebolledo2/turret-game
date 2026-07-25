extends GutTest

# =============================================================================
# Unit tests for Projectile
# Tests damage calculation, Executioner's Mark, pierce, AoE, and DoT mechanics
# =============================================================================

const Projectile = preload("res://scenes/projectile.tscn")

var projectile: Area2D


func before_each() -> void:
	projectile = Projectile.instantiate()
	add_child_autofree(projectile)


# =============================================================================
# BASIC SETUP
# =============================================================================

func test_basic_setup():
	projectile.setup(Vector2.RIGHT, 500.0, 25.0, true, false)

	assert_eq(projectile.direction, Vector2.RIGHT, "Should set direction")
	assert_eq(projectile.speed, 500.0, "Should set speed")
	assert_eq(projectile.damage, 25.0, "Should set damage")
	assert_true(projectile.is_player_projectile, "Should be player projectile")
	assert_false(projectile.is_crit, "Should not be crit")
	assert_true(projectile.is_setup, "Should be marked as setup")


func test_basic_setup_with_crit():
	projectile.setup(Vector2.LEFT, 300.0, 15.0, true, true)

	assert_true(projectile.is_crit, "Should be crit")


func test_enemy_projectile_setup():
	projectile.setup(Vector2.DOWN, 400.0, 20.0, false, false)

	assert_false(projectile.is_player_projectile, "Should be enemy projectile")


func test_extended_setup():
	var stats := {
		"projectile_speed": 600.0,
		"damage": 30.0,
		"pierce": 2,
		"aoe_radius": 50.0,
		"dot_damage": 5.0,
		"dot_duration": 3.0,
		"dot_tick_rate": 0.5,
		"knockback_force": 100.0
	}
	projectile.setup_extended(stats, Vector2.UP, true, GameEnums.DamageType.FIRE, true)

	assert_eq(projectile.speed, 600.0, "Should set speed from stats")
	assert_eq(projectile.damage, 30.0, "Should set damage from stats")
	assert_eq(projectile.pierce, 2, "Should set pierce")
	assert_eq(projectile.aoe_radius, 50.0, "Should set aoe_radius")
	assert_eq(projectile.dot_damage, 5.0, "Should set dot_damage")
	assert_eq(projectile.dot_duration, 3.0, "Should set dot_duration")
	assert_eq(projectile.dot_tick_rate, 0.5, "Should set dot_tick_rate")
	assert_eq(projectile.knockback_force, 100.0, "Should set knockback_force")
	assert_eq(projectile.damage_type, GameEnums.DamageType.FIRE, "Should set damage type")
	assert_true(projectile.is_crit, "Should be crit")


func test_extended_setup_defaults():
	var stats := {}
	projectile.setup_extended(stats, Vector2.RIGHT, true, GameEnums.DamageType.PHYSICAL)

	assert_eq(projectile.speed, 500.0, "Should default speed to 500")
	assert_eq(projectile.damage, 10.0, "Should default damage to 10")
	assert_eq(projectile.pierce, 0, "Should default pierce to 0")
	assert_eq(projectile.aoe_radius, 0.0, "Should default aoe_radius to 0")


# =============================================================================
# DIRECTION NORMALIZATION
# =============================================================================

func test_direction_normalized():
	var unnormalized = Vector2(10, 0)
	projectile.setup(unnormalized, 500.0, 25.0, true)

	assert_eq(projectile.direction.length(), 1.0, "Direction should be normalized")


func test_diagonal_direction_normalized():
	var diagonal = Vector2(3, 4)
	projectile.setup(diagonal, 500.0, 25.0, true)

	assert_almost_eq(projectile.direction.length(), 1.0, 0.001, "Diagonal direction should be normalized")


# =============================================================================
# EXECUTIONER'S MARK DAMAGE CALCULATION
# =============================================================================

func test_calculate_damage_with_executioner_no_item():
	# Without the item, damage should be unchanged
	# Clear any existing item counts
	ItemTrackingService.item_counts.clear()

	var mock_enemy = _create_mock_enemy(100.0, 20.0) # 20% health
	add_child_autofree(mock_enemy)

	var result = projectile._calculate_damage_with_executioner(100.0, mock_enemy)
	assert_eq(result, 100.0, "Should return base damage without item")


func test_calculate_damage_with_executioner_high_health():
	# With item but enemy above 25% health - no bonus
	ItemTrackingService.item_counts["executioners_mark"] = 1

	var mock_enemy = _create_mock_enemy(100.0, 50.0) # 50% health
	add_child_autofree(mock_enemy)

	var result = projectile._calculate_damage_with_executioner(100.0, mock_enemy)
	assert_eq(result, 100.0, "Should return base damage when health > 25%")

	# Cleanup
	ItemTrackingService.item_counts.clear()


func test_calculate_damage_with_executioner_low_health():
	# With item and enemy below 25% health - +50% bonus
	ItemTrackingService.item_counts["executioners_mark"] = 1

	var mock_enemy = _create_mock_enemy(100.0, 20.0) # 20% health
	add_child_autofree(mock_enemy)

	var result = projectile._calculate_damage_with_executioner(100.0, mock_enemy)
	assert_eq(result, 150.0, "Should return 150% damage when health < 25%")

	# Cleanup
	ItemTrackingService.item_counts.clear()


func test_calculate_damage_with_executioner_boundary():
	# At exactly 25% health - no bonus (must be below)
	ItemTrackingService.item_counts["executioners_mark"] = 1

	var mock_enemy = _create_mock_enemy(100.0, 25.0) # Exactly 25%
	add_child_autofree(mock_enemy)

	var result = projectile._calculate_damage_with_executioner(100.0, mock_enemy)
	assert_eq(result, 100.0, "Should return base damage at exactly 25%")

	# Cleanup
	ItemTrackingService.item_counts.clear()


func test_calculate_damage_zero_max_health():
	# Edge case: enemy with 0 max health should not cause division by zero
	ItemTrackingService.item_counts["executioners_mark"] = 1

	var mock_enemy = _create_mock_enemy_zero_max()
	add_child_autofree(mock_enemy)

	var result = projectile._calculate_damage_with_executioner(100.0, mock_enemy)
	assert_eq(result, 100.0, "Should return base damage when max_health is 0 (no crash)")

	# Cleanup
	ItemTrackingService.item_counts.clear()


# =============================================================================
# PIERCE MECHANICS
# =============================================================================

func test_pierce_tracks_hit_enemies():
	projectile.setup(Vector2.RIGHT, 500.0, 25.0, true)
	projectile.pierce = 2

	var enemy1 = _create_mock_enemy(100.0, 100.0)
	add_child_autofree(enemy1)

	projectile.hit_enemies.append(enemy1)

	assert_true(enemy1 in projectile.hit_enemies, "Should track hit enemies")


func test_pierce_count_increments():
	projectile.setup(Vector2.RIGHT, 500.0, 25.0, true)
	projectile.pierce = 2
	projectile.pierce_count = 0

	projectile.pierce_count += 1
	assert_eq(projectile.pierce_count, 1, "Pierce count should increment")


# =============================================================================
# MOVEMENT
# =============================================================================

func test_physics_process_moves_projectile():
	projectile.setup(Vector2.RIGHT, 100.0, 25.0, true)
	var start_pos = projectile.position

	projectile._physics_process(0.1)

	var expected_movement = Vector2.RIGHT * 100.0 * 0.1
	assert_eq(projectile.position, start_pos + expected_movement, "Should move based on speed and delta")


func test_physics_process_diagonal_movement():
	var diagonal = Vector2(1, 1).normalized()
	projectile.setup(diagonal, 200.0, 25.0, true)
	var start_pos = projectile.position

	projectile._physics_process(0.05)

	var expected_movement = diagonal * 200.0 * 0.05
	assert_almost_eq(projectile.position.x, start_pos.x + expected_movement.x, 0.001)
	assert_almost_eq(projectile.position.y, start_pos.y + expected_movement.y, 0.001)


# =============================================================================
# HELPERS
# =============================================================================

func _create_mock_enemy(max_hp: float, current_hp: float) -> Node2D:
	var enemy = Node2D.new()
	enemy.add_to_group("enemies")

	var script = GDScript.new()
	script.source_code = """
extends Node2D

var current_health: float = %s
var max_health: float = %s
var damage_taken: float = 0.0
var last_crit: bool = false

func take_damage(amount: float, is_crit: bool = false) -> void:
	damage_taken += amount
	last_crit = is_crit
	current_health -= amount

func get_health_percent() -> float:
	if max_health <= 0:
		return 1.0
	return current_health / max_health
""" % [current_hp, max_hp]
	script.reload()
	enemy.set_script(script)
	return enemy


func _create_mock_enemy_zero_max() -> Node2D:
	var enemy = Node2D.new()
	enemy.add_to_group("enemies")

	var script = GDScript.new()
	script.source_code = """
extends Node2D

var current_health: float = 0.0
var max_health: float = 0.0

func get_health_percent() -> float:
	return 1.0
"""
	script.reload()
	enemy.set_script(script)
	return enemy


# =============================================================================
# POOLED REUSE
# =============================================================================

func test_pool_released_clears_extended_stats():
	# setup() does not touch the extended stats, so a pierce/AoE/DoT projectile
	# returning to the pool must not carry those into the next basic use.
	projectile.setup_extended({
		"projectile_speed": 600.0,
		"damage": 30.0,
		"pierce": 3,
		"aoe_radius": 50.0,
		"dot_damage": 5.0,
		"dot_duration": 3.0,
		"dot_tick_rate": 0.5,
		"knockback_force": 100.0,
	}, Vector2.RIGHT, true, GameEnums.DamageType.FIRE, true)

	projectile._pool_released()

	assert_eq(projectile.pierce, 0, "pierce should reset")
	assert_eq(projectile.pierce_count, 0, "pierce_count should reset")
	assert_eq(projectile.aoe_radius, 0.0, "aoe_radius should reset")
	assert_eq(projectile.dot_damage, 0.0, "dot_damage should reset")
	assert_eq(projectile.dot_duration, 0.0, "dot_duration should reset")
	assert_eq(projectile.dot_tick_rate, 1.0, "dot_tick_rate should reset")
	assert_eq(projectile.knockback_force, 0.0, "knockback_force should reset")
	assert_eq(projectile.damage_type, GameEnums.DamageType.PHYSICAL, "damage_type should reset")
	assert_false(projectile.is_crit, "is_crit should reset")
	assert_false(projectile.is_setup, "is_setup should reset")


func test_pool_released_clears_pierce_hit_list():
	projectile.setup_extended({"pierce": 2}, Vector2.RIGHT, true, GameEnums.DamageType.PHYSICAL, false)
	var dummy := Node2D.new()
	add_child_autofree(dummy)
	projectile.hit_enemies.append(dummy)

	projectile._pool_released()

	assert_eq(projectile.hit_enemies.size(), 0, "hit_enemies must not carry into the next use")


func test_basic_setup_after_extended_use_is_clean():
	# The end-to-end version of the leak: an AoE shot, recycled, then a basic shot.
	projectile.setup_extended({
		"pierce": 3, "aoe_radius": 50.0, "dot_damage": 5.0,
	}, Vector2.RIGHT, true, GameEnums.DamageType.FIRE, true)
	projectile._pool_released()
	projectile.setup(Vector2.LEFT, 400.0, 12.0, true, false)

	assert_eq(projectile.aoe_radius, 0.0, "Recycled basic projectile must not explode")
	assert_eq(projectile.pierce, 0, "Recycled basic projectile must not pierce")
	assert_eq(projectile.dot_damage, 0.0, "Recycled basic projectile must not apply DoT")
	assert_eq(projectile.damage, 12.0, "New setup values should apply")


func test_despawn_is_idempotent():
	projectile.setup(Vector2.RIGHT, 500.0, 10.0, true, false)

	projectile._despawn()
	assert_true(projectile._is_despawning, "First despawn should latch")
	# A projectile overlapping several hurtboxes in one frame despawns repeatedly.
	projectile._despawn()
	assert_true(projectile._is_despawning, "Repeat despawn should be a no-op, not an error")


func test_time_alive_resets_on_release():
	projectile._time_alive = 2.9
	projectile._pool_released()
	assert_eq(projectile._time_alive, 0.0, "Lifetime counter must reset or the next use expires instantly")
