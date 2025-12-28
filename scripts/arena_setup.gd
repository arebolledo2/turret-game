extends Node2D

## Arena Setup - Configures arena bounds and visuals
## Attach this to the Arena node in main.tscn
##
## The arena size is FIXED for consistent gameplay across all resolutions.
## Supports both rectangular and isometric diamond shapes.

# Fixed arena dimensions for consistent gameplay (from GameConstants)
const FIXED_ARENA_WIDTH: int = GameConstants.ARENA_WIDTH
const FIXED_ARENA_HEIGHT: int = GameConstants.ARENA_HEIGHT

# Original rectangular nodes (from scene)
@onready var ground: TextureRect = $Ground
@onready var boundary: ColorRect = $Boundary

# Isometric nodes (created dynamically)
var diamond_ground: Polygon2D = null
var diamond_border: Polygon2D = null
var bg_sprite: Sprite2D = null
var debug_outline: Line2D = null

# Available background images (hardcoded list)
const AVAILABLE_BACKGROUNDS: Array[String] = [
	"res://assets/sprites/isometric_arena_bg.jpeg",
	"res://assets/sprites/isometric_arena_bg_2.jpeg",
]
var current_bg_index: int = 0

# Alignment (Adjustable at runtime, stored per-background)
var bg_zoom: Vector2 = Vector2.ONE
var bg_offset: Vector2 = Vector2.ZERO
var bg_configs: Dictionary = {} # Stores {path: {offset: Vector2, scale: Vector2}}

# Key state tracking for debounce
var _prev_bracket_left: bool = false
var _prev_bracket_right: bool = false
var _prev_save_key: bool = false
var start_time: int = 0 # For debug print throttling


func _ready() -> void:
	# Ensure this script runs even when game is paused (for debug editing)
	process_mode = Node.PROCESS_MODE_ALWAYS
	DebugService.log(DebugService.ARENA, "Arena _ready called. Process Mode set to ALWAYS. Visible: ", visible)

	# Connect to debug signal early so it works regardless of arena setup timing
	if not Events.isometric_debug_toggled.is_connected(_on_isometric_debug_toggled):
		Events.isometric_debug_toggled.connect(_on_isometric_debug_toggled)
		DebugService.log(DebugService.ARENA, "Arena connected to isometric_debug_toggled signal")

	if not Events.arena_background_selected.is_connected(_on_arena_background_selected):
		Events.arena_background_selected.connect(_on_arena_background_selected)
	
	# Wait for game mode to be set before configuring arena
	# If game is already started, setup now; otherwise wait for signal
	if GameStateService.is_game_active:
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


func _on_arena_background_selected(index: int) -> void:
	current_bg_index = index
	if ArenaBoundsService.is_isometric():
		_apply_current_background()


func setup_arena() -> void:
	# Ensure arena is behind all gameplay entities
	z_index = -10
	
	# Get dimensions from ArenaBoundsService (it handles different sizes for isometric)
	var half_dims := ArenaBoundsService.get_half_dimensions()
	var half_width := half_dims.x
	var half_height := half_dims.y
	
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
	
	_load_all_bg_configs() # Load all saved background configs
	_apply_current_background() # Apply the current background

	
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
	debug_outline.visible = SettingsService.isometric_debug_enabled # HIDE by default (unless enabled)


func _on_isometric_debug_toggled(enabled: bool) -> void:
	DebugService.log(DebugService.ARENA, "_on_isometric_debug_toggled called. Enabled: ", enabled, " | Outline exists: ", debug_outline != null)
	if debug_outline:
		debug_outline.visible = enabled

	# Print status to console
	if enabled:
		DebugService.log(DebugService.ARENA, "ISOMETRIC EDIT MODE: ENABLED (Use Arrows/Shift/Plus/Minus/S)")
	else:
		DebugService.log(DebugService.ARENA, "ISOMETRIC EDIT MODE: DISABLED")


func _process(delta: float) -> void:
	# Debug print to verify process is running (throttled)
	if start_time == 0: start_time = Time.get_ticks_msec()
	if Time.get_ticks_msec() - start_time > 2000: # Print every 2s if running
		DebugService.log(DebugService.ARENA, "Arena _process running. Paused: ", get_tree().paused, " | Visible: ", visible, " | Sprite: ", bg_sprite != null, " | GlobalDebug: ", SettingsService.isometric_debug_enabled)
		start_time = Time.get_ticks_msec()

	# Only run if visible, sprite exists, AND DEBUG MODE IS ENABLED
	if not visible:
		return
	if not bg_sprite:
		return
	if not SettingsService.isometric_debug_enabled:
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
		DebugService.log(DebugService.ARENA, "Plus pressed. New Zoom: ", bg_zoom)
	if Input.is_key_pressed(KEY_MINUS) or Input.is_key_pressed(KEY_KP_SUBTRACT):
		bg_zoom -= Vector2(scale_speed, scale_speed)
		changed = true
		DebugService.log(DebugService.ARENA, "Minus pressed. New Zoom: ", bg_zoom)

	# Save (S) - with debounce
	var save_pressed := Input.is_physical_key_pressed(KEY_S)
	if save_pressed and not _prev_save_key:
		DebugService.log(DebugService.ARENA, "Save key pressed")
		_save_all_bg_configs()
	_prev_save_key = save_pressed

	# Switch backgrounds ([ and ]) - with debounce (just-pressed detection)
	var bracket_left := Input.is_physical_key_pressed(KEY_BRACKETLEFT)
	var bracket_right := Input.is_physical_key_pressed(KEY_BRACKETRIGHT)

	if bracket_left and not _prev_bracket_left:
		DebugService.log(DebugService.ARENA, "[ pressed")
		_switch_background(-1)
	if bracket_right and not _prev_bracket_right:
		DebugService.log(DebugService.ARENA, "] pressed")
		_switch_background(1)
	
	_prev_bracket_left = bracket_left
	_prev_bracket_right = bracket_right
		
	if changed:
		bg_sprite.position = bg_offset
		bg_sprite.scale = bg_zoom
		_store_current_bg_config() # Update in-memory config
		# print("BG Alignment | Offset: ", bg_offset, " | Scale: ", bg_zoom)


const CONFIG_PATH = "user://isometric_bg_config.cfg"


## Switch to next/previous background
func _switch_background(direction: int) -> void:
	if AVAILABLE_BACKGROUNDS.size() <= 1:
		return

	# Store current config before switching
	_store_current_bg_config()

	# Change index with wraparound
	current_bg_index = (current_bg_index + direction) % AVAILABLE_BACKGROUNDS.size()
	if current_bg_index < 0:
		current_bg_index = AVAILABLE_BACKGROUNDS.size() - 1

	_apply_current_background()
	var bg_name := _get_bg_filename(AVAILABLE_BACKGROUNDS[current_bg_index])
	DebugService.log(DebugService.ARENA, "SWITCHED to background: ", bg_name, " [", current_bg_index + 1, "/", AVAILABLE_BACKGROUNDS.size(), "]")


## Apply the current background texture and load its saved config
func _apply_current_background() -> void:
	if current_bg_index < 0 or current_bg_index >= AVAILABLE_BACKGROUNDS.size():
		return

	var bg_path := AVAILABLE_BACKGROUNDS[current_bg_index]
	var texture = load(bg_path)

	if texture:
		bg_sprite.texture = texture
		bg_sprite.visible = true

		# Load config for this specific background
		if bg_configs.has(bg_path):
			bg_offset = bg_configs[bg_path].get("offset", Vector2.ZERO)
			bg_zoom = bg_configs[bg_path].get("scale", Vector2.ONE)
		else:
			bg_offset = Vector2.ZERO
			bg_zoom = Vector2.ONE

		bg_sprite.position = bg_offset
		bg_sprite.scale = bg_zoom
		DebugService.log(DebugService.ARENA, "Arena BG Loaded: ", _get_bg_filename(bg_path), " | Size: ", texture.get_size())
	else:
		DebugService.error(DebugService.VALIDATION, "Failed to load background: ", bg_path)


## Store current background's config in memory
func _store_current_bg_config() -> void:
	if current_bg_index < 0 or current_bg_index >= AVAILABLE_BACKGROUNDS.size():
		return
	var bg_path := AVAILABLE_BACKGROUNDS[current_bg_index]
	bg_configs[bg_path] = {"offset": bg_offset, "scale": bg_zoom}


## Get just the filename from a path for display
func _get_bg_filename(path: String) -> String:
	return path.get_file()


## Save all background configs to file
func _save_all_bg_configs() -> void:
	_store_current_bg_config() # Ensure current is saved

	var config = ConfigFile.new()
	for bg_path in bg_configs.keys():
		var section := _get_bg_filename(bg_path)
		config.set_value(section, "offset", bg_configs[bg_path]["offset"])
		config.set_value(section, "scale", bg_configs[bg_path]["scale"])

	config.save(CONFIG_PATH)
	var global_path = ProjectSettings.globalize_path(CONFIG_PATH)
	DebugService.log(DebugService.ARENA, "SAVED all background configs to: ", global_path)


## Load all background configs from file
func _load_all_bg_configs() -> void:
	bg_configs.clear()
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)

	if err != OK:
		DebugService.log(DebugService.ARENA, "No saved background configs found, using defaults.")
		return

	# Migration: Check for old [alignment] section format
	if config.has_section("alignment"):
		var old_offset = config.get_value("alignment", "offset", Vector2.ZERO)
		var old_scale = config.get_value("alignment", "scale", Vector2.ONE)
		# Apply old settings to the first (original) background
		if AVAILABLE_BACKGROUNDS.size() > 0:
			var first_bg := AVAILABLE_BACKGROUNDS[0]
			bg_configs[first_bg] = {"offset": old_offset, "scale": old_scale}
			DebugService.log(DebugService.ARENA, "MIGRATED old alignment config to: ", _get_bg_filename(first_bg))
		return # Skip new format loading if migrating

	# Load configs for each available background (new format)
	for bg_path in AVAILABLE_BACKGROUNDS:
		var section := _get_bg_filename(bg_path)
		if config.has_section(section):
			bg_configs[bg_path] = {
				"offset": config.get_value(section, "offset", Vector2.ZERO),
				"scale": config.get_value(section, "scale", Vector2.ONE)
			}

	DebugService.log(DebugService.ARENA, "LOADED background configs from: ", ProjectSettings.globalize_path(CONFIG_PATH))
