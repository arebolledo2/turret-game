class_name GameModeSelectUI
extends ScalableUIPanel

## Handles game mode selection screen

var sentinel_button: Button
var invasion_button: Button

# Base values at 1080p
const BASE_PANEL_WIDTH: float = 600.0
const BASE_PANEL_HEIGHT: float = 450.0
const BASE_BUTTON_HEIGHT: float = 60.0


func setup(nodes: Dictionary, owner: Node) -> void:
	sentinel_button = nodes.get("sentinel_button")
	invasion_button = nodes.get("invasion_button")

	# Note: Button connections are handled in hud.tscn scene file
	# No need to connect them here to avoid duplicate signal emissions

	base_panel_size = Vector2(BASE_PANEL_WIDTH, BASE_PANEL_HEIGHT)

	# Call parent setup
	super.setup(nodes, owner)


func _scale_fonts(scale: float) -> void:
	# Scale button heights if needed
	if sentinel_button:
		sentinel_button.custom_minimum_size.y = UIScaler.scale(BASE_BUTTON_HEIGHT)
	if invasion_button:
		invasion_button.custom_minimum_size.y = UIScaler.scale(BASE_BUTTON_HEIGHT)


func show() -> void:
	if container:
		container.visible = true
		container.modulate.a = 0.0
		var tween = _owner.create_tween()
		tween.tween_property(container, "modulate:a", 1.0, 0.3)
		if sentinel_button:
			sentinel_button.grab_focus()


func hide_and_emit(mode: GameEnums.GameMode) -> void:
	if container:
		var tween = _owner.create_tween()
		tween.tween_property(container, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func():
			container.visible = false
			Events.game_mode_selected.emit(mode)
		)
