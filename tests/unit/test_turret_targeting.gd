extends GutTest

## Targeting modes use bare CombatActors (no scene tree): only position, health, type and the dead flag matter.

func after_each() -> void:
	TurretRegistry.clear_test_types()

func _enemy(x: float, type_id: String = "basic", health: float = 20.0) -> CombatActor:
	var actor := CombatActor.new()
	autofree(actor)
	actor.is_enemy = true
	actor.enemy_type = type_id
	actor.health = health
	actor.max_health = maxf(health, 20.0)
	actor.position = Vector3(x, 0, 0)
	return actor

func _list(actors: Array) -> Array[CombatActor]:
	var typed: Array[CombatActor] = []
	typed.assign(actors)
	return typed

func test_toughest_picks_highest_current_health_not_max() -> void:
	var healthy := _enemy(3.0, "basic", 40.0)
	var wounded_giant := _enemy(1.0, "tank", 10.0)
	wounded_giant.max_health = 500.0
	assert_same(TurretTargeting.toughest(Vector3.ZERO, 10.0, _list([wounded_giant, healthy])), healthy)

func test_toughest_ties_go_to_the_nearest() -> void:
	var far := _enemy(5.0, "basic", 30.0)
	var near := _enemy(2.0, "basic", 30.0)
	var weak := _enemy(1.0, "basic", 5.0)
	assert_same(TurretTargeting.toughest(Vector3.ZERO, 10.0, _list([far, near, weak])), near)
	assert_same(TurretTargeting.toughest(Vector3.ZERO, 10.0, _list([near, far, weak])), near, "Order does not matter")

func test_toughest_ignores_out_of_range_and_dead_enemies() -> void:
	var out_of_range := _enemy(50.0, "tank", 999.0)
	var dead := _enemy(1.0, "tank", 500.0)
	dead.dead = true
	var valid := _enemy(4.0, "basic", 8.0)
	assert_same(TurretTargeting.toughest(Vector3.ZERO, 10.0, _list([out_of_range, dead, valid])), valid)
	assert_null(TurretTargeting.toughest(Vector3.ZERO, 10.0, _list([out_of_range, dead])))
	assert_null(TurretTargeting.toughest(Vector3.ZERO, 10.0, _list([])))

func test_toughest_treats_bosses_and_tech_drop_crates_as_targets() -> void:
	var boss := _enemy(6.0, "broadside_baron", 800.0)
	var crate := _enemy(2.0, "basic", 300.0)
	crate.stationary = true
	var grunt := _enemy(1.0, "basic", 20.0)
	assert_same(TurretTargeting.toughest(Vector3.ZERO, 10.0, _list([grunt, crate, boss])), boss)
	assert_same(TurretTargeting.toughest(Vector3.ZERO, 10.0, _list([grunt, crate])), crate)

func test_toughest_counts_range_to_the_hurtbox_edge() -> void:
	var edge := _enemy(10.2, "basic", 50.0) # basic footprint .36 reaches in
	assert_same(TurretTargeting.toughest(Vector3.ZERO, 10.0, _list([edge])), edge)
	edge.position.x = 10.5
	assert_null(TurretTargeting.toughest(Vector3.ZERO, 10.0, _list([edge])))

func test_backline_prefers_kites_lobbers_and_tenders_over_nearer_enemies() -> void:
	var grunt := _enemy(1.0, "basic")
	for type_id in TurretTargeting.BACKLINE_TYPES:
		var ranged := _enemy(7.0, type_id)
		assert_same(TurretTargeting.backline(Vector3.ZERO, 10.0, _list([grunt, ranged])), ranged, type_id)

func test_backline_picks_nearest_among_preferred_types() -> void:
	var tender := _enemy(8.0, "tender")
	var kite := _enemy(4.0, "kite")
	var lobber := _enemy(6.0, "lobber")
	var grunt := _enemy(1.0, "basic")
	assert_same(TurretTargeting.backline(Vector3.ZERO, 10.0, _list([tender, grunt, lobber, kite])), kite)

func test_backline_falls_back_to_closest_when_no_ranged_enemy_is_in_range() -> void:
	var near := _enemy(2.0, "fast")
	var far := _enemy(5.0, "tank")
	var out_of_range_kite := _enemy(40.0, "kite")
	assert_same(TurretTargeting.backline(Vector3.ZERO, 10.0, _list([far, out_of_range_kite, near])), near)
	assert_null(TurretTargeting.backline(Vector3.ZERO, 10.0, _list([out_of_range_kite])))

func test_backline_does_not_prefer_bosses() -> void:
	var boss := _enemy(5.0, "broadside_baron", 800.0)
	var grunt := _enemy(2.0, "basic")
	assert_same(TurretTargeting.backline(Vector3.ZERO, 10.0, _list([boss, grunt])), grunt)

func test_farthest_and_closest() -> void:
	var near := _enemy(2.0)
	var far := _enemy(8.0)
	var dead := _enemy(9.0)
	dead.dead = true
	var candidates := _list([far, dead, near])
	assert_same(TurretTargeting.farthest(Vector3.ZERO, 10.0, candidates), far)
	assert_same(TurretTargeting.closest(Vector3.ZERO, 10.0, candidates), near)

func test_select_dispatches_by_mode_and_defaults_to_closest() -> void:
	var near := _enemy(2.0, "basic", 10.0)
	var tough := _enemy(6.0, "tank", 90.0)
	var kite := _enemy(9.0, "kite", 6.0)
	var all := _list([near, tough, kite])
	assert_same(TurretTargeting.select("toughest", Vector3.ZERO, 12.0, all), tough)
	assert_same(TurretTargeting.select("backline", Vector3.ZERO, 12.0, all), kite)
	assert_same(TurretTargeting.select("farthest", Vector3.ZERO, 12.0, all), kite)
	assert_same(TurretTargeting.select("anything_else", Vector3.ZERO, 12.0, all), near)

func test_handles_only_modes_this_helper_resolves() -> void:
	for mode in ["toughest", "backline", "farthest"]:
		assert_true(TurretTargeting.handles(mode), mode)
	for mode in ["closest", "cluster", ""]:
		assert_false(TurretTargeting.handles(mode), mode)

func test_registry_reports_targeting_from_entry_or_base_stats() -> void:
	assert_eq(TurretRegistry.get_targeting("normal"), "closest")
	assert_eq(TurretRegistry.get_targeting("plasma"), "cluster")
	assert_eq(TurretRegistry.get_targeting("sniper"), "farthest")
	assert_eq(TurretRegistry.get_targeting("not_a_turret"), "closest")
	TurretRegistry.register_test_type("test_top", {"base_stats": {"damage": 1.0}, "targeting": "toughest"})
	TurretRegistry.register_test_type("test_stat", {"base_stats": {"damage": 1.0, "targeting": "backline"}})
	assert_eq(TurretRegistry.get_targeting("test_top"), "toughest")
	assert_eq(TurretRegistry.get_targeting("test_stat"), "backline")
