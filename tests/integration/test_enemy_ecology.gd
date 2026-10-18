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
	world.turrets[0].set_physics_process(false)
	world.preparation.deploy()
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)

func enemy(kind: String, at: Vector3 = Vector3.ZERO) -> CombatActor:
	var result := world.spawn_enemy(at, kind)
	result.set_physics_process(false)
	return result

func test_wave_rosters_are_distinct_and_spend_budget_reproducibly() -> void:
	for wave in range(1, 21):
		var plan := EnemyEcology.schedule(wave, 120)
		var spent := 0
		assert_eq(plan, EnemyEcology.schedule(wave, 120))
		for kind in plan:
			assert_true(EnemyEcology.roster(wave).has(kind))
			spent += EnemyEcology.cost(kind)
		assert_lte(spent, 120)
		assert_gte(spent, 118)
	assert_false(EnemyEcology.roster(9).has("kite"))
	assert_false(EnemyEcology.roster(8).has("lobber"))
	assert_eq(EnemyEcology.BOSSES[20], "grand_marionettist")

func test_drowse_wakes_warns_then_loses_interest() -> void:
	var beetle := enemy("drowse")
	world.player.position = Vector3(1, 0, 0)
	assert_eq(beetle.brain.move(.1, beetle.speed), Vector3.ZERO)
	assert_true(beetle.brain.awake)
	assert_false(beetle.brain.contact_allowed())
	beetle.brain.move(.8, beetle.speed)
	assert_gt(beetle.brain.move(.1, beetle.speed).length(), 0.0)
	world.player.position = Vector3(7, 0, 0)
	beetle.brain.move(2.1, beetle.speed)
	assert_false(beetle.brain.awake)
	assert_false(beetle.brain.contact_allowed())

func test_damage_wakes_beetle_without_removing_leash() -> void:
	var beetle := enemy("drowse")
	world.player.position = Vector3(8, 0, 0)
	beetle.take_damage(.1)
	assert_true(beetle.brain.awake)
	beetle.brain.move(2.1, beetle.speed)
	assert_false(beetle.brain.awake)

func test_summons_have_no_economy_pickups() -> void:
	var skitter := enemy("skitter")
	assert_eq(skitter.scrap_value, 0)
	var before := world.pickup_root.get_child_count()
	skitter.take_damage(10000)
	assert_eq(world.pickup_root.get_child_count(), before)

func test_hopper_windup_locks_heading_and_has_safe_recovery() -> void:
	var hopper := enemy("hopper")
	world.player.position = Vector3(1, 0, 0)
	hopper.brain.move(.1, hopper.speed)
	assert_eq(hopper.brain.pounce.phase, ChargeController3D.Phase.WINDUP)
	assert_false(hopper.brain.contact_allowed())
	var locked := hopper.brain.pounce.heading
	world.player.position = Vector3(-1, 0, 0)
	hopper.brain.move(.7, hopper.speed)
	assert_eq(hopper.brain.pounce.heading, locked)
	assert_true(hopper.brain.contact_allowed())
	hopper.brain.move(.4, hopper.speed)
	assert_false(hopper.brain.contact_allowed())

func test_hostile_bolt_hits_only_hero_once_and_cleanup_removes_attacks() -> void:
	var kite := enemy("kite", Vector3(2, 0, 0))
	world.player.position = Vector3.ZERO
	var shot := EnemyOrdnance.launch(kite, "bolt", Vector3(1, .5, 0), Vector3.ZERO, 3.0)
	world.actor_root.add_child(shot)
	shot.set_physics_process(false)
	var hp := world.player.health
	shot._physics_process(.2)
	assert_lt(world.player.health, hp)
	assert_true(shot.is_queued_for_deletion())
	var area := EnemyOrdnance.launch(kite, "area", Vector3.ZERO, Vector3.ZERO, 4.0)
	world.actor_root.add_child(area)
	world.finish_wave()
	assert_true(area.is_queued_for_deletion())

func test_old_enemy_sizes_are_reduced_without_changing_stats() -> void:
	assert_almost_eq(enemy("basic").body_scale, .9, .001)
	assert_almost_eq(enemy("tank").body_scale, 1.26, .001)
	assert_almost_eq(enemy("fast").body_scale, .72, .001)

func test_early_waves_mix_few_lazy_beetles_with_active_enemies() -> void:
	for wave in range(1, 6):
		assert_gt(float(EnemyEcology.roster(wave).drowse), 0.0)
		assert_lte(float(EnemyEcology.roster(wave).drowse), 40.0, "Beetles are a minority so early waves stay interesting")
		assert_lte(EnemyEcology.budget_multiplier(wave), .8)
		for kind in EnemyEcology.roster(wave):
			assert_true(kind in ["drowse", "basic", "fast"])

func test_boss_timeout_clears_without_reward_and_final_wave_wins() -> void:
	GameStateService.current_wave = 20
	var boss := enemy("grand_marionettist", Vector3(4, 0, 0))
	assert_gt(boss.health, 1000.0)
	world.finish_wave()
	assert_true(world.drops.pending_items.is_empty())
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.VICTORY)
	assert_true(world.enemies.is_empty())

func test_boss_kill_reserves_high_rarity_reward_without_ending_wave() -> void:
	GameStateService.current_wave = 6
	var boss := enemy("brass_ram", Vector3(4, 0, 0))
	world.combat.apply_hit(boss, CombatHit3D.new(100000.0, Vector3.ZERO))
	assert_eq(world.drops.pending_items.size(), 1)
	assert_eq(ItemRegistry.get_rarity(world.drops.pending_items[0].id), GameEnums.ItemRarity.EPIC)
	assert_eq(world.drops.pending_items[0].source, "BOSS DEFEATED")
	assert_true(world.is_combat())
	world.combat.apply_hit(boss, CombatHit3D.new(100000.0, Vector3.ZERO))
	assert_eq(world.drops.pending_items.size(), 1, "kill reward once")

func test_active_tether_dies_with_its_anchor() -> void:
	var anchor := enemy("anchor", Vector3.ZERO)
	var tether := EnemyOrdnance.launch(anchor, "beam", Vector3.ZERO, Vector3(2, 0, 0), 3.0)
	tether.warning_time = .01
	world.actor_root.add_child(tether)
	tether.set_physics_process(false)
	tether._physics_process(.02)
	assert_true(tether.fired)
	anchor.dead = true
	tether._physics_process(.02)
	assert_true(tether.is_queued_for_deletion())

func test_prism_lens_destruction_interrupts_and_stuns() -> void:
	var boss := enemy("prism_conductor", Vector3(3, 0, 0))
	boss.health = boss.max_health * .5
	boss.brain.move(.01, boss.speed)
	assert_eq(boss.brain.children.size(), 2)
	for lens in boss.brain.children:
		lens.set_physics_process(false)
		lens.dead = true
	boss.brain.move(.01, boss.speed)
	assert_eq(boss.brain.state, EnemyBrain.State.STUNNED)
	assert_almost_eq(boss.brain.clock, 2.0, .001)
	assert_eq(boss.brain.move(.2, boss.speed), Vector3.ZERO)

func test_hatchery_caps_summons_and_never_awards_scrap() -> void:
	var tender := enemy("tender", Vector3(3, 0, 0))
	for cycle in range(4):
		tender.brain.state = EnemyBrain.State.WARNING
		tender.brain.clock = 0.0
		tender.brain.move(.01, tender.speed)
	assert_eq(tender.brain.children.size(), 4)
	for child in tender.brain.children:
		child.set_physics_process(false)
		assert_eq(child.scrap_value, 0)
	assert_lte(world.waves.active_count("skitter"), 8)

func test_ecology_imported_clips_play_without_legacy_leg_layer() -> void:
	for kind in ["drowse", "hopper", "kite", "lobber", "tender", "brass_ram", "prism_conductor", "grand_marionettist", "skitter", "lens", "anchor", "puppet"]:
		var actor := enemy(kind)
		assert_not_null(actor.ecology_motion, kind)
		assert_null(actor.clockwork_motion)
		var animation := actor.ecology_motion.player
		assert_not_null(animation, kind + " AnimationPlayer")
		if not animation: continue
		for clip in ["Idle", "Walk", "Swim", "Attack"]:
			assert_true(animation.has_animation(clip), kind + " " + clip)
		actor.ecology_motion.tick(.1, true, false, false)
		assert_eq(animation.current_animation, "Walk")
		assert_gt(animation.current_animation_position, 0.0)

func test_marionettist_final_phase_charge_completes_without_becoming_a_volley() -> void:
	var boss := enemy("grand_marionettist", Vector3(3, 0, 0))
	boss.health = boss.max_health * .2
	boss.brain.move(.01, boss.speed)
	boss.brain.clock = 0.0
	boss.brain.attacks = 1
	boss.brain.pounce.phase = ChargeController3D.Phase.APPROACH
	boss.brain.move(.01, boss.speed)
	assert_eq(boss.brain.attack_mode, "charge")
	assert_eq(boss.brain.pounce.phase, ChargeController3D.Phase.WINDUP)
	boss.brain.move(1.2, boss.speed)
	assert_eq(boss.brain.pounce.phase, ChargeController3D.Phase.DASH)
	assert_eq(boss.brain.attacks, 1)
	boss.brain.move(.9, boss.speed)
	assert_eq(boss.brain.attacks, 2)

func test_precision_warning_cap_defers_extra_attackers() -> void:
	for index in range(3):
		var kite := enemy("kite", Vector3(3, 0, index * .3))
		kite.brain.clock = 0.0
		kite.brain.move(.01, kite.speed)
	var warnings := 0
	for actor in world.enemies:
		if actor.brain and actor.brain.state == EnemyBrain.State.WARNING: warnings += 1
	assert_eq(warnings, 2)

func test_last_combat_tick_can_award_boss_before_timeout_cleanup() -> void:
	GameStateService.current_wave = 6
	world.waves.boss_spawned = true
	world.waves.remaining_spawns = 0
	var boss := enemy("brass_ram", Vector3(4, 0, 0))
	world.waves.time_left = .001
	world.waves.tick(.01)
	assert_true(world.is_combat(), "cleanup is deferred until actors have their final tick")
	world.combat.apply_hit(boss, CombatHit3D.new(100000.0, Vector3.ZERO))
	await get_tree().process_frame
	assert_eq(world.drops.pending_items.size(), 1)
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.WAVE_END)

func test_tender_prunes_freed_children_without_aborting() -> void:
	var tender := enemy("tender", Vector3(4, 0, 0))
	var child := enemy("skitter", Vector3(5, 0, 0))
	tender.brain.children.append(child)
	world.enemies.erase(child)
	child.free()
	tender.brain.move(.1, tender.speed)
	assert_eq(tender.brain.children.size(), 0)

func test_warning_slot_counts_only_nearby_warning_enemies() -> void:
	var first := enemy("kite", Vector3.ZERO)
	var second := enemy("kite", Vector3(2, 0, 0))
	var third := enemy("kite", Vector3(3, 0, 0))
	var far := enemy("kite", Vector3(20, 0, 0))
	assert_true(first.brain._warning_slot(false))
	second.brain.state = EnemyBrain.State.WARNING
	assert_true(first.brain._warning_slot(false))
	third.brain.state = EnemyBrain.State.WARNING
	assert_false(first.brain._warning_slot(false))
	far.brain.state = EnemyBrain.State.WARNING
	third.brain.state = EnemyBrain.State.IDLE
	assert_true(first.brain._warning_slot(false))
	second.dead = true
	assert_true(first.brain._warning_slot(false))

func test_actual_hopper_uses_speed_matched_legs_during_charge() -> void:
	var hopper := enemy("hopper", Vector3(3, 0, 0))
	assert_not_null(hopper.ecology_motion)
	assert_null(hopper.clockwork_motion, "The red hopper has a different rig from the horned charger")
	hopper.brain.state = EnemyBrain.State.ATTACK
	hopper.velocity = Vector3(6.6, 0, 0)
	hopper._animate(.01, Vector3.RIGHT, true)
	var motion := hopper.ecology_motion
	assert_eq(motion.current, "Walk", "Moving dash must not use the slow crouch/extension Attack clip")
	motion.player.seek(0.0, true)
	hopper._animate(.03, Vector3.RIGHT, true)
	assert_almost_eq(motion.player.current_animation_position, .22, .002, "Reduced Motion keeps the dash stride in sync")
	var leg := hopper.visual.find_child("Leg_L_0", true, false) as Node3D
	assert_not_null(leg)
	var pose := leg.transform
	hopper._animate(.04, Vector3.RIGHT, true)
	assert_false(leg.transform.is_equal_approx(pose), "Actual imported leg pivots move")
	hopper.velocity = Vector3.ZERO
	hopper.brain.state = EnemyBrain.State.WARNING
	hopper._animate(.01, Vector3.ZERO, false)
	assert_eq(motion.current, "Attack", "Stationary windup retains the authored crouch")
	hopper.brain.state = EnemyBrain.State.IDLE
	hopper._animate(.01, Vector3.ZERO, false)
	assert_eq(motion.current, "Idle")
