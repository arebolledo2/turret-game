class_name GameModeSelectUI
extends ScalableUIPanel

## Handles game mode selection screen (two-stage: spawn + win condition)

# Spawn location buttons
var sentinel_button: Button
var invasion_button: Button

# Win condition buttons (to be added to scene)
var survival_button: Button
var tech_defense_button: Button
var tunneling_timed_button: Button
var tunneling_alert_button: Button

# UI state
var selected_spawn_mode: GameEnums.GameMode = GameEnums.GameMode.SENTINEL
var selected_win_mode: GameEnums.GameMode = GameEnums.GameMode.SURVIVAL
var current_stage: int = 1 # 1 = spawn location, 2 = win condition

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
	
	# Get new win condition buttons (if they exist)
	survival_button = nodes.get("survival_button")
	tech_defense_button = nodes.get("tech_defense_button")
	tunneling_timed_button = nodes.get("tunneling_timed_button")
	tunneling_alert_button = nodes.get("tunneling_alert_button")
	
	# Get UI elements
	title_label = nodes.get("title_label")
	subtitle_label = nodes.get("subtitle_label")
	button_container = nodes.get("button_container")
	
	# Note: Button connections are handled in hud.tscn scene file
	# No need to connect them here to avoid duplicate signal emissions
	
	base_panel_size = Vector2(BASE_PANEL_WIDTH, BASE_PANEL_HEIGHT)
	
	# Call parent setup
	super.setup(nodes, owner)


func _scale_fonts(scale: float) -> void:
	# Scale button heights if needed
	for button in [sentinel_button, invasion_button, survival_button, tech_defense_button, tunneling_timed_button, tunneling_alert_button]:
		if button:
			button.custom_minimum_size.y = UIScaler.scale(BASE_BUTTON_HEIGHT)


func show() -> void:
	current_stage = 1
	_show_spawn_location_selection()
	
	if container:
		container.visible = true
		container.modulate.a = 0.0
		var tween = _owner.create_tween()
		tween.tween_property(container, "modulate:a", 1.0, 0.3)


func _show_spawn_location_selection() -> void:
	"""Show stage 1: spawn location selection."""
	current_stage = 1
	
	if title_label:
		title_label.text = "SELECT SPAWN MODE"
	if subtitle_label:
		subtitle_label.text = "Where should enemies spawn?"
	
	# Show only spawn location buttons
	if sentinel_button:
		sentinel_button.visible = true
		sentinel_button.grab_focus()
	if invasion_button:
		invasion_button.visible = true
	
	# Hide win condition buttons
	if survival_button:
		survival_button.visible = false
	if tech_defense_button:
		tech_defense_button.visible = false
	if tunneling_timed_button:
		tunneling_timed_button.visible = false
	if tunneling_alert_button:
		tunneling_alert_button.visible = false


func _show_win_condition_selection() -> void:
	"""Show stage 2: win condition selection."""
	current_stage = 2
	
	# TEMPORARY: If win condition buttons don't exist in scene yet, auto-select SURVIVAL
	if not survival_button and not tech_defense_button:
		print("Win condition buttons not in scene - auto-selecting SURVIVAL mode")
		on_win_condition_selected(GameEnums.GameMode.SURVIVAL)
		return
	
	if title_label:
		title_label.text = "SELECT WIN CONDITION"
	if subtitle_label:
		subtitle_label.text = "How do you want to win?"
	
	# Hide spawn location buttons
	if sentinel_button:
		sentinel_button.visible = false
	if invasion_button:
		invasion_button.visible = false
	
	# Show win condition buttons
	if survival_button:
		survival_button.visible = true
		survival_button.grab_focus()
	if tech_defense_button:
		tech_defense_button.visible = true
	if tunneling_timed_button:
		tunneling_timed_button.visible = true
	if tunneling_alert_button:
		tunneling_alert_button.visible = true


func on_spawn_mode_selected(mode: GameEnums.GameMode) -> void:
	"""Called when a spawn location mode is selected."""
	selected_spawn_mode = mode
	_show_win_condition_selection()


func on_win_condition_selected(mode: GameEnums.GameMode) -> void:
	"""Called when a win condition mode is selected. Sets both modes and starts game."""
	selected_win_mode = mode
	
	# Set both modes directly via GameModeService (don't trigger game start yet)
	GameModeService.set_mode(selected_spawn_mode)
	GameModeService.set_mode(selected_win_mode)
	
	# Now emit game_mode_selected with the win mode to trigger game start
	# (game_manager will see both modes are already set)
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
