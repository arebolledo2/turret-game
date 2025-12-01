extends Camera2D

## Camera Setup - Configures camera limits from Globals constants
## Automatically sets camera limits to match arena bounds

func _ready() -> void:
	setup_camera_limits()

func setup_camera_limits() -> void:
	var half_width := Globals.ARENA_WIDTH / 2.0
	var half_height := Globals.ARENA_HEIGHT / 2.0

	limit_left = int(-half_width)
	limit_top = int(-half_height)
	limit_right = int(half_width)
	limit_bottom = int(half_height)
