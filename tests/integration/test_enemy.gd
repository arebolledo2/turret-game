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
	GameStateService.reset_state()
	DifficultyService.set_difficulty(GameEnums.Difficulty.EASY)
	GameStateService.is_game_active = true
	
	enemy = enemy_scene.instantiate()
	add_child_autofree(enemy)


# =============================================================================
# INITIALIZATION TESTS
# =============================================================================

func test_enemy_added_to_group():
	assert_true(enemy.is_in_group("enemies"), "Enemy should be in 'enemies' group")


func test_enemy_initializes_with_wave_scaling():
	enemy.initialize(5)

	var expected_hp = EnemyRegistry.get_stats_for_wave("basic", 5, DifficultyService.get_difficulty_config())["health"]

	assert_eq(enemy.max_health, expected_hp, "Health should match wave 5 scaling")
	assert_eq(enemy.current_health, enemy.max_health, "Current health should equal max")


func test_enemy_contact_damage_from_globals():
	enemy.initialize(1)
	
	var expected_damage = GameConstants.ENEMY_BASE_CONTACT_DAMAGE
	assert_eq(enemy.contact_damage, expected_damage, "Contact damage should match Globals")


func test_enemy_harder_on_hard_difficulty():
	DifficultyService.set_difficulty(GameEnums.Difficulty.EASY)
	enemy.initialize(3)
	var easy_hp = enemy.max_health
	
	# Create new enemy for hard mode
	var hard_enemy = enemy_scene.instantiate()
	add_child_autofree(hard_enemy)
	DifficultyService.set_difficulty(GameEnums.Difficulty.HARD)
	hard_enemy.initialize(3)
	
	assert_gt(hard_enemy.max_health, easy_hp, "Hard enemies should have more health")


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
	assert_gt(enemy.current_health, 0.0, "Health should remain positive")


# =============================================================================
# DEATH TESTS
# =============================================================================

func test_enemy_emits_killed_signal_on_death():
	watch_signals(Events)
	enemy.initialize(1)
	
	enemy.take_damage(1000) # Overkill to ensure death
	
	assert_signal_emitted(Events, "enemy_killed", "Should emit enemy_killed signal")


func test_enemy_emits_scrap_dropped_signal_on_death():
	watch_signals(Events)
	enemy.initialize(1)

	enemy.take_damage(1000)

	assert_signal_emitted(Events, "scrap_dropped", "Should emit scrap_dropped signal")


func test_enemy_increments_kill_counter():
	GameStateService.total_kills = 0
	enemy.initialize(1)
	
	enemy.take_damage(1000)
	
	assert_eq(GameStateService.total_kills, 1, "Kill counter should increment")


func test_multiple_kills_increment_counter():
	GameStateService.total_kills = 0
	
	for i in range(3):
		var e = enemy_scene.instantiate()
		add_child_autofree(e)
		e.initialize(1)
		e.take_damage(1000)
	
	assert_eq(GameStateService.total_kills, 3, "Kill counter should be 3 after 3 kills")


# =============================================================================
# SCRAP VALUE TESTS
# =============================================================================

func test_enemy_has_scrap_value():
	assert_gt(enemy.scrap_value, 0, "Enemy should have positive scrap value")


func test_scrap_dropped_signal_has_correct_value():
	watch_signals(Events)
	var expected_scrap = enemy.scrap_value
	enemy.initialize(1)

	enemy.take_damage(1000)

	var signal_params = get_signal_parameters(Events, "scrap_dropped")
	# signal_params[1] is the scrap amount (second parameter)
	assert_eq(signal_params[1], expected_scrap, "Scrap dropped should match enemy's scrap_value")


# =============================================================================
# DEFENSE MODE AGGRO TESTS
# =============================================================================

func test_enemy_switches_target_to_player_when_in_aggro_range():
	"""Test that enemies in defense mode switch from defense target to player when close."""
	# Set up defense mode
	GameModeService.set_mode(GameEnums.GameMode.TECH_DEFENSE)
	
	# Create defense target and player mock
	var defense_target_scene = load("res://scenes/defense_target.tscn")
	var player_scene = load("res://scenes/player.tscn")
	
	var def_target = defense_target_scene.instantiate()
	def_target.global_position = Vector2(500, 500)
	add_child_autofree(def_target)
	
	# Start player FAR AWAY (beyond deaggro range of 600) so enemy starts targeting defense target
	var mock_player = player_scene.instantiate()
	mock_player.global_position = Vector2(2000, 2000) # Very far from any enemy
	add_child_autofree(mock_player)
	
	# Create enemy near defense target (far from player initially)
	var test_enemy = enemy_scene.instantiate()
	test_enemy.global_position = Vector2(400, 400) # Near defense target
	add_child_autofree(test_enemy)
	test_enemy.initialize(1)
	
	await wait_frames(2) # Let physics process
	
	# Initially should target defense target
	assert_eq(test_enemy.movement.player, test_enemy.movement.defense_target,
		"Enemy should initially target defense target")
	
	# Move player close to enemy (within 300 aggro range)
	mock_player.global_position = Vector2(500, 400) # 100 units from enemy at (400, 400)
	
	# Process movement to trigger aggro check
	test_enemy.movement.process(0.016, 1.0)
	
	# After processing, should have switched to player (within 300 units)
	assert_eq(test_enemy.movement.player, test_enemy.movement.player_character,
		"Enemy should switch to player when within aggro range")
	
	# Clean up
	GameModeService.set_mode(GameEnums.GameMode.SURVIVAL)


func test_enemy_deaggros_player_when_beyond_range():
	"""Test that enemies switch back to defense target when player moves away."""
	# Set up defense mode
	GameModeService.set_mode(GameEnums.GameMode.TECH_DEFENSE)
	
	# Create defense target and player mock
	var defense_target_scene = load("res://scenes/defense_target.tscn")
	var player_scene = load("res://scenes/player.tscn")
	
	var def_target = defense_target_scene.instantiate()
	def_target.global_position = Vector2(500, 500)
	add_child_autofree(def_target)
	
	var mock_player = player_scene.instantiate()
	mock_player.global_position = Vector2(2000, 2000) # Start FAR AWAY
	add_child_autofree(mock_player)
	
	# Create enemy near defense target (far from player initially)
	var test_enemy = enemy_scene.instantiate()
	test_enemy.global_position = Vector2(400, 400) # Near defense target
	add_child_autofree(test_enemy)
	test_enemy.initialize(1)
	
	await wait_frames(2)
	
	# Move player close and trigger aggro to player
	mock_player.global_position = Vector2(500, 400) # 100 units from enemy
	test_enemy.movement.process(0.016, 1.0)
	assert_eq(test_enemy.movement.player, test_enemy.movement.player_character,
		"Enemy should be targeting player")
	
	# Move player far away (beyond 600 deaggro range)
	mock_player.global_position = Vector2(1000, 1000) # ~1130 units from enemy
	
	# Process movement to trigger deaggro check
	test_enemy.movement.process(0.016, 1.0)
	
	# Should switch back to defense target
	assert_eq(test_enemy.movement.player, test_enemy.movement.defense_target,
		"Enemy should switch back to defense target when player beyond deaggro range")
	
	# Clean up
	GameModeService.set_mode(GameEnums.GameMode.SURVIVAL)
