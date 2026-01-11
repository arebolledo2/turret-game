extends Node2D

var duration: float = 2.0
var elapsed: float = 0.0

@onready var label: Label = $Label

func _ready() -> void:
	# Render above all gameplay entities
	z_index = 100

	# Start animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 20, duration).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN).set_delay(duration * 0.5)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), duration).set_ease(Tween.EASE_IN).set_delay(duration * 0.3)
	tween.chain().tween_callback(queue_free)

func setup(amount: float, is_crit: bool = false) -> void:
	if label:
		label.text = str(int(amount))

		# Apply crit styling using centralized FontSizes
		if is_crit:
			# White color for crits
			label.add_theme_color_override("font_color", Color.WHITE)
			# Larger size for crits
			label.add_theme_font_size_override("font_size", FontSizes.get_scaled(FontSizes.DAMAGE_CRIT))
			# Slightly more dramatic spawn scale
			scale = Vector2(1.4, 1.4)
		else:
			# Normal white color
			label.add_theme_color_override("font_color", Color.WHITE)
			label.add_theme_font_size_override("font_size", FontSizes.get_scaled(FontSizes.DAMAGE_NORMAL))
