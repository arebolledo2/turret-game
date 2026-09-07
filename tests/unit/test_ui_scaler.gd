extends GutTest

# =============================================================================
# Unit tests for UIScaler
# Tests scaling calculations, resolution handling, and utility methods
# =============================================================================

var ui_scaler: Node


func before_all() -> void:
	ui_scaler = get_node("/root/UIScaler")


# =============================================================================
# CONSTANTS
# =============================================================================

func test_base_resolution_is_1080p() -> void:
	assert_eq(UIScaler.BASE_WIDTH, 1920, "Base width should be 1920")
	assert_eq(UIScaler.BASE_HEIGHT, 1080, "Base height should be 1080")


func test_minimum_resolution_is_720p() -> void:
	assert_eq(UIScaler.MIN_WIDTH, 1280, "Min width should be 1280")
	assert_eq(UIScaler.MIN_HEIGHT, 720, "Min height should be 720")


# =============================================================================
# SCALE FACTOR
# =============================================================================

func test_scale_factor_is_positive() -> void:
	assert_gt(ui_scaler.scale_factor, 0.0, "Scale factor should be positive")


func test_scale_factor_is_reasonable_range() -> void:
	# Scale factor should be between 0.5x (720p) and 4x (4K+)
	assert_gte(ui_scaler.scale_factor, 0.5,
		"Scale factor should be at least 0.5")
	assert_lte(ui_scaler.scale_factor, 5.0,
		"Scale factor should be at most 5.0")


# =============================================================================
# SCALE METHOD
# =============================================================================

func test_scale_returns_scaled_value() -> void:
	var base_value := 100.0
	var result = ui_scaler.scale(base_value)
	var expected = base_value * ui_scaler.scale_factor
	assert_almost_eq(result, expected, 0.01,
		"scale() should multiply by scale factor")


func test_scale_zero_returns_zero() -> void:
	assert_almost_eq(ui_scaler.scale(0.0), 0.0, 0.001,
		"Scaling zero should return zero")


func test_scale_negative_value() -> void:
	var result = ui_scaler.scale(-50.0)
	assert_lt(result, 0.0, "Scaling negative value should return negative")


# =============================================================================
# SCALE_VEC METHOD
# =============================================================================

func test_scale_vec_scales_both_components() -> void:
	var base := Vector2(100, 200)
	var result = ui_scaler.scale_vec(base)
	assert_almost_eq(result.x, base.x * ui_scaler.scale_factor, 0.01,
		"X component should be scaled")
	assert_almost_eq(result.y, base.y * ui_scaler.scale_factor, 0.01,
		"Y component should be scaled")


func test_scale_vec_zero_returns_zero() -> void:
	var result = ui_scaler.scale_vec(Vector2.ZERO)
	assert_almost_eq(result.x, 0.0, 0.001, "Zero vector x should remain zero")
	assert_almost_eq(result.y, 0.0, 0.001, "Zero vector y should remain zero")


# =============================================================================
# SCALE_FONT METHOD
# =============================================================================

func test_scale_font_returns_integer() -> void:
	var result = ui_scaler.scale_font(18)
	assert_true(result is int, "scale_font should return int")


func test_scale_font_minimum_is_8() -> void:
	var result = ui_scaler.scale_font(1)
	assert_gte(result, 8, "Minimum font size should be 8px")


func test_scale_font_zero_returns_minimum() -> void:
	var result = ui_scaler.scale_font(0)
	assert_gte(result, 8, "Zero base size should return minimum 8px")


func test_scale_font_scales_proportionally() -> void:
	var small = ui_scaler.scale_font(12)
	var large = ui_scaler.scale_font(24)
	assert_gt(large, small, "Larger base size should produce larger scaled size")


func test_scale_font_common_sizes() -> void:
	# All common sizes should produce valid results
	var sizes := [14, 16, 18, 20, 24, 32, 42, 64]
	for base_size in sizes:
		var result = ui_scaler.scale_font(base_size)
		assert_gte(result, 8, "Font size %d should scale to at least 8" % base_size)


# =============================================================================
# VIEWPORT SIZE
# =============================================================================

func test_get_viewport_size_returns_valid() -> void:
	var size = ui_scaler.get_viewport_size()
	assert_gt(size.x, 0, "Viewport width should be positive")
	assert_gt(size.y, 0, "Viewport height should be positive")


func test_viewport_size_matches_actual() -> void:
	var size = ui_scaler.get_viewport_size()
	assert_eq(size, ui_scaler.viewport_size,
		"get_viewport_size should match stored viewport_size")


# =============================================================================
# MINIMUM RESOLUTION CHECK
# =============================================================================

func test_is_at_minimum_resolution_returns_bool() -> void:
	var result = ui_scaler.is_at_minimum_resolution()
	assert_true(result is bool, "Should return bool")


# =============================================================================
# SIGNAL
# =============================================================================

func test_scale_changed_signal_exists() -> void:
	assert_true(ui_scaler.has_signal("scale_changed"),
		"UIScaler should have scale_changed signal")


# =============================================================================
# EDGE CASES
# =============================================================================

func test_scale_very_large_value() -> void:
	var result = ui_scaler.scale(10000.0)
	assert_gt(result, 0.0, "Very large values should scale without issues")


func test_scale_font_very_large_base() -> void:
	var result = ui_scaler.scale_font(200)
	assert_gt(result, 100, "Very large font should scale to large result")


func before_each() -> void:
	TestHelpers.reset_all_services()
