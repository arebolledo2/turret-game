class_name StatTile
extends PanelContainer

## Icon, a big number and a small caption. The number is a Label so callers can update it per frame.
var icon_rect: TextureRect
var value_label: Label
var caption_label: Label

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", ChamferStyle.make(UiPalette.PANEL_SOLID, UiPalette.LINE, 8.0, 14.0, 8.0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(34, 34)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_rect)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	row.add_child(column)
	value_label = Label.new()
	value_label.theme_type_variation = &"Numeral"
	value_label.add_theme_font_size_override("font_size", 30)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(value_label)
	caption_label = Label.new()
	caption_label.add_theme_font_size_override("font_size", 15)
	caption_label.add_theme_color_override("font_color", UiPalette.MUTED)
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(caption_label)

func setup(icon_name: String, stat: String, caption: String, value_text: String = "") -> StatTile:
	icon_rect.texture = UiIcons.get_icon(icon_name)
	icon_rect.modulate = UiPalette.stat_color(stat)
	caption_label.text = caption.to_upper()
	caption_label.visible = not caption.is_empty()
	value_label.text = value_text
	return self

func set_value(text: String, color: Color = UiPalette.INK) -> void:
	value_label.text = text
	value_label.add_theme_color_override("font_color", color)
