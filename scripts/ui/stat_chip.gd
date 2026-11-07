class_name StatChip
extends PanelContainer

## Icon + value, the one stat style used across the shop: no pill, no border. Neutral stats draw a muted
## icon and ink text; a good/bad tone recolours both, so colour only ever means "this changes".
const ICON_SIZE: float = 20.0
const ICON_NEUTRAL: Color = Color("7fa3ad")

var icon_rect: TextureRect
var label: Label

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
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

## icon_name: UiIconData key; stat: UI stat key (kept for callers, no longer colours the chip); tone: -1 bad, 0 neutral, 1 good.
func setup(icon_name: String, text: String, _stat: String = "", tone: int = 0, neutral: Color = UiPalette.INK) -> StatChip:
	icon_rect.texture = UiIcons.get_icon(icon_name)
	icon_rect.modulate = UiPalette.tone_color(tone, ICON_NEUTRAL)
	label.text = text
	label.add_theme_color_override("font_color", UiPalette.tone_color(tone, neutral))
	return self

## Prefix the chip with attack family badges: the stat only applies to those families.
func with_families(families: Array) -> StatChip:
	var row := icon_rect.get_parent()
	for family in UiIcons.sort_families(families):
		var badge := TextureRect.new()
		badge.texture = UiIcons.family_badge(family)
		badge.tooltip_text = UiIcons.family_name(family) + " only"
		badge.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(badge)
		row.move_child(badge, icon_rect.get_index())
	return self
