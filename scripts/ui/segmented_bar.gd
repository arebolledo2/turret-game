class_name SegmentedBar
extends Control

## A row of skewed cells. `value` cells are lit; `now_index` blinks (the wave in progress); `danger`
## turns the lit cells red and pulses them. Pulsing stops when Reduced motion is on.
const GAP: float = 4.0
const SKEW: float = .35 # horizontal lean as a fraction of the bar height
const EMPTY: Color = Color(1, 1, 1, .09)

var cells: int = 10
var value: int = 0
var now_index: int = -1
var danger: bool = false
var fail_index: int = -1 # a cell drawn in the danger colour (the wave that ended the run)
var color: Color = UiPalette.TEAL_HI
var pulse_clock: float = 0.0

func _init() -> void:
	custom_minimum_size = Vector2(40, 16)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

func set_state(lit: int, total: int = -1, danger_state: bool = false, blink_index: int = -1) -> void:
	var new_total := cells if total < 0 else maxi(1, total)
	lit = clampi(lit, 0, new_total)
	if lit == value and new_total == cells and danger_state == danger and blink_index == now_index:
		return
	value = lit
	cells = new_total
	danger = danger_state
	now_index = blink_index
	set_process((danger or now_index >= 0) and not FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION))
	queue_redraw()

## Marks one cell as failed (-1 clears it).
func set_fail(index: int) -> void:
	if index != fail_index:
		fail_index = index
		queue_redraw()

func _process(delta: float) -> void:
	pulse_clock += delta
	queue_redraw()

## Opacity multiplier for pulsing cells; steady 1.0 under Reduced motion.
func pulse_alpha() -> float:
	if FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION):
		return 1.0
	return .55 + .45 * (.5 + .5 * sin(pulse_clock * TAU * .9))

func _draw() -> void:
	var lean := size.y * SKEW
	var cell_width := (size.x - GAP * (cells - 1) - lean) / float(cells)
	if cell_width <= 0.0:
		return
	var lit_color := UiPalette.BAD if danger else color
	var alpha := pulse_alpha()
	for index in cells:
		var left := index * (cell_width + GAP)
		var fill := EMPTY
		if index < value:
			fill = lit_color
			if danger:
				fill.a = alpha
		elif index == fail_index:
			fill = UiPalette.BAD
		elif index == now_index:
			fill = color
			fill.a = alpha
		draw_colored_polygon(PackedVector2Array([
			Vector2(left + lean, 0), Vector2(left + cell_width + lean, 0),
			Vector2(left + cell_width, size.y), Vector2(left, size.y)]), fill)
