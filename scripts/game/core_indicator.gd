class_name CoreIndicator
extends Control

## Screen-edge arrow pointing at the core when it is off-screen (core mode only).
const MARGIN: float = 60.0
var world: ArenaWorld
var arrow_visible: bool = false
var arrow_at: Vector2 = Vector2.ZERO
var arrow_heading: Vector2 = Vector2.UP

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	var was_visible := arrow_visible
	arrow_visible = false
	if is_instance_valid(world) and world.core and not world.core.dead and world.camera and visible:
		var target := world.core.position + Vector3(0, .6, 0)
		var viewport_size := get_viewport_rect().size
		var centre := viewport_size * .5
		var behind := world.camera.is_position_behind(target)
		var projected := world.camera.unproject_position(target)
		var inside := not behind and Rect2(Vector2(MARGIN, MARGIN), viewport_size - Vector2.ONE * MARGIN * 2.0).has_point(projected)
		if not inside:
			var direction := (projected - centre).normalized() * (-1.0 if behind else 1.0)
			if direction.is_zero_approx():
				direction = Vector2.UP
			var limit := centre - Vector2.ONE * MARGIN
			var scale_to_edge := minf(limit.x / maxf(absf(direction.x), .0001), limit.y / maxf(absf(direction.y), .0001))
			arrow_at = centre + direction * scale_to_edge
			arrow_heading = direction
			arrow_visible = true
	if arrow_visible or was_visible:
		queue_redraw()

func _draw() -> void:
	if not arrow_visible:
		return
	var side := arrow_heading.orthogonal()
	var colour := Color("58ece1")
	draw_colored_polygon(PackedVector2Array([arrow_at + arrow_heading * 18.0, arrow_at - arrow_heading * 10.0 + side * 12.0,
		arrow_at - arrow_heading * 10.0 - side * 12.0]), colour)
	var font := get_theme_default_font()
	draw_string(font, arrow_at - arrow_heading * 32.0 - Vector2(18, -5), "CORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, colour)
