extends Node2D

## Arena Setup - Configures arena bounds from Globals constants
## Attach this to the Arena node in main.tscn
##
## The arena size is FIXED for consistent gameplay across all resolutions.
## Only the camera zoom and UI scale adapt to different window sizes.

# Fixed arena dimensions for consistent gameplay
const FIXED_ARENA_WIDTH: int = 1920
const FIXED_ARENA_HEIGHT: int = 1080

@onready var ground: ColorRect = $Ground
@onready var boundary: ColorRect = $Boundary

func _ready() -> void:
	# Arena size is fixed - no need to listen to viewport changes
	setup_arena()

func setup_arena() -> void:
	# Ensure arena is behind all gameplay entities
	z_index = -10
	
	# Use fixed dimensions for consistent gameplay
	Globals.ARENA_WIDTH = FIXED_ARENA_WIDTH
	Globals.ARENA_HEIGHT = FIXED_ARENA_HEIGHT

	var half_width := float(Globals.ARENA_WIDTH) / 2.0
	var half_height := float(Globals.ARENA_HEIGHT) / 2.0
	var border_thickness := 10.0

	# Setup ground (playable area)
	if ground:
		ground.offset_left = -half_width
		ground.offset_top = -half_height
		ground.offset_right = half_width
		ground.offset_bottom = half_height

	# Setup boundary (border around ground)
	if boundary:
		boundary.offset_left = -half_width - border_thickness
		boundary.offset_top = -half_height - border_thickness
		boundary.offset_right = half_width + border_thickness
		boundary.offset_bottom = half_height + border_thickness
