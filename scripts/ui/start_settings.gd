class_name StartSettingsUI
extends ScalableUIPanel

## Handles consolidated start settings screen

var difficulty_dropdown: OptionButton
var spawn_dropdown: OptionButton
var mode_dropdown: OptionButton
var arena_dropdown: OptionButton
var bg_dropdown: OptionButton
var start_button: Button

# Base values at 1080p
const BASE_PANEL_WIDTH: float = 600.0
const BASE_PANEL_HEIGHT: float = 500.0
const BASE_ELEMENT_HEIGHT: float = 50.0


func setup(nodes: Dictionary, owner: Node) -> void:
	difficulty_dropdown = nodes.get("difficulty_dropdown")
	spawn_dropdown = nodes.get("spawn_dropdown")
	mode_dropdown = nodes.get("mode_dropdown")
	arena_dropdown = nodes.get("arena_dropdown")
	bg_dropdown = nodes.get("bg_dropdown")
	start_button = nodes.get("start_button")

	_setup_options()

	# Set base size
	base_panel_size = Vector2(BASE_PANEL_WIDTH, BASE_PANEL_HEIGHT)

	# Call parent setup
	super.setup(nodes, owner)

	# Connect start button
	if start_button:
		start_button.pressed.connect(_on_start_pressed)


func _setup_options() -> void:
	# Difficulty Options
	if difficulty_dropdown:
		difficulty_dropdown.clear()
		difficulty_dropdown.add_item("Easy", GameEnums.Difficulty.EASY)
		difficulty_dropdown.add_item("Medium", GameEnums.Difficulty.MEDIUM)
		difficulty_dropdown.add_item("Hard", GameEnums.Difficulty.HARD)
		# Default to Medium
		difficulty_dropdown.select(1)

	# Spawn Mode (Wave Structure) Options
	if spawn_dropdown:
		spawn_dropdown.clear()
		spawn_dropdown.add_item("Sentinel (Edges)", GameEnums.GameMode.SENTINEL)
		spawn_dropdown.add_item("Invasion (Anywhere)", GameEnums.GameMode.INVASION)
		# Default to Sentinel
		spawn_dropdown.select(0)

	# Game Mode (Win Condition) Options
	if mode_dropdown:
		mode_dropdown.clear()
		mode_dropdown.add_item("Survival", GameEnums.GameMode.SURVIVAL)
		mode_dropdown.add_item("Tech Defense", GameEnums.GameMode.TECH_DEFENSE)
		mode_dropdown.add_item("Tunneling (Timed)", GameEnums.GameMode.TUNNELING_TIMED)
		mode_dropdown.add_item("Tunneling (Alert)", GameEnums.GameMode.TUNNELING_ALERT)
		mode_dropdown.add_item("Escort", GameEnums.GameMode.ESCORT)
		# Default to Defense (Tech Defense is index 1)
		mode_dropdown.select(1)

	# Arena Type Options
	if arena_dropdown:
		arena_dropdown.clear()
		arena_dropdown.add_item("Classic", GameEnums.GameMode.ARENA_RECTANGULAR)
		arena_dropdown.add_item("Isometric", GameEnums.GameMode.ARENA_ISOMETRIC)
		# Default to Isometric
		arena_dropdown.select(1)
		arena_dropdown.item_selected.connect(_on_arena_type_selected)

	# Background Options
	if bg_dropdown:
		bg_dropdown.clear()
		bg_dropdown.add_item("Factory Ruins", 0)
		bg_dropdown.add_item("Desert Outpost", 1)
		bg_dropdown.add_item("Neon District", 2)
		bg_dropdown.add_item("Dorama 1", 3)
		# Default to Desert Outpost
		bg_dropdown.select(1)
		# Initially visible only if isometric is selected (which is default)
		bg_dropdown.disabled = false


func _scale_fonts(scale: float) -> void:
	# Scale elements if needed
	for element in [difficulty_dropdown, spawn_dropdown, mode_dropdown, arena_dropdown, bg_dropdown, start_button]:
		if element:
			element.custom_minimum_size.y = UIScaler.scale(BASE_ELEMENT_HEIGHT)


func show() -> void:
	if container:
		container.visible = true
		container.modulate.a = 0.0
		var tween = _owner.create_tween()
		tween.tween_property(container, "modulate:a", 1.0, 0.3)
		if start_button:
			start_button.grab_focus()


func hide_screen() -> void:
	if container:
		var tween = _owner.create_tween()
		tween.tween_property(container, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func():
			container.visible = false
		)


func _on_start_pressed() -> void:
	var difficulty = difficulty_dropdown.get_selected_id()
	var spawn_mode = spawn_dropdown.get_selected_id()
	var win_mode = mode_dropdown.get_selected_id()
	var arena_mode = arena_dropdown.get_selected_id()
	var bg_index = bg_dropdown.get_selected_id()
	
	Events.start_settings_applied.emit(difficulty, spawn_mode, win_mode, arena_mode, bg_index)
	hide_screen()


func _on_arena_type_selected(index: int) -> void:
	var arena_mode = arena_dropdown.get_item_id(index)
	if bg_dropdown:
		bg_dropdown.disabled = (arena_mode != GameEnums.GameMode.ARENA_ISOMETRIC)
