extends GutTest

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_all_services()
	world = ArenaWorld.new()
	world.auto_start = false
	world.show_hud = false
	add_child_autofree(world)
	world.start_run()
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.session.state.turret_progression_enabled = true
	for turret in world.turrets:
		turret.set_physics_process(false)
	GameStateMachine.force_transition(GameStateMachine.GameState.SHOP)

func test_evolution_replaces_model_preserving_identity_and_investment() -> void:
	var turret := world.turrets[0]
	turret.progression.award(110)
	turret.stay_time = 14
	turret.entrench_stacks_cached = 2
	var before_id := turret.turret_id
	var before_position := turret.position
	var before_count := TurretStatsService.get_total_turret_count()
	var old_model := turret.model
	assert_true(turret.evolve("machine_gun"))
	assert_ne(turret.model, old_model)
	assert_eq(turret.turret_id, before_id)
	assert_eq(turret.position, before_position)
	assert_eq(turret.stay_time, 14.0)
	assert_eq(turret.progression.total_xp, 110)
	assert_eq(TurretStatsService.get_total_turret_count(), before_count)
	assert_eq(turret.turret_type, "normal")
	assert_eq(turret.display_name(), "Machine Gun")
	assert_gt(turret._current_view(0).fire_rate, 3.0)
	assert_false(turret.evolve("scatter"), "Cannot spend a milestone twice")

func test_scatter_emits_three_distinct_attributed_projectiles() -> void:
	var turret := world.turrets[0]
	turret.progression.award(110)
	assert_true(turret.evolve("scatter"))
	var enemy := world.spawn_enemy(turret.position + Vector3(0, 0, -1.8))
	enemy.set_physics_process(false)
	turret.target = enemy
	turret._fire_projectile(turret._current_view(0))
	assert_eq(world.projectiles.size(), 3)
	assert_ne(world.projectiles[0].direction, world.projectiles[1].direction)
	assert_ne(world.projectiles[1].direction, world.projectiles[2].direction)
	for shot in world.projectiles:
		assert_eq(shot.shot.source_id, turret.turret_id)
		assert_eq(shot.shot.attack_families, ["projectile"])

func test_saber_reaches_and_hits_beyond_base_bat_radius() -> void:
	var turret := world.add_turret(Vector3.ZERO, "melee")
	turret.set_physics_process(false)
	turret.progression.award(110)
	assert_true(turret.evolve("saber"))
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	var enemy := world.spawn_enemy(Vector3(0, 0, -1.5))
	enemy.set_physics_process(false)
	enemy.health = 100
	world.crowd.rebuild(world.enemies)
	var stats := turret._current_view(0)
	turret._spin_bat(.1, stats, stats.range_metres)
	assert_lt(enemy.health, 100.0)
	assert_gt(stats.range_metres, 1.45)
	assert_almost_eq(WorldGeometry.planar(turret.muzzle.global_position - turret.aim.global_position).length(), stats.range_metres, .001)

func test_gatling_spools_and_loses_speed_without_target() -> void:
	var turret := world.turrets[0]
	turret.progression.award(389)
	assert_true(turret.evolve("machine_gun"))
	assert_true(turret.evolve("machine_gun"))
	assert_eq(turret.display_name(), "Gatling")
	assert_not_null(turret.rotor)
	var view := turret._current_view(0)
	turret._reset_cooldown(view)
	var cold := turret.cooldown
	turret._tick_mechanisms(1.0, true)
	turret._reset_cooldown(view)
	assert_almost_eq(turret.cooldown, cold / 2.0, .001)
	turret._tick_mechanisms(.5, false)
	assert_eq(turret.spool, 0.0)
	assert_eq(turret.progression.pending_evolutions.size(), 0)

func test_crossfire_uses_four_distinct_outward_muzzles() -> void:
	var turret := world.turrets[0]
	turret.progression.award(389)
	assert_true(turret.evolve("scatter"))
	assert_true(turret.evolve("scatter"))
	turret.target = world.spawn_enemy(turret.position + Vector3(0, 0, -2))
	turret.target.set_physics_process(false)
	turret._fire_projectile(turret._current_view(0))
	assert_eq(world.projectiles.size(), 4)
	for i in 4:
		var shot := world.projectiles[i]
		assert_gt(WorldGeometry.planar(shot.position - turret.position).normalized().dot(shot.direction), .99)
		for j in range(i + 1, 4):
			assert_lt(shot.direction.dot(world.projectiles[j].direction), .01)

func test_siege_heavy_projectile_radius_resets_when_pool_is_reused() -> void:
	var turret := world.add_turret(Vector3.ZERO, "plasma")
	turret.set_physics_process(false)
	turret.progression.award(110)
	assert_true(turret.evolve("siege"))
	var shot := turret._new_shot(turret._current_view(0))
	assert_eq(shot.radius, .22)
	assert_gt(shot.damage, 40.0)
	assert_gt(shot.splash_radius, 1.3)
	var projectile := world.fire_direction(Vector3.ZERO, Vector3.FORWARD, shot)
	assert_almost_eq((projectile.sweep.shape as SphereShape3D).radius, .22, .0001)
	projectile.release()
	var reused := world.fire_direction(Vector3.ZERO, Vector3.FORWARD, CombatShot3D.new())
	assert_same(reused, projectile)
	assert_almost_eq((reused.sweep.shape as SphereShape3D).radius, .075, .0001)

func test_gunblade_resolves_projectile_and_kinetic_upgrades_separately() -> void:
	var turret := world.add_turret(Vector3.ZERO, "melee")
	turret.set_physics_process(false)
	turret.progression.award(110)
	assert_true(turret.evolve("gunblade"))
	var blade_before := turret._current_view(0).damage
	var gun_before := turret.gun_stats.damage
	ModifierService.add_modifier({"id": "gun_only", "stat": "damage", "operation": "increase", "value": .2, "filter": {"attack_family": ["projectile"]}})
	turret.invalidate_stats()
	assert_almost_eq(turret._current_view(0).damage, blade_before, .001)
	assert_almost_eq(turret.gun_stats.damage, gun_before * 1.2, .001)
	ModifierService.add_modifier({"id": "blade_only", "stat": "damage", "operation": "increase", "value": .3, "filter": {"attack_family": ["kinetic"]}})
	turret.invalidate_stats()
	assert_almost_eq(turret._current_view(0).damage, blade_before * 1.3, .001)
	assert_almost_eq(turret.gun_stats.damage, gun_before * 1.2, .001)
	assert_eq(turret.turret_type, "melee", "Hybrid retains ownership lineage")

func test_gunblade_sweeps_at_blade_tip_and_shoots_along_bore() -> void:
	var turret := world.add_turret(Vector3.ZERO, "melee")
	turret.set_physics_process(false)
	turret.progression.award(110)
	assert_true(turret.evolve("gunblade"))
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	var close := world.spawn_enemy(Vector3(0, 0, -1.3))
	close.set_physics_process(false)
	close.health = 100.0
	world.crowd.rebuild(world.enemies)
	var stats := turret._current_view(0)
	turret._spin_bat(.01, stats, stats.range_metres)
	assert_lt(close.health, 100.0)
	assert_not_null(turret.blade_tip)
	assert_almost_eq(WorldGeometry.planar(turret.blade_tip.global_position - turret.aim.global_position).length(), stats.range_metres, .001)
	var heading := WorldGeometry.planar(-turret.muzzle.global_basis.z).normalized()
	var distant := world.spawn_enemy(heading * 2.8)
	distant.set_physics_process(false)
	world.crowd.rebuild(world.enemies)
	turret._fire_gunblade()
	assert_eq(world.projectiles.size(), 1)
	var projectile := world.projectiles[0]
	assert_true(projectile.direction.is_equal_approx(heading))
	assert_eq(projectile.shot.source_id, turret.turret_id)
	assert_eq(projectile.shot.attack_families, ["projectile"])
	turret._fire_gunblade()
	assert_eq(world.projectiles.size(), 1, "Gun respects its cooldown")

func test_bow_branches_consume_all_three_milestones_and_change_attacks() -> void:
	for branch: String in ["repeater_bow", "greatbow"]:
		var turret := world.add_turret(Vector3.ZERO, "bow")
		turret.set_physics_process(false)
		var xp := 0
		for level in range(1, 15):
			xp += TurretProgression.cost_to_next(level)
		turret.progression.award(xp)
		var last_damage := 0.0
		for stage in range(1, 4):
			assert_true(turret.evolve(branch))
			assert_eq(turret.progression.evolution_stage, stage)
			var stats := turret._current_view(0)
			assert_gt(stats.damage, last_damage)
			last_damage = stats.damage
			if branch == "greatbow":
				var shot := turret._new_shot(stats)
				assert_gt(shot.visual_scale, 1.0)
				assert_gte(shot.pierce, 3)
				assert_gt(shot.knockback, 0.0)
		assert_true(turret.available_evolutions().is_empty())
		assert_eq(turret.progression.total_xp, xp)

func test_repeater_burst_is_timed_attributed_and_cancelled_at_wave_end() -> void:
	var turret := world.add_turret(Vector3.ZERO, "bow")
	turret.set_physics_process(false)
	turret.progression.award(110)
	assert_true(turret.evolve("repeater_bow"))
	var enemy := world.spawn_enemy(Vector3(0, 0, -3))
	enemy.set_physics_process(false)
	turret.target = enemy
	var stats := turret._current_view(0)
	turret._fire_projectile(stats)
	assert_eq(world.projectiles.size(), 1)
	assert_false(turret.loaded_arrow.visible)
	turret._tick_bow_burst(.04, stats)
	assert_eq(world.projectiles.size(), 1)
	turret._tick_bow_burst(.06, stats)
	assert_eq(world.projectiles.size(), 2)
	for projectile in world.projectiles:
		assert_eq(projectile.shot.visual_key, "arrow")
		assert_eq(projectile.shot.source_id, turret.turret_id)
		assert_eq(projectile.shot.attack_families, ["projectile"])
	turret._fire_projectile(stats)
	assert_eq(turret.bow_burst_left, 1)
	turret._physics_process(.1) # Shop state cancels a pending burst.
	assert_eq(turret.bow_burst_left, 0)

func test_flame_evolutions_trade_coverage_for_reach_and_burn() -> void:
	var wide := world.add_turret(Vector3.ZERO, "flamethrower")
	var jet := world.add_turret(Vector3(8, 0, 0), "flamethrower")
	for turret in [wide, jet]:
		turret.set_physics_process(false)
		var xp := 0
		for level in range(1, 15):
			xp += TurretProgression.cost_to_next(level)
		turret.progression.award(xp)
	for stage in range(1, 4):
		assert_true(wide.evolve("wide_flame"))
		assert_true(jet.evolve("focused_jet"))
		var wide_stats := wide._current_view(0)
		var jet_stats := jet._current_view(0)
		assert_gt(float(wide_stats.values.cone_degrees), float(jet_stats.values.cone_degrees))
		assert_gt(jet_stats.range_metres, wide_stats.range_metres)
		assert_gt(float(jet_stats.values.burn_ratio), float(wide_stats.values.burn_ratio))
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	var wide_enemy := world.spawn_enemy(Vector3(1.1, 0, -1.5))
	var jet_side := world.spawn_enemy(jet.position + Vector3(1.1, 0, -1.5))
	var jet_far := world.spawn_enemy(jet.position + Vector3(0, 0, -4.0))
	for enemy in [wide_enemy, jet_side, jet_far]:
		enemy.set_physics_process(false)
		enemy.health = 1000.0
	world.crowd.rebuild(world.enemies)
	wide._fire_flame(wide._current_view(0), wide._current_view(0).range_metres, Vector3.FORWARD)
	jet._fire_flame(jet._current_view(0), jet._current_view(0).range_metres, Vector3.FORWARD)
	assert_lt(wide_enemy.health, 1000.0, "Wide fan reaches the flank")
	assert_eq(jet_side.health, 1000.0, "Narrow jet excludes the flank")
	assert_lt(jet_far.health, 1000.0, "Jet reaches distant targets")
	assert_eq(jet_far.statuses.burn_source_id, jet.turret_id)
	assert_gt(jet_far.statuses.burn_dps, wide_enemy.statuses.burn_dps)

func test_bowling_branches_support_all_milestones_and_distinct_shots() -> void:
	for branch: String in ["heavy_roller", "bank_shot"]:
		var turret := world.add_turret(Vector3.ZERO, "bowling")
		turret.set_physics_process(false)
		var xp := 0
		for level in range(1, 15):
			xp += TurretProgression.cost_to_next(level)
		turret.progression.award(xp)
		var previous_damage := 0.0
		for stage in range(1, 4):
			assert_true(turret.evolve(branch))
			var shot := turret._new_shot(turret._current_view(0))
			assert_gt(shot.damage, previous_damage)
			previous_damage = shot.damage
			assert_eq(shot.attack_families, ["projectile", "kinetic"])
			if branch == "heavy_roller":
				assert_gt(shot.radius, .24)
				assert_gte(shot.pierce, 7)
				assert_eq(shot.ricochets, 0)
			else:
				assert_eq(shot.ricochets, stage * 2)
				assert_eq(shot.pierce, 0)
		assert_true(turret.available_evolutions().is_empty())

func test_shop_reports_evolved_stats_and_preview_does_not_mutate_combat_cache() -> void:
	var turret := world.add_turret(Vector3.ZERO, "melee")
	turret.set_physics_process(false)
	turret.progression.award(110)
	assert_true(turret.evolve("gunblade"))
	turret._current_view(0)
	var cached := turret.cached_stats.duplicate(true)
	var cached_gun := turret.gun_stats.values.duplicate(true)
	var before := ShopViewData.build_data(world)
	var after := ShopViewData.preview(world, ShopOffer.new("item", "dense_rounds", 10))
	var before_instance: Dictionary = {}
	var after_instance: Dictionary = {}
	for row: Dictionary in before.turrets:
		for instance: Dictionary in row.instances:
			if instance.id == turret.turret_id:
				before_instance = instance
	for row: Dictionary in after.turrets:
		for instance: Dictionary in row.instances:
			if instance.id == turret.turret_id:
				after_instance = instance
	assert_eq(before_instance.name, "Gunblade")
	assert_almost_eq(float(before_instance.combat.damage), turret.stats_view.damage, .001)
	assert_almost_eq(float(before_instance.gun.damage), turret.gun_stats.damage, .001)
	assert_almost_eq(float(after_instance.combat.damage), float(before_instance.combat.damage), .001)
	assert_gt(float(after_instance.gun.damage), float(before_instance.gun.damage))
	assert_eq(turret.cached_stats, cached)
	assert_eq(turret.gun_stats.values, cached_gun)
	assert_eq(ShopViewData.build_data(world), before, "Preview restores all temporary ownership and modifiers")

func test_fresh_resolution_matches_cached_evolved_stats_with_entrenchment() -> void:
	var turret := world.turrets[0]
	turret.progression.award(110)
	assert_true(turret.evolve("machine_gun"))
	turret.entrench_stacks_cached = 2
	turret.invalidate_stats()
	assert_eq(turret._current_stats(0), turret.resolve_attack_stats())
	var data := ShopViewData.build_data(world)
	assert_eq(data.turrets[0].instances[0].name, "Machine Gun")
	assert_almost_eq(float(data.turrets[0].instances[0].combat.fire_rate), turret.stats_view.fire_rate, .001)

func test_gunblade_later_forms_fire_attributed_bursts_from_moving_barrel() -> void:
	var turret := world.add_turret(Vector3.ZERO, "melee")
	turret.set_physics_process(false)
	var xp := 0
	for level in range(1, 15):
		xp += TurretProgression.cost_to_next(level)
	turret.progression.award(xp)
	for stage in range(3):
		assert_true(turret.evolve("gunblade"))
	assert_eq(turret.display_name(), "Stormblade")
	assert_eq(turret.progression.total_xp, xp)
	assert_true(turret.available_evolutions().is_empty())
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	var enemy := world.spawn_enemy(Vector3(0, 0, -2.8))
	enemy.set_physics_process(false)
	world.crowd.rebuild(world.enemies)
	turret._current_view(0)
	turret._fire_gunblade()
	assert_eq(world.projectiles.size(), 1)
	assert_eq(turret.gun_burst_left, 2)
	turret.aim.rotation.y = .3
	turret._tick_gunblade_burst(.07)
	assert_eq(world.projectiles.size(), 2)
	assert_false(world.projectiles[0].direction.is_equal_approx(world.projectiles[1].direction))
	turret._tick_gunblade_burst(.07)
	assert_eq(world.projectiles.size(), 3)
	for projectile in world.projectiles:
		assert_eq(projectile.shot.source_id, turret.turret_id)
		assert_eq(projectile.shot.attack_families, ["projectile"])
		assert_eq(projectile.shot.pierce, 1)
	assert_eq(turret.gun_burst_left, 0)
	turret.cooldown = 0.0
	turret.aim.rotation.y = 0.0
	turret._fire_gunblade()
	assert_eq(turret.gun_burst_left, 2)
	GameStateMachine.force_transition(GameStateMachine.GameState.SHOP)
	turret._physics_process(.1)
	assert_eq(turret.gun_burst_left, 0, "Wave end cancels delayed shots")

func test_cyclone_gatling_reaches_higher_spool_and_fires_piercing_rounds() -> void:
	var turret := world.turrets[0]
	var xp := 0
	for level in range(1, 15):
		xp += TurretProgression.cost_to_next(level)
	turret.progression.award(xp)
	for stage in range(3):
		assert_true(turret.evolve("machine_gun"))
	assert_eq(turret.display_name(), "Cyclone Gatling")
	var stats := turret._current_view(0)
	turret._tick_mechanisms(1.0, true)
	assert_eq(turret.spool, 1.5)
	turret._reset_cooldown(stats)
	assert_almost_eq(turret.cooldown, stats.cooldown_seconds / 2.5, .001)
	assert_eq(turret._new_shot(stats).pierce, 1)
	turret._tick_mechanisms(1.0, false)
	assert_eq(turret.spool, 0.0)
	assert_true(turret.available_evolutions().is_empty())

func test_omnifire_covers_all_twelve_unique_radial_directions() -> void:
	var turret := world.turrets[0]
	var xp := 0
	for level in range(1, 15):
		xp += TurretProgression.cost_to_next(level)
	turret.progression.award(xp)
	for stage in range(3):
		assert_true(turret.evolve("scatter"))
	assert_eq(turret.display_name(), "Omnifire")
	turret.target = world.spawn_enemy(turret.position + Vector3(0, 0, -2))
	turret.target.set_physics_process(false)
	turret._fire_projectile(turret._current_view(0))
	assert_eq(world.projectiles.size(), 12)
	var angles: Array[float] = []
	for projectile in world.projectiles:
		assert_eq(projectile.shot.source_id, turret.turret_id)
		angles.append(wrapf(atan2(projectile.direction.x, projectile.direction.z), 0.0, TAU))
	angles.sort()
	for i in range(12):
		var gap := wrapf(angles[(i + 1) % 12] - angles[i], 0.0, TAU)
		assert_almost_eq(gap, TAU / 12.0, .001)

func test_orbit_saber_has_three_visible_arms_and_three_sweep_directions() -> void:
	ModifierService.add_modifier({"id": "no_crit_overlap_test", "stat": "turret_crit_chance", "operation": "more", "value": 0.0})
	var turret := world.add_turret(Vector3.ZERO, "melee")
	turret.set_physics_process(false)
	var xp := 0
	for level in range(1, 15):
		xp += TurretProgression.cost_to_next(level)
	turret.progression.award(xp)
	for stage in range(1, 4):
		assert_true(turret.evolve("saber"))
		assert_eq(turret.saber_angles.size(), stage)
	assert_eq(turret.display_name(), "Orbit Saber")
	for index in range(1, 3):
		var arm := turret.aim.get_node("SaberArm%d" % index)
		assert_not_null(arm.get_node("Prism_Blade"))
		assert_not_null(arm.get_node("Ceramic_Hand"))
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	var targets: Array[CombatActor] = []
	for angle in turret.saber_angles:
		var enemy := world.spawn_enemy(Vector3.FORWARD.rotated(Vector3.UP, angle) * 1.4)
		enemy.set_physics_process(false)
		enemy.health = 1000.0
		targets.append(enemy)
	var overlapping := world.spawn_enemy(Vector3.ZERO)
	overlapping.set_physics_process(false)
	overlapping.health = 1000.0
	world.crowd.rebuild(world.enemies)
	var stats := turret._current_view(0)
	turret._spin_bat(.01, stats, stats.range_metres)
	for enemy in targets:
		assert_lt(enemy.health, 1000.0, "Each blade direction deals damage")
	assert_almost_eq(overlapping.health, 1000.0 - stats.damage, .001, "Overlapping blades share a rehit lockout")
	var health := overlapping.health
	turret._spin_bat(.01, stats, stats.range_metres)
	assert_eq(overlapping.health, health)

func test_siege_evolutions_expand_shell_blast_and_knockback() -> void:
	ModifierService.add_modifier({"id": "no_crit_siege_test", "stat": "turret_crit_chance", "operation": "more", "value": 0.0})
	var turret := world.add_turret(Vector3.ZERO, "plasma")
	turret.set_physics_process(false)
	var xp := 0
	for level in range(1, 15):
		xp += TurretProgression.cost_to_next(level)
	turret.progression.award(xp)
	var previous: CombatShot3D
	for stage in range(3):
		assert_true(turret.evolve("siege"))
		var current := turret._new_shot(turret._current_view(0))
		if previous:
			assert_gt(current.damage, previous.damage)
			assert_gt(current.radius, previous.radius)
			assert_gt(current.splash_radius, previous.splash_radius)
			assert_gt(current.knockback, previous.knockback)
		previous = current
	assert_eq(turret.display_name(), "Worldbreaker")
	assert_true(turret.available_evolutions().is_empty())
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	var inside := world.spawn_enemy(Vector3(previous.splash_radius + .1, 0, 0))
	var outside := world.spawn_enemy(Vector3(previous.splash_radius + 1.0, 0, 0))
	for enemy in [inside, outside]:
		enemy.set_physics_process(false)
		enemy.health = 1000.0
	world.combat.impact(null, Vector3.ZERO, Vector3.FORWARD, previous, world.enemies)
	assert_almost_eq(inside.health, 1000.0 - previous.damage, .001, "Blast includes hurtbox overlap")
	assert_gt(inside.knockback_velocity.x, 0.0)
	assert_eq(outside.health, 1000.0)
	var ball := world.fire_direction(Vector3.ZERO, Vector3.FORWARD, previous)
	assert_almost_eq((ball.sweep.shape as SphereShape3D).radius, .34, .001)
	ball.release()
	world.fire_direction(Vector3.ZERO, Vector3.FORWARD, CombatShot3D.new())
	assert_almost_eq((ball.sweep.shape as SphereShape3D).radius, .075, .001)

func test_evolution_preview_matches_committed_stats_without_mutating_actor() -> void:
	var turret := world.turrets[0]
	turret.progression.award(1500)
	turret.entrench_stacks_cached = 2
	world.shop.apply_item("polished_barrels")
	var snapshot := turret.progression.snapshot()
	var cached := turret.cached_stats.duplicate(true)
	var model := turret.model
	var preview := turret.resolve_attack_stats(false, "machine_gun", 1)
	assert_eq(turret.progression.snapshot(), snapshot)
	assert_eq(turret.cached_stats, cached)
	assert_same(turret.model, model)
	assert_true(turret.evolve("machine_gun"))
	assert_eq(turret.resolve_attack_stats(), preview)
