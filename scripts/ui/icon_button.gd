class_name IconButton
extends Button

## Chamfered button with a leading icon and a short word. `primary` gives it the bright teal edge.
func setup(icon_name: String, label_text: String = "", primary: bool = false, icon_size: int = 28) -> IconButton:
	text = label_text
	icon = UiIcons.get_icon(icon_name)
	expand_icon = true
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	custom_minimum_size.y = maxf(custom_minimum_size.y, 56.0)
	add_theme_constant_override("icon_max_width", icon_size)
	add_theme_constant_override("h_separation", 12)
	add_theme_font_size_override("font_size", 24)
	var ink := Color.WHITE if primary else UiPalette.INK
	for slot in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		add_theme_color_override(slot, ink)
	for slot in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		add_theme_color_override(slot, ink)
	add_theme_color_override("font_disabled_color", Color(ink, .4))
	add_theme_color_override("icon_disabled_color", Color(ink, .4))
	var fill := Color("0e4447") if primary else UiPalette.PANEL
	var edge := UiPalette.TEAL_HI if primary else UiPalette.LINE
	var margin_x := 22.0
	add_theme_stylebox_override("normal", ChamferStyle.make(fill, edge, 10.0, margin_x, 8.0))
	add_theme_stylebox_override("hover", ChamferStyle.make(fill.lerp(UiPalette.TEAL, .12), UiPalette.TEAL, 10.0, margin_x, 8.0))
	add_theme_stylebox_override("pressed", ChamferStyle.make(fill.lerp(UiPalette.TEAL_HI, .2), UiPalette.TEAL_HI, 10.0, margin_x, 8.0))
	add_theme_stylebox_override("focus", ChamferStyle.make(Color(0, 0, 0, 0), UiPalette.TEAL_HI, 10.0, margin_x, 8.0))
	add_theme_stylebox_override("disabled", ChamferStyle.make(Color(fill, .5), Color(edge, .4), 10.0, margin_x, 8.0))
	return self
