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
var bg_sprite: Sprite2D = null
var debug_outline: Line2D = null

# Alignment (Adjustable at runtime)
var bg_zoom: Vector2 = Vector2.ONE
var bg_offset: Vector2 = Vector2.ZERO


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
	
	# Get dimensions from ArenaBoundsService (it handles different sizes for isometric)
	var half_dims := ArenaBoundsService.get_half_dimensions()
	var half_width := half_dims.x
	var half_height := half_dims.y
	
	# Update Globals for legacy code
	Globals.ARENA_WIDTH = int(half_width * 2)
	Globals.ARENA_HEIGHT = int(half_height * 2)
	
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
	diamond_ground.visible = false # Hide generated ground to show sprite
	
	# Create or Update Background Sprite
	if bg_sprite == null:
		bg_sprite = Sprite2D.new()
		bg_sprite.name = "BackgroundSprite"
		bg_sprite.z_index = -1 # Just behind entities (which are 0)
		add_child(bg_sprite)
	
	var texture = load("res://assets/sprites/isometric_arena_bg.jpeg")
	if texture:
		bg_sprite.texture = texture
		bg_sprite.visible = true
		_load_alignment_config() # Load saved settings
		print("DEBUG: Arena BG Texture Loaded. Size: ", texture.get_size())
	else:
		print("ERROR: Arena BG Texture FAILED to load!")

	
	# Configure diamond border - slightly larger
	# Make invisible if using sprite background as it blocks view (it's a filled poly)
	var border_inset := 15.0
	var border_points := PackedVector2Array([
		Vector2(half_width + border_inset, 0),
		Vector2(0, half_height + border_inset),
		Vector2(-half_width - border_inset, 0),
		Vector2(0, -half_height - border_inset),
	])
	diamond_border.polygon = border_points
	diamond_border.color = Color(0.4, 0.45, 0.5, 1.0)
	diamond_border.visible = false # user reported "blank background" blocking sprite
	diamond_border.z_index = -2

	# Create Debug Outline (Target Bounds)
	if debug_outline == null:
		debug_outline = Line2D.new()
		debug_outline.name = "DebugOutline"
		debug_outline.default_color = Color.MAGENTA
		debug_outline.width = 4.0
		debug_outline.z_index = 0 # On top of background
		add_child(debug_outline)
		
	var outline_points = ground_points.duplicate()
	outline_points.append(ground_points[0]) # Close loop
	debug_outline.points = outline_points
	debug_outline.visible = Globals.isometric_debug_enabled # HIDE by default (unless enabled)
	
	# Connect to debug event
	if not Events.isometric_debug_toggled.is_connected(_on_isometric_debug_toggled):
		Events.isometric_debug_toggled.connect(_on_isometric_debug_toggled)


func _on_isometric_debug_toggled(enabled: bool) -> void:
	if debug_outline:
		debug_outline.visible = enabled
	
	# Print status to console
	if enabled:
		print("ISOMETRIC EDIT MODE: ENABLED (Use Arrows/Shift/Plus/Minus/S)")
	else:
		print("ISOMETRIC EDIT MODE: DISABLED")


func _process(delta: float) -> void:
	# Only run if visible, sprite exists, AND DEBUG MODE IS ENABLED
	if not visible or not bg_sprite or not Globals.isometric_debug_enabled:
		return
		
	# Simple Runtime Alignment Tool
	var changed := false
	var speed := 100.0 * delta
	var scale_speed := 1.0 * delta
	
	var is_shift := Input.is_key_pressed(KEY_SHIFT)
	
	# Movement (Arrows)
	if not is_shift:
		if Input.is_key_pressed(KEY_UP):
			bg_offset.y -= speed
			changed = true
		if Input.is_key_pressed(KEY_DOWN):
			bg_offset.y += speed
			changed = true
		if Input.is_key_pressed(KEY_LEFT):
			bg_offset.x -= speed
			changed = true
		if Input.is_key_pressed(KEY_RIGHT):
			bg_offset.x += speed
			changed = true
	
	# Independent Scaling (Shift + Arrows)
	if is_shift:
		if Input.is_key_pressed(KEY_UP): # Scale Y Down (Smaller height)
			bg_zoom.y -= scale_speed
			changed = true
		if Input.is_key_pressed(KEY_DOWN): # Scale Y Up (Larger height)
			bg_zoom.y += scale_speed
			changed = true
		if Input.is_key_pressed(KEY_LEFT): # Scale X Down (Thinner)
			bg_zoom.x -= scale_speed
			changed = true
		if Input.is_key_pressed(KEY_RIGHT): # Scale X Up (Wider)
			bg_zoom.x += scale_speed
			changed = true

	# Uniform Scale (+/-)
	if Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_KP_ADD):
		bg_zoom += Vector2(scale_speed, scale_speed)
		changed = true
	if Input.is_key_pressed(KEY_MINUS) or Input.is_key_pressed(KEY_KP_SUBTRACT):
		bg_zoom -= Vector2(scale_speed, scale_speed)
		changed = true
		
	# Save (S)
	if Input.is_physical_key_pressed(KEY_S):
		_save_alignment_config()
		
	if changed:
		bg_sprite.position = bg_offset
		bg_sprite.scale = bg_zoom
		print("BG Alignment | Offset: ", bg_offset, " | Scale: ", bg_zoom)


const CONFIG_PATH = "user://isometric_bg_config.cfg"

func _save_alignment_config() -> void:
	# Ensure directory exists (user:// always exists but good practice if using subdirs)
	var config = ConfigFile.new()
	config.set_value("alignment", "offset", bg_offset)
	config.set_value("alignment", "scale", bg_zoom)
	config.save(CONFIG_PATH)
	
	var global_path = ProjectSettings.globalize_path(CONFIG_PATH)
	print("SAVED Alignment to: ", global_path)

func _load_alignment_config() -> void:
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	if err == OK:
		bg_offset = config.get_value("alignment", "offset", Vector2.ZERO)
		bg_zoom = config.get_value("alignment", "scale", Vector2.ONE)
		bg_sprite.position = bg_offset
		bg_sprite.scale = bg_zoom
		print("LOADED Alignment from: ", ProjectSettings.globalize_path(CONFIG_PATH))
