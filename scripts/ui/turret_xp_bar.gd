class_name TurretXpBar
extends ProgressBar

## Consistent, high-contrast XP meter for the reward recap and turret inspection.
func _init() -> void:
	custom_minimum_size.y = 26
	show_percentage = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := StyleBoxFlat.new()
	track.bg_color = UiPalette.PANEL_HI
	track.border_color = UiPalette.TEAL
	track.set_border_width_all(1)
	track.set_corner_radius_all(4)
	add_theme_stylebox_override("background", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiPalette.TEAL_HI
	fill.set_corner_radius_all(4)
	add_theme_stylebox_override("fill", fill)

func show_progress(level: int, xp: int) -> void:
	max_value = TurretProgression.cost_to_next(level)
	value = xp
