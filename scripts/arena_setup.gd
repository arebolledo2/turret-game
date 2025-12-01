extends Node2D

## Arena Setup - Configures arena bounds from Globals constants
## Attach this to the Arena node in main.tscn

@onready var ground: ColorRect = $Ground
@onready var boundary: ColorRect = $Boundary

func _ready() -> void:
	setup_arena()

func setup_arena() -> void:
	var half_width := Globals.ARENA_WIDTH / 2.0
	var half_height := Globals.ARENA_HEIGHT / 2.0
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
