extends GutTest

func test_branch_choice_is_locked_and_milestones_resolve_in_order() -> void:
	var growth := TurretProgression.new()
	assert_false(growth.evolve("normal", "machine_gun"))
	growth.award(896)
	var before := growth.snapshot()
	assert_eq(growth.evolution_options("normal"), ["machine_gun", "scatter"])
	assert_false(growth.evolve("normal", "gunblade"))
	assert_true(growth.evolve("normal", "scatter"))
	assert_eq(growth.evolution_stage, 1)
	assert_eq(growth.pending_evolutions, [10, 15])
	assert_false(growth.evolve("normal", "machine_gun"))
	assert_true(growth.evolve("normal", "scatter"))
	assert_true(growth.evolve("normal", "scatter"))
	assert_false(growth.evolve("normal", "scatter"))
	assert_eq(growth.level, before.level)
	assert_eq(growth.total_xp, before.total_xp)
	assert_eq(growth.xp, before.xp)
	assert_eq(growth.evolution_stage, 3)
	assert_eq(TurretEvolution.form_name("normal", "scatter", 3), "Omnifire")
	assert_eq(before.evolution_stage, 0, "Earlier settlement snapshots remain frozen")

func test_each_base_has_two_complete_named_paths() -> void:
	for base: String in TurretEvolution.PATHS:
		assert_eq(TurretEvolution.branches(base).size(), 2)
		for branch: String in TurretEvolution.branches(base):
			for stage in range(1, 4):
				assert_false(TurretEvolution.form_name(base, branch, stage).is_empty())
				assert_false(TurretEvolution.model_key(base, branch, stage).is_empty())

func test_invalid_base_or_unearned_milestone_cannot_evolve() -> void:
	var growth := TurretProgression.new()
	growth.pending_evolutions.assign([5])
	assert_false(growth.evolve("normal", "machine_gun"))
	growth.level = 5
	assert_false(growth.evolve("missing", "machine_gun"))
	assert_true(growth.evolve("normal", "machine_gun"))
	assert_eq(growth.evolution_stage, 1)
