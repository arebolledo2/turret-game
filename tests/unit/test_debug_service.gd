extends GutTest

# =============================================================================
# Unit tests for DebugService
# Tests compile-time category flags, logging methods, and helper functions
# =============================================================================


# =============================================================================
# CATEGORY FLAGS
# =============================================================================

func test_enabled_flag_exists() -> void:
	assert_true(DebugService.ENABLED is bool, "ENABLED should be a bool constant")


func test_entity_flag_exists() -> void:
	assert_true(DebugService.ENTITY is bool, "ENTITY should be a bool constant")


func test_combat_flag_exists() -> void:
	assert_true(DebugService.COMBAT is bool, "COMBAT should be a bool constant")


func test_ai_flag_exists() -> void:
	assert_true(DebugService.AI is bool, "AI should be a bool constant")


func test_arena_flag_exists() -> void:
	assert_true(DebugService.ARENA is bool, "ARENA should be a bool constant")


func test_ui_flag_exists() -> void:
	assert_true(DebugService.UI is bool, "UI should be a bool constant")


func test_systems_flag_exists() -> void:
	assert_true(DebugService.SYSTEMS is bool, "SYSTEMS should be a bool constant")


func test_validation_flag_exists() -> void:
	assert_true(DebugService.VALIDATION is bool, "VALIDATION should be a bool constant")


func test_validation_enabled_by_default() -> void:
	assert_true(DebugService.VALIDATION, "VALIDATION should be enabled by default")


# =============================================================================
# IS_ENABLED HELPER
# =============================================================================

func test_is_enabled_returns_true_for_enabled_category() -> void:
	if DebugService.ENABLED:
		assert_eq(DebugService.is_enabled(true), true,
			"is_enabled should return true when master and category are both true")


func test_is_enabled_returns_false_for_disabled_category() -> void:
	assert_eq(DebugService.is_enabled(false), false,
		"is_enabled should return false when category is false")


# =============================================================================
# LOG METHODS (verify they don't crash)
# =============================================================================

func test_log_with_single_message_does_not_crash() -> void:
	# Should not throw regardless of category state
	DebugService.log(DebugService.VALIDATION, "Test message")
	pass_test("log() with single message did not crash")


func test_log_with_multiple_args_does_not_crash() -> void:
	DebugService.log(DebugService.VALIDATION, "Value: ", 42, " at pos: ", Vector2(1, 2))
	pass_test("log() with multiple args did not crash")


func test_log_with_disabled_category_does_not_crash() -> void:
	DebugService.log(false, "This should be suppressed")
	pass_test("log() with disabled category did not crash")


func test_warn_does_not_crash() -> void:
	DebugService.warn(DebugService.VALIDATION, "Test warning")
	pass_test("warn() did not crash")


func test_warn_with_multiple_args_does_not_crash() -> void:
	DebugService.warn(DebugService.VALIDATION, "Warning: ", "detail ", 123)
	pass_test("warn() with multiple args did not crash")


func test_error_does_not_crash() -> void:
	# Uses disabled category to avoid push_error() which GUT treats as test failure
	DebugService.error(false, "Test error")
	pass_test("error() did not crash")


func test_error_with_multiple_args_does_not_crash() -> void:
	# Uses disabled category to avoid push_error() which GUT treats as test failure
	DebugService.error(false, "Error: ", "detail ", 456)
	pass_test("error() with multiple args did not crash")


# =============================================================================
# GET_STATUS HELPER
# =============================================================================

func test_get_status_returns_string() -> void:
	var status := DebugService.get_status()
	assert_true(status is String, "get_status should return a string")
	assert_true(status.length() > 0, "get_status should return non-empty string")


func test_get_status_contains_category_names() -> void:
	var status := DebugService.get_status()
	if DebugService.ENABLED:
		assert_string_contains(status, "ENTITY", "Status should mention ENTITY category")
		assert_string_contains(status, "COMBAT", "Status should mention COMBAT category")
		assert_string_contains(status, "AI", "Status should mention AI category")
		assert_string_contains(status, "ARENA", "Status should mention ARENA category")
		assert_string_contains(status, "UI", "Status should mention UI category")
		assert_string_contains(status, "SYSTEMS", "Status should mention SYSTEMS category")
		assert_string_contains(status, "VALIDATION", "Status should mention VALIDATION category")


func test_get_status_shows_enabled_state() -> void:
	var status := DebugService.get_status()
	if DebugService.ENABLED:
		assert_string_contains(status, "ENABLED",
			"Status should indicate debug system is enabled")
	else:
		assert_string_contains(status, "DISABLED",
			"Status should indicate debug system is disabled")


# =============================================================================
# EDGE CASES
# =============================================================================

func test_log_with_null_variant_does_not_crash() -> void:
	DebugService.log(DebugService.VALIDATION, "Null test: ", null)
	pass_test("log() with null variant did not crash")


func test_log_with_empty_string_does_not_crash() -> void:
	DebugService.log(DebugService.VALIDATION, "")
	pass_test("log() with empty string did not crash")


func test_log_with_all_arg_slots_filled() -> void:
	DebugService.log(DebugService.VALIDATION, "a", "b", "c", "d", "e", "f", "g", "h", "i")
	pass_test("log() with all arg slots did not crash")
