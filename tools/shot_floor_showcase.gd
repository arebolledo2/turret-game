extends Node

## Developer check for the menu floor gallery. Needs a rendering driver (not --headless):
##   Godot --path . --resolution 1920x1080 res://tools/shot_floor_showcase.tscn -- --themes=orrery,frost
## Writes .test-results/floor/showcase_<theme>.png.
func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var themes := PackedStringArray(WorldGeometry.FLOOR_THEMES)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--themes="):
			themes = argument.trim_prefix("--themes=").split(",")
	var showcase := FloorShowcase.new()
	add_child(showcase)
	showcase.open()
	for theme in themes:
		var index := showcase.themes.find(theme)
		showcase.list.select(index)
		showcase.show_theme(index)
		for i in range(20):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var output := ProjectSettings.globalize_path("res://.test-results/floor/showcase_%s.png" % theme)
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		get_viewport().get_texture().get_image().save_png(output)
		print("SHOWCASE_SHOT ", output)
	get_tree().quit()
