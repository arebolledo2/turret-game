extends GutTest

var app: GameApp

func before_each() -> void:
	TestHelpers.reset_all_services()
	app = preload("res://scenes/main.tscn").instantiate()
	add_child_autofree(app)

func test_menu_button_opens_and_back_closes() -> void:
	app.enemy_button.pressed.emit()
	assert_not_null(app.enemy_showcase)
	assert_false(app.menu.visible)
	app.enemy_showcase.close()
	await wait_process_frames(1)
	assert_null(app.enemy_showcase)
	assert_true(app.menu.visible)

func test_entries_cover_enemies_and_bosses_but_not_summons_or_legacy() -> void:
	var ids: Array[String] = []
	for entry in EnemyShowcase.build_entries():
		ids.append(entry["id"])
	assert_has(ids, "basic")
	assert_has(ids, "drowse")
	assert_has(ids, "brass_ram")
	for skipped in EnemyEcology.SUMMONS + EnemyShowcase.LEGACY:
		assert_does_not_have(ids, skipped)

func test_every_entry_has_a_name_description_and_health() -> void:
	for entry in EnemyShowcase.build_entries():
		assert_ne(entry["name"], "", entry["id"])
		assert_ne(entry["description"], "", "%s has a description" % entry["id"])
		assert_gt(float(entry["stats"]["health"]), 0.0, "%s health" % entry["id"])

func test_every_entry_builds_a_model() -> void:
	var showcase := EnemyShowcase.new()
	add_child_autofree(showcase)
	assert_eq(showcase.list.item_count, showcase.entries.size())
	for index in showcase.entries.size():
		showcase.show_entry(index)
		assert_not_null(showcase.model, showcase.entries[index]["id"])
		assert_eq(showcase.title_label.text, str(showcase.entries[index]["name"]).to_upper())
