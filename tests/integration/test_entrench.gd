extends GutTest

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_flags()
	world = load("res://scenes/game/arena.tscn").instantiate() as ArenaWorld
	add_child_autofree(world)
	await wait_process_frames(2)

func after_each() -> void:
	ModifierService.clear_modifiers()
	TestHelpers.reset_flags()

func _turret() -> TurretActor:
	var turret := world.add_turret(Vector3(2, 0, 2), "normal")
	await wait_process_frames(1)
	return turret

func test_stacks_follow_stay_time_and_cap() -> void:
	var turret := await _turret()
	turret.stay_time = GameConstants.ENTRENCH_STACK_SECONDS * 2.5
	assert_eq(turret.entrench_stacks(), 2)
	turret.stay_time = 9999.0
	assert_eq(turret.entrench_stacks(), GameConstants.ENTRENCH_MAX_STACKS)

func test_pickup_resets_stacks() -> void:
	var turret := await _turret()
	turret.stay_time = 30.0
	turret.carried = true
	assert_eq(turret.stay_time, 0.0)
	assert_eq(turret.entrench_stacks(), 0)

func test_stacks_raise_damage_and_fire_rate() -> void:
	var turret := await _turret()
	var base := TurretStatsService.get_turret_stats("normal", float(world.difficulty_config["turret_damage_mult"]))
	turret.entrench_stacks_cached = 3
	turret.invalidate_stats()
	var stats := turret._current_view(0.0).values
	assert_almost_eq(float(stats["damage"]), float(base["damage"]) * (1.0 + 3.0 * GameConstants.ENTRENCH_DAMAGE_PER_STACK), .001)
	assert_almost_eq(float(stats["fire_rate"]), float(base["fire_rate"]) * (1.0 + 3.0 * GameConstants.ENTRENCH_FIRE_RATE_PER_STACK), .001)

func test_items_retune_entrench() -> void:
	var turret := await _turret()
	ModifierService.add_modifier({"id": "t1", "stat": "entrench_stack_seconds", "operation": "increase", "value": -0.5})
	ModifierService.add_modifier({"id": "t2", "stat": "entrench_max_stacks", "operation": "add", "value": 2})
	ModifierService.add_modifier({"id": "t3", "stat": "entrench_bonus", "operation": "increase", "value": 0.5})
	turret.stay_time = GameConstants.ENTRENCH_STACK_SECONDS * .5 * 7.0
	assert_eq(turret.entrench_stacks(), GameConstants.ENTRENCH_MAX_STACKS + 2)
	turret.entrench_stacks_cached = 7
	assert_almost_eq(turret.entrench_damage_bonus(), 7.0 * GameConstants.ENTRENCH_DAMAGE_PER_STACK * 1.5, .0001)


func test_stay_time_accrues_only_in_combat() -> void:
	var turret := await _turret()
	turret.stay_time = 0.0
	turret._physics_process(1.0)
	assert_eq(turret.stay_time, 1.0 if world.is_combat() else 0.0)

func test_preview_follows_carry() -> void:
	var turret := await _turret()
	world.placement.carried = turret
	turret.carried = true
	world.placement.update_preview()
	assert_not_null(world.placement.preview)
	assert_true(world.placement.preview.visible)
	world.placement.carried = null
	world.placement.update_preview()
	assert_false(world.placement.preview.visible)
