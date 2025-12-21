class_name DifficultySelectUI
extends ScalableUIPanel

## Handles difficulty selection screen

var easy_button: Button

# Base values at 1080p
const BASE_PANEL_WIDTH: float = 500.0
const BASE_PANEL_HEIGHT: float = 400.0
const BASE_BUTTON_HEIGHT: float = 50.0


func setup(nodes: Dictionary, owner: Node) -> void:
	easy_button = nodes.get("easy_button")

	# Set base size
	base_panel_size = Vector2(BASE_PANEL_WIDTH, BASE_PANEL_HEIGHT)

	# Call parent setup
	super.setup(nodes, owner)


func _scale_fonts(scale: float) -> void:
	# Scale button heights if needed
	if easy_button:
		easy_button.custom_minimum_size.y = UIScaler.scale(BASE_BUTTON_HEIGHT)


func show() -> void:
	if container:
		container.visible = true
		container.modulate.a = 0.0
		var tween = _owner.create_tween()
		tween.tween_property(container, "modulate:a", 1.0, 0.3)
		if easy_button:
			easy_button.grab_focus()


func hide_and_emit(difficulty: Globals.Difficulty) -> void:
	if container:
		var tween = _owner.create_tween()
		tween.tween_property(container, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func():
			container.visible = false
			Events.difficulty_selected.emit(difficulty)
		)
