extends GutTest
var world: ArenaWorld
func before_each() -> void:
	TestHelpers.reset_all_services()
	TestHelpers.reset_flags()
	world = ArenaWorld.new()
	world.auto_start = false
	world.show_hud = false
	world.run_config = RunConfig.slice()
	world.run_config.difficulty = GameEnums.Difficulty.MEDIUM
	world.run_config.mode = RunConfig.MODE_CORE
	add_child_autofree(world)
	world.start_run()
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	for turret in world.turrets:
		turret.set_physics_process(false)
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)

func test_hero_family_items_and_snapshot() -> void:
	var base := PlayerStatsService.get_weapon_stats().duplicate()
	world.shop.apply_item("dense_rounds")
	world.shop.apply_item("quick_loader")
	var stats := PlayerStatsService.get_weapon_stats()
	assert_almost_eq(stats.damage, base.damage * 1.1, .001)
	assert_almost_eq(stats.projectile_speed, base.projectile_speed * 1.15, .001)
	assert_almost_eq(stats.fire_rate, base.fire_rate * 1.07, .001)
	ModifierService.add_modifier({"stat": "pierce", "operation": "add", "value": 2, "filter": {"attack_family": ["projectile"], "requires": ["direct_projectile"]}})
	var enemy := world.spawn_enemy(world.player.position + Vector3(1, 0, 0))
	enemy.set_physics_process(false)
	world.player.weapon_clock = 0
	world.player._tick_player_weapon(.01)
	var shot: CombatShot3D = world.projectiles[-1].shot
	assert_eq(shot.pierce, 2)
	assert_has(shot.attack_families, "projectile")
	assert_almost_eq(shot.damage, base.damage * 1.1, .001)

func test_hero_excludes_other_families_and_turret_only_bonuses() -> void:
	var base := PlayerStatsService.get_player_weapon_damage()
	for filter in [{"attack_family": ["kinetic"]}, {"turret_type": ["all"]}, {"entity_type": ["turret"]}, {"attack_family": ["projectile"], "requires": ["chain"]}]:
		ModifierService.add_modifier({"stat": "damage", "operation": "increase", "value": 1.0, "filter": filter})
	assert_eq(PlayerStatsService.get_player_weapon_damage(), base)
	ModifierService.add_modifier({"stat": "damage", "operation": "increase", "value": .1, "filter": {"attack_family": ["projectile", "aoe"]}})
	assert_almost_eq(PlayerStatsService.get_player_weapon_damage(), base * 1.1, .001, "overlapping filter applies once")

func test_late_core_waves_raise_pressure_without_early_elites() -> void:
	var config := world.difficulty_config
	for wave in range(1, 6):
		GameStateService.current_wave = wave
		for i in range(100): assert_false(world.waves._take_credit("elite_chance"))
	var previous := 0
	for wave in [1, 4, 10, 15, 20]:
		var count := GameStateService.get_wave_enemy_count(wave, 2.2, 1.0)
		assert_gt(count, previous)
		previous = count
	assert_gt(GameStateService.get_wave_enemy_count(20, 2.2, 1.0), 500)
	assert_almost_eq(DifficultyService.wave_rule(config, "seeker_share", 20), .3, .001)
	assert_almost_eq(DifficultyService.wave_rule(config, "elite_chance", 20), .12, .001)
	GameStateService.current_wave = 20
	world.waves.elite_credit = 0
	var elites := 0
	for i in range(100):
		if world.waves._take_credit("elite_chance"): elites += 1
	assert_between(elites, 11, 12)
	var tanks := 0
	for i in range(100):
		if EnemyVariants.pick_type(14, i) == "tank": tanks += 1
	assert_gt(tanks, 0)
	assert_false(EnemyEcology.roster(20).has("tank"), "Final boss has light escorts")
	var disabled := DifficultyService.without_rules(config)
	assert_eq(DifficultyService.wave_rule(disabled, "seeker_share", 20), 0.0)

func test_effects_clear_and_do_not_consume_gameplay_rng() -> void:
	var before := GameRandom.gameplay.state
	world.effects.show_arc(Vector3.ZERO, Vector3(2, .5, 1))
	world.effects.show_shock(Vector3.ZERO, 2)
	assert_eq(GameRandom.gameplay.state, before)
	var enemy := world.spawn_enemy(Vector3(3, 0, 3))
	enemy.set_physics_process(false)
	enemy.health = 100
	var hit := CombatHit3D.new(1)
	hit.burn_dps = 2
	hit.burn_duration = 3
	world.combat.apply_hit(enemy, hit)
	world.effects._update_burns()
	assert_eq(world.effects.burn_visuals.size(), 1)
	enemy.statuses.clear()
	world.effects._update_burns()
	assert_eq(world.effects.burn_visuals.size(), 0)
	world.effects.reset()
	for arc in world.effects.arcs: assert_false(arc.visible)
	for pulse in world.effects.pulses: assert_false(pulse.visible)

func test_hero_shop_preview_does_not_mutate_live_stats() -> void:
	var before := PlayerStatsService.get_weapon_stats().duplicate(true)
	var offer := ShopOffer.new("item", "dense_rounds", 10)
	var preview := ShopViewData.preview(world, offer)
	assert_almost_eq(preview.hero_weapon.damage, before.damage * 1.1, .001)
	assert_eq(PlayerStatsService.get_weapon_stats(), before)
