extends GutTest

var app: GameApp

func before_each() -> void:
	TestHelpers.reset_all_services()
	app = preload("res://scenes/main.tscn").instantiate()
	add_child_autofree(app)

func test_menu_button_opens_and_back_closes() -> void:
	app.floor_button.pressed.emit()
	assert_not_null(app.floor_showcase)
	assert_false(app.menu.visible)
	app.floor_showcase.close()
	await wait_process_frames(1)
	assert_null(app.floor_showcase)
	assert_true(app.menu.visible)

func test_every_theme_has_a_row_a_name_and_a_material() -> void:
	var showcase := FloorShowcase.new()
	add_child_autofree(showcase)
	assert_eq(showcase.themes.size(), WorldGeometry.FLOOR_THEMES.size())
	assert_eq(showcase.list.item_count, WorldGeometry.FLOOR_THEMES.size())
	for index in showcase.themes.size():
		showcase.show_theme(index)
		var theme := showcase.themes[index]
		assert_ne(FloorThemes.display_name(theme), theme.capitalize(), "%s has a display name" % theme)
		assert_ne(FloorThemes.note(theme), "", theme)
		assert_eq(showcase.floor_visual.material_override.albedo_texture, WorldGeometry._floor_texture(theme, "albedo"))
		assert_eq(showcase.title_label.text, FloorThemes.display_name(theme).to_upper())

func test_every_theme_is_used_by_a_layout_and_has_a_rim_colour_and_decal_tint() -> void:
	for theme in WorldGeometry.FLOOR_THEMES:
		assert_ne(FloorThemes.layout_name(theme), "", "%s has an arena layout" % theme)
		assert_true(ArenaStage.RIM_COLORS.has(theme), "%s rim" % theme)
		assert_true(FloorDecals.TINTS.has(theme), "%s tints" % theme)
		assert_true(WorldGeometry.FLOOR_METALLIC.has(theme), "%s metallic" % theme)
