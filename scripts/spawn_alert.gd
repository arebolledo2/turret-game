extends Node2D

const ALERT_DURATION: float = 1.5
const OUTER_RADIUS: float = 40.0
const INNER_RADIUS: float = 25.0
const PULSE_SPEED: float = 3.0

var time_remaining: float = ALERT_DURATION
var outer_circle: Polygon2D
var inner_circle: Polygon2D

func _ready() -> void:
	# Render above all gameplay entities
	z_index = 100

	outer_circle = $OuterCircle
	inner_circle = $InnerCircle

	# Create circle polygons
	_create_circle_polygon(outer_circle, OUTER_RADIUS)
	_create_circle_polygon(inner_circle, INNER_RADIUS)

func _create_circle_polygon(polygon: Polygon2D, radius: float) -> void:
	var points: PackedVector2Array = []
	var num_points := 32

	for i in range(num_points):
		var angle := (i / float(num_points)) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * radius)

	polygon.polygon = points

func _process(delta: float) -> void:
	time_remaining -= delta

	if time_remaining <= 0:
		queue_free()
		return

	# Pulsing animation
	var pulse := (sin(time_remaining * PULSE_SPEED * TAU) + 1.0) / 2.0

	# Fade out as time runs out
	var alpha := clampf(time_remaining / ALERT_DURATION, 0.0, 1.0)

	# Pulse the opacity
	var pulse_alpha := 0.3 + (pulse * 0.3)
	outer_circle.modulate.a = pulse_alpha * alpha
	inner_circle.modulate.a = (pulse_alpha + 0.2) * alpha

	# Scale pulse effect
	var scale_factor := 1.0 + (pulse * 0.15)
	scale = Vector2.ONE * scale_factor
