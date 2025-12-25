extends Node2D

## Arena Setup - Configures arena bounds and visuals
## Attach this to the Arena node in main.tscn
##
## The arena size is FIXED for consistent gameplay across all resolutions.
## Supports both rectangular and isometric diamond shapes.

# Fixed arena dimensions for consistent gameplay
const FIXED_ARENA_WIDTH: int = 1920
const FIXED_ARENA_HEIGHT: int = 1080

# Original rectangular nodes (from scene)
@onready var ground: TextureRect = $Ground
@onready var boundary: ColorRect = $Boundary

# Isometric nodes (created dynamically)
var diamond_ground: Polygon2D = null
var diamond_border: Polygon2D = null

func _ready() -> void:
	# Wait for game mode to be set before configuring arena
	# If game is already started, setup now; otherwise wait for signal
	if Globals.is_game_active:
		setup_arena()
	else:
		# Defer setup until arena type is known
		Events.game_mode_selected.connect(_on_game_mode_selected)
		# Also setup if difficulty selected (for initial load)
		Events.difficulty_selected.connect(_on_difficulty_selected)
		# Fallback: setup after a frame if nothing else triggers
		await get_tree().process_frame
		await get_tree().process_frame
		if diamond_ground == null and not ArenaBoundsService.is_isometric():
			setup_arena()


func _on_game_mode_selected(_mode: GameEnums.GameMode) -> void:
	setup_arena()


func _on_difficulty_selected(_difficulty: int) -> void:
	# Setup with default (rectangular) - will be updated when game mode selected
	pass


func setup_arena() -> void:
	# Ensure arena is behind all gameplay entities
	z_index = -10
	
	# Use fixed dimensions for consistent gameplay
	Globals.ARENA_WIDTH = FIXED_ARENA_WIDTH
	Globals.ARENA_HEIGHT = FIXED_ARENA_HEIGHT
	
	# Update ArenaBoundsService with dimensions
	ArenaBoundsService.update_dimensions(FIXED_ARENA_WIDTH, FIXED_ARENA_HEIGHT)
	
	var half_width := float(Globals.ARENA_WIDTH) / 2.0
	var half_height := float(Globals.ARENA_HEIGHT) / 2.0
	
	if ArenaBoundsService.is_isometric():
		_setup_isometric_arena(half_width, half_height)
	else:
		_setup_rectangular_arena(half_width, half_height)


func _setup_rectangular_arena(half_width: float, half_height: float) -> void:
	"""Setup classic rectangular arena."""
	var border_thickness := 10.0
	
	# Show rectangular nodes, hide isometric
	if ground:
		ground.visible = true
		ground.offset_left = - half_width
		ground.offset_top = - half_height
		ground.offset_right = half_width
		ground.offset_bottom = half_height
	
	if boundary:
		boundary.visible = true
		boundary.offset_left = - half_width - border_thickness
		boundary.offset_top = - half_height - border_thickness
		boundary.offset_right = half_width + border_thickness
		boundary.offset_bottom = half_height + border_thickness
	
	# Hide isometric nodes
	if diamond_ground:
		diamond_ground.visible = false
	if diamond_border:
		diamond_border.visible = false


func _setup_isometric_arena(half_width: float, half_height: float) -> void:
	"""Setup isometric diamond arena."""
	# Hide rectangular nodes
	if ground:
		ground.visible = false
	if boundary:
		boundary.visible = false
	
	# Create the diamond ground if not exists
	if diamond_ground == null:
		diamond_ground = Polygon2D.new()
		diamond_ground.name = "DiamondGround"
		add_child(diamond_ground)
	
	# Create the diamond border if not exists
	if diamond_border == null:
		diamond_border = Polygon2D.new()
		diamond_border.name = "DiamondBorder"
		add_child(diamond_border)
		# Move border behind ground
		move_child(diamond_border, 0)
	
	# Configure diamond ground - vertices at cardinal points
	var ground_points := PackedVector2Array([
		Vector2(half_width, 0), # Right
		Vector2(0, half_height), # Bottom
		Vector2(-half_width, 0), # Left
		Vector2(0, -half_height), # Top
	])
	diamond_ground.polygon = ground_points
	diamond_ground.color = Color(0.15, 0.18, 0.22, 1.0) # Dark floor color
	diamond_ground.visible = true
	
	# Configure diamond border - slightly larger
	var border_inset := 15.0
	var border_points := PackedVector2Array([
		Vector2(half_width + border_inset, 0),
		Vector2(0, half_height + border_inset),
		Vector2(-half_width - border_inset, 0),
		Vector2(0, -half_height - border_inset),
	])
	diamond_border.polygon = border_points
	diamond_border.color = Color(0.4, 0.45, 0.5, 1.0) # Border color
	diamond_border.visible = true
	diamond_border.z_index = -1
