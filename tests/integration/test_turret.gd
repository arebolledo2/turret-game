extends GutTest

# =============================================================================
# Integration tests for turret.gd
# Tests turret behavior and targeting
# =============================================================================

var turret_scene: PackedScene
var enemy_scene: PackedScene
var turret: Node2D


func before_all() -> void:
	turret_scene = load("res://scenes/turret.tscn")
	enemy_scene = load("res://scenes/enemy.tscn")


func before_each() -> void:
	Globals.reset_stats()
	Globals.current_difficulty = GameEnums.Difficulty.EASY
	Globals.is_game_active = true
	
	turret = turret_scene.instantiate()
	add_child_autofree(turret)
	turret.global_position = Vector2.ZERO


# =============================================================================
# INITIALIZATION TESTS
# =============================================================================

func test_turret_added_to_group():
	assert_true(turret.is_in_group("turrets"), "Turret should be in 'turrets' group")


func test_turret_stats_from_globals():
	# Normal turret type uses stats from TURRET_TYPES["normal"]
	var expected_stats = Globals.get_turret_stats("normal")
	assert_eq(turret.current_damage, expected_stats["damage"], "Damage should match Globals")
	assert_eq(turret.current_fire_rate, expected_stats["fire_rate"], "Fire rate should match Globals")
	assert_eq(turret.current_range, expected_stats["range"], "Range should match Globals")


func test_turret_can_fire_initially():
	assert_true(turret.can_fire, "Turret should be able to fire initially")


# =============================================================================
# TARGETING TESTS (without firing to avoid projectile issues)
# =============================================================================

func test_turret_finds_enemy_in_range():
	# Disable firing to prevent projectile creation issues
	turret.can_fire = false
	
	# Create enemy within range
	var enemy = enemy_scene.instantiate()
	add_child_autofree(enemy)
	enemy.global_position = Vector2(100, 0)  # Within default range
	enemy.initialize(1)
	
	# Let physics process run
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	turret.find_target()
	
	assert_not_null(turret.target, "Turret should find nearby enemy")


func test_turret_ignores_enemy_out_of_range():
	turret.can_fire = false
	
	# Create enemy far outside range
	var enemy = enemy_scene.instantiate()
	add_child_autofree(enemy)
	enemy.global_position = Vector2(10000, 0)  # Way outside range
	enemy.initialize(1)
	
	await get_tree().physics_frame
	
	turret.find_target()
	
	assert_null(turret.target, "Turret should not target distant enemy")


func test_turret_targets_closest_enemy():
	turret.can_fire = false
	
	# Create two enemies at different distances
	var enemy_near = enemy_scene.instantiate()
	add_child_autofree(enemy_near)
	enemy_near.global_position = Vector2(100, 0)
	enemy_near.initialize(1)
	
	var enemy_far = enemy_scene.instantiate()
	add_child_autofree(enemy_far)
	enemy_far.global_position = Vector2(200, 0)
	enemy_far.initialize(1)
	
	await get_tree().physics_frame
	
	turret.find_target()
	
	assert_eq(turret.target, enemy_near, "Turret should target closest enemy")


func test_turret_clears_target_when_no_enemies():
	turret.can_fire = false
	
	# First give it a target
	var enemy = enemy_scene.instantiate()
	add_child_autofree(enemy)
	enemy.global_position = Vector2(100, 0)
	enemy.initialize(1)
	
	await get_tree().physics_frame
	turret.find_target()
	assert_not_null(turret.target)
	
	# Remove enemy
	enemy.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	
	turret.find_target()
	
	assert_null(turret.target, "Target should be null when no enemies exist")


# =============================================================================
# FIRE COOLDOWN TEST (without actually firing)
# =============================================================================

func test_fire_cooldown_disables_can_fire():
	# Directly test the cooldown mechanism without firing projectiles
	assert_true(turret.can_fire, "Should start able to fire")

	# Simulate what happens when fire() sets can_fire = false
	turret.can_fire = false
	assert_false(turret.can_fire, "Should not be able to fire after firing")

	# Start the fire timer manually
	turret.fire_timer.start()

	# Wait for timer using a scene tree timer to avoid signal issues on cleanup
	var wait_time = turret.fire_timer.wait_time + 0.1
	await get_tree().create_timer(wait_time).timeout

	assert_true(turret.can_fire, "Should be able to fire after cooldown")


# =============================================================================
# DIFFICULTY SCALING TESTS
# =============================================================================

func test_turret_damage_reduced_on_hard():
	# Easy turret damage
	Globals.current_difficulty = GameEnums.Difficulty.EASY
	var easy_turret = turret_scene.instantiate()
	add_child_autofree(easy_turret)
	var easy_damage = easy_turret.current_damage
	
	# Hard turret damage
	Globals.current_difficulty = GameEnums.Difficulty.HARD
	var hard_turret = turret_scene.instantiate()
	add_child_autofree(hard_turret)
	var hard_damage = hard_turret.current_damage
	
	assert_lt(hard_damage, easy_damage, "Hard mode turrets should deal less damage")


# =============================================================================
# ATTACK STYLE SELECTION TESTS
# =============================================================================

func test_normal_turret_uses_projectile_attack():
	var normal_turret = turret_scene.instantiate()
	normal_turret.turret_type = "normal"
	add_child_autofree(normal_turret)
	
	var turret_def = TurretRegistry.get_type("normal")
	var attack_styles = turret_def["attack_styles"]
	
	assert_true(GameEnums.AttackStyle.PROJECTILE in attack_styles, "Normal turret should have PROJECTILE attack style")


func test_sniper_turret_uses_instant_attack():
	var sniper_turret = turret_scene.instantiate()
	sniper_turret.turret_type = "sniper"
	add_child_autofree(sniper_turret)
	
	var turret_def = TurretRegistry.get_type("sniper")
	var attack_styles = turret_def["attack_styles"]
	
	assert_true(GameEnums.AttackStyle.INSTANT in attack_styles, "Sniper turret should have INSTANT attack style")


func test_shock_turret_uses_aoe_attack():
	var shock_turret = turret_scene.instantiate()
	shock_turret.turret_type = "shock"
	add_child_autofree(shock_turret)
	
	var turret_def = TurretRegistry.get_type("shock")
	var attack_styles = turret_def["attack_styles"]
	
	assert_true(GameEnums.AttackStyle.AOE in attack_styles, "Shock turret should have AOE attack style")


func test_tesla_turret_uses_chain_attack():
	var tesla_turret = turret_scene.instantiate()
	tesla_turret.turret_type = "tesla"
	add_child_autofree(tesla_turret)
	
	var turret_def = TurretRegistry.get_type("tesla")
	var attack_styles = turret_def["attack_styles"]
	
	assert_true(GameEnums.AttackStyle.CHAIN in attack_styles, "Tesla turret should have CHAIN attack style")


func test_fire_turret_has_fire_damage_type():
	var fire_turret = turret_scene.instantiate()
	fire_turret.turret_type = "fire"
	add_child_autofree(fire_turret)
	
	var turret_def = TurretRegistry.get_type("fire")
	var damage_types = turret_def["damage_types"]
	
	assert_true(GameEnums.DamageType.FIRE in damage_types, "Fire turret should have FIRE damage type")


func test_plasma_turret_has_plasma_damage_type():
	var plasma_turret = turret_scene.instantiate()
	plasma_turret.turret_type = "plasma"
	add_child_autofree(plasma_turret)
	
	var turret_def = TurretRegistry.get_type("plasma")
	var damage_types = turret_def["damage_types"]
	
	assert_true(GameEnums.DamageType.PLASMA in damage_types, "Plasma turret should have PLASMA damage type")


# =============================================================================
# FIRING MECHANISM TESTS
# =============================================================================

func test_projectile_turret_spawns_projectile():
	watch_signals(Events)
	
	var normal_turret = turret_scene.instantiate()
	normal_turret.turret_type = "normal"
	add_child_autofree(normal_turret)
	normal_turret.global_position = Vector2.ZERO
	
	# Create enemy in range
	var enemy = enemy_scene.instantiate()
	add_child_autofree(enemy)
	enemy.global_position = Vector2(100, 0)
	enemy.initialize(1)
	
	await get_tree().physics_frame
	
	# Give turret a target
	normal_turret.target = enemy
	
	# Count Area2D nodes before (projectiles are Area2D)
	var scene_root = get_tree().current_scene if get_tree().current_scene else get_tree().root
	var projectiles_before = scene_root.get_children().filter(func(n): return n is Area2D).size()
	
	# Fire
	normal_turret.fire()
	
	await get_tree().physics_frame
	
	# Check projectile was spawned
	var projectiles_after = scene_root.get_children().filter(func(n): return n is Area2D).size()
	assert_gt(projectiles_after, projectiles_before, "Projectile turret should spawn a projectile")
	
	# Check signal emitted
	assert_signal_emitted(Events, "turret_fired", "Should emit turret_fired signal")


func test_instant_turret_damages_target_immediately():
	var sniper_turret = turret_scene.instantiate()
	sniper_turret.turret_type = "sniper"
	add_child_autofree(sniper_turret)
	sniper_turret.global_position = Vector2.ZERO
	
	# Create enemy in range
	var enemy = enemy_scene.instantiate()
	add_child_autofree(enemy)
	enemy.global_position = Vector2(100, 0)
	enemy.initialize(1)
	
	await get_tree().physics_frame
	
	sniper_turret.target = enemy
	var initial_health = enemy.current_health
	
	# Fire instant attack
	sniper_turret._fire_instant()
	
	await get_tree().physics_frame
	
	# Enemy should have taken damage
	assert_lt(enemy.current_health, initial_health, "Instant attack should damage enemy immediately")


func test_aoe_turret_hits_multiple_enemies():
	var shock_turret = turret_scene.instantiate()
	shock_turret.turret_type = "shock"
	add_child_autofree(shock_turret)
	shock_turret.global_position = Vector2.ZERO
	
	# Create multiple enemies in range
	var enemy1 = enemy_scene.instantiate()
	add_child_autofree(enemy1)
	enemy1.global_position = Vector2(50, 0)
	enemy1.initialize(1)
	
	var enemy2 = enemy_scene.instantiate()
	add_child_autofree(enemy2)
	enemy2.global_position = Vector2(-50, 0)
	enemy2.initialize(1)
	
	var enemy3 = enemy_scene.instantiate()
	add_child_autofree(enemy3)
	enemy3.global_position = Vector2(0, 50)
	enemy3.initialize(1)
	
	await get_tree().physics_frame
	
	var initial_health1 = enemy1.current_health
	var initial_health2 = enemy2.current_health
	var _initial_health3 = enemy3.current_health
	
	# Fire AOE pulse
	shock_turret._fire_aoe_pulse()
	
	await get_tree().physics_frame
	
	# All enemies in range should be damaged
	assert_lt(enemy1.current_health, initial_health1, "Enemy 1 should be damaged by AOE")
	assert_lt(enemy2.current_health, initial_health2, "Enemy 2 should be damaged by AOE")
	assert_lt(enemy3.current_health, _initial_health3, "Enemy 3 should be damaged by AOE")


func test_aoe_turret_applies_slow_effect():
	var shock_turret = turret_scene.instantiate()
	shock_turret.turret_type = "shock"
	add_child_autofree(shock_turret)
	shock_turret.global_position = Vector2.ZERO
	
	# Disable automatic firing to control when damage is applied
	shock_turret.can_fire = false
	
	# Create enemy in range
	var enemy = enemy_scene.instantiate()
	add_child_autofree(enemy)
	enemy.global_position = Vector2(50, 0)
	enemy.initialize(1)
	
	await get_tree().physics_frame
	
	var _initial_speed = enemy.speed
	var _initial_health = enemy.current_health
	
	# Fire AOE pulse - this should apply both damage and slow effect
	shock_turret._fire_aoe_pulse()
	
	# Check that enemy is still alive (didn't die from one hit)
	assert_false(enemy.is_dying, "Enemy should survive a single AOE pulse to test slow effect")
	
	# Check if slow effect was applied - enemy should have active status effects
	var has_slow = not enemy.active_effects.is_empty()
	
	assert_true(has_slow, "Shock turret should apply slow effect to enemies")


func test_chain_lightning_chains_between_enemies():
	watch_signals(Events)
	
	var tesla_turret = turret_scene.instantiate()
	tesla_turret.turret_type = "tesla"
	add_child_autofree(tesla_turret)
	tesla_turret.global_position = Vector2.ZERO
	
	# Create multiple enemies in chain range
	var enemy1 = enemy_scene.instantiate()
	add_child_autofree(enemy1)
	enemy1.global_position = Vector2(100, 0)
	enemy1.initialize(1)
	
	var enemy2 = enemy_scene.instantiate()
	add_child_autofree(enemy2)
	enemy2.global_position = Vector2(200, 0)
	enemy2.initialize(1)
	
	var enemy3 = enemy_scene.instantiate()
	add_child_autofree(enemy3)
	enemy3.global_position = Vector2(300, 0)
	enemy3.initialize(1)
	
	await get_tree().physics_frame
	
	tesla_turret.target = enemy1
	
	var initial_health1 = enemy1.current_health
	var initial_health2 = enemy2.current_health
	var initial_health3 = enemy3.current_health
	
	# Fire chain lightning
	tesla_turret._fire_chain()
	
	await get_tree().physics_frame
	
	# First enemy should definitely be hit
	assert_lt(enemy1.current_health, initial_health1, "First enemy should be hit by chain lightning")
	
	# Second enemy should be chained to
	assert_lt(enemy2.current_health, initial_health2, "Second enemy should be hit by chain")
	
	# Third enemy may or may not be hit depending on chain_count
	# Check that chain_lightning_hit signal was emitted at least once
	assert_signal_emitted(Events, "chain_lightning_hit", "Chain lightning should emit signal")


func test_chain_lightning_damage_decays():
	var tesla_turret = turret_scene.instantiate()
	tesla_turret.turret_type = "tesla"
	add_child_autofree(tesla_turret)
	tesla_turret.global_position = Vector2.ZERO
	
	# Create enemies at increasing distances
	var enemy1 = enemy_scene.instantiate()
	add_child_autofree(enemy1)
	enemy1.global_position = Vector2(100, 0)
	enemy1.initialize(1)
	
	var enemy2 = enemy_scene.instantiate()
	add_child_autofree(enemy2)
	enemy2.global_position = Vector2(200, 0)
	enemy2.initialize(1)
	
	await get_tree().physics_frame
	
	tesla_turret.target = enemy1
	
	var initial_health1 = enemy1.current_health
	var initial_health2 = enemy2.current_health
	
	tesla_turret._fire_chain()
	
	await get_tree().physics_frame
	
	var damage1 = initial_health1 - enemy1.current_health
	var damage2 = initial_health2 - enemy2.current_health
	
	# Second target should take less damage due to chain_decay
	assert_gt(damage1, damage2, "Chain lightning damage should decay on subsequent targets")


# =============================================================================
# TARGETING STRATEGY TESTS
# =============================================================================

func test_sniper_targets_farthest_enemy():
	var sniper_turret = turret_scene.instantiate()
	sniper_turret.turret_type = "sniper"
	add_child_autofree(sniper_turret)
	sniper_turret.global_position = Vector2.ZERO
	
	# Create enemies at different distances (both within sniper's 500 range)
	var enemy_near = enemy_scene.instantiate()
	add_child_autofree(enemy_near)
	enemy_near.global_position = Vector2(100, 0)
	enemy_near.initialize(1)
	
	var enemy_far = enemy_scene.instantiate()
	add_child_autofree(enemy_far)
	enemy_far.global_position = Vector2(400, 0)
	enemy_far.initialize(1)
	
	# Wait for physics to settle
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	# Explicitly verify distances before testing
	var dist_near = sniper_turret.global_position.distance_to(enemy_near.global_position)
	var dist_far = sniper_turret.global_position.distance_to(enemy_far.global_position)
	
	assert_lt(dist_near, dist_far, "Test setup: near enemy should be closer than far enemy")
	
	sniper_turret.find_target()
	
	# Sniper has "farthest" targeting strategy - should target the farther enemy
	assert_not_null(sniper_turret.target, "Sniper should find a target")
	if sniper_turret.target:
		var target_dist = sniper_turret.global_position.distance_to(sniper_turret.target.global_position)
		# Target distance should be closer to far enemy distance than near enemy distance
		assert_almost_eq(target_dist, dist_far, 1.0, "Sniper should target the farther enemy")


func test_normal_turret_targets_nearest_enemy():
	var normal_turret = turret_scene.instantiate()
	normal_turret.turret_type = "normal"
	add_child_autofree(normal_turret)
	normal_turret.global_position = Vector2.ZERO
	
	# Create enemies at different distances
	var enemy_near = enemy_scene.instantiate()
	add_child_autofree(enemy_near)
	enemy_near.global_position = Vector2(80, 0)
	enemy_near.initialize(1)
	
	var enemy_far = enemy_scene.instantiate()
	add_child_autofree(enemy_far)
	enemy_far.global_position = Vector2(150, 0)
	enemy_far.initialize(1)
	
	await get_tree().physics_frame
	
	normal_turret.find_target()
	
	# Normal turret defaults to nearest targeting
	assert_eq(normal_turret.target, enemy_near, "Normal turret should target nearest enemy in range")
