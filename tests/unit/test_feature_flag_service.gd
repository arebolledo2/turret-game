extends GutTest

## Unit coverage for the centralized feature-flag contract.

func before_each() -> void:
	TestHelpers.reset_all_services()
	FeatureFlagService.reset_state()


func after_each() -> void:
	FeatureFlagService.reset_state()


func test_default_flags_are_available() -> void:
	assert_false(FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION))


func test_flags_can_be_toggled_and_reset() -> void:
	assert_true(FeatureFlagService.set_enabled(FeatureFlagService.REDUCED_MOTION, true))
	assert_true(FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION))
	assert_true(FeatureFlagService.toggle(FeatureFlagService.REDUCED_MOTION))
	assert_false(FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION))

	FeatureFlagService.set_enabled(FeatureFlagService.REDUCED_MOTION, true)
	FeatureFlagService.reset_state()
	assert_false(FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION))


func test_unknown_flag_is_rejected() -> void:
	assert_false(FeatureFlagService.is_known_flag("missing_flag"))
	assert_false(FeatureFlagService.set_enabled("missing_flag", true))
	assert_false(FeatureFlagService.is_enabled("missing_flag"))
