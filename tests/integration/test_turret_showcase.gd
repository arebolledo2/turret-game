extends GutTest

var app: GameApp

func before_each() -> void:
	TestHelpers.reset_all_services()
	app = preload("res://scenes/main.tscn").instantiate()
	add_child_autofree(app)

func test_entries_cover_every_stocked_base_and_implemented_form() -> void:
	var expected := ShopCatalog.ids("turret").size()
	for base: String in ShopCatalog.ids("turret"):
		for form_stage in 2:
			for form: String in TurretEvolution.options(base, form_stage):
				if TurretEvolution.is_implemented(form):
					expected += 1
	assert_eq(TurretShowcase.build_entries().size(), expected)

func test_menu_button_opens_and_back_closes() -> void:
	app.showcase_button.pressed.emit()
	assert_not_null(app.showcase)
	assert_false(app.menu.visible)
	app.showcase.close()
	await wait_process_frames(1)
	assert_null(app.showcase)
	assert_true(app.menu.visible)

func test_every_entry_fires_and_effects_expire() -> void:
	var showcase := TurretShowcase.new()
	add_child_autofree(showcase)
	for index in showcase.entries.size():
		showcase.show_entry(index)
		for step in 40:
			showcase.fire.advance(.1)
		assert_gt(showcase.fire.shots_fired, 0, "entry %d fires" % index)
		for step in 20:
			showcase.fire.advance(.1)
		assert_lt(showcase.fire.effects.size(), 12, "entry %d does not pile up effects" % index)

func test_every_entry_builds_a_model_and_swaps_without_leaking() -> void:
	var showcase := TurretShowcase.new()
	add_child_autofree(showcase)
	for index in showcase.entries.size():
		showcase.show_entry(index)
		assert_not_null(showcase.actor.model, "entry %d has a model" % index)
		assert_gt(showcase.model_bounds().size.length(), 0.0, "entry %d has geometry" % index)
		assert_eq(showcase.pivot.get_child_count(), 1)
