extends GutTest

func after_each() -> void:
	UiIcons.reset_cache()

func test_chamfer_outline_cuts_top_left_and_bottom_right() -> void:
	var style := ChamferStyle.make(Color.BLACK, Color.WHITE, 10.0)
	style.edge_width = 0.0
	var points := style.outline(Rect2(0, 0, 100, 50))
	assert_eq(points.size(), 6)
	assert_eq(points[0], Vector2(10, 0), "top edge starts after the top-left cut")
	assert_eq(points[3], Vector2(90, 50), "bottom edge ends before the bottom-right cut")
	assert_eq(points[5], Vector2(0, 10))

func test_chamfer_is_limited_to_half_the_shorter_side() -> void:
	var style := ChamferStyle.make(Color.BLACK, Color.WHITE, 400.0)
	style.edge_width = 0.0
	assert_eq(style.outline(Rect2(0, 0, 100, 40))[0].x, 20.0)

func test_icons_rasterise_at_raster_size_and_are_cached() -> void:
	var first := UiIcons.get_icon("hull")
	assert_eq(first.get_width(), UiIcons.RASTER_SIZE)
	assert_same(UiIcons.get_icon("hull"), first)

func test_unknown_icons_draw_the_missing_box() -> void:
	assert_same(UiIcons.get_icon("no_such_icon"), UiIcons.get_icon("missing"))

func test_turret_and_item_icons_fall_back_when_art_is_missing() -> void:
	assert_true(UiIcons.has_icon("turret_shock"))
	assert_same(UiIcons.turret("not_a_turret"), UiIcons.get_icon("turret"))
	assert_same(UiIcons.item("not_an_item"), UiIcons.get_icon("module"))

func test_every_icon_fragment_rasterises() -> void:
	for icon_name: String in UiIconData.PATHS:
		var image := Image.new()
		var error := image.load_svg_from_string(UiIcons.WRAPPER % UiIconData.PATHS[icon_name], 1.0)
		assert_eq(error, OK, "icon '%s' is valid SVG" % icon_name)

func test_every_catalogued_turret_has_an_icon() -> void:
	for type_id: String in ShopCatalog.ids("turret"):
		assert_true(UiIcons.has_icon("turret_" + type_id), "turret icon for %s" % type_id)

func test_segmented_bar_clamps_and_tracks_state() -> void:
	var bar: SegmentedBar = add_child_autofree(SegmentedBar.new())
	bar.set_state(99, 25)
	assert_eq(bar.value, 25)
	assert_eq(bar.cells, 25)
	bar.set_state(-3)
	assert_eq(bar.value, 0)

func test_segmented_bar_pulses_only_while_danger_or_blinking() -> void:
	var bar: SegmentedBar = add_child_autofree(SegmentedBar.new())
	bar.set_state(5, 25)
	assert_false(bar.is_processing())
	bar.set_state(5, 25, true)
	assert_eq(bar.is_processing(), not FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION))

func test_stat_chip_shows_text_and_tone() -> void:
	var chip: StatChip = add_child_autofree(StatChip.new().setup("damage", "+6%", "dmg", 1))
	assert_eq(chip.label.text, "+6%")
	assert_eq(chip.label.get_theme_color("font_color"), UiPalette.GOOD)
	assert_eq(chip.icon_rect.modulate, UiPalette.stat_color("dmg"))

func test_stat_tile_updates_its_value() -> void:
	var tile: StatTile = add_child_autofree(StatTile.new().setup("hull", "hull", "Hull", "25"))
	tile.set_value("23", UiPalette.BAD)
	assert_eq(tile.value_label.text, "23")
	assert_eq(tile.caption_label.text, "HULL")

func test_icon_button_carries_icon_and_label() -> void:
	var button: IconButton = add_child_autofree(IconButton.new().setup("deploy", "DEPLOY", true))
	assert_eq(button.text, "DEPLOY")
	assert_not_null(button.icon)
