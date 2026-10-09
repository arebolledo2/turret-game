class_name StatChip
extends PanelContainer

## Small icon + value pill. The icon keeps its stat colour; a good/bad tone recolours the whole chip.
const ICON_SIZE: float = 22.0

var icon_rect: TextureRect
var label: Label

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_rect)
	label = Label.new()
	label.theme_type_variation = &"Numeral"
	label.add_theme_font_size_override("font_size", 20)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)

## icon_name: UiIconData key; stat: UI stat key for the colour; tone: -1 bad, 0 neutral, 1 good.
func setup(icon_name: String, text: String, stat: String = "", tone: int = 0) -> StatChip:
	var stat_color := UiPalette.stat_color(stat)
	var tint := UiPalette.tone_color(tone, UiPalette.INK)
	icon_rect.texture = UiIcons.get_icon(icon_name)
	icon_rect.modulate = stat_color
	label.text = text
	label.add_theme_color_override("font_color", tint)
	var base := stat_color if tone == 0 else tint
	add_theme_stylebox_override("panel", ChamferStyle.make(
		UiPalette.PANEL_SOLID.lerp(base, .14), Color(base, .45), 6.0, 7.0, 3.0))
	return self
