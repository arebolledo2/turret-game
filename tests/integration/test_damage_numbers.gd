extends GutTest

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_all_services()
	world = ArenaWorld.new()
	world.auto_start = false
	world.show_hud = false
	world.run_config = RunConfig.slice()
	world.run_config.mode = RunConfig.MODE_CORE
	add_child_autofree(world)
	world.start_run()
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.effects.set_physics_process(false)
	for turret in world.turrets:
		turret.set_physics_process(false)
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)

func test_numbers_use_actual_damage_and_ignore_blocked_hits() -> void:
	var enemy := world.spawn_enemy(Vector3.ZERO)
	enemy.set_physics_process(false)
	enemy.health = 7.5
	var hit := CombatHit3D.new(100)
	hit.critical = true
	world.combat.apply_hit(enemy, hit)
	var numbers := world.effects.damage_numbers
	assert_eq(numbers.entries.size(), 1)
	assert_eq(numbers.entries[0].amount, 7.5)
	assert_eq(numbers.entries[0].label.text, "7.5!")
	world.player.invulnerability = 1
	world.combat.apply_hit(world.player, CombatHit3D.new(10))
	assert_eq(numbers.entries.size(), 1)
	world.player.invulnerability = 0
	world.combat.apply_hit(world.player, CombatHit3D.new(3))
	assert_true(numbers.entries[-1].friendly)
	world.damage_core(4)
	assert_true(numbers.entries[-1].friendly)
	assert_eq(numbers.entries[-1].amount, 4.0)

func test_number_pool_merges_rapid_hits_and_respects_reduced_motion() -> void:
	var numbers := world.effects.damage_numbers
	for i in range(10):
		numbers.show_damage(world.player, .5, false, false, true)
	assert_eq(numbers.entries.size(), 1)
	assert_eq(numbers.entries[0].amount, 5.0)
	var at: Vector3 = numbers.entries[0].label.position
	numbers.advance(.3, true)
	assert_almost_eq(numbers.entries[0].label.position.y - at.y, .65 * (.3 / DamageNumbers3D.LIFETIME) * GameConstants.REDUCED_MOTION_SPEED, .001)
	assert_eq(numbers.entries[0].label.scale, Vector3.ONE)
	numbers.show_damage(world.player, 2, false)
	assert_eq(numbers.entries.size(), 2)
	for i in range(100):
		numbers.advance(.17, false)
		numbers.show_damage(world.player, 2, false)
	assert_lte(numbers.entries.size(), DamageNumbers3D.LIMIT)
	numbers.reset()
	for entry in numbers.entries:
		assert_false(entry.label.visible)

func test_fatal_damage_survives_defeat_then_fades() -> void:
	world.player.health = 1
	world.combat.apply_hit(world.player, CombatHit3D.new(10))
	var numbers := world.effects.damage_numbers
	assert_true(numbers.entries[0].label.visible)
	assert_eq(numbers.entries[0].amount, 1.0)
	world.effects._physics_process(1.0)
	assert_false(numbers.entries[0].label.visible)

func test_full_number_pool_recycles_without_exceeding_limit() -> void:
	var numbers := world.effects.damage_numbers
	for i in range(DamageNumbers3D.LIMIT + 10):
		var actor := Node3D.new()
		add_child_autofree(actor)
		numbers.show_damage(actor, 3, false)
	assert_eq(numbers.entries.size(), DamageNumbers3D.LIMIT)
	var shot := CombatShot3D.new()
	shot.critical = true
	assert_true(shot.copy().critical)
