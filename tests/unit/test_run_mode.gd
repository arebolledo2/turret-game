extends GutTest

func test_default_mode_is_survive() -> void:
	assert_eq(RunConfig.new().mode, RunConfig.MODE_SURVIVE)

func test_mode_argument_parses() -> void:
	assert_eq(RunConfig.from_args(PackedStringArray(["--mode=core"])).mode, RunConfig.MODE_CORE)
	assert_eq(RunConfig.from_args(PackedStringArray(["--mode=CORE"])).mode, RunConfig.MODE_CORE)

func test_unknown_mode_falls_back_to_survive() -> void:
	assert_eq(RunConfig.from_args(PackedStringArray(["--mode=banana"])).mode, RunConfig.MODE_SURVIVE)

func test_flag_is_an_experiment_off_in_release() -> void:
	FeatureFlagService.reset_state()
	assert_true(FeatureFlagService.is_enabled(FeatureFlagService.MODE_PROTECT_CORE))
	FeatureFlagService.apply_preset("release")
	assert_false(FeatureFlagService.is_enabled(FeatureFlagService.MODE_PROTECT_CORE))
	FeatureFlagService.reset_state()
