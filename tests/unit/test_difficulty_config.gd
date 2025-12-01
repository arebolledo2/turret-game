extends GutTest

# =============================================================================
# Unit tests for difficulty configuration validation
# Ensures all difficulties have required keys and valid values
# =============================================================================

const REQUIRED_KEYS := [
	"name",
	"description",
	"enemy_health_mult",
	"enemy_speed_mult",
	"enemy_damage_mult",
	"enemy_count_mult",
	"enemy_hp_scale_per_wave",
	"enemy_speed_scale_per_wave",
	"player_health_mult",
	"turret_damage_mult",
]

func before_each() -> void:
	Globals.reset_stats()


# =============================================================================
# CONFIGURATION VALIDATION
# =============================================================================

func test_all_difficulties_exist():
	assert_has(Globals.DIFFICULTY_CONFIG, Globals.Difficulty.EASY, "EASY should exist")
	assert_has(Globals.DIFFICULTY_CONFIG, Globals.Difficulty.MEDIUM, "MEDIUM should exist")
	assert_has(Globals.DIFFICULTY_CONFIG, Globals.Difficulty.HARD, "HARD should exist")


func test_all_difficulties_have_required_keys():
	for difficulty in Globals.DIFFICULTY_CONFIG.keys():
		var config = Globals.DIFFICULTY_CONFIG[difficulty]
		for key in REQUIRED_KEYS:
			assert_has(config, key, "Difficulty %s missing key: %s" % [difficulty, key])


func test_all_multipliers_are_positive():
	for difficulty in Globals.DIFFICULTY_CONFIG.keys():
		var config = Globals.DIFFICULTY_CONFIG[difficulty]
		
		assert_gt(config["enemy_health_mult"], 0.0, "enemy_health_mult must be positive")
		assert_gt(config["enemy_speed_mult"], 0.0, "enemy_speed_mult must be positive")
		assert_gt(config["enemy_damage_mult"], 0.0, "enemy_damage_mult must be positive")
		assert_gt(config["enemy_count_mult"], 0.0, "enemy_count_mult must be positive")
		assert_gt(config["player_health_mult"], 0.0, "player_health_mult must be positive")
		assert_gt(config["turret_damage_mult"], 0.0, "turret_damage_mult must be positive")


func test_scaling_factors_greater_than_one():
	# Wave scaling should increase stats, so multipliers > 1
	for difficulty in Globals.DIFFICULTY_CONFIG.keys():
		var config = Globals.DIFFICULTY_CONFIG[difficulty]
		
		assert_gt(config["enemy_hp_scale_per_wave"], 1.0, 
			"HP scaling must be > 1 for progression")


func test_difficulty_names_are_strings():
	for difficulty in Globals.DIFFICULTY_CONFIG.keys():
		var config = Globals.DIFFICULTY_CONFIG[difficulty]
		assert_typeof(config["name"], TYPE_STRING, "name should be a string")
		assert_typeof(config["description"], TYPE_STRING, "description should be a string")


# =============================================================================
# DIFFICULTY PROGRESSION (Easy < Medium < Hard)
# =============================================================================

func test_enemy_health_mult_increases_with_difficulty():
	var easy = Globals.DIFFICULTY_CONFIG[Globals.Difficulty.EASY]["enemy_health_mult"]
	var medium = Globals.DIFFICULTY_CONFIG[Globals.Difficulty.MEDIUM]["enemy_health_mult"]
	var hard = Globals.DIFFICULTY_CONFIG[Globals.Difficulty.HARD]["enemy_health_mult"]
	
	assert_lte(easy, medium, "Easy should have <= enemy health mult than Medium")
	assert_lte(medium, hard, "Medium should have <= enemy health mult than Hard")


func test_enemy_count_mult_increases_with_difficulty():
	var easy = Globals.DIFFICULTY_CONFIG[Globals.Difficulty.EASY]["enemy_count_mult"]
	var medium = Globals.DIFFICULTY_CONFIG[Globals.Difficulty.MEDIUM]["enemy_count_mult"]
	var hard = Globals.DIFFICULTY_CONFIG[Globals.Difficulty.HARD]["enemy_count_mult"]
	
	assert_lte(easy, medium, "Easy should have <= enemy count mult than Medium")
	assert_lte(medium, hard, "Medium should have <= enemy count mult than Hard")


func test_player_health_mult_decreases_with_difficulty():
	var easy = Globals.DIFFICULTY_CONFIG[Globals.Difficulty.EASY]["player_health_mult"]
	var hard = Globals.DIFFICULTY_CONFIG[Globals.Difficulty.HARD]["player_health_mult"]
	
	assert_gte(easy, hard, "Easy should have >= player health mult than Hard")


# =============================================================================
# SET/GET DIFFICULTY
# =============================================================================

func test_set_difficulty():
	Globals.set_difficulty(Globals.Difficulty.HARD)
	assert_eq(Globals.current_difficulty, Globals.Difficulty.HARD)


func test_get_difficulty_config_returns_correct_config():
	Globals.current_difficulty = Globals.Difficulty.MEDIUM
	var config = Globals.get_difficulty_config()
	
	assert_eq(config["name"], "Medium", "Should return Medium config")


func test_get_difficulty_name():
	Globals.current_difficulty = Globals.Difficulty.HARD
	var name = Globals.get_difficulty_name()
	
	assert_eq(name, "Hard", "Should return 'Hard'")
