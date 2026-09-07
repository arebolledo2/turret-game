extends GutTest

# =============================================================================
# Unit tests for FontSizes
# Tests font size constants, scaling, and helper methods
# =============================================================================

var font_sizes: Node


func before_all() -> void:
	font_sizes = get_node("/root/FontSizes")


# =============================================================================
# HEADING CONSTANTS
# =============================================================================

func test_heading_sizes_are_descending() -> void:
	assert_gt(FontSizes.HEADING_1, FontSizes.HEADING_2,
		"HEADING_1 should be larger than HEADING_2")
	assert_gt(FontSizes.HEADING_2, FontSizes.HEADING_3,
		"HEADING_2 should be larger than HEADING_3")
	assert_gt(FontSizes.HEADING_3, FontSizes.HEADING_4,
		"HEADING_3 should be larger than HEADING_4")


func test_heading_1_base_size() -> void:
	assert_eq(FontSizes.HEADING_1, 64, "HEADING_1 should be 64px at 1080p")


func test_heading_2_base_size() -> void:
	assert_eq(FontSizes.HEADING_2, 42, "HEADING_2 should be 42px at 1080p")


func test_heading_3_base_size() -> void:
	assert_eq(FontSizes.HEADING_3, 32, "HEADING_3 should be 32px at 1080p")


func test_heading_4_base_size() -> void:
	assert_eq(FontSizes.HEADING_4, 24, "HEADING_4 should be 24px at 1080p")


# =============================================================================
# BODY TEXT CONSTANTS
# =============================================================================

func test_body_sizes_are_descending() -> void:
	assert_gt(FontSizes.BODY, FontSizes.BODY_SMALL,
		"BODY should be larger than BODY_SMALL")
	assert_gt(FontSizes.BODY_SMALL, FontSizes.BODY_TINY,
		"BODY_SMALL should be larger than BODY_TINY")
	assert_gte(FontSizes.BODY_TINY, FontSizes.CAPTION,
		"BODY_TINY should be >= CAPTION")


func test_body_base_size() -> void:
	assert_eq(FontSizes.BODY, 18, "BODY should be 18px at 1080p")


func test_caption_is_smallest() -> void:
	assert_eq(FontSizes.CAPTION, 14, "CAPTION should be 14px at 1080p")


# =============================================================================
# COMBAT FEEDBACK CONSTANTS
# =============================================================================

func test_damage_crit_larger_than_normal() -> void:
	assert_gt(FontSizes.DAMAGE_CRIT, FontSizes.DAMAGE_NORMAL,
		"Crit damage text should be larger than normal damage text")


# =============================================================================
# BUTTON SIZE CONSTANTS
# =============================================================================

func test_button_sizes_are_ordered() -> void:
	assert_gt(FontSizes.BUTTON_XLARGE, FontSizes.BUTTON_LARGE,
		"BUTTON_XLARGE should be larger than BUTTON_LARGE")
	assert_gt(FontSizes.BUTTON_LARGE, FontSizes.BUTTON_MEDIUM,
		"BUTTON_LARGE should be larger than BUTTON_MEDIUM")


# =============================================================================
# ICON SIZE CONSTANTS
# =============================================================================

func test_icon_sizes_are_ordered() -> void:
	assert_gt(FontSizes.ICON_LARGE, FontSizes.ICON_MEDIUM,
		"ICON_LARGE should be larger than ICON_MEDIUM")
	assert_gt(FontSizes.ICON_MEDIUM, FontSizes.ICON_SMALL,
		"ICON_MEDIUM should be larger than ICON_SMALL")
	assert_gt(FontSizes.ICON_SMALL, FontSizes.ICON_BADGE,
		"ICON_SMALL should be larger than ICON_BADGE")


# =============================================================================
# GET_SCALED METHOD
# =============================================================================

func test_get_scaled_returns_integer() -> void:
	var result = font_sizes.get_scaled(18)
	assert_true(result is int, "get_scaled should return int")


func test_get_scaled_minimum_is_8() -> void:
	var result = font_sizes.get_scaled(1)
	assert_gte(result, 8, "Minimum scaled font should be 8px")


func test_get_scaled_proportional() -> void:
	var small = font_sizes.get_scaled(12)
	var large = font_sizes.get_scaled(24)
	assert_gt(large, small,
		"Larger base size should produce larger scaled result")


# =============================================================================
# GET_HEADING METHOD
# =============================================================================

func test_get_heading_level_1() -> void:
	assert_eq(font_sizes.get_heading(1), FontSizes.HEADING_1,
		"Level 1 should return HEADING_1")


func test_get_heading_level_2() -> void:
	assert_eq(font_sizes.get_heading(2), FontSizes.HEADING_2,
		"Level 2 should return HEADING_2")


func test_get_heading_level_3() -> void:
	assert_eq(font_sizes.get_heading(3), FontSizes.HEADING_3,
		"Level 3 should return HEADING_3")


func test_get_heading_level_4() -> void:
	assert_eq(font_sizes.get_heading(4), FontSizes.HEADING_4,
		"Level 4 should return HEADING_4")


func test_get_heading_invalid_level_returns_body() -> void:
	assert_eq(font_sizes.get_heading(0), FontSizes.BODY,
		"Invalid level 0 should return BODY")
	assert_eq(font_sizes.get_heading(5), FontSizes.BODY,
		"Invalid level 5 should return BODY")
	assert_eq(font_sizes.get_heading(-1), FontSizes.BODY,
		"Negative level should return BODY")


# =============================================================================
# GET_ICON_SIZE METHOD
# =============================================================================

func test_get_icon_size_large() -> void:
	assert_eq(font_sizes.get_icon_size("large"), FontSizes.ICON_LARGE,
		"'large' should return ICON_LARGE")


func test_get_icon_size_medium() -> void:
	assert_eq(font_sizes.get_icon_size("medium"), FontSizes.ICON_MEDIUM,
		"'medium' should return ICON_MEDIUM")


func test_get_icon_size_small() -> void:
	assert_eq(font_sizes.get_icon_size("small"), FontSizes.ICON_SMALL,
		"'small' should return ICON_SMALL")


func test_get_icon_size_badge() -> void:
	assert_eq(font_sizes.get_icon_size("badge"), FontSizes.ICON_BADGE,
		"'badge' should return ICON_BADGE")


func test_get_icon_size_unknown_returns_medium() -> void:
	assert_eq(font_sizes.get_icon_size("unknown"), FontSizes.ICON_MEDIUM,
		"Unknown category should return ICON_MEDIUM")
	assert_eq(font_sizes.get_icon_size(""), FontSizes.ICON_MEDIUM,
		"Empty category should return ICON_MEDIUM")


func before_each() -> void:
	TestHelpers.reset_all_services()
