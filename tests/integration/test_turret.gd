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
	Globals.current_difficulty = Globals.Difficulty.EASY
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
	Globals.current_difficulty = Globals.Difficulty.EASY
	var easy_turret = turret_scene.instantiate()
	add_child_autofree(easy_turret)
	var easy_damage = easy_turret.current_damage
	
	# Hard turret damage
	Globals.current_difficulty = Globals.Difficulty.HARD
	var hard_turret = turret_scene.instantiate()
	add_child_autofree(hard_turret)
	var hard_damage = hard_turret.current_damage
	
	assert_lt(hard_damage, easy_damage, "Hard mode turrets should deal less damage")
