extends Node2D

var float_speed: float = 80.0
var duration: float = 0.6
var elapsed: float = 0.0

@onready var label: Label = $Label

func _ready() -> void:
	# Render above all gameplay entities
	z_index = 100

	# Start animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 40, duration).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN).set_delay(duration * 0.5)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), duration).set_ease(Tween.EASE_IN).set_delay(duration * 0.3)
	tween.chain().tween_callback(queue_free)

func setup(amount: float, is_crit: bool = false) -> void:
	if label:
		label.text = str(int(amount))

		# Apply crit styling
		if is_crit:
			# Gold color for crits
			label.add_theme_color_override("font_color", Color("#FFD700"))
			# Larger size for crits (22 vs 16)
			label.add_theme_font_size_override("font_size", 22)
			# Slightly more dramatic spawn scale
			scale = Vector2(1.2, 1.2)
		else:
			# Normal white color
			label.add_theme_color_override("font_color", Color.WHITE)
			label.add_theme_font_size_override("font_size", 16)
