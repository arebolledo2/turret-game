extends GutTest

# =============================================================================
# Integration tests for enemy.gd
# Tests enemy behavior, signals, and interactions
# =============================================================================

var enemy_scene: PackedScene
var enemy: Node2D


func before_all() -> void:
	enemy_scene = load("res://scenes/enemy.tscn")


func before_each() -> void:
	Globals.reset_stats()
	Globals.current_difficulty = Globals.Difficulty.EASY
	Globals.is_game_active = true
	
	enemy = enemy_scene.instantiate()
	add_child_autofree(enemy)


# =============================================================================
# INITIALIZATION TESTS
# =============================================================================

func test_enemy_added_to_group():
	assert_true(enemy.is_in_group("enemies"), "Enemy should be in 'enemies' group")


func test_enemy_initializes_with_wave_scaling():
	enemy.initialize(5)
	
	var expected_hp = Globals.get_enemy_health(5)
	var expected_speed = Globals.get_enemy_speed(5)
	
	assert_eq(enemy.max_health, expected_hp, "Health should match wave 5 scaling")
	assert_eq(enemy.speed, expected_speed, "Speed should match wave 5 scaling")
	assert_eq(enemy.current_health, enemy.max_health, "Current health should equal max")


func test_enemy_contact_damage_from_globals():
	enemy.initialize(1)
	
	var expected_damage = Globals.ENEMY_CONTACT_DAMAGE
	assert_eq(enemy.contact_damage, expected_damage, "Contact damage should match Globals")


func test_enemy_harder_on_hard_difficulty():
	Globals.current_difficulty = Globals.Difficulty.EASY
	enemy.initialize(3)
	var easy_hp = enemy.max_health
	var easy_speed = enemy.speed
	
	# Create new enemy for hard mode
	var hard_enemy = enemy_scene.instantiate()
	add_child_autofree(hard_enemy)
	Globals.current_difficulty = Globals.Difficulty.HARD
	hard_enemy.initialize(3)
	
	assert_gt(hard_enemy.max_health, easy_hp, "Hard enemies should have more health")
	assert_gt(hard_enemy.speed, easy_speed, "Hard enemies should be faster")


# =============================================================================
# DAMAGE TESTS
# =============================================================================

func test_enemy_takes_damage():
	enemy.initialize(1)
	var initial_hp = enemy.current_health
	
	enemy.take_damage(10)
	
	assert_eq(enemy.current_health, initial_hp - 10, "Health should decrease by damage amount")


func test_enemy_survives_partial_damage():
	enemy.initialize(1)
	enemy.take_damage(5)
	
	assert_true(is_instance_valid(enemy), "Enemy should survive partial damage")
	assert_gt(enemy.current_health, 0, "Health should remain positive")


# =============================================================================
# DEATH TESTS
# =============================================================================

func test_enemy_emits_killed_signal_on_death():
	watch_signals(Events)
	enemy.initialize(1)
	
	enemy.take_damage(1000)  # Overkill to ensure death
	
	assert_signal_emitted(Events, "enemy_killed", "Should emit enemy_killed signal")


func test_enemy_emits_xp_dropped_signal_on_death():
	watch_signals(Events)
	enemy.initialize(1)
	
	enemy.take_damage(1000)
	
	assert_signal_emitted(Events, "xp_dropped", "Should emit xp_dropped signal")


func test_enemy_increments_kill_counter():
	Globals.total_kills = 0
	enemy.initialize(1)
	
	enemy.take_damage(1000)
	
	assert_eq(Globals.total_kills, 1, "Kill counter should increment")


func test_multiple_kills_increment_counter():
	Globals.total_kills = 0
	
	for i in range(3):
		var e = enemy_scene.instantiate()
		add_child_autofree(e)
		e.initialize(1)
		e.take_damage(1000)
	
	assert_eq(Globals.total_kills, 3, "Kill counter should be 3 after 3 kills")


# =============================================================================
# XP VALUE TESTS
# =============================================================================

func test_enemy_has_xp_value():
	assert_gt(enemy.xp_value, 0, "Enemy should have positive XP value")


func test_xp_dropped_signal_has_correct_value():
	watch_signals(Events)
	var expected_xp = enemy.xp_value
	enemy.initialize(1)
	
	enemy.take_damage(1000)
	
	var signal_params = get_signal_parameters(Events, "xp_dropped")
	# signal_params[1] is the xp amount (second parameter)
	assert_eq(signal_params[1], expected_xp, "XP dropped should match enemy's xp_value")
