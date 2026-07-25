extends Node2D

var duration: float = 2.0
var elapsed: float = 0.0

## Assigned by NodePool. Called instead of queue_free() when the animation ends.
var pool_release: Callable = Callable()

var _tween: Tween = null

@onready var label: Label = $Label

func _ready() -> void:
	# Render above all gameplay entities
	z_index = 100


## Clear everything setup() and the HUD may have changed, so a pooled instance
## does not inherit the previous use's crit scale or DoT tint.
func _pool_released() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

	elapsed = 0.0
	scale = Vector2.ONE
	modulate = Color.WHITE
	if label:
		label.modulate = Color.WHITE

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
	
	# Start animation AFTER position has been set by the caller
	# Rise 25% of distance, pause, then fade
	var rise_distance: float = 40.0 # Rise distance in pixels
	var rise_duration: float = duration * 0.25 # Rise in first 25% of time
	var pause_duration: float = duration * 0.25 # Pause for next 25%
	var fade_duration: float = duration * 0.5 # Fade during remaining 50%
	
	# Kill any animation left over from a previous pooled use
	if _tween != null and _tween.is_valid():
		_tween.kill()

	var tween = create_tween()
	_tween = tween

	# Phase 1: Rise up quickly
	tween.tween_property(self, "position:y", position.y - rise_distance, rise_duration).set_ease(Tween.EASE_OUT)

	# Phase 2: Pause (just wait)
	tween.tween_interval(pause_duration)

	# Phase 3: Fade out and shrink (parallel with each other)
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, fade_duration).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), fade_duration).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)

	# Return to the pool after the animation completes, or free if unpooled
	tween.tween_callback(_finish)


## End of life: hand back to the pool when pooled, otherwise free as before.
func _finish() -> void:
	_tween = null
	if pool_release.is_valid():
		pool_release.call(self)
	else:
		queue_free()
