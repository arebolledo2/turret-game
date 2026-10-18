extends GutTest

const SPEED := 3.75 # m/s, the hero's base speed
const STEP := 1.0 / 60.0

func _run(start: Vector3, direction: Vector3, seconds: float) -> Vector3:
	var velocity := start
	for _step in roundi(seconds / STEP):
		velocity = HeroActor.steer_velocity(velocity, direction, SPEED, STEP)
	return velocity

func _time_to_reach(start: Vector3, direction: Vector3, goal: Vector3, tolerance: float) -> float:
	var velocity := start
	var elapsed := 0.0
	while velocity.distance_to(goal) > tolerance and elapsed < 5.0:
		velocity = HeroActor.steer_velocity(velocity, direction, SPEED, STEP)
		elapsed += STEP
	return elapsed

func test_reaches_full_speed_quickly_from_rest() -> void:
	assert_lt(_time_to_reach(Vector3.ZERO, Vector3.RIGHT, Vector3.RIGHT * SPEED, .01), .2)

func test_reversing_is_much_faster_than_the_old_single_rate() -> void:
	var time := _time_to_reach(Vector3.RIGHT * SPEED, Vector3.LEFT, Vector3.LEFT * SPEED, .01)
	assert_lt(time, .2, "full reversal in under 0.2 s (it took ~0.54 s before)")

func test_reversal_brakes_harder_than_speeding_up() -> void:
	var speeding := HeroActor.steer_velocity(Vector3.ZERO, Vector3.RIGHT, SPEED, STEP)
	var reversing := HeroActor.steer_velocity(Vector3.RIGHT * SPEED, Vector3.LEFT, SPEED, STEP)
	assert_gt((Vector3.RIGHT * SPEED - reversing).length(), speeding.length(), "braking against the input beats accelerating")

func test_no_turn_boost_from_standstill_or_when_aligned() -> void:
	var step_distance := GameConstants.PLAYER_ACCELERATION * WorldGeometry.METRES_PER_PIXEL * STEP
	assert_almost_eq(HeroActor.steer_velocity(Vector3.ZERO, Vector3.RIGHT, SPEED, STEP).length(), step_distance, .0001)
	assert_almost_eq(HeroActor.steer_velocity(Vector3.RIGHT, Vector3.RIGHT, SPEED, STEP).length(), 1.0 + step_distance, .0001)

func test_sideways_turn_is_boosted_by_half() -> void:
	var step_distance := GameConstants.PLAYER_ACCELERATION * WorldGeometry.METRES_PER_PIXEL * STEP
	var boost := lerpf(1.0, GameConstants.PLAYER_TURN_BOOST, .5)
	var turned := HeroActor.steer_velocity(Vector3.RIGHT * SPEED, Vector3.FORWARD, SPEED, STEP)
	var expected := (Vector3.RIGHT * SPEED).move_toward(Vector3.FORWARD * SPEED, step_distance * boost)
	assert_almost_eq(turned.distance_to(expected), 0.0, .0001)

func test_releasing_input_stops_without_overshoot() -> void:
	var velocity := _run(Vector3.RIGHT * SPEED, Vector3.ZERO, .5)
	assert_eq(velocity, Vector3.ZERO)
