extends GutTest

## The form table (`TurretForms`) is the single definition of each form. These tests check the rows themselves, so a new
## row that is malformed fails here with its id instead of surfacing as a missing model or a silent default attack.

const REQUIRED: Array[String] = ["base", "kind", "name", "model", "description", "stats", "implemented"]
const OPTIONAL: Array[String] = ["behaviour", "visual", "shot", "params"]

func test_every_row_has_every_required_key_and_no_unknown_one() -> void:
	for form: String in TurretForms.FORMS:
		var row: Dictionary = TurretForms.FORMS[form]
		for key in REQUIRED:
			assert_true(row.has(key), "%s has %s" % [form, key])
		for key: String in row:
			assert_true(key in REQUIRED or key in OPTIONAL, "%s: %s is not a row key" % [form, key])
		assert_true(row.get("kind") in [TurretForms.UPGRADE, TurretForms.FINAL], "%s has a known kind" % form)
		assert_typeof(row.get("implemented"), TYPE_BOOL)
		assert_typeof(row.get("stats"), TYPE_DICTIONARY)

func test_every_row_belongs_to_a_registered_base_turret() -> void:
	for form: String in TurretForms.FORMS:
		assert_true(TurretRegistry.TYPES.has(TurretForms.FORMS[form]["base"]), "%s: base turret is in the registry" % form)

func test_paths_are_derived_one_upgrade_then_two_finals_per_base_in_row_order() -> void:
	var rows_by_base: Dictionary = {}
	for form: String in TurretForms.FORMS:
		var base: String = TurretForms.FORMS[form]["base"]
		var kinds: Array = rows_by_base.get(base, [])
		kinds.append(TurretForms.FORMS[form]["kind"])
		rows_by_base[base] = kinds
	for base: String in rows_by_base:
		assert_eq(rows_by_base[base], [TurretForms.UPGRADE, TurretForms.FINAL, TurretForms.FINAL], "%s rows read upgrade, final, final" % base)
	assert_eq(TurretEvolution.bases(), rows_by_base.keys(), "Bases keep the table's order")

func test_named_behaviours_and_visuals_resolve_to_the_right_kind_of_script() -> void:
	for form: String in TurretForms.FORMS:
		var behaviour: Variant = TurretEvolution.behaviour_script("", form)
		if TurretForms.FORMS[form].has("behaviour"):
			assert_not_null(behaviour, "%s: behaviour %s resolves" % [form, TurretForms.FORMS[form]["behaviour"]])
			assert_true(behaviour.new() is TurretForm, "%s: behaviour extends TurretForm" % form)
		else:
			assert_null(behaviour, "%s has the default attack" % form)
		var visual: Variant = TurretEvolution.visual_script(form)
		if TurretForms.FORMS[form].has("visual"):
			assert_not_null(visual, "%s: visual %s resolves" % [form, TurretForms.FORMS[form]["visual"]])
			assert_true(visual.has_method("build"), "%s: visual has a static build(model, form_id)" % form)
		else:
			assert_null(visual, "%s adds no hardware" % form)
	assert_null(TurretEvolution.behaviour_script("normal", ""), "A plain base turret uses the default attack")
	assert_true(TurretEvolution.behaviour_script("quake", "").new() is QuakeForm, "The unevolved Quake pulses through its form")
	assert_true(TurretEvolution.behaviour_script("decoy", "").new() is DecoyForm, "The unevolved Decoy taunts through its form")
	assert_true(TurretEvolution.behaviour_script("scrap_press", "").new() is ScrapPressForm, "The unevolved Scrap Press makes its drops through its form")
	assert_true(TurretEvolution.behaviour_script("mine_layer", "").new() is MineLayerForm, "The unevolved Mine Layer lays its mines through its form")

func test_every_visual_ignores_a_form_that_is_not_its_own() -> void:
	var model := Node3D.new()
	add_child_autofree(model)
	for form: String in TurretForms.FORMS:
		var visual: Variant = TurretEvolution.visual_script(form)
		if visual == null:
			continue
		assert_null(visual.build(model, "machine_gun" if form != "machine_gun" else "saber"), "%s's builder skips a foreign form" % form)
		assert_eq(model.get_child_count(), 0)

func test_shape_fields_and_params_use_known_keys() -> void:
	var shot := CombatShot3D.new()
	var shot_keys: Array = []
	for property in shot.get_property_list():
		shot_keys.append(property["name"])
	for form: String in TurretForms.FORMS:
		for key: String in TurretForms.FORMS[form].get("shot", {}):
			assert_true(key in shot_keys, "%s: shot field %s exists on CombatShot3D" % [form, key])
	for base: String in TurretForms.BASES:
		for key: String in TurretForms.BASES[base].get("shot", {}):
			assert_true(key in shot_keys, "%s: shot field %s exists on CombatShot3D" % [base, key])

func test_param_reads_the_row_and_falls_back_to_the_default() -> void:
	assert_eq(TurretEvolution.param("arrowstorm", "volley"), 5)
	assert_eq(TurretEvolution.param("machine_gun", "volley", 1), 1)
	assert_eq(TurretEvolution.param("missing", "volley", 7), 7)
	assert_eq(TurretEvolution.volley_size("repeater_bow"), 2)
	assert_eq(TurretEvolution.volley_size("omnifire"), 1)
	assert_eq(TurretEvolution.blade_count("orbit_saber"), 3)
	assert_eq(TurretEvolution.blade_count("saber"), 1)
	assert_eq(TurretEvolution.barrel_burst("stormblade"), 3)
	assert_eq(TurretEvolution.shot_scale("juggernaut"), 1.75)
	assert_eq(TurretEvolution.shot_scale("saber"), 1.0)
