extends GutHookScript

func run() -> void:
	var path := OS.get_environment("TURRET_TEST_RESULTS")
	if path.is_empty():
		return
	var exporter = load("res://addons/gut/result_exporter.gd").new()
	if exporter.write_json_file(gut, path) != OK:
		set_exit_code(1)
