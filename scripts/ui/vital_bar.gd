class_name VitalBar
extends PanelContainer

## Hull or core readout: icon, number and a segmented bar with one cell per point (scaled past MAX_CELLS).
## The bar turns red and pulses below LOW_FRACTION.
const MAX_CELLS: int = 40
const LOW_FRACTION: float = .25

var icon_rect: TextureRect
var value_label: Label
var max_label: Label
var bar: SegmentedBar
var low: bool = false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", ChamferStyle.make(UiPalette.PANEL, UiPalette.LINE, 10.0, 20.0, 12.0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	add_child(row)
	icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(48, 48)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_rect)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)
	row.add_child(column)
	var numbers := HBoxContainer.new()
	numbers.add_theme_constant_override("separation", 4)
	column.add_child(numbers)
	value_label = Label.new()
	value_label.theme_type_variation = &"Numeral"
	value_label.add_theme_font_size_override("font_size", 34)
	value_label.add_theme_color_override("font_color", UiPalette.INK)
	numbers.add_child(value_label)
	max_label = Label.new()
	max_label.theme_type_variation = &"Numeral"
	max_label.add_theme_font_size_override("font_size", 22)
	max_label.add_theme_color_override("font_color", UiPalette.MUTED)
	max_label.size_flags_vertical = Control.SIZE_SHRINK_END
	numbers.add_child(max_label)
	bar = SegmentedBar.new()
	bar.custom_minimum_size = Vector2(0, 18)
	column.add_child(bar)

func setup(icon_name: String, stat: String) -> VitalBar:
	var tint := UiPalette.stat_color(stat)
	icon_rect.texture = UiIcons.get_icon(icon_name)
	icon_rect.modulate = tint
	bar.color = tint
	return self

func set_values(current: float, maximum: float) -> void:
	var shown := ceili(current)
	var cap := maxi(ceili(maximum), 1)
	var cells := mini(cap, MAX_CELLS)
	var lit := 0 if shown <= 0 else maxi(1, ceili(float(shown) / float(cap) * cells))
	var now_low := float(shown) / float(cap) < LOW_FRACTION
	if now_low != low:
		low = now_low
		value_label.add_theme_color_override("font_color", UiPalette.BAD if low else UiPalette.INK)
	value_label.text = str(shown)
	max_label.text = "/%d" % cap
	bar.set_state(lit, cells, low)
