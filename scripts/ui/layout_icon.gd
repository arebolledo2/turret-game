class_name LayoutIcon
extends Control

## Tiny top-down arena diagram for a preparation layout: dots are turrets, rings are their reach.
const DOTS: Dictionary = {
	"tight": [Vector2(-.14, -.1), Vector2(.14, -.1), Vector2(-.14, .12), Vector2(.14, .12)],
	"balanced": [Vector2(-.3, -.22), Vector2(.3, -.22), Vector2(-.3, .22), Vector2(.3, .22)],
	"area": [Vector2(-.5, 0), Vector2(0, -.5), Vector2(.5, 0), Vector2(0, .5)],
	"spread": [Vector2(-.5, -.5), Vector2(.5, -.5), Vector2(-.5, .5), Vector2(.5, .5)],
	"saved": [Vector2(-.55, -.25), Vector2(.2, -.55), Vector2(.4, .1), Vector2(-.2, .45)],
}
## Ring radius as a fraction of the icon half-width; area rings just touch, tight rings pile up.
const REACH: Dictionary = {"tight": .38, "balanced": .3, "area": .22, "spread": .16, "saved": .2}
var kind := "tight"
var ink := UiPalette.INK

func setup(layout: String, size_px: float = 64.0) -> LayoutIcon:
	kind = layout
	custom_minimum_size = Vector2(size_px, size_px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	return self

func set_ink(colour: Color) -> void:
	ink = colour
	queue_redraw()

func _draw() -> void:
	var half := size * .5
	var scale := minf(half.x, half.y) * .86
	draw_rect(Rect2(Vector2.ZERO, size), Color(ink, .08))
	draw_rect(Rect2(Vector2.ZERO, size), Color(ink, .45), false, 1.5)
	for dot: Vector2 in DOTS[kind]:
		var at := half + dot * scale
		draw_arc(at, REACH[kind] * scale * 1.6, 0, TAU, 28, Color(ink, .5), 1.5)
		draw_circle(at, maxf(2.5, size.x * .06), ink)
	if kind == "saved":
		# A pin marks the layout as remembered rather than computed.
		var top := Vector2(size.x - 11, 10)
		draw_circle(top, 4.5, UiPalette.SCRAP)
		draw_line(top, top + Vector2(0, 8), UiPalette.SCRAP, 2.0)
