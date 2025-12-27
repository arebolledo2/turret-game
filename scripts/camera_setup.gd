extends Camera2D

## Camera Setup - Configures camera limits and handles zoom
## Automatically sets camera limits to match arena bounds
## Auto-adjusts zoom to fit the fixed arena in different viewport sizes

const MIN_ZOOM: float = 0.5
const MAX_ZOOM: float = 2.0
const ZOOM_SPEED: float = 10.0
const ZOOM_STEP: float = 0.1

var target_zoom: float = 1.0
var base_zoom: float = 1.0 # Auto-calculated zoom to fit arena

func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_changed)
	# Defer initial setup to ensure ArenaBoundsService is initialized
	call_deferred("_on_viewport_changed")
	call_deferred("_sync_target_zoom")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = clamp(target_zoom + ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = clamp(target_zoom - ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)

func _physics_process(delta: float) -> void:
	# Round camera position to prevent sub-pixel jitter
	position = position.round()

	if not is_equal_approx(zoom.x, target_zoom):
		var new_zoom: float = lerp(zoom.x, target_zoom, ZOOM_SPEED * delta)
		zoom = Vector2(new_zoom, new_zoom)
		setup_camera_limits()  # Recalculate limits for new zoom level

func _sync_target_zoom() -> void:
	target_zoom = base_zoom

func _on_viewport_changed() -> void:
	calculate_base_zoom()      # Must calculate zoom first
	setup_camera_limits()      # Then set limits based on that zoom

func setup_camera_limits() -> void:
	var bounds_rect := ArenaBoundsService.get_bounds_rect()
	var viewport_size := get_viewport().get_visible_rect().size

	# Safety check - if bounds are zero, service isn't initialized yet
	if bounds_rect.size.x == 0 or bounds_rect.size.y == 0:
		return

	# Get the actual player-reachable bounds (with margin)
	var half_dims := ArenaBoundsService.get_half_dimensions()
	var player_margin := 20.0  # Same margin used in player clamping

	if ArenaBoundsService.is_isometric():
		# For isometric, player can reach diamond vertices at (±W, 0) and (0, ±H)
		# Camera should be able to CENTER on the player at these extreme positions
		# This means camera center can go all the way to the player's max position
		limit_left = int(-half_dims.x + player_margin)
		limit_right = int(half_dims.x - player_margin)
		limit_top = int(-half_dims.y + player_margin)
		limit_bottom = int(half_dims.y - player_margin)
	else:
		# Rectangular arena: camera can follow player to edges
		# but viewport edge shouldn't show past arena edge
		var visible_world_size := viewport_size / zoom
		var half_visible := visible_world_size / 2.0

		limit_left = int(bounds_rect.position.x + half_visible.x)
		limit_right = int(bounds_rect.end.x - half_visible.x)
		limit_top = int(bounds_rect.position.y + half_visible.y)
		limit_bottom = int(bounds_rect.end.y - half_visible.y)

		# Handle edge case: if arena is smaller than viewport, center the camera
		if limit_left > limit_right:
			limit_left = 0
			limit_right = 0
		if limit_top > limit_bottom:
			limit_top = 0
			limit_bottom = 0

	print("Camera limits: L=", limit_left, " R=", limit_right, " T=", limit_top, " B=", limit_bottom, " zoom=", zoom.x)


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
