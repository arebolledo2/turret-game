extends Node2D

# Draws a circle for the turret range indicator

@export var radius: float = 100.0
@export var color: Color = Color(0.3, 0.8, 0.3, 0.2)
@export var outline_color: Color = Color(0.3, 0.8, 0.3, 0.5)
@export var outline_width: float = 2.0

func _draw() -> void:
	# Draw filled circle
	draw_circle(Vector2.ZERO, radius, color)
	# Draw outline
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, outline_color, outline_width)

func set_radius(new_radius: float) -> void:
	radius = new_radius
	queue_redraw()
