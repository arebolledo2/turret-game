extends Control

## OffScreenIndicators - UI container that manages all off-screen indicator instances
## Creates and positions indicators at screen edges based on OffScreenIndicatorService data
## Handles indicator pooling and dynamic updates each frame

# Indicator scene (will be set up programmatically since we can't preload scene that doesn't exist yet)
var indicator_scene: PackedScene = null

# Active indicators pool
var active_indicators: Dictionary = {}  # key -> OffScreenIndicator node

# Camera reference
var camera: Camera2D = null


func _ready() -> void:
	# Set up full-screen control
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Try to load indicator scene
	_try_load_indicator_scene()

	# Wait for game to start to get camera
	Events.game_started.connect(_on_game_started)


func _on_game_started() -> void:
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("get_viewport"):
		camera = player.get_viewport().get_camera_2d()


func _try_load_indicator_scene() -> void:
	# Try to load the scene file if it exists
	if ResourceLoader.exists("res://scenes/ui/off_screen_indicator.tscn"):
		indicator_scene = load("res://scenes/ui/off_screen_indicator.tscn")
	else:
		# Scene doesn't exist yet, we'll create indicators programmatically
		print("OffScreenIndicators: Indicator scene not found, will create programmatically")


func _process(_delta: float) -> void:
	if not camera or not OffScreenIndicatorService:
		return

	# Get grouped entities from service
	var groups := OffScreenIndicatorService.get_indicator_groups()
	var viewport_bounds := OffScreenIndicatorService.get_viewport_bounds()

	if viewport_bounds.size.x == 0 or viewport_bounds.size.y == 0:
		return

	# Track which indicators are still active
	var active_keys: Array[String] = []

	# Create/update indicators for each group
	for sector in groups:
		for entity_type in groups[sector]:
			var entities: Array = groups[sector][entity_type]
			if entities.is_empty():
				continue

			# Create unique key for this group
			var key := "%d_%s" % [sector, entity_type]
			active_keys.append(key)

			# Calculate indicator position
			var indicator_data := OffScreenIndicatorService.calculate_indicator_position(
				entities, viewport_bounds
			)

			if indicator_data.is_empty():
				continue

			# Get or create indicator
			var indicator := _get_or_create_indicator(key)
			if not indicator:
				continue

			# Convert world position to screen position
			var screen_pos := _world_to_screen(indicator_data.screen_position)

			# Update indicator
			indicator.position = screen_pos
			indicator.setup(
				indicator_data.direction,
				indicator_data.count,
				entities[0].category,
				entity_type
			)
			indicator.visible = true

	# Hide inactive indicators
	for key in active_indicators:
		if not key in active_keys:
			active_indicators[key].visible = false


## Get or create indicator for a specific key
func _get_or_create_indicator(key: String) -> Control:
	# Return existing indicator
	if key in active_indicators:
		return active_indicators[key]

	# Create new indicator
	var indicator: Control = null

	if indicator_scene:
		# Use scene instance
		indicator = indicator_scene.instantiate()
	else:
		# Create programmatically
		indicator = _create_indicator_programmatically()

	if not indicator:
		return null

	add_child(indicator)
	active_indicators[key] = indicator

	return indicator


## Create indicator programmatically if scene doesn't exist
func _create_indicator_programmatically() -> Control:
	var indicator := Control.new()
	indicator.set_script(load("res://scripts/off_screen_indicator.gd"))

	# Create arrow polygon
	var arrow := Polygon2D.new()
	arrow.name = "ArrowPolygon"
	indicator.add_child(arrow)

	# Create count label
	var label := Label.new()
	label.name = "CountLabel"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	indicator.add_child(label)

	return indicator


## Convert world position to screen position
func _world_to_screen(world_pos: Vector2) -> Vector2:
	if not camera:
		return Vector2.ZERO

	# Get viewport info
	var viewport_size := get_viewport_rect().size
	var screen_center := viewport_size / 2.0

	# Calculate offset from camera
	var offset := (world_pos - camera.global_position) * camera.zoom

	# Screen position
	return screen_center + offset


## Clean up indicators on exit
func _exit_tree() -> void:
	for indicator in active_indicators.values():
		if is_instance_valid(indicator):
			indicator.queue_free()
	active_indicators.clear()
