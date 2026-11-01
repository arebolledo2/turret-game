extends GutTest

## Room-reactive lamps (`ArenaRoom.set_alert`, driven by `ArenaStage.set_floor_wave`) and the tower lanterns' flicker. The lamps, glow
## pools and lantern lights tint towards the alert colour and the lamps pulse while an alert lasts; at amount 0 everything is exactly
## the theme's colours again. Headless runs cannot render, so these check the material and light values.

const BOSS_COLOR: Color = Color(1.0, 0.45, 0.85)

var world: ArenaWorld
var room: ArenaRoom

func before_each() -> void:
	TestHelpers.reset_all_services()
	FeatureFlagService.set_enabled(FeatureFlagService.TERRAIN_ZONES, true)
	world = ArenaWorld.new()
	world.auto_start = false
	world.show_hud = false
	add_child_autofree(world)
	world.start_run()
	room = world.stage.room

func _peak(color: Color) -> float:
	return maxf(color.r, maxf(color.g, color.b))

func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()

## The colour scaled so its brightest channel is 1 (the pools breathe with the lamps, so only their hue is fixed).
func _hue(color: Color) -> Color:
	var peak := _peak(color)
	return Color(color.r / peak, color.g / peak, color.b / peak, 1.0)

func _assert_rgb(got: Color, want: Color, tolerance: float, message: String = "") -> void:
	assert_almost_eq(got.r, want.r, tolerance, "%s r" % message)
	assert_almost_eq(got.g, want.g, tolerance, "%s g" % message)
	assert_almost_eq(got.b, want.b, tolerance, "%s b" % message)

## The colours of the lamp and glow materials and the first lantern.
func _colors() -> Array[Color]:
	return [room._lamp.albedo_color, room._glow.albedo_color, room.lantern_lights()[0].light_color]

func _assert_colors_equal(got: Array[Color], want: Array[Color], message: String) -> void:
	for index in want.size():
		assert_eq(got[index], want[index], "%s (%d)" % [message, index])

func test_a_calm_room_is_untouched_by_a_zero_alert() -> void:
	var calm := _colors()
	room.set_alert(BOSS_COLOR, 0.0, 0.0)
	_assert_colors_equal(_colors(), calm, "set_alert(_, 0) keeps the theme's colours")
	assert_eq(room.alert_amount(), 0.0)
	for frame in 20:
		room._process(0.1)
	_assert_colors_equal(_colors(), calm, "no pulse without an alert")

func test_alert_tints_lamps_glow_pools_and_lantern_lights_towards_the_colour() -> void:
	var calm := _colors()
	room.set_alert(BOSS_COLOR, 1.0, 0.0)
	assert_eq(room.alert_amount(), 1.0)
	var lamp: Color = room._lamp.albedo_color
	var glow: Color = room._glow.albedo_color
	var light: Color = room.lantern_lights()[0].light_color
	_assert_rgb(lamp, BOSS_COLOR * ArenaRoom.LAMP_VALUE, 0.001, "lamps are the alert colour at calm brightness at the start of the pulse")
	_assert_rgb(glow, BOSS_COLOR, 0.001, "pools are the alert colour")
	assert_gt(light.r, light.g, "the lantern light moved towards the alert colour")
	assert_lt(_distance(light, BOSS_COLOR), _distance(calm[2], BOSS_COLOR), "closer to the alert colour than before")
	assert_gt(_distance(lamp, calm[0]), 0.05, "and the lamps visibly changed")

func test_a_partial_alert_blends_between_the_theme_and_the_alert_colour() -> void:
	var theme_glow: Color = room._glow.albedo_color
	room.set_alert(BOSS_COLOR, 0.5, 0.0)
	_assert_rgb(room._glow.albedo_color, theme_glow.lerp(BOSS_COLOR, 0.5), 0.001, "half way")

func test_ending_the_alert_restores_the_theme_colours_exactly() -> void:
	var calm := _colors()
	room.set_alert(BOSS_COLOR, 1.0, 0.0)
	for frame in 15:
		room._process(0.2)
	room.set_alert(BOSS_COLOR, 0.0, 0.0)
	_assert_colors_equal(_colors(), calm, "amount 0 gives the theme's colours back")
	room.set_alert(BOSS_COLOR, 1.0, 0.0)
	room.reset_alert()
	_assert_colors_equal(_colors(), calm, "reset_alert too")
	assert_eq(room.alert_amount(), 0.0)

func test_lamps_pulse_between_the_pulse_limits_only_during_an_alert() -> void:
	assert_almost_eq(ArenaRoom.alert_pulse(0.0), ArenaRoom.ALERT_PULSE_MAX, 0.0001, "the pulse starts at a calm lamp's brightness")
	assert_almost_eq(ArenaRoom.alert_pulse(ArenaRoom.ALERT_PERIOD * 0.5), ArenaRoom.ALERT_PULSE_MIN, 0.0001)
	assert_almost_eq(ArenaRoom.ALERT_PULSE_MIN, 0.35, 0.0001)
	assert_almost_eq(ArenaRoom.ALERT_PULSE_MAX, 0.8, 0.0001)
	room.set_alert(BOSS_COLOR, 1.0, 0.0)
	var lowest := INF
	var highest := -INF
	for frame in 60: # 6 seconds, two and a half pulses
		room._process(0.1)
		var value := _peak(room._lamp.albedo_color) / _peak(BOSS_COLOR)
		lowest = minf(lowest, value)
		highest = maxf(highest, value)
	assert_almost_eq(lowest, ArenaRoom.ALERT_PULSE_MIN, 0.03, "dims to the lower limit")
	assert_almost_eq(highest, ArenaRoom.ALERT_PULSE_MAX, 0.03, "and back up, never above a calm lamp")

func test_unlit_lamps_stay_below_the_bloom_threshold_through_every_alert() -> void:
	var colors: Array[Color] = [BOSS_COLOR, Color.WHITE, Color.YELLOW, Color(1, 0.2, 0.2), Color(0.2, 0.4, 1.0)]
	for color in colors:
		room.set_alert(color, 1.0, 0.0)
		for step in 25:
			room._alert_clock = step * ArenaRoom.ALERT_PERIOD / 25.0
			room._apply_alert()
			assert_lt(_peak(room._lamp.albedo_color), 0.9, "lamp albedo under 0.9 for %s at step %d" % [color, step])
			assert_lt(_peak(room._glow.albedo_color), 1.0001, "glow colour never above 1")
	room.set_alert(Color.WHITE, 0.0, 0.0)
	assert_lt(_peak(room._lamp.albedo_color), 0.9)

func test_alert_eases_in_and_out() -> void:
	room.set_alert(BOSS_COLOR, 1.0)
	assert_lt(room.alert_amount(), 1.0, "it eases in rather than jumping")
	await get_tree().create_timer(ArenaRoom.ALERT_FADE + 0.4).timeout
	assert_almost_eq(room.alert_amount(), 1.0, 0.001)
	var calm_glow: Color = ArenaStage.RIM_COLORS[world.stage.floor_theme]
	room.set_alert(BOSS_COLOR, 0.0)
	await get_tree().create_timer(ArenaRoom.ALERT_FADE + 0.4).timeout
	assert_eq(room.alert_amount(), 0.0)
	assert_eq(room._glow.albedo_color, calm_glow, "back to the theme's lamp colour")

func test_boss_waves_alert_the_room_and_the_next_wave_calms_it() -> void:
	var calm := _colors()
	world.stage.set_floor_wave(6, true)
	await get_tree().create_timer(ArenaRoom.ALERT_FADE + 0.4).timeout
	assert_almost_eq(room.alert_amount(), 1.0, 0.001, "a boss wave is a full alert")
	_assert_rgb(_hue(room._glow.albedo_color), _hue(ArenaStage.SEAM_BOSS), 0.01, "in the wave colour")
	world.stage.set_floor_wave(7, false)
	await get_tree().create_timer(ArenaRoom.ALERT_FADE + 0.4).timeout
	assert_eq(room.alert_amount(), 0.0)
	_assert_colors_equal(_colors(), calm, "an ordinary wave leaves the room calm")

func test_ordinary_waves_never_raise_an_alert() -> void:
	for wave in [1, 2, 5, 11, 20]:
		world.stage.set_floor_wave(wave, false)
		assert_eq(room._alert_amount, 0.0, "wave %d" % wave)
		room._process(0.1)
		assert_eq(room.alert_amount(), 0.0)

func test_a_new_wave_one_resets_an_alert_left_over_from_the_last_run() -> void:
	world.stage.set_floor_wave(19, true)
	await get_tree().create_timer(ArenaRoom.ALERT_FADE + 0.4).timeout
	world.start_run()
	world.stage.set_floor_wave(1, false)
	await get_tree().create_timer(ArenaRoom.ALERT_FADE + 0.4).timeout
	assert_eq(room.alert_amount(), 0.0)

func test_a_theme_change_during_an_alert_keeps_the_alert_on_the_new_theme() -> void:
	var other := "frost" if world.stage.floor_theme != "frost" else "foundry"
	room.set_alert(BOSS_COLOR, 0.5, 0.0)
	world.stage.set_floor_theme(other)
	var rim: Color = ArenaStage.RIM_COLORS[other]
	room._process(0.016)
	_assert_rgb(room._glow.albedo_color, rim.lerp(BOSS_COLOR, 0.5), 0.02, "blended from the new theme's lamp colour, not the old one")
	room.reset_alert()
	assert_eq(room._glow.albedo_color, rim, "and calm again is the new theme's colour")

func test_a_room_outside_the_tree_applies_the_alert_at_once() -> void:
	var loose: ArenaRoom = autofree(ArenaRoom.new())
	loose.build()
	loose.apply_theme("foundry", Color("258e99"))
	loose.set_alert(BOSS_COLOR, 1.0)
	assert_eq(loose.alert_amount(), 1.0, "no tween without a tree")
	loose.reset_alert()
	assert_eq(loose._glow.albedo_color, Color("258e99"))

func test_a_new_room_starts_calm_with_one_shared_process() -> void:
	var fresh: ArenaRoom = autofree(ArenaRoom.new())
	fresh.build()
	assert_eq(fresh.alert_amount(), 0.0)
	assert_true(fresh.is_processing(), "flywheels, flicker and the pulse share one process")
	assert_eq(fresh.lantern_lights().size(), 4)

func test_lantern_flicker_stays_within_its_band_and_actually_moves() -> void:
	var lights := room.lantern_lights()
	assert_eq(lights.size(), 4)
	for index in lights.size():
		var lowest := INF
		var highest := -INF
		for step in 400:
			var energy := room.lantern_energy(step * 0.05, index)
			lowest = minf(lowest, energy)
			highest = maxf(highest, energy)
		assert_gte(lowest, ArenaRoom.LANTERN_ENERGY - ArenaRoom.LANTERN_FLICKER - 0.0001, "lantern %d" % index)
		assert_lte(highest, ArenaRoom.LANTERN_ENERGY + ArenaRoom.LANTERN_FLICKER + 0.0001, "lantern %d" % index)
		assert_gt(highest - lowest, ArenaRoom.LANTERN_FLICKER * 0.5, "lantern %d flickers" % index)
	assert_almost_eq(ArenaRoom.LANTERN_ENERGY, 0.7, 0.0001)
	assert_almost_eq(ArenaRoom.LANTERN_FLICKER, 0.06, 0.0001)

func test_process_drives_the_lantern_lights_without_leaving_the_band() -> void:
	var seen := {}
	for frame in 120:
		room._process(1.0 / 30.0)
		for light in room.lantern_lights():
			assert_between(light.light_energy, ArenaRoom.LANTERN_ENERGY - ArenaRoom.LANTERN_FLICKER - 0.0001, ArenaRoom.LANTERN_ENERGY + ArenaRoom.LANTERN_FLICKER + 0.0001)
			seen[snappedf(light.light_energy, 0.001)] = true
	assert_gt(seen.size(), 20, "the energy varies from frame to frame")

func test_lanterns_differ_from_each_other() -> void:
	var same := 0
	for step in 50:
		if is_equal_approx(room.lantern_energy(step * 0.2, 0), room.lantern_energy(step * 0.2, 1)):
			same += 1
	assert_lt(same, 10, "each lantern follows its own stretch of noise")

func test_alert_state_does_not_disturb_the_flywheels() -> void:
	var before := room._flywheels[0].rotation.z
	room.set_alert(BOSS_COLOR, 1.0, 0.0)
	room._process(1.0)
	assert_ne(room._flywheels[0].rotation.z, before, "the flywheels keep turning in an alert")
