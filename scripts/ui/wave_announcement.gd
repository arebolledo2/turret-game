class_name WaveAnnouncementUI
extends ScalableUIPanel

## Handles wave announcement overlay display

var label: Label

# Base values at 1080p
const BASE_PANEL_WIDTH: float = 400.0
const BASE_PANEL_HEIGHT: float = 100.0


func setup(nodes: Dictionary, owner: Node) -> void:
	label = nodes.get("label")

	# Set base size
	base_panel_size = Vector2(BASE_PANEL_WIDTH, BASE_PANEL_HEIGHT)

	# Call parent setup
	super.setup(nodes, owner)

	# Register fonts using centralized FontSizes
	if label:
		register_font(label, FontSizes.HEADING_1)


func _scale_fonts(scale: float) -> void:
	if label:
		label.add_theme_font_size_override("font_size", FontSizes.get_scaled(FontSizes.HEADING_1))


func show_announcement(wave_number: int) -> void:
	if container and label:
		label.text = "Wave %d" % wave_number
		container.visible = true

		# Animate in
		container.modulate.a = 0.0
		container.scale = Vector2(0.5, 0.5)
		var tween = _owner.create_tween()
		tween.set_parallel(true)
		tween.tween_property(container, "modulate:a", 1.0, 0.3)
		tween.tween_property(container, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func hide_announcement() -> void:
	if container:
		var tween = _owner.create_tween()
		tween.tween_property(container, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func(): container.visible = false)
