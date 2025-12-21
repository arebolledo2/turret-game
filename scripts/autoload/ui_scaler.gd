extends Node

## Centralized UI scaling system for resolution-independent UI
##
## This autoload singleton calculates and provides scaling values based on
## viewport size, ensuring UI elements scale proportionally across different
## resolutions and aspect ratios.
##
## Base reference resolution: 1920x1080 (1080p)
## Minimum supported resolution: 1280x720 (720p)
## Scaling method: Based on viewport height (not width) to handle ultrawide properly

# Base reference resolution (1080p)
const BASE_WIDTH: int = 1920
const BASE_HEIGHT: int = 1080
const MIN_WIDTH: int = 1280
const MIN_HEIGHT: int = 720

# Current scale factors
var scale_factor: float = 1.0  # Based on height
var viewport_size: Vector2i = Vector2i(BASE_WIDTH, BASE_HEIGHT)

signal scale_changed(new_scale: float)


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_update_scale()


func _on_viewport_size_changed() -> void:
	_update_scale()


func _update_scale() -> void:
	var new_size = get_viewport().get_visible_rect().size

	# Enforce minimum resolution
	if new_size.x < MIN_WIDTH or new_size.y < MIN_HEIGHT:
		# Clamp to minimum
		new_size.x = maxi(int(new_size.x), MIN_WIDTH)
		new_size.y = maxi(int(new_size.y), MIN_HEIGHT)
		DisplayServer.window_set_size(new_size)
		return

	viewport_size = Vector2i(new_size)

	# Calculate scale factor based on HEIGHT
	# This ensures UI stays proportional on ultrawide/vertical screens
	var old_scale = scale_factor
	scale_factor = new_size.y / float(BASE_HEIGHT)

	if not is_equal_approx(old_scale, scale_factor):
		scale_changed.emit(scale_factor)


## Get scaled pixel value (for offsets, sizes, etc)
func scale(base_pixels: float) -> float:
	return base_pixels * scale_factor


## Get scaled Vector2 (for positions, sizes)
func scale_vec(base_vec: Vector2) -> Vector2:
	return base_vec * scale_factor


## Get scaled font size (rounded to int, minimum 8px)
func scale_font(base_size: int) -> int:
	return maxi(int(base_size * scale_factor), 8)


## Get current viewport size
func get_viewport_size() -> Vector2i:
	return viewport_size


## Check if at minimum resolution
func is_at_minimum_resolution() -> bool:
	return viewport_size.x <= MIN_WIDTH or viewport_size.y <= MIN_HEIGHT
