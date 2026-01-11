class_name GameOverScreenUI
extends ScalableUIPanel

## Handles game over / victory screen display

var title_label: Label
var stats_label: Label
var restart_button: Button

# Base values at 1080p
const BASE_PANEL_WIDTH: float = 400.0
const BASE_PANEL_HEIGHT: float = 300.0
const BASE_BUTTON_HEIGHT: float = 40.0


func setup(nodes: Dictionary, owner: Node) -> void:
	title_label = nodes.get("title")
	stats_label = nodes.get("stats")
	restart_button = nodes.get("restart_button")

	# Set base size
	base_panel_size = Vector2(BASE_PANEL_WIDTH, BASE_PANEL_HEIGHT)

	# Call parent setup
	super.setup(nodes, owner)

	# Register fonts using centralized FontSizes
	if title_label:
		register_font(title_label, FontSizes.HEADING_2)
	if stats_label:
		register_font(stats_label, FontSizes.BODY_SMALL)


func _scale_fonts(scale: float) -> void:
	if title_label:
		title_label.add_theme_font_size_override("font_size", FontSizes.get_scaled(FontSizes.HEADING_2))
	if stats_label:
		stats_label.add_theme_font_size_override("font_size", FontSizes.get_scaled(FontSizes.BODY_SMALL))

	# Scale button
	if restart_button:
		restart_button.custom_minimum_size.y = UIScaler.scale(BASE_BUTTON_HEIGHT)


func show_game_over(victory: bool) -> void:
	if not container or not title_label or not stats_label:
		return

	# Set title based on victory/defeat
	title_label.text = "VICTORY!" if victory else "GAME OVER"
	title_label.modulate = Color.GREEN if victory else Color.RED

	# Format stats
	var total_time = GameStateService.time_survived
	var time_minutes := int(total_time / 60.0)
	var time_seconds := int(total_time) % 60
	stats_label.text = """Wave Reached: %d
Enemies Killed: %d
Scrap Collected: %d
Turrets Spawned: %d
Time Survived: %d:%02d""" % [
		GameStateService.current_wave,
		GameStateService.total_kills,
		EconomyService.total_scrap,
		GameStateService.turrets_spawned,
		time_minutes, time_seconds
	]

	# Show with fade animation
	container.visible = true
	container.modulate.a = 0.0
	var tween = _owner.create_tween()
	tween.tween_property(container, "modulate:a", 1.0, 0.5)

	if restart_button:
		restart_button.grab_focus()


func hide() -> void:
	if container:
		container.visible = false
