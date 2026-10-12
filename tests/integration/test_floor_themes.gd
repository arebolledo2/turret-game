extends GutTest

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_all_services()
	FeatureFlagService.set_enabled(FeatureFlagService.TERRAIN_ZONES, true)
	world = ArenaWorld.new()
	world.auto_start = false
	world.show_hud = false
	add_child_autofree(world)

func test_every_layout_names_an_available_theme_with_all_four_maps() -> void:
	for layout_id in ArenaLayouts.ids():
		var layout := ArenaLayouts.get_layout(layout_id)
		assert_has(WorldGeometry.FLOOR_THEMES, layout.floor_theme, layout_id)
	for theme in WorldGeometry.FLOOR_THEMES:
		for map in ["albedo", "normal", "roughness", "emission"]:
			assert_not_null(WorldGeometry._floor_texture(theme, map), "%s %s" % [theme, map])

func test_run_applies_the_layouts_floor_theme() -> void:
	world.run_config.layout_id = "sump"
	world.start_run()
	assert_eq(world.stage.floor_theme, "grating")
	assert_eq(world.stage.floor_visual.material_override.albedo_texture, WorldGeometry._floor_texture("grating", "albedo"))

func test_unknown_theme_falls_back_to_default() -> void:
	var material := WorldGeometry.floor_material(Vector2(10, 10), "nope")
	assert_eq(material.albedo_texture, WorldGeometry._floor_texture(WorldGeometry.DEFAULT_FLOOR_THEME, "albedo"))

func test_explosions_leave_recycled_scorch_marks() -> void:
	world.start_run()
	var decals := world.stage.floor_decals
	for index in FloorDecals.MAX_SCORCH + 5:
		world.combat.explosion.emit(Vector3(index * 2.0 - 20.0, 0, 0), 2.0)
	assert_eq(decals.scorch_count(), FloorDecals.MAX_SCORCH)
	world.combat.explosion.emit(Vector3(-20, 0, 0.2), 2.0)
	assert_eq(decals.scorch_count(), FloorDecals.MAX_SCORCH, "A mark on top of another is ignored")
	world.start_run()
	assert_eq(decals.scorch_count(), 0)

func test_boss_wave_shifts_seam_light() -> void:
	world.start_run()
	world.stage.set_floor_wave(6, true)
	await get_tree().create_timer(1.2).timeout
	var seam: Color = world.stage.floor_visual.material_override.emission
	assert_almost_eq(seam.g, ArenaStage.SEAM_BOSS.g, 0.02)
