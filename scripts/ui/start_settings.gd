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
	if not FeatureFlagService.flag_changed.is_connected(_on_feature_flag_changed):
		FeatureFlagService.flag_changed.connect(_on_feature_flag_changed)


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
		_populate_mode_dropdown(spawn_dropdown, "spawn_location")

	# Game Mode (Win Condition) Options
	if mode_dropdown:
		_populate_mode_dropdown(mode_dropdown, "win_condition")

	# Arena Type Options
	if arena_dropdown:
		_populate_mode_dropdown(arena_dropdown, "arena_type")
		if not arena_dropdown.item_selected.is_connected(_on_arena_type_selected):
			arena_dropdown.item_selected.connect(_on_arena_type_selected)

	# Background Options (populated from GameConstants)
	if bg_dropdown:
		bg_dropdown.clear()
		for i in GameConstants.BACKGROUNDS.size():
			bg_dropdown.add_item(GameConstants.BACKGROUNDS[i].name, i)
		# Default to Desert Outpost
		bg_dropdown.select(1)
		# Initially visible only if isometric is selected (which is default)
		bg_dropdown.disabled = false
		if arena_dropdown:
			bg_dropdown.disabled = arena_dropdown.get_selected_id() != GameEnums.GameMode.ARENA_ISOMETRIC


func _populate_mode_dropdown(dropdown: OptionButton, group: String) -> void:
	"""Build mode choices from the registry so disabled modes disappear everywhere."""
	dropdown.clear()
	var available_modes := GameModeRegistry.get_modes_in_group(group)
	var default_mode := GameModeRegistry.get_default_mode_for_group(group)

	for mode_id in available_modes:
		var config := GameModeRegistry.get_mode_config(mode_id)
		dropdown.add_item(str(config.get("name", mode_id)), mode_id)

	if available_modes.is_empty():
		dropdown.disabled = true
		return

	dropdown.disabled = false
	var selected_index := 0
	for index in range(available_modes.size()):
		if available_modes[index] == default_mode:
			selected_index = index
			break
	dropdown.select(selected_index)


func _on_feature_flag_changed(flag_id: String, _enabled: bool) -> void:
	if flag_id.begins_with("mode_"):
		_setup_options()


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
	if difficulty_dropdown == null or spawn_dropdown == null or mode_dropdown == null or arena_dropdown == null:
		return
	if spawn_dropdown.get_selected_id() < 0 or mode_dropdown.get_selected_id() < 0 or arena_dropdown.get_selected_id() < 0:
		return

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
