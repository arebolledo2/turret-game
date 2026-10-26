extends GutTest

## The roster contract: every stocked turret can be bought through the shop and taken through every form its table rows mark
## implemented, ending with the model, behaviour, name and portrait the rows promise. Everything is derived from `ShopCatalog`
## and `TurretForms`, so a new turret is covered without editing this file. A form that is missing its model, its entry in the
## implemented list, its portrait or its behaviour would otherwise show up only as "Form in development" in the shop.

var rig: TurretTestRig
var world: ArenaWorld

func before_each() -> void:
	rig = TurretTestRig.start(self)
	rig.disable_crits()
	world = rig.world
	EconomyService.total_scrap = 1000000

func after_each() -> void:
	ShopCatalog.reset()

func _implemented(forms: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for form in forms:
		if TurretEvolution.is_implemented(form):
			result.append(form)
	return result

## Buys one `base_type` through the normal shop validation and returns the turret it deployed.
func _buy(base_type: String) -> TurretActor:
	var price := world.turret_price(base_type)
	EconomyService.current_shop_offers.assign([ShopOffer.new("turret", base_type, price)])
	var balance := EconomyService.total_scrap
	var count := world.turrets.size()
	assert_true(world.shop.purchase(0), "%s purchases through normal Shop validation" % base_type)
	assert_eq(EconomyService.total_scrap, balance - price)
	assert_eq(world.turrets.size(), count + 1)
	var bought := world.turrets[-1]
	bought.set_physics_process(false)
	assert_eq(bought.turret_type, base_type)
	assert_not_null(bought.model, "%s has a model" % base_type)
	assert_not_null(bought.aim, base_type)
	assert_not_null(bought.muzzle, base_type)
	return bought

## What the rows promise for a turret that has taken `form`.
func _assert_form_built(turret: TurretActor, form: String) -> void:
	var base := turret.turret_type
	assert_eq(turret.progression.evolution_form, form)
	assert_eq(turret.display_name(), TurretEvolution.form_name(form))
	assert_false(TurretEvolution.description(form).is_empty(), "%s has a description" % form)
	assert_true(ClockworkModels.available(TurretEvolution.model_key(form)), "%s: chassis %s loads" % [form, TurretEvolution.model_key(form)])
	assert_true(is_instance_valid(turret.model), "%s has a model" % form)
	var behaviour: Variant = TurretEvolution.behaviour_script(base, form)
	if behaviour == null:
		assert_null(turret.form, "%s uses the actor's own attack" % form)
	else:
		assert_not_null(turret.form, "%s has its behaviour" % form)
		if turret.form != null:
			assert_eq(turret.form.get_script(), behaviour, "%s runs the behaviour its row names" % form)
			assert_eq(turret.form.form_id, form)
	var portrait := "res://assets/ui/turrets/%s.png" % ShopArt.turret_portrait_key(base, form)
	assert_true(FileAccess.file_exists(portrait), "%s has a portrait file: %s" % [form, portrait])
	assert_true(ResourceLoader.exists(portrait), "%s's portrait is imported: %s" % [form, portrait])
	assert_same(ShopArt.turret(base, form), load(portrait), "%s shows its own portrait, not the icon fallback" % form)

func test_every_stocked_turret_has_its_base_portrait_and_a_path_of_forms() -> void:
	for base in ShopCatalog.ids("turret"):
		var portrait := "res://assets/ui/turrets/%s.png" % base
		assert_true(FileAccess.file_exists(portrait), "%s has a base portrait file: %s" % [base, portrait])
		assert_true(ResourceLoader.exists(portrait), "%s's base portrait is imported" % base)
		assert_same(ShopArt.turret(base), load(portrait), "%s shows its portrait, not the icon fallback" % base)
		assert_true(base in TurretEvolution.bases(), "%s is stocked, so the form table gives it an upgrade and two finals" % base)

func test_every_stocked_turret_is_bought_and_taken_through_every_implemented_form() -> void:
	var evolved := 0
	for base in ShopCatalog.ids("turret"):
		var upgrades := _implemented(TurretEvolution.options(base, 0))
		var finals := _implemented(TurretEvolution.options(base, 1))
		var turret := _buy(base)
		rig.level_to(turret, TurretProgression.EVOLUTION_LEVELS[-1])
		assert_false(turret.progression.evolution_options(base).is_empty(), "%s has an evolution waiting" % base)
		if upgrades.is_empty():
			assert_true(turret.available_evolutions().is_empty(), "%s: nothing is offered until a form is built" % base)
			continue
		assert_eq(turret.available_evolutions(), upgrades, "%s level 5 offers its upgrade" % base)
		assert_true(turret.evolve(upgrades[0]), "%s takes its upgrade" % base)
		evolved += 1
		_assert_form_built(turret, upgrades[0])
		assert_eq(turret.progression.evolution_stage, 1)
		assert_eq(turret.available_evolutions(), finals, "%s level 10 offers its built finals" % base)
		for index in finals.size():
			# One turret takes one final: the first goes on the bought turret, the others on a fresh copy.
			var upgrade_path: Array[String] = [upgrades[0]]
			var candidate := turret if index == 0 else rig.turret(base, upgrade_path)
			rig.level_to(candidate, TurretProgression.EVOLUTION_LEVELS[-1])
			assert_true(candidate.evolve(finals[index]), "%s takes %s" % [base, finals[index]])
			evolved += 1
			_assert_form_built(candidate, finals[index])
			assert_eq(candidate.progression.evolution_stage, 2)
			assert_true(candidate.available_evolutions().is_empty(), "%s has nothing left after its final" % base)
	assert_eq(evolved, TurretEvolution.implemented_forms().size(), "Every implemented form was taken by some turret")

func test_a_turret_without_built_forms_keeps_its_milestone_instead_of_offering_a_stub() -> void:
	var unbuilt := 0
	for base in TurretEvolution.bases():
		if not _implemented(TurretEvolution.options(base, 0) + TurretEvolution.options(base, 1)).is_empty():
			continue
		unbuilt += 1
		var turret := rig.turret(base)
		rig.level_to(turret, TurretProgression.EVOLUTION_LEVELS[0])
		assert_true(turret.available_evolutions().is_empty(), "%s offers nothing while its forms are unbuilt" % base)
		assert_eq(turret.progression.evolution_options(base), TurretEvolution.options(base, 0), "%s keeps its milestone for later" % base)
	if unbuilt == 0:
		pass_test("Every base turret has a built form")
