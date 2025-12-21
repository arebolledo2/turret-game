extends Camera2D

## Camera Setup - Configures camera limits and handles zoom
## Automatically sets camera limits to match arena bounds

const MIN_ZOOM: float = 0.5
const MAX_ZOOM: float = 2.0
const ZOOM_SPEED: float = 10.0
const ZOOM_STEP: float = 0.1

var target_zoom: float = 1.0

func _ready() -> void:
	setup_camera_limits()
	target_zoom = zoom.x

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = clamp(target_zoom - ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = clamp(target_zoom + ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)

func _process(delta: float) -> void:
	if not is_equal_approx(zoom.x, target_zoom):
		var new_zoom: float = lerp(zoom.x, target_zoom, ZOOM_SPEED * delta)
		zoom = Vector2(new_zoom, new_zoom)

func setup_camera_limits() -> void:
	var half_width := Globals.ARENA_WIDTH / 2.0
	var half_height := Globals.ARENA_HEIGHT / 2.0

	limit_left = int(-half_width)
	limit_top = int(-half_height)
	limit_right = int(half_width)
	limit_bottom = int(half_height)
