extends Camera2D

## Camera Setup - Configures camera limits and handles zoom
## Automatically sets camera limits to match arena bounds
## Auto-adjusts zoom to fit the fixed arena in different viewport sizes

const MIN_ZOOM: float = 0.5
const MAX_ZOOM: float = 2.0
const ZOOM_SPEED: float = 10.0
const ZOOM_STEP: float = 0.1

var target_zoom: float = 1.0
var base_zoom: float = 1.0  # Auto-calculated zoom to fit arena

func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_changed)
	_on_viewport_changed()
	target_zoom = base_zoom

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = clamp(target_zoom + ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = clamp(target_zoom - ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)

func _process(delta: float) -> void:
	if not is_equal_approx(zoom.x, target_zoom):
		var new_zoom: float = lerp(zoom.x, target_zoom, ZOOM_SPEED * delta)
		zoom = Vector2(new_zoom, new_zoom)

func _on_viewport_changed() -> void:
	setup_camera_limits()
	calculate_base_zoom()

func setup_camera_limits() -> void:
	var half_width := Globals.ARENA_WIDTH / 2.0
	var half_height := Globals.ARENA_HEIGHT / 2.0

	limit_left = int(-half_width)
	limit_top = int(-half_height)
	limit_right = int(half_width)
	limit_bottom = int(half_height)

func calculate_base_zoom() -> void:
	# Calculate zoom to fit the arena in the viewport
	var viewport_size = get_viewport().get_visible_rect().size

	# Calculate zoom needed to fit arena width and height
	var zoom_for_width = viewport_size.x / float(Globals.ARENA_WIDTH)
	var zoom_for_height = viewport_size.y / float(Globals.ARENA_HEIGHT)

	# Use the smaller zoom to ensure entire arena fits
	base_zoom = min(zoom_for_width, zoom_for_height) * GameConstants.CAMERA_DEFAULT_ZOOM_BOOST

	# Set initial zoom
	zoom = Vector2(base_zoom, base_zoom)
	target_zoom = base_zoom
