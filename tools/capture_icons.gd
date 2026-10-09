extends Node

## Developer visual check: a contact sheet of every icon in UiIconData, written to ignored .test-results.
func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var back := ColorRect.new()
	back.color = Color("08151e")
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var grid := GridContainer.new()
	grid.columns = 10
	grid.position = Vector2(20, 20)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	add_child(grid)
	var names: Array = UiIconData.PATHS.keys()
	for icon_name: String in names:
		var cell := VBoxContainer.new()
		cell.custom_minimum_size.x = 176
		var rect := TextureRect.new()
		rect.texture = UiIcons.get_icon(icon_name)
		rect.custom_minimum_size = Vector2(72, 72)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.modulate = UiPalette.stat_color("slow") if icon_name.begins_with("item_") else UiPalette.TEAL_HI
		cell.add_child(rect)
		var label := Label.new()
		label.text = icon_name.trim_prefix("item_")
		label.add_theme_font_size_override("font_size", 15)
		cell.add_child(label)
		grid.add_child(cell)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.test-results/icons.png"))
	print("ICONS_CAPTURE ", names.size())
	get_tree().quit()
