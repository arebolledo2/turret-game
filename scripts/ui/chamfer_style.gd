class_name ChamferStyle
extends StyleBox

## Flat panel with the top-left and bottom-right corners cut. A StyleBox so buttons, panels and
## containers can all use it through the normal theme/override slots.
var fill: Color = UiPalette.PANEL
var edge: Color = UiPalette.LINE
var cut: float = 14.0
var edge_width: float = 1.5

static func make(fill_color: Color = UiPalette.PANEL, edge_color: Color = UiPalette.LINE, cut_size: float = 14.0,
		margin_x: float = 20.0, margin_y: float = 14.0) -> ChamferStyle:
	var style := ChamferStyle.new()
	style.fill = fill_color
	style.edge = edge_color
	style.cut = cut_size
	style.content_margin_left = margin_x
	style.content_margin_right = margin_x
	style.content_margin_top = margin_y
	style.content_margin_bottom = margin_y
	return style

## Polygon corners, clockwise from the top edge; the first and last corners are the chamfers.
func outline(rect: Rect2) -> PackedVector2Array:
	var inset := rect.grow(-edge_width * .5)
	var corner := minf(cut, minf(inset.size.x, inset.size.y) * .5)
	var start := inset.position
	var finish := inset.end
	return PackedVector2Array([
		Vector2(start.x + corner, start.y), Vector2(finish.x, start.y), Vector2(finish.x, finish.y - corner),
		Vector2(finish.x - corner, finish.y), Vector2(start.x, finish.y), Vector2(start.x, start.y + corner),
	])

func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var points := outline(rect)
	RenderingServer.canvas_item_add_polygon(to_canvas_item, points, PackedColorArray([fill]))
	if edge_width > 0.0:
		var loop := points.duplicate()
		loop.append(points[0])
		RenderingServer.canvas_item_add_polyline(to_canvas_item, loop, PackedColorArray([edge]), edge_width, true)
