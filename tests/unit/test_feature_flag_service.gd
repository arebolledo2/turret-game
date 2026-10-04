extends GutTest

## Unit coverage for the centralized feature-flag contract.

const EXP_A: String = "test_experiment_a"
const EXP_B: String = "test_experiment_b"

func before_each() -> void:
	TestHelpers.reset_all_services()
	FeatureFlagService.reset_state()


func after_each() -> void:
	FeatureFlagService.reset_state()
	GameStateService.is_game_active = false


func _register_experiments() -> void:
	FeatureFlagService.register_flag(EXP_A, {"name": "A", "scope": FeatureFlagService.SCOPE_EXPERIMENT})
	FeatureFlagService.register_flag(EXP_B, {"name": "B", "scope": FeatureFlagService.SCOPE_EXPERIMENT, "requires": [EXP_A]})


func test_default_flags_are_available() -> void:
	assert_false(FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION))
	assert_true(FeatureFlagService.is_enabled(FeatureFlagService.DEV_PANEL))
	assert_false(FeatureFlagService.is_enabled(FeatureFlagService.DEBUG_OVERLAYS))


func test_every_definition_has_a_name_scope_and_valid_requirements() -> void:
	for flag_id in FeatureFlagService.get_flag_ids():
		var definition := FeatureFlagService.get_definition(flag_id)
		assert_ne(definition["name"], "", "%s needs a name" % flag_id)
		assert_true(definition["scope"] in [FeatureFlagService.SCOPE_USER, FeatureFlagService.SCOPE_DEV, FeatureFlagService.SCOPE_EXPERIMENT])
		for required: String in definition["requires"]:
			assert_true(FeatureFlagService.is_known_flag(required), "%s requires unknown %s" % [flag_id, required])


func test_flags_can_be_toggled_and_reset() -> void:
	assert_true(FeatureFlagService.set_enabled(FeatureFlagService.REDUCED_MOTION, true))
	assert_true(FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION))
	assert_true(FeatureFlagService.toggle(FeatureFlagService.REDUCED_MOTION))
	assert_false(FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION))

	FeatureFlagService.set_enabled(FeatureFlagService.REDUCED_MOTION, true)
	FeatureFlagService.reset_state()
	assert_false(FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION))


func test_unknown_flag_is_rejected() -> void:
	assert_false(FeatureFlagService.is_known_flag("missing_flag"))
	assert_false(FeatureFlagService.set_enabled("missing_flag", true))
	assert_false(FeatureFlagService.is_enabled("missing_flag"))
	assert_eq(FeatureFlagService.request_enabled("missing_flag", true), FeatureFlagService.REJECTED)


func test_change_signals_fire_once_per_change() -> void:
	watch_signals(FeatureFlagService)
	FeatureFlagService.set_enabled(FeatureFlagService.REDUCED_MOTION, true)
	FeatureFlagService.set_enabled(FeatureFlagService.REDUCED_MOTION, true)
	assert_signal_emit_count(FeatureFlagService, "flag_changed", 1)
	assert_signal_emitted_with_parameters(FeatureFlagService, "flag_changed", [FeatureFlagService.REDUCED_MOTION, true])


func test_requirements_block_enabling_and_cascade_when_disabling() -> void:
	_register_experiments()
	assert_false(FeatureFlagService.set_enabled(EXP_B, true), "B needs A")
	assert_true(FeatureFlagService.set_enabled(EXP_A, true))
	assert_true(FeatureFlagService.set_enabled(EXP_B, true))
	FeatureFlagService.set_enabled(EXP_A, false)
	assert_false(FeatureFlagService.is_enabled(EXP_B), "Dependents switch off with their requirement")


func test_debug_overlays_require_the_dev_panel() -> void:
	assert_true(FeatureFlagService.set_enabled(FeatureFlagService.DEBUG_OVERLAYS, true))
	FeatureFlagService.set_enabled(FeatureFlagService.DEV_PANEL, false)
	assert_false(FeatureFlagService.is_enabled(FeatureFlagService.DEBUG_OVERLAYS))
	assert_false(FeatureFlagService.set_enabled(FeatureFlagService.DEBUG_OVERLAYS, true))


func test_live_safe_flags_apply_immediately_during_a_run() -> void:
	GameStateService.is_game_active = true
	assert_eq(FeatureFlagService.request_enabled(FeatureFlagService.DEBUG_OVERLAYS, true), FeatureFlagService.APPLIED)
	assert_true(FeatureFlagService.is_enabled(FeatureFlagService.DEBUG_OVERLAYS))


func test_non_live_safe_flags_queue_during_a_run_and_land_with_the_next_wave() -> void:
	_register_experiments()
	GameStateService.is_game_active = true
	watch_signals(FeatureFlagService)
	assert_eq(FeatureFlagService.request_enabled(EXP_A, true), FeatureFlagService.QUEUED)
	assert_false(FeatureFlagService.is_enabled(EXP_A), "Applied value is unchanged")
	assert_true(FeatureFlagService.get_effective(EXP_A), "Effective value shows the queued change")
	assert_true(FeatureFlagService.has_pending())
	assert_eq(FeatureFlagService.request_enabled(EXP_B, true), FeatureFlagService.QUEUED, "A queued requirement satisfies a dependent")
	assert_eq(FeatureFlagService.apply_pending(), 2)
	assert_true(FeatureFlagService.is_enabled(EXP_A))
	assert_true(FeatureFlagService.is_enabled(EXP_B))
	assert_false(FeatureFlagService.has_pending())
	assert_signal_emitted(FeatureFlagService, "pending_changed")


func test_queued_request_reverts_when_asked_for_the_current_value() -> void:
	_register_experiments()
	GameStateService.is_game_active = true
	FeatureFlagService.request_enabled(EXP_A, true)
	FeatureFlagService.request_enabled(EXP_A, false)
	assert_false(FeatureFlagService.has_pending())


func test_requests_apply_immediately_when_no_run_is_active() -> void:
	_register_experiments()
	assert_eq(FeatureFlagService.request_enabled(EXP_A, true), FeatureFlagService.APPLIED)
	assert_true(FeatureFlagService.is_enabled(EXP_A))


func test_queued_dependent_without_its_requirement_is_rejected() -> void:
	_register_experiments()
	GameStateService.is_game_active = true
	assert_eq(FeatureFlagService.request_enabled(EXP_B, true), FeatureFlagService.REJECTED)


func test_release_preset_turns_experiments_off_and_leaves_other_scopes_alone() -> void:
	_register_experiments()
	FeatureFlagService.set_enabled(EXP_A, true)
	FeatureFlagService.set_enabled(FeatureFlagService.REDUCED_MOTION, true)
	assert_true(FeatureFlagService.apply_preset("release"))
	assert_false(FeatureFlagService.is_enabled(EXP_A))
	assert_true(FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION))


func test_all_experiments_preset_respects_dependency_order() -> void:
	_register_experiments()
	assert_true(FeatureFlagService.apply_preset("all_experiments"))
	assert_true(FeatureFlagService.is_enabled(EXP_A))
	assert_true(FeatureFlagService.is_enabled(EXP_B))
	assert_false(FeatureFlagService.apply_preset("nope"))


func test_presets_reference_only_known_flags() -> void:
	assert_true("release" in FeatureFlagService.get_preset_ids())
	assert_true("all_experiments" in FeatureFlagService.get_preset_ids())
	for preset_id in FeatureFlagService.get_preset_ids():
		for flag_id: String in FeatureFlagService.PRESETS[preset_id]["overrides"]:
			assert_true(FeatureFlagService.is_known_flag(flag_id))


func test_flag_list_enables_and_disables_and_reports_failures() -> void:
	_register_experiments()
	var failed := FeatureFlagService.apply_flag_list("%s,%s,missing" % [EXP_A, EXP_B])
	assert_eq(failed, PackedStringArray(["missing"]))
	assert_true(FeatureFlagService.is_enabled(EXP_B))
	FeatureFlagService.apply_flag_list("-" + EXP_A)
	assert_false(FeatureFlagService.is_enabled(EXP_A))
	assert_false(FeatureFlagService.is_enabled(EXP_B))


func test_snapshot_lists_non_user_flags_only() -> void:
	_register_experiments()
	var snapshot := FeatureFlagService.get_snapshot()
	assert_true(snapshot.has(EXP_A))
	assert_true(snapshot.has(FeatureFlagService.DEV_PANEL))
	assert_false(snapshot.has(FeatureFlagService.REDUCED_MOTION))


func test_reset_drops_registered_flags_and_pending_changes() -> void:
	_register_experiments()
	GameStateService.is_game_active = true
	FeatureFlagService.request_enabled(EXP_A, true)
	FeatureFlagService.reset_state()
	assert_false(FeatureFlagService.is_known_flag(EXP_A))
	assert_false(FeatureFlagService.has_pending())


func test_dev_panel_is_available_in_debug_builds_and_follows_its_flag() -> void:
	assert_true(FeatureFlagService.is_dev_build(), "Tests run from a debug build")
	assert_true(FeatureFlagService.dev_panel_available())
	FeatureFlagService.set_enabled(FeatureFlagService.DEV_PANEL, false)
	assert_false(FeatureFlagService.dev_panel_available())
