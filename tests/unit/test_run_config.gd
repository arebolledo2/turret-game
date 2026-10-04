extends GutTest

func test_defaults_match_the_twenty_wave_easy_run() -> void:
	var config := RunConfig.new()
	assert_eq(config.wave_limit, 20)
	assert_eq(config.difficulty, GameEnums.Difficulty.EASY)
	assert_eq(config.flag_preset, "")
	assert_eq(config.difficulty_name(), "Easy")


func test_slice_keeps_the_original_six_waves() -> void:
	assert_eq(RunConfig.slice().wave_limit, 6)


func test_difficulty_config_is_a_copy() -> void:
	var config := RunConfig.new()
	config.difficulty_config()["enemy_count_mult"] = 99.0
	assert_ne(DifficultyService.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]["enemy_count_mult"], 99.0)


func test_sanitize_clamps_wave_limit_and_drops_unknown_presets() -> void:
	var config := RunConfig.new()
	config.wave_limit = -5
	config.flag_preset = "nope"
	config.sanitize()
	assert_eq(config.wave_limit, 1)
	assert_eq(config.flag_preset, "")
	config.wave_limit = 100000
	assert_eq(config.sanitize().wave_limit, GameConstants.RUN_MAX_WAVE_LIMIT)


func test_from_args_parses_known_options_and_ignores_the_rest() -> void:
	var config := RunConfig.from_args(PackedStringArray(["--waves=8", "--difficulty=HARD", "--preset=all_experiments", "--control", "--waves"]))
	assert_eq(config.wave_limit, 8)
	assert_eq(config.difficulty, GameEnums.Difficulty.HARD)
	assert_eq(config.flag_preset, "all_experiments")
	assert_eq(RunConfig.from_args(PackedStringArray()).wave_limit, 20)
	assert_eq(RunConfig.from_args(PackedStringArray(["--waves=abc"])).wave_limit, 1, "Unparseable counts clamp to the minimum")
