extends GutTest

class RecordingEffects extends TurretAttackEffects:
	var traces: int = 0
	func draw_tracer(_end: Vector2) -> void:
		traces += 1

class RecordingEmitter extends ProjectileEmitter:
	var shots: Array[Dictionary] = []
	func emit_shot(origin: Vector2, direction: Vector2, stats: Dictionary, friendly: bool, damage_type: int, is_crit: bool) -> Node2D:
		shots.append({"origin": origin, "direction": direction, "stats": stats.duplicate(true), "friendly": friendly, "damage_type": damage_type, "crit": is_crit})
		return null

func before_each() -> void:
	TestHelpers.reset_all_services()

func test_selection_respects_distance_range_and_exclusions() -> void:
	var near := Node2D.new()
	var far := Node2D.new()
	add_child_autofree(near)
	add_child_autofree(far)
	near.position = Vector2(10, 0)
	far.position = Vector2(20, 0)
	assert_same(TargetSelection.select(Vector2.ZERO, [far, near]), near)
	assert_same(TargetSelection.select(Vector2.ZERO, [far, near], 30, true), far)
	assert_null(TargetSelection.select(Vector2.ZERO, [far, near], 5))
	assert_same(TargetSelection.select(Vector2.ZERO, [far, near], 30, false, [near]), far)

func test_projectile_attack_can_run_without_spawning_a_scene() -> void:
	var owner := Node2D.new()
	var target := Node2D.new()
	add_child_autofree(owner)
	add_child_autofree(target)
	target.position = Vector2(50, 0)
	var combat := TurretCombat.new()
	add_child_autofree(combat)
	var emitter := RecordingEmitter.new()
	combat.initialize(owner, "normal", {"damage": 12.0}, RecordingEffects.new(), emitter)
	combat.target = target
	combat._fire_projectile()
	assert_eq(emitter.shots.size(), 1)
	assert_eq(emitter.shots[0].direction, Vector2.RIGHT)
	assert_true(emitter.shots[0].friendly)
	assert_gt(emitter.shots[0].stats.damage, 0.0)

func test_melee_cooldowns_advance_only_with_simulation_time() -> void:
	var owner := Node2D.new()
	add_child_autofree(owner)
	var combat := TurretCombat.new()
	add_child_autofree(combat)
	combat.initialize(owner, "melee", {"range": 80.0}, RecordingEffects.new())
	combat.melee_hit_cooldowns[123] = 0.0
	combat.process(0.2)
	assert_true(combat.melee_hit_cooldowns.has(123))
	combat.process(0.0)
	assert_true(combat.melee_hit_cooldowns.has(123))
	combat.process(0.11)
	assert_false(combat.melee_hit_cooldowns.has(123))
