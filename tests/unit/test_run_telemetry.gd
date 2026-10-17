extends GutTest

var telemetry: RunTelemetry

func before_each() -> void:
	TestHelpers.reset_all_services()
	FeatureFlagService.reset_state()
	telemetry = RunTelemetry.new()
	telemetry.begin_run()


func test_counters_accumulate_per_wave() -> void:
	telemetry.begin_wave(1)
	telemetry.record_kill("2:normal")
	telemetry.record_kill("2:normal")
	telemetry.record_kill()
	telemetry.record_turret_move()
	telemetry.record_scrap_earned(7)
	telemetry.record_spend("turret", 9)
	telemetry.begin_wave(2)
	telemetry.record_kill("3:shock")
	telemetry.record_spend("turret", 4)
	telemetry.record_spend("reroll", 1)
	assert_eq(telemetry.waves.size(), 2)
	assert_eq(telemetry.waves[0]["kills"], 3)
	assert_eq(telemetry.waves[0]["kills_by_turret"], {"2:normal": 2})
	assert_eq(telemetry.waves[1]["kills_by_turret"], {"3:shock": 1})
	assert_eq(telemetry.total("kills"), 4)
	assert_eq(telemetry.total("turret_moves"), 1)
	assert_eq(telemetry.total_spent("turret"), 13)
	var totals: Dictionary = telemetry.to_dict()["totals"]
	assert_eq(totals["scrap_earned"], 7)
	assert_eq(totals["scrap_spent"], {"turret": 13, "item": 0, "reroll": 1})


func test_recording_before_the_first_wave_opens_wave_zero() -> void:
	telemetry.record_kill()
	assert_eq(telemetry.waves.size(), 1)
	assert_eq(telemetry.waves[0]["wave"], 0)


func test_begin_run_clears_waves_and_snapshots_flags() -> void:
	telemetry.begin_wave(1)
	FeatureFlagService.set_enabled(FeatureFlagService.DEBUG_OVERLAYS, true)
	telemetry.begin_run()
	assert_true(telemetry.waves.is_empty())
	assert_true(telemetry.flags[FeatureFlagService.DEBUG_OVERLAYS])


func test_to_dict_is_json_serialisable() -> void:
	telemetry.begin_wave(1)
	telemetry.record_kill("1:normal")
	var parsed: Variant = JSON.parse_string(JSON.stringify(telemetry.to_dict()))
	assert_true(parsed is Dictionary)
	assert_eq(int(parsed["totals"]["kills"]), 1)
