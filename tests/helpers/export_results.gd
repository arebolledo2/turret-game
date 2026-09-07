extends GutHookScript

func run() -> void:
	var path := OS.get_environment("TURRET_TEST_RESULTS")
	if path.is_empty():
		return
	var exporter = load("res://addons/gut/result_exporter.gd").new()
	var results: Dictionary = exporter.get_results_dictionary(gut)
	# Only errors explicitly asserted by a test can be exempted from stderr checking.
	var expected: Array[String] = []
	for errors in gut.error_tracker.errors.items.values():
		for error in errors:
			if error.handled and error.is_engine_error():
				expected.append(error.rationale if not error.rationale.is_empty() else error.code)
	results["expected_engine_errors"] = expected
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		set_exit_code(1)
		return
	file.store_string(JSON.stringify(results, "  "))
