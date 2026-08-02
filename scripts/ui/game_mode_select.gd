class_name GameModeSelectUI
extends ScalableUIPanel

## Handles game mode selection screen (three-stage: spawn + win condition + arena type)

# Spawn location buttons
var sentinel_button: Button
var invasion_button: Button

# Win condition buttons
var survival_button: Button
var tech_defense_button: Button
var tunneling_timed_button: Button
var tunneling_alert_button: Button
var escort_button: Button

# Arena type buttons
var classic_arena_button: Button
var isometric_arena_button: Button

# UI state
var selected_spawn_mode: GameEnums.GameMode = GameEnums.GameMode.SENTINEL
var selected_win_mode: GameEnums.GameMode = GameEnums.GameMode.SURVIVAL
var selected_arena_mode: GameEnums.GameMode = GameEnums.GameMode.ARENA_RECTANGULAR
var current_stage: int = 1 # 1 = spawn location, 2 = win condition, 3 = arena type

var title_label: Label
var subtitle_label: Label
var button_container: VBoxContainer

# Base values at 1080p
const BASE_PANEL_WIDTH: float = 600.0
const BASE_PANEL_HEIGHT: float = 500.0
const BASE_BUTTON_HEIGHT: float = 60.0


func setup(nodes: Dictionary, owner: Node) -> void:
	sentinel_button = nodes.get("sentinel_button")
	invasion_button = nodes.get("invasion_button")
	
	# Get win condition buttons
	survival_button = nodes.get("survival_button")
	tech_defense_button = nodes.get("tech_defense_button")
	tunneling_timed_button = nodes.get("tunneling_timed_button")
	tunneling_alert_button = nodes.get("tunneling_alert_button")
	
	# Get arena type buttons
	classic_arena_button = nodes.get("classic_arena_button")
	isometric_arena_button = nodes.get("isometric_arena_button")
	
	# Get UI elements
	title_label = nodes.get("title_label")
	subtitle_label = nodes.get("subtitle_label")
	button_container = nodes.get("button_container")
	_ensure_dynamic_mode_buttons()
	
	# Note: Button connections are handled in hud.tscn scene file
	
	base_panel_size = Vector2(BASE_PANEL_WIDTH, BASE_PANEL_HEIGHT)
	
	# Call parent setup
	super.setup(nodes, owner)


func _scale_fonts(scale: float) -> void:
	# Scale button heights if needed
	for button in [sentinel_button, invasion_button, survival_button, tech_defense_button,
			tunneling_timed_button, tunneling_alert_button, classic_arena_button, isometric_arena_button, escort_button]:
		if button:
			button.custom_minimum_size.y = UIScaler.scale(BASE_BUTTON_HEIGHT)


func show() -> void:
	selected_spawn_mode = GameModeRegistry.get_default_mode_for_group("spawn_location") as GameEnums.GameMode
	selected_win_mode = GameModeRegistry.get_default_mode_for_group("win_condition") as GameEnums.GameMode
	selected_arena_mode = GameModeRegistry.get_default_mode_for_group("arena_type") as GameEnums.GameMode
	current_stage = 1
	_show_spawn_location_selection()
	
	if container:
		container.visible = true
		container.modulate.a = 0.0
		var tween = _owner.create_tween()
		tween.tween_property(container, "modulate:a", 1.0, 0.3)


func _hide_all_buttons() -> void:
	"""Helper to hide all selection buttons."""
	for button in [sentinel_button, invasion_button, survival_button, tech_defense_button,
			tunneling_timed_button, tunneling_alert_button, classic_arena_button, isometric_arena_button, escort_button]:
		if button:
			button.visible = false


func _ensure_dynamic_mode_buttons() -> void:
	"""Keep the legacy selector usable for registry modes not in the scene."""
	if not button_container or escort_button:
		return

	escort_button = Button.new()
	escort_button.name = "EscortButton"
	escort_button.custom_minimum_size = Vector2(0, BASE_BUTTON_HEIGHT)
	escort_button.add_theme_font_size_override("font_size", 20)
	escort_button.text = "Escort - Defend the moving target"
	escort_button.pressed.connect(func(): on_win_condition_selected(GameEnums.GameMode.ESCORT))
	button_container.add_child(escort_button)


func _show_mode_button(button: Button, mode_id: GameEnums.GameMode) -> bool:
	if not button:
		return false
	button.visible = GameModeRegistry.is_mode_enabled(mode_id)
	return button.visible


func _show_spawn_location_selection() -> void:
	"""Show stage 1: spawn location selection."""
	current_stage = 1
	
	if title_label:
		title_label.text = "SELECT SPAWN MODE"
	if subtitle_label:
		subtitle_label.text = "Where should enemies spawn?"
	
	_hide_all_buttons()
	
	# Show only spawn location buttons
	var first_button: Button = null
	if _show_mode_button(sentinel_button, GameEnums.GameMode.SENTINEL):
		first_button = sentinel_button
	_show_mode_button(invasion_button, GameEnums.GameMode.INVASION)
	if first_button:
		first_button.grab_focus()


func _show_win_condition_selection() -> void:
	"""Show stage 2: win condition selection."""
	current_stage = 2
	
	# TEMPORARY: If win condition buttons don't exist in scene yet, skip to arena
	if not survival_button and not tech_defense_button:
		DebugService.log(DebugService.UI, "Win condition buttons not in scene - auto-selecting SURVIVAL mode")
		selected_win_mode = GameEnums.GameMode.SURVIVAL
		_show_arena_type_selection()
		return
	
	if title_label:
		title_label.text = "SELECT WIN CONDITION"
	if subtitle_label:
		subtitle_label.text = "How do you want to win?"
	
	_hide_all_buttons()
	
	# Show win condition buttons
	var first_button: Button = null
	if _show_mode_button(survival_button, GameEnums.GameMode.SURVIVAL):
		first_button = survival_button
	if first_button == null and _show_mode_button(tech_defense_button, GameEnums.GameMode.TECH_DEFENSE):
		first_button = tech_defense_button
	_show_mode_button(tunneling_timed_button, GameEnums.GameMode.TUNNELING_TIMED)
	_show_mode_button(tunneling_alert_button, GameEnums.GameMode.TUNNELING_ALERT)
	_show_mode_button(escort_button, GameEnums.GameMode.ESCORT)
	if first_button:
		first_button.grab_focus()


func _show_arena_type_selection() -> void:
	"""Show stage 3: arena type selection."""
	current_stage = 3
	
	# Skip if arena buttons don't exist
	if not classic_arena_button and not isometric_arena_button:
		DebugService.log(DebugService.UI, "Arena type buttons not in scene - auto-selecting RECTANGULAR")
		on_arena_type_selected(GameEnums.GameMode.ARENA_RECTANGULAR)
		return
	
	if title_label:
		title_label.text = "SELECT ARENA TYPE"
	if subtitle_label:
		subtitle_label.text = "Choose your arena shape"
	
	_hide_all_buttons()
	
	# Show arena type buttons
	var first_button: Button = null
	if _show_mode_button(classic_arena_button, GameEnums.GameMode.ARENA_RECTANGULAR):
		first_button = classic_arena_button
	if first_button == null and _show_mode_button(isometric_arena_button, GameEnums.GameMode.ARENA_ISOMETRIC):
		first_button = isometric_arena_button
	if first_button:
		first_button.grab_focus()

func on_spawn_mode_selected(mode: GameEnums.GameMode) -> void:
	"""Called when a spawn location mode is selected."""
	if not GameModeRegistry.is_mode_enabled(mode):
		return
	selected_spawn_mode = mode
	_show_win_condition_selection()


func on_win_condition_selected(mode: GameEnums.GameMode) -> void:
	"""Called when a win condition mode is selected. Advances to arena selection."""
	if not GameModeRegistry.is_mode_enabled(mode):
		return
	selected_win_mode = mode
	_show_arena_type_selection()


func on_arena_type_selected(mode: GameEnums.GameMode) -> void:
	"""Called when an arena type is selected. Sets all modes and starts game."""
	if not GameModeRegistry.is_mode_enabled(mode):
		return
	selected_arena_mode = mode
	
	# Set all three modes via GameModeService
	GameModeService.set_mode(selected_spawn_mode)
	GameModeService.set_mode(selected_win_mode)
	GameModeService.set_mode(selected_arena_mode)
	
	# Emit game_mode_selected with the win mode to trigger game start
	Events.game_mode_selected.emit(selected_win_mode)
	
	# Hide the screen
	hide_screen()


func hide_screen() -> void:
	"""Hide the mode selection screen."""
	if container:
		var tween = _owner.create_tween()
		tween.tween_property(container, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func():
			container.visible = false
		)
