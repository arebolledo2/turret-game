extends GutTest

## ShockwaveRing: the ring runs out at a fixed speed and strikes each enemy once, nearest first.

func _enemy(at: Vector3) -> CombatActor:
	var actor := autofree(EnemyActor.new()) as CombatActor
	actor.position = at
	return actor

func _candidates(list: Array) -> Array[CombatActor]:
	var result: Array[CombatActor] = []
	for actor in list:
		result.append(actor)
	return result

func test_the_ring_grows_at_its_speed_and_stops_at_the_reach() -> void:
	var ring := ShockwaveRing.new(Vector3(3, 0, 4), 2.6, 8.0)
	assert_eq(ring.origin, Vector3(3, 0, 4))
	assert_eq(ring.radius, 0.0)
	ring.advance(.1, [] as Array[CombatActor])
	assert_almost_eq(ring.radius, .8, .0001)
	assert_false(ring.is_finished())
	ring.advance(.2, [] as Array[CombatActor])
	assert_almost_eq(ring.radius, 2.4, .0001)
	ring.advance(.5, [] as Array[CombatActor])
	assert_eq(ring.radius, 2.6, "It never overshoots")
	assert_true(ring.is_finished())
	assert_almost_eq(ring.seconds_to_reach(4.0), .5, .0001)

func test_near_enemies_are_struck_before_far_ones() -> void:
	var far := _enemy(Vector3(2.2, 0, 0))
	var near := _enemy(Vector3(0, 0, -.9))
	var middle := _enemy(Vector3(0, 0, 1.6))
	var all := _candidates([far, near, middle])
	var ring := ShockwaveRing.new(Vector3.ZERO, 2.6, 8.0)
	var order: Array[CombatActor] = []
	var times: Dictionary = {}
	var elapsed := 0.0
	for step in 60:
		elapsed += 1.0 / 60.0
		for enemy in ring.advance(1.0 / 60.0, all):
			order.append(enemy)
			times[enemy] = elapsed
	assert_eq(order, _candidates([near, middle, far]), "Struck in order of distance")
	assert_lt(float(times[near]), float(times[middle]))
	assert_lt(float(times[middle]), float(times[far]))
	# The ring reaches an enemy when it touches the body: distance minus the body radius, at 8 m/s.
	assert_almost_eq(float(times[far]), (2.2 - far.hurtbox_radius()) / 8.0, 1.0 / 60.0 + .001)

func test_an_enemy_is_struck_only_once() -> void:
	var enemy := _enemy(Vector3(1, 0, 0))
	var ring := ShockwaveRing.new(Vector3.ZERO, 3.0, 8.0)
	var hits := 0
	for step in 120:
		hits += ring.advance(1.0 / 60.0, _candidates([enemy])).size()
	assert_eq(hits, 1)

func test_enemies_beyond_the_reach_are_never_struck_and_the_dead_are_skipped() -> void:
	var out := _enemy(Vector3(3.6, 0, 0))
	var dead := _enemy(Vector3(1, 0, 0))
	dead.dead = true
	var ring := ShockwaveRing.new(Vector3.ZERO, 2.6, 8.0)
	var hits := 0
	for step in 120:
		hits += ring.advance(1.0 / 60.0, _candidates([out, dead])).size()
	assert_eq(hits, 0, "Out of reach (even counting the body radius), and a dead enemy is not a target")

func test_a_body_straddling_the_edge_of_the_reach_is_struck() -> void:
	var edge := _enemy(Vector3(2.6 + 0.2, 0, 0))
	var ring := ShockwaveRing.new(Vector3.ZERO, 2.6, 8.0)
	var hits := 0
	for step in 120:
		hits += ring.advance(1.0 / 60.0, _candidates([edge])).size()
	assert_eq(hits, 1, "Basic enemies are about 0.36 m wide, so a centre 0.2 m past the radius is still touched")

func test_advance_with_zero_time_strikes_whatever_the_ring_already_overlaps() -> void:
	var under_foot := _enemy(Vector3(.1, 0, 0))
	var close := _enemy(Vector3(1.0, 0, 0))
	var ring := ShockwaveRing.new(Vector3.ZERO, 2.6, 8.0)
	var first := ring.advance(0.0, _candidates([under_foot, close]))
	assert_eq(first, _candidates([under_foot]), "Only the enemy touching the turret at release")
	assert_eq(ring.radius, 0.0)

func test_one_attack_target_set_is_shared_with_the_shot() -> void:
	var shot := CombatShot3D.new()
	var ring := ShockwaveRing.new(Vector3.ZERO, 2.0, 8.0, shot)
	assert_same(ring.shot, shot)
	ring.attack_targets[1] = true
	assert_true(ring.attack_targets.has(1))
