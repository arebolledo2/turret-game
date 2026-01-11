class_name UIHelpers
extends RefCounted

## General UI formatting and navigation helpers

const _BASE_FONT = preload("res://assets/fonts/NunitoSans-VariableFont.ttf")
static var MAIN_FONT: FontVariation = _create_medium_font()

static func _create_medium_font() -> FontVariation:
	var font_var := FontVariation.new()
	font_var.base_font = _BASE_FONT
	font_var.variation_opentype = {"wght": 500}
	return font_var

## Format a stat with base and modified values
## Returns Dictionary with text and color for display
static func format_stat_with_modifier(
	stat_name: String,
	base_value: float,
	modified_value: float,
	format_string: String = "%.1f",
	is_higher_better: bool = true
) -> Dictionary:
	var has_change := not is_equal_approx(base_value, modified_value)
	var text: String
	var color := Color.WHITE

	if has_change:
		var diff := modified_value - base_value
		var diff_sign := "+" if diff > 0 else ""
		text = "%s: %s (%s%s)" % [
			stat_name,
			format_string % modified_value,
			diff_sign,
			format_string % diff
		]
		var is_improved := (modified_value > base_value) == is_higher_better
		color = Color.GREEN if is_improved else Color.RED
	else:
		text = "%s: %s" % [stat_name, format_string % modified_value]

	return {"text": text, "color": color}


## Sets up focus neighbors for a row of buttons
## Connects left/right within the row, and up/down to specified targets
static func setup_focus_neighbors(buttons: Array[Button], up_target: Control, down_target: Control) -> void:
	if buttons.is_empty():
		return

	for i in range(buttons.size()):
		var btn := buttons[i]

		# Left neighbor
		if i > 0:
			btn.focus_neighbor_left = buttons[i - 1].get_path()

		# Right neighbor
		if i < buttons.size() - 1:
			btn.focus_neighbor_right = buttons[i + 1].get_path()

		# Up neighbor
		if up_target and is_instance_valid(up_target):
			btn.focus_neighbor_top = up_target.get_path()

		# Down neighbor
		if down_target and is_instance_valid(down_target):
			btn.focus_neighbor_bottom = down_target.get_path()


## Format a float as a percentage string
static func format_percentage(value: float) -> String:
	return "%.0f%%" % (value * 100.0)
