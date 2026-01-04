extends "res://addons/gut/test.gd"

var HUD = load("res://scripts/hud.gd")
var hud_instance

func before_each():
	hud_instance = HUD.new()
	# Mock dependencies or ensure they don't crash
	# We need to manually add nodes that @onready variables expect if we want to test everything,
	# but for this logic we mainly care about low_health_overlay.
	
	# Manually trigger _ready logic that creates the overlay
	hud_instance._ready()
	add_child(hud_instance)

func after_each():
	hud_instance.free()

func test_overlay_alpha_at_full_health():
	hud_instance._update_low_health_visual(100.0, 100.0)
	assert_eq(hud_instance.low_health_overlay.color.a, 0.0, "Overlay should be invisible at 100% health")

func test_overlay_alpha_at_50_percent_health():
	hud_instance._update_low_health_visual(50.0, 100.0)
	assert_eq(hud_instance.low_health_overlay.color.a, 0.0, "Overlay should be invisible at 50% health")

func test_overlay_alpha_at_25_percent_health():
	hud_instance._update_low_health_visual(25.0, 100.0)
	# intensity = (0.5 - 0.25) / 0.5 = 0.25 / 0.5 = 0.5
	# alpha = 0.5 * 0.4 = 0.2
	assert_almost_eq(hud_instance.low_health_overlay.color.a, 0.2, 0.01, "Overlay should have 0.2 alpha at 25% health")

func test_overlay_alpha_at_zero_health():
	hud_instance._update_low_health_visual(0.0, 100.0)
	# intensity = (0.5 - 0) / 0.5 = 1.0
	# alpha = 1.0 * 0.4 = 0.4
	assert_almost_eq(hud_instance.low_health_overlay.color.a, 0.4, 0.01, "Overlay should have 0.4 alpha at 0% health")

func test_overlay_alpha_above_50_percent():
	hud_instance._update_low_health_visual(75.0, 100.0)
	assert_eq(hud_instance.low_health_overlay.color.a, 0.0, "Overlay should be invisible at 75% health")
