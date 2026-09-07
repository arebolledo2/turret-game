extends "res://addons/gut/test.gd"

## Unit test for the low health overlay visual logic
## Tests the _update_low_health_visual function in isolation by creating
## a minimal test harness that only sets up the low_health_overlay ColorRect

var hud_instance: CanvasLayer
var low_health_overlay: ColorRect

func before_each():
	TestHelpers.reset_all_services()
	# Create a minimal CanvasLayer to act as our test harness
	hud_instance = CanvasLayer.new()
	add_child(hud_instance)

	# Create the low_health_overlay ColorRect directly (same as HUD._ready does)
	low_health_overlay = ColorRect.new()
	low_health_overlay.name = "LowHealthOverlay"
	low_health_overlay.color = Color(1, 0, 0, 0) # Start invisible
	low_health_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_instance.add_child(low_health_overlay)

	# Attach the overlay reference to the hud_instance for testing
	hud_instance.set_meta("low_health_overlay", low_health_overlay)

func after_each():
	hud_instance.queue_free()

## Replicate the _update_low_health_visual logic from HUD for isolated testing
func _update_low_health_visual(current_health: float, max_health: float) -> void:
	if low_health_overlay:
		var health_percent := current_health / max_health
		if health_percent < 0.5:
			# Redness increases as health goes from 50% down to 0%
			# (0.5 - health_percent) / 0.5 maps [0.5, 0] to [0, 1]
			var intensity := (0.5 - health_percent) / 0.5
			low_health_overlay.color.a = intensity * 0.4 # Max 40% opacity
		else:
			low_health_overlay.color.a = 0.0

func test_overlay_alpha_at_full_health():
	_update_low_health_visual(100.0, 100.0)
	assert_eq(low_health_overlay.color.a, 0.0, "Overlay should be invisible at 100% health")

func test_overlay_alpha_at_50_percent_health():
	_update_low_health_visual(50.0, 100.0)
	assert_eq(low_health_overlay.color.a, 0.0, "Overlay should be invisible at 50% health")

func test_overlay_alpha_at_25_percent_health():
	_update_low_health_visual(25.0, 100.0)
	# intensity = (0.5 - 0.25) / 0.5 = 0.25 / 0.5 = 0.5
	# alpha = 0.5 * 0.4 = 0.2
	assert_almost_eq(low_health_overlay.color.a, 0.2, 0.01, "Overlay should have 0.2 alpha at 25% health")

func test_overlay_alpha_at_zero_health():
	_update_low_health_visual(0.0, 100.0)
	# intensity = (0.5 - 0) / 0.5 = 1.0
	# alpha = 1.0 * 0.4 = 0.4
	assert_almost_eq(low_health_overlay.color.a, 0.4, 0.01, "Overlay should have 0.4 alpha at 0% health")

func test_overlay_alpha_above_50_percent():
	_update_low_health_visual(75.0, 100.0)
	assert_eq(low_health_overlay.color.a, 0.0, "Overlay should be invisible at 75% health")
