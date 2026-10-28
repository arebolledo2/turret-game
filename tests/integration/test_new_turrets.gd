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
	world.pickup_root.process_mode = Node.PROCESS_MODE_DISABLED
	world.preparation.deploy()
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)

func enemy(at: Vector3) -> CombatActor:
	var actor := world.spawn_enemy(at)
	actor.set_physics_process(false)
	actor.health = 100
	actor.max_health = 100
	return actor

func turret(type_id: String, at: Vector3 = Vector3(0, 0, 0)) -> TurretActor:
	var result := world.add_turret(at, type_id)
	result.set_physics_process(false)
	return result

func stats(type_id: String) -> Dictionary:
	return TurretStatsService.get_turret_stats(type_id, float(world.difficulty_config["turret_damage_mult"]))

func tick(actor: TurretActor, delta: float = .1) -> void:
	world.crowd.rebuild(world.enemies)
	actor._physics_process(delta)

# --- Melee ---

func test_melee_visual_tip_tracks_modified_reach_without_changing_height() -> void:
	var bat := turret("melee", Vector3(3, 0, 2))
	var height := bat.muzzle.global_position.y
	var view := TurretStats.new(stats("melee"))
	for reach: float in [view.range_metres * 1.5, view.range_metres, view.range_metres * 2.0]:
		bat.form.spin(.1, view, reach)
		var actual := WorldGeometry.planar(bat.muzzle.global_position - bat.aim.global_position).length()
		assert_almost_eq(actual, reach, .001, "Visible tip follows the attack radius without accumulated scaling")
		assert_almost_eq(bat.muzzle.global_position.y, height, .001)

func test_melee_bat_hits_enemy_in_swept_arc_with_outward_knockback() -> void:
	TestHelpers.disable_crits()
	var bat := turret("melee")
	var target := enemy(Vector3(0, 0, -1.0))
	tick(bat)
	assert_almost_eq(target.health, 100.0 - float(stats("melee")["damage"]), .001)
	assert_lt(target.knockback_velocity.z, 0.0, "Pushed away from the turret")
	assert_almost_eq(bat.aim.rotation.y, deg_to_rad(float(stats("melee")["rotation_rate"])) * .1, .001)

func test_melee_ignores_enemies_behind_the_bat_or_beyond_reach() -> void:
	var bat := turret("melee")
	var behind := enemy(Vector3(0, 0, 1.0))
	var beyond := enemy(Vector3(0, 0, -2.0))
	tick(bat)
	assert_eq(behind.health, 100.0)
	assert_eq(beyond.health, 100.0)

func test_melee_rehit_lockout_prevents_double_hits_then_expires() -> void:
	var bat := turret("melee")
	var target := enemy(Vector3(0, 0, -1.0))
	# Park the enemy in the sweep for two ticks inside the lockout, then a full revolution later.
	tick(bat, .05)
	var after_first := target.health
	bat.form.spin_angle = 0.0
	tick(bat, .05)
	assert_eq(target.health, after_first, "Lockout blocks an immediate second hit")
	for step in range(12):
		tick(bat, .05)
	bat.form.spin_angle = 0.0
	tick(bat, .05)
	assert_lt(target.health, after_first, "Hit again once the lockout has expired")

func test_carried_melee_cannot_hit_enemies_at_its_old_ground_position() -> void:
	world.player.position = Vector3(5, 0, 5)
	var bat := turret("melee")
	var target := enemy(Vector3(0, 0, -1.0))
	bat.carried = true
	tick(bat)
	assert_eq(target.health, 100.0)

func test_melee_can_hit_every_enemy_in_one_sweep() -> void:
	var bat := turret("melee")
	var first := enemy(Vector3(0, 0, -1.0))
	var second := enemy(Vector3(-.2, 0, -.9))
	tick(bat, .2)
	assert_lt(first.health, 100.0)
	assert_lt(second.health, 100.0)

# --- Tesla ---

func test_chain_hits_primary_then_nearest_unhit_with_decay() -> void:
	var shot := CombatShot3D.from_stats({"damage": 10.0}, GameEnums.DamageType.ELECTRIC)
	var a := enemy(Vector3(1, 0, 0))
	var b := enemy(Vector3(2, 0, 0))
	var c := enemy(Vector3(3, 0, 0))
	var far := enemy(Vector3(8, 0, 0))
	watch_signals(world.combat)
	var hits := world.combat.chain(Vector3.ZERO, a, shot, 3, 1.5, .7, world.enemies)
	assert_eq(hits, 3, "Chain stops when nothing is in jump range")
	assert_almost_eq(a.health, 90.0, .001)
	assert_almost_eq(b.health, 93.0, .001)
	assert_almost_eq(c.health, 95.1, .001)
	assert_eq(far.health, 100.0)
	assert_signal_emit_count(world.combat, "chain_arc", 3)

func test_chain_never_hits_the_same_enemy_twice_and_respects_jump_limit() -> void:
	var shot := CombatShot3D.from_stats({"damage": 10.0}, GameEnums.DamageType.ELECTRIC)
	var group: Array[CombatActor] = []
	for index in range(6):
		group.append(enemy(Vector3(index * .5, 0, 0)))
	var hits := world.combat.chain(Vector3(-1, 0, 0), group[0], shot, 2, 1.0, 1.0, world.enemies)
	assert_eq(hits, 3, "Primary plus two jumps")
	assert_eq(group[3].health, 100.0)

func test_chain_continues_through_a_kill() -> void:
	var shot := CombatShot3D.from_stats({"damage": 500.0}, GameEnums.DamageType.ELECTRIC)
	var a := enemy(Vector3(1, 0, 0))
	var b := enemy(Vector3(1.5, 0, 0))
	var hits := world.combat.chain(Vector3.ZERO, a, shot, 3, 1.0, .7, world.enemies)
	assert_eq(hits, 2)
	assert_true(a.dead and b.dead)
	assert_eq(world.enemies.size(), 0)

func test_tesla_turret_fires_chain_at_nearest_enemy_and_respects_cooldown() -> void:
	var coil := turret("tesla")
	var near := enemy(Vector3(1, 0, 0))
	var neighbour := enemy(Vector3(2, 0, 0))
	var out_of_range := enemy(Vector3(5, 0, 0))
	watch_signals(world.combat)
	coil.target_clock = 0.0
	tick(coil, .01)
	assert_lt(near.health, 100.0)
	assert_lt(neighbour.health, 100.0)
	assert_eq(out_of_range.health, 100.0)
	assert_signal_emit_count(world.combat, "chain_arc", 2)
	var health := near.health
	tick(coil, .01)
	assert_eq(near.health, health, "Fire rate gates the next bolt")

func test_arc_effects_are_pooled_and_bounded() -> void:
	for index in range(CombatEffects3D.MAX_ARCS + 10):
		world.effects.show_arc(Vector3.ZERO, Vector3(index + 1, 0, 0))
	assert_eq(world.effects.arcs.size(), CombatEffects3D.MAX_ARCS)
	world.effects.reset()
	for arc in world.effects.arcs:
		assert_false(arc.visible)

# --- Shared plumbing ---

func test_crowd_radius_query_returns_only_living_actors_inside_radius() -> void:
	var inside := enemy(Vector3(1, 0, 1))
	var outside := enemy(Vector3(3, 0, 0))
	var dead := enemy(Vector3(.5, 0, 0))
	dead.dead = true
	world.crowd.rebuild(world.enemies)
	var found := world.crowd.query_radius(Vector3.ZERO, 1.5)
	assert_true(found.has(inside))
	assert_false(found.has(outside))
	assert_false(found.has(dead))

func test_shop_sells_new_turrets_with_descriptions_and_summary() -> void:
	for type_id in ["tesla", "melee"]:
		assert_true(ArenaShop.TURRETS.has(type_id))
		var offer := ShopOffer.new("turret", type_id, 0)
		assert_ne(ArenaShop.offer_description(offer), "")
		assert_ne(ArenaShop.offer_name(offer), "")
		assert_gt(world.turret_price(type_id), 0)
		turret(type_id)
	assert_string_contains(world.shop.build_summary(), "Melee ×1")
	assert_string_contains(world.shop.build_summary(), "Tesla ×1")

func test_new_turret_models_honor_aim_and_muzzle_contract() -> void:
	for type_id in ["tesla", "melee"]:
		var actor := turret(type_id, Vector3(3, 0, 0))
		assert_not_null(actor.aim, type_id)
		assert_not_null(actor.muzzle, type_id)
