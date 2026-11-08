extends GutTest

## The second level-5 branch of Plasma and Tesla and both of Tesla's: Mortar and Constellation (indirect shells that land on a
## marked circle), and Forked Coil, Storm Network, Capacitor and Thunderhead (forked chains, two coil heads, a charge meter and a
## storm cloud). Their rows are checked by the roster contract tests; this file checks the attacks.

const STEP := 1.0 / 60.0

var rig: TurretTestRig
var world: ArenaWorld

func before_each() -> void:
	rig = TurretTestRig.start(self)
	rig.disable_crits()
	world = rig.world
	GameStateService.current_wave = 1
	for starting in world.turrets:
		starting.position = Vector3(24, 0, 16)

func after_each() -> void:
	ModifierService.clear_modifiers()
	TestHelpers.reset_flags()

func _run(turret: TurretActor, seconds: float) -> void:
	rig.run(turret, seconds, STEP)

# --- Branches ---

func test_plasma_and_tesla_branch_at_level_5_and_each_upgrade_leads_to_its_own_capstone() -> void:
	for pair: Array in [["plasma", "siege", "worldbreaker"], ["plasma", "mortar", "constellation"], ["tesla", "forked_coil", "storm_network"], ["tesla", "capacitor", "thunderhead"]]:
		var turret := rig.turret(pair[0])
		rig.level_to(turret, TurretProgression.EVOLUTION_LEVELS[-1])
		assert_eq(turret.available_evolutions().size(), 2, "%s offers both branches" % pair[0])
		assert_true(turret.evolve(pair[1]), "%s takes %s" % [pair[0], pair[1]])
		assert_eq(turret.available_evolutions(), [pair[2]], "%s leads to %s" % [pair[1], pair[2]])
		assert_true(turret.evolve(pair[2]))

# --- Mortar and Constellation ---

func test_mortar_marks_the_ground_and_lands_after_its_delay_whether_or_not_the_enemy_stays() -> void:
	var mortar := rig.turret("plasma", ["mortar"])
	var stayed := rig.enemy(Vector3(0, 0, -3), 1000.0)
	rig.combat()
	_run(mortar, STEP * 2.0)
	var form := mortar.form as MortarForm
	assert_eq(form.blasts.size(), 1, "One shell is in the air")
	assert_eq(stayed.health, 1000.0, "Nothing lands at once")
	mortar.cooldown = 999.0
	_run(mortar, 0.9)
	assert_eq(stayed.health, 1000.0, "The shell is still on its way")
	_run(mortar, 0.4)
	assert_eq(form.blasts_landed, 1)
	assert_lt(stayed.health, 1000.0, "The shell lands on the marked circle")
	assert_true(form.blasts.is_empty())

func test_mortar_misses_an_enemy_that_left_the_marked_circle() -> void:
	var mortar := rig.turret("plasma", ["mortar"])
	var enemy := rig.enemy(Vector3(0, 0, -3), 1000.0)
	rig.combat()
	_run(mortar, STEP * 2.0)
	mortar.cooldown = 999.0
	enemy.position = Vector3(0, 0, -3.0) + Vector3(3.5, 0, 0)
	world.crowd.rebuild(world.enemies)
	_run(mortar, 1.5)
	assert_eq(enemy.health, 1000.0, "The shell lands where the target was")

func test_mortar_shell_never_knocks_back() -> void:
	var stats := TurretEvolution.base_stats("plasma", "mortar")
	assert_eq(float(stats.knockback_force), 0.0)
	assert_eq(float(TurretEvolution.base_stats("plasma", "constellation").knockback_force), 0.0)
	assert_gt(float(stats.range), float(TurretEvolution.base_stats("plasma", "siege").range), "The mortar outranges the siege cannon")

func test_constellation_lands_a_star_and_repeats_it_once() -> void:
	var turret := rig.turret("plasma", ["mortar", "constellation"])
	var centre := rig.enemy(Vector3(0, 0, -3), 1000.0)
	var ring := rig.enemy(Vector3(1.7, 0, -3), 1000.0)
	var outside := rig.enemy(Vector3(-3.2, 0, -3), 1000.0)
	rig.combat()
	_run(turret, STEP * 2.0)
	turret.cooldown = 999.0
	var form := turret.form as MortarForm
	assert_eq(form.blasts.size(), 14, "A centre blast and six more, twice")
	_run(turret, 1.3)
	assert_lt(ring.health, 1000.0, "The ring blast reaches the enemy beside the centre")
	assert_lt(centre.health, 1000.0)
	var after_first := centre.health
	assert_eq(outside.health, 1000.0, "An enemy beyond the star is spared")
	_run(turret, .6)
	assert_eq(form.blasts_landed, 14)
	assert_lt(centre.health, after_first, "The star lands a second time")

func test_nothing_lands_after_combat_ends() -> void:
	var mortar := rig.turret("plasma", ["mortar"])
	var enemy := rig.enemy(Vector3(0, 0, -3), 1000.0)
	rig.combat()
	_run(mortar, STEP * 2.0)
	assert_false((mortar.form as MortarForm).blasts.is_empty())
	rig.shop()
	rig.step(mortar)
	assert_true((mortar.form as MortarForm).blasts.is_empty(), "Wave end drops the queued shells")
	assert_eq(enemy.health, 1000.0)

func test_mortar_hardware_lifts_the_barrel_and_constellation_adds_a_star_halo() -> void:
	var mortar := rig.turret("plasma", ["mortar"])
	var barrel := mortar.model.find_child("Barrel", true, false) as Node3D
	assert_gt(barrel.rotation.x, .2, "The barrel is lifted for lobbing")
	var constellation := rig.turret("plasma", ["mortar", "constellation"])
	var halo := constellation.model.find_child("ConstellationHalo", true, false)
	assert_not_null(halo)
	assert_eq(halo.get_child_count(), 7, "The centre star and six round it")
	assert_null(mortar.model.find_child("ConstellationHalo", true, false))

# --- Tesla ---

func test_forked_coil_forks_after_the_first_hit_and_never_strikes_an_enemy_twice() -> void:
	var coil := rig.turret("tesla", ["forked_coil"])
	var first := rig.enemy(Vector3(0, 0, -2), 1000.0)
	var left := rig.enemy(Vector3(-1, 0, -3), 1000.0)
	var right := rig.enemy(Vector3(1, 0, -3), 1000.0)
	var rear := rig.enemy(Vector3(0, 0, -4), 1000.0)
	rig.combat()
	_run(coil, STEP * 2.0)
	var stats := coil._current_view(0.0)
	assert_almost_eq(first.health, 1000.0 - stats.damage, .01, "The nearest enemy takes the full hit")
	assert_almost_eq(left.health, 1000.0 - stats.damage * stats.chain_decay, .01, "Each fork takes one decayed hit")
	assert_almost_eq(right.health, 1000.0 - stats.damage * stats.chain_decay, .01)
	assert_lt(rear.health, 1000.0, "A fork continues on down the line")
	assert_gt(rear.health, 1000.0 - stats.damage * stats.chain_decay, "...and no enemy is struck twice by one strike")

func test_a_plain_tesla_chain_does_not_fork() -> void:
	var plain := rig.turret("tesla")
	var first := rig.enemy(Vector3(0, 0, -2), 1000.0)
	var left := rig.enemy(Vector3(-1, 0, -3), 1000.0)
	var right := rig.enemy(Vector3(1, 0, -3.1), 1000.0)
	rig.combat()
	_run(plain, STEP * 2.0)
	assert_lt(first.health, 1000.0)
	var untouched := int(left.health == 1000.0) + int(right.health == 1000.0)
	assert_lte(untouched, 1, "A single chain moves along one path, so at most one of the pair is spared")

func test_storm_network_alternates_its_two_heads_and_shares_one_jump_budget() -> void:
	var network := rig.turret("tesla", ["forked_coil", "storm_network"])
	assert_eq(network.chain_muzzles.size(), 2, "Two coil heads")
	var origins: Array[Vector3] = []
	var record := func(from: Vector3, _to: Vector3, hop: int) -> void:
		if hop == 0:
			origins.append(from)
	world.combat.chain_arc.connect(record)
	var line: Array[CombatActor] = []
	for index in 16:
		line.append(rig.enemy(Vector3(0, 0, -2.0 - .8 * index), 100000.0))
	rig.combat()
	_run(network, STEP * 2.0)
	var struck := 0
	for enemy in line:
		struck += int(enemy.health < 100000.0)
	assert_eq(struck, 11, "The primary plus two forks of five jumps each")
	network.cooldown = 0.0
	_run(network, STEP * 2.0)
	world.combat.chain_arc.disconnect(record)
	assert_gte(origins.size(), 2)
	assert_false(origins[0].is_equal_approx(origins[origins.size() - 1]), "The second strike leaves from the other head")

func test_capacitor_meter_fills_while_the_cooldown_runs() -> void:
	var capacitor := rig.turret("tesla", ["capacitor"])
	var meter := capacitor.model.find_child("ChargeMeter", true, false) as Node3D
	assert_not_null(meter)
	assert_eq(capacitor.model.find_children("CapacitorCan*", "MeshInstance3D", true, false).size(), 2)
	var enemy := rig.enemy(Vector3(0, 0, -2), 100000.0)
	rig.combat()
	_run(capacitor, STEP * 2.0)
	assert_lt(enemy.health, 100000.0, "The discharge lands")
	var empty := meter.scale.x
	_run(capacitor, .9)
	assert_gt(meter.scale.x, empty, "The meter climbs as the charge builds")
	var stats := capacitor._current_view(0.0)
	assert_gt(stats.damage, 2.0 * TurretRegistry.get_base_stats("tesla")["damage"], "A discharge is more than twice a base strike")
	assert_lt(stats.fire_rate, 1.0, "...paid for with a slow recharge")

func test_thunderhead_leaves_a_storm_cloud_that_arcs_then_clears() -> void:
	var head := rig.turret("tesla", ["capacitor", "thunderhead"])
	var enemy := rig.enemy(Vector3(0, 0, -2), 100000.0)
	var bystander := rig.enemy(Vector3(1.0, 0, -2.5), 100000.0)
	rig.combat()
	_run(head, STEP * 2.0)
	var form := head.form as ChainForm
	assert_false(form.cloud.is_empty(), "The strike raises a cloud")
	assert_not_null(head.get_node_or_null("StormCloud"))
	var after_strike := enemy.health
	head.cooldown = 999.0
	_run(head, 2.7)
	assert_gte(form.cloud_arcs, 4, "The cloud arcs about every half second")
	assert_lt(enemy.health, after_strike, "The cloud's arcs add damage to the strike")
	assert_lt(bystander.health, 100000.0)
	assert_true(form.cloud.is_empty(), "The cloud lasts 2.5 seconds")
	await get_tree().process_frame
	assert_null(head.get_node_or_null("StormCloud"))

func test_a_storm_cloud_is_dropped_when_combat_ends() -> void:
	var head := rig.turret("tesla", ["capacitor", "thunderhead"])
	rig.enemy(Vector3(0, 0, -2), 100000.0)
	rig.combat()
	_run(head, STEP * 2.0)
	assert_false((head.form as ChainForm).cloud.is_empty())
	rig.shop()
	rig.step(head)
	assert_true((head.form as ChainForm).cloud.is_empty())

func test_forked_coil_wears_a_pair_of_prongs() -> void:
	var coil := rig.turret("tesla", ["forked_coil"])
	assert_eq(coil.model.find_children("ForkProng*", "MeshInstance3D", true, false).size(), 2)
	assert_null(rig.turret("tesla").model.find_child("ForkProng", true, false), "The base coil has none")
