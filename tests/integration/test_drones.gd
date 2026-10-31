extends GutTest

## Engine piece S10, `Drones`: launching, the arena-wide and per-owner caps, flight (seek, orbit, hold, return and dock), the hover, the
## airframe, the pooled drawing and every clean-up path, driven without any turret (the Drone Bay that uses it is in
## `test_drone_bay_turret.gd`).

const STEP := 1.0 / 60.0

var rig: TurretTestRig
var world: ArenaWorld
var swarm: Drones

func before_each() -> void:
	rig = TurretTestRig.start(self, true)
	rig.disable_crits()
	world = rig.world
	swarm = world.drones
	# The run's starting turret stays out of the way unless a test moves it.
	for starting in world.turrets:
		starting.position = Vector3(24, 0, 16)

func after_each() -> void:
	TestHelpers.reset_flags()

func _drone(owner_id: int = 1, at: Vector3 = Vector3.ZERO) -> Drone:
	var drone := Drone.new()
	drone.owner_id = owner_id
	drone.position = at
	drone.home = at
	return drone

func _launched(owner_id: int = 1, at: Vector3 = Vector3.ZERO) -> Drone:
	var drone := _drone(owner_id, at)
	assert_true(swarm.launch(drone), "The drone launches")
	return drone

func _run(seconds: float) -> void:
	for i in roundi(seconds / STEP):
		swarm.tick(STEP)

func _planar_gap(a: Vector3, b: Vector3) -> float:
	return WorldGeometry.planar(a - b).length()

# --- Launching and the caps ---

func test_a_new_world_has_an_empty_swarm_with_a_fixed_drawing_buffer() -> void:
	assert_eq(swarm.count(), 0)
	assert_false(swarm.has_drones())
	assert_eq(swarm.multimesh.instance_count, GameConstants.DRONE_MAX)
	assert_eq(swarm.multimesh.visible_instance_count, 0)

func test_launching_counts_drones_by_owner_and_draws_them() -> void:
	_launched(1)
	_launched(1)
	_launched(2)
	assert_eq(swarm.count(), 3)
	assert_eq(swarm.count_of(1), 2)
	assert_eq(swarm.count_of(2), 1)
	assert_eq(swarm.count_of(3), 0)
	assert_eq(swarm.launched, 3)
	assert_eq(swarm.of_owner(1).size(), 2)
	assert_eq(swarm.multimesh.visible_instance_count, 3)

func test_the_arena_wide_cap_refuses_a_drone_and_never_pushes_one_out() -> void:
	var first := _launched(1)
	for i in GameConstants.DRONE_MAX - 1:
		_launched(1 + i % 4)
	assert_eq(swarm.count(), GameConstants.DRONE_MAX)
	var extra := _drone(9)
	assert_false(swarm.launch(extra), "The arena is full")
	assert_eq(swarm.count(), GameConstants.DRONE_MAX)
	assert_eq(swarm.count_of(9), 0)
	assert_false(first.spent, "Nobody else's drone was recycled")
	assert_eq(swarm.multimesh.visible_instance_count, GameConstants.DRONE_MAX)
	swarm.clear_owner(1)
	assert_lt(swarm.count(), GameConstants.DRONE_MAX)
	assert_true(swarm.launch(extra), "Room again")

func test_an_owner_cap_refuses_the_drone_that_would_pass_it() -> void:
	for i in 3:
		var drone := _drone(5)
		drone.owner_cap = 3
		assert_true(swarm.launch(drone))
	var over := _drone(5)
	over.owner_cap = 3
	assert_false(swarm.launch(over), "A fourth is refused")
	assert_eq(swarm.count_of(5), 3)
	var other := _drone(6)
	other.owner_cap = 3
	assert_true(swarm.launch(other), "Another owner has its own allowance")
	swarm.destroy(swarm.of_owner(5)[0])
	assert_true(swarm.launch(over), "A freed place can be taken")

func test_drawing_never_adds_nodes_however_many_drones_fly() -> void:
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var children := swarm.get_child_count()
	for round in 3:
		for i in GameConstants.DRONE_MAX:
			_launched(1 + i % 5, Vector3(float(i % 8) - 4.0, 0, float(i / 8)))
		_run(.2)
		swarm.clear()
	assert_eq(swarm.get_child_count(), children, "One multimesh for the whole swarm")
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes)
	assert_eq(swarm.multimesh.instance_count, GameConstants.DRONE_MAX)

# --- Flight ---

func test_a_docked_drone_sits_on_its_dock_and_follows_it() -> void:
	var drone := _launched(1, Vector3(2, 0, 1))
	_run(.5)
	assert_eq(drone.position, Vector3(2, 0, 1))
	drone.home = Vector3(-3, 0, 2)
	_run(.1)
	assert_eq(drone.position, Vector3(-3, 0, 2), "A moving bay carries its parked drones")
	assert_true(drone.is_docked())

func test_a_drone_seeks_a_point_without_passing_its_top_speed() -> void:
	var drone := _launched()
	drone.speed = 6.0
	drone.go_to(Vector3(5, 0, 0))
	var top := 0.0
	for i in 240:
		swarm.tick(STEP)
		top = maxf(top, drone.velocity.length())
	assert_lte(top, 6.0 + .001, "Never faster than its top speed")
	assert_lt(_planar_gap(drone.position, Vector3(5, 0, 0)), .25, "and it arrives and settles")
	assert_lt(drone.velocity.length(), .5)

func test_a_drone_climbs_off_its_dock_and_settles_back_onto_it() -> void:
	var drone := _launched()
	assert_almost_eq(drone.height(), Drone.DOCK_HEIGHT, .001)
	drone.go_to(Vector3(2, 0, 0))
	_run(.2)
	assert_gt(drone.altitude, Drone.DOCK_HEIGHT, "It rises")
	_run(1.0)
	assert_almost_eq(drone.altitude, Drone.HEIGHT, .001)
	drone.recall()
	_run(3.0)
	assert_true(drone.is_docked())
	_run(.6)
	assert_almost_eq(drone.altitude, Drone.DOCK_HEIGHT, .001)

func test_an_orbit_circles_its_anchor_at_its_radius_and_follows_a_moving_anchor() -> void:
	var drone := _launched()
	drone.orbit_radius = 1.5
	drone.orbit_rate = 2.0
	drone.orbit(Vector3(2, 0, 2))
	_run(2.0)
	for i in 30:
		swarm.tick(STEP)
		assert_almost_eq(_planar_gap(drone.position, Vector3(2, 0, 2)), 1.5, .35)
	var angle_before := drone.orbit_angle
	_run(.25)
	assert_ne(drone.orbit_angle, angle_before, "It keeps circling")
	for i in 240:
		drone.anchor += Vector3(.01, 0, 0)
		swarm.tick(STEP)
	assert_almost_eq(_planar_gap(drone.position, drone.anchor), 1.5, .5)

func test_a_drone_holds_beside_its_enemy_at_its_distance_and_circles_it() -> void:
	var enemy := rig.enemy(Vector3(3, 0, 0), 1.0e9)
	var drone := _launched()
	drone.engage(enemy, 1.0)
	_run(3.0)
	assert_almost_eq(_planar_gap(drone.position, enemy.position), 1.0, .2)
	var first := drone.position
	_run(2.0)
	assert_gt(_planar_gap(drone.position, first), .1, "It drifts round its enemy instead of hanging still")
	assert_almost_eq(_planar_gap(drone.position, enemy.position), 1.0, .25)

func test_a_drone_whose_enemy_dies_stays_where_it_is_and_reports_no_target() -> void:
	var enemy := rig.enemy(Vector3(3, 0, 0), 5.0)
	var drone := _launched()
	drone.engage(enemy, 1.0)
	_run(2.0)
	assert_true(drone.has_target())
	enemy.dead = true
	var at := drone.position
	_run(.5)
	assert_false(drone.has_target())
	assert_lt(_planar_gap(drone.position, at), .05, "It waits for its owner's next order")

func test_a_returning_drone_docks_when_it_arrives() -> void:
	var drone := _launched(1, Vector3(1, 0, 1))
	drone.go_to(Vector3(5, 0, 1))
	_run(1.5)
	drone.recall()
	_run(3.0)
	assert_true(drone.is_docked())
	assert_eq(drone.position, drone.home)
	assert_eq(drone.velocity, Vector3.ZERO)

func test_drones_stay_inside_the_arena() -> void:
	var drone := _launched()
	drone.go_to(Vector3(80, 0, -80))
	_run(8.0)
	assert_lte(absf(drone.position.x), WorldGeometry.HALF_ARENA.x)
	assert_lte(absf(drone.position.z), WorldGeometry.HALF_ARENA.y)

func test_a_drone_faces_its_enemy_while_holding_and_its_heading_otherwise() -> void:
	var enemy := rig.enemy(Vector3(0, 0, -4), 1.0e9)
	var drone := _launched(1, Vector3(0, 0, 0))
	drone.engage(enemy, 1.0)
	_run(2.0)
	var look := WorldGeometry.planar(enemy.position - drone.position)
	assert_almost_eq(drone.yaw, atan2(-look.x, -look.z), .3)

func test_the_hover_bobs_a_little_and_never_leaves_the_floor() -> void:
	var drone := _launched()
	drone.go_to(Vector3(1, 0, 0))
	_run(1.5)
	var low := 99.0
	var high := -99.0
	for i in 200:
		swarm.tick(STEP)
		low = minf(low, drone.height())
		high = maxf(high, drone.height())
	assert_gt(low, Drone.HEIGHT - Drone.BOB - .001)
	assert_lt(high, Drone.HEIGHT + Drone.BOB + .001)
	assert_gt(high - low, .02, "It bobs")

# --- The airframe ---

func test_an_airframe_wears_out_and_the_drone_goes() -> void:
	var drone := _launched()
	drone.life = .5
	var other := _launched()
	_run(.4)
	assert_false(drone.spent)
	_run(.2)
	assert_true(drone.spent, "Its airframe gave out")
	assert_false(other.spent, "No life means it never wears out")
	assert_eq(swarm.count(), 1)
	assert_eq(swarm.lost, 1)
	assert_eq(swarm.multimesh.visible_instance_count, 1)

func test_destroying_a_drone_twice_counts_once() -> void:
	var drone := _launched(3)
	swarm.destroy(drone, true)
	swarm.destroy(drone, true)
	assert_eq(swarm.count_of(3), 0)
	assert_eq(swarm.lost, 1)
	assert_eq(swarm.count(), 0)

func test_a_spent_drone_can_be_replaced_by_a_new_one_from_the_same_owner() -> void:
	var cap := 2
	var a := _drone(4)
	a.owner_cap = cap
	var b := _drone(4)
	b.owner_cap = cap
	swarm.launch(a)
	swarm.launch(b)
	a.life = .1
	_run(.2)
	assert_eq(swarm.count_of(4), 1)
	var replacement := _drone(4)
	replacement.owner_cap = cap
	assert_true(swarm.launch(replacement), "The slot is open again")
	assert_eq(swarm.count_of(4), 2)

# --- Clean-up ---

func test_clear_owner_drops_only_that_owners_drones() -> void:
	_launched(1)
	_launched(1)
	_launched(2)
	swarm.clear_owner(1)
	assert_eq(swarm.count_of(1), 0)
	assert_eq(swarm.count_of(2), 1)
	swarm.clear_owner(1)
	swarm.clear_owner(99)
	assert_eq(swarm.count(), 1)

func test_combat_stopping_clears_the_swarm_on_the_next_physics_step() -> void:
	_launched()
	rig.shop()
	swarm._physics_process(STEP)
	assert_eq(swarm.count(), 0)
	assert_eq(swarm.lost, 0, "Dropped, not worn out")

func test_pausing_clears_the_swarm() -> void:
	_launched()
	world.paused = true
	swarm._physics_process(STEP)
	assert_eq(swarm.count(), 0)

func test_clear_field_and_a_new_run_clear_the_swarm() -> void:
	_launched()
	world.clear_field(false)
	assert_eq(swarm.count(), 0)
	_launched()
	world.start_run()
	assert_eq(world.drones.count(), 0)

func test_defeat_clears_the_swarm() -> void:
	_launched()
	world._end_run_in_defeat("test")
	assert_eq(swarm.count(), 0)

func test_an_idle_swarm_costs_nothing_and_accepts_a_clear() -> void:
	swarm.tick(STEP)
	swarm.clear()
	swarm.clear_owner(3)
	assert_eq(swarm.count(), 0)

# --- Safety ---

func test_drones_flying_over_the_hero_and_turrets_hurt_nothing() -> void:
	var turret := rig.turret("normal", [], Vector3(1, 0, 0))
	var hero_health: float = world.player.health
	for i in 6:
		var drone := _launched(1, Vector3(0, 0, 0))
		drone.go_to(world.player.position)
	_run(3.0)
	assert_eq(world.player.health, hero_health)
	assert_not_null(turret)
	assert_eq(world.player.dead, false)
