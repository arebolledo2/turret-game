extends Control

## Individual off-screen indicator - Displays arrow, count, and animations
## Shows directional arrow pointing toward off-screen entities
## Supports grouping with count display and spawn alert pulsing

const ARROW_SIZE: float = 20.0
const PULSE_SPEED: float = 2.0
const COUNT_LABEL_OFFSET: Vector2 = Vector2(25, -5)

var direction: Vector2 = Vector2.RIGHT
var entity_count: int = 1
var category: String = "enemy"
var entity_type: String = ""
var is_spawn_alert: bool = false

@onready var arrow_polygon: Polygon2D = $ArrowPolygon
@onready var count_label: Label = $CountLabel

var pulse_tween: Tween = null


func _ready() -> void:
	# Set up count label
	count_label.visible = false
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Initial draw
	_update_arrow()


## Setup indicator with entity data
func setup(p_direction: Vector2, p_count: int, p_category: String, p_type: String = "") -> void:
	direction = p_direction.normalized()
	entity_count = p_count
	category = p_category
	entity_type = p_type
	is_spawn_alert = (category == "spawn")

	_update_arrow()
	_update_count_label()
	_update_color()

	# Start pulse animation for spawn alerts
	if is_spawn_alert:
		_start_pulse_animation()
	else:
		_stop_pulse_animation()


## Update arrow direction and shape
func _update_arrow() -> void:
	if not arrow_polygon:
		return

	# Calculate rotation angle
	var angle := direction.angle()

	# Create arrow triangle pointing in the direction
	# Arrow points TOWARD the screen center (inward), so we invert the direction
	var inward_angle := (-direction).angle()

	var points := PackedVector2Array([
		Vector2(15, 0).rotated(inward_angle),        # Arrow tip (points inward)
		Vector2(-10, -8).rotated(inward_angle),      # Left wing
		Vector2(-10, 8).rotated(inward_angle),       # Right wing
	])

	arrow_polygon.polygon = points

	# Also create an outline for better visibility
	var outline_color := Color.BLACK
	outline_color.a = 0.7


## Update count label visibility and text
func _update_count_label() -> void:
	if not count_label:
		return

	if entity_count > 1:
		count_label.visible = true
		if entity_count >= 10:
			count_label.text = "10+"
		else:
			count_label.text = "x%d" % entity_count

		# Position label next to arrow
		count_label.position = COUNT_LABEL_OFFSET
	else:
		count_label.visible = false


## Update color based on category
func _update_color() -> void:
	if not arrow_polygon:
		return

	var color := OffScreenIndicatorService.get_category_color(category)
	arrow_polygon.color = color

	# Lighter color for outline
	var outline_color := color.lightened(0.3)
	outline_color.a = 0.8


## Start pulse animation for spawn alerts
func _start_pulse_animation() -> void:
	if pulse_tween:
		pulse_tween.kill()

	pulse_tween = create_tween()
	pulse_tween.set_loops()

	# Opacity pulse
	pulse_tween.tween_property(self, "modulate:a", 0.5, 0.4)
	pulse_tween.tween_property(self, "modulate:a", 1.0, 0.4)

	# Scale pulse
	pulse_tween.parallel().tween_property(self, "scale", Vector2.ONE * 1.2, 0.4)
	pulse_tween.tween_property(self, "scale", Vector2.ONE, 0.4)


## Stop pulse animation
func _stop_pulse_animation() -> void:
	if pulse_tween:
		pulse_tween.kill()
		pulse_tween = null

	modulate.a = 1.0
	scale = Vector2.ONE


func _exit_tree() -> void:
	if pulse_tween:
		pulse_tween.kill()
