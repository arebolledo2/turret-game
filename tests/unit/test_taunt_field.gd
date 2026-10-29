extends GutTest

## S1 taunt bookkeeping: `TauntField` is the short list enemies ask for a Decoy's pull, so these tests pin who answers whom
## (nearest live post in reach, ranged only when the post says so) and that a post goes away with its turret.

var field: TauntField

func before_each() -> void:
	field = TauntField.new()

func _turret(id: int, at: Vector3) -> TurretActor:
	var turret: TurretActor = autofree(TurretActor.new())
	turret.turret_id = id
	turret.position = at
	return turret

func _post(id: int, at: Vector3, radius: float, ranged: bool = false) -> TauntPost:
	var post := TauntPost.new(_turret(id, at))
	post.radius = radius
	post.ranged = ranged
	field.publish(post)
	return post

func test_an_empty_field_pulls_nothing() -> void:
	assert_false(field.has_posts())
	assert_null(field.post_for(Vector3.ZERO, false))
	assert_null(field.post_for(Vector3.ZERO, true))

func test_a_post_covers_bodies_inside_its_radius_only() -> void:
	var post := _post(1, Vector3(5, 0, 0), 4.5)
	assert_same(field.post_for(Vector3(5, 0, 4.4), false), post)
	assert_same(field.post_for(Vector3(5, 0, 4.5), false), post, "The edge is inside")
	assert_null(field.post_for(Vector3(5, 0, 4.6), false))
	assert_true(post.covers(Vector3(5, 0, 1)))
	assert_false(post.covers(Vector3(5, 3, 5)), "Height is ignored, the ground distance decides")

func test_the_nearest_post_wins() -> void:
	var near := _post(1, Vector3(0, 0, 0), 5.0)
	_post(2, Vector3(6, 0, 0), 5.0)
	assert_same(field.post_for(Vector3(2, 0, 0), false), near)
	assert_eq(field.post_for(Vector3(5, 0, 0), false).owner_id, 2)

func test_ranged_enemies_only_answer_a_ranged_post() -> void:
	var melee_only := _post(1, Vector3.ZERO, 5.0, false)
	assert_same(field.post_for(Vector3(1, 0, 0), false), melee_only)
	assert_null(field.post_for(Vector3(1, 0, 0), true), "A plain Decoy does not draw Kites and Lobbers")
	var wide := _post(2, Vector3(8, 0, 0), 7.0, true)
	assert_same(field.post_for(Vector3(1, 0, 0), true), wide, "The Maelstrom does, even when a nearer plain post exists")
	assert_same(field.post_for(Vector3(1, 0, 0), false), melee_only, "Melee enemies still take the nearer one")

func test_publishing_again_replaces_the_same_owners_post() -> void:
	var first := _post(1, Vector3.ZERO, 4.0)
	var turret := first.turret
	var second := TauntPost.new(turret)
	second.radius = 7.0
	field.publish(second)
	assert_eq(field.posts.size(), 1)
	assert_same(field.post_of(1), second)

func test_withdraw_removes_only_that_owner() -> void:
	_post(1, Vector3.ZERO, 4.0)
	_post(2, Vector3(1, 0, 0), 4.0)
	field.withdraw(1)
	assert_null(field.post_of(1))
	assert_not_null(field.post_of(2))
	field.clear()
	assert_false(field.has_posts())

func test_a_freed_turret_leaves_the_field() -> void:
	var turret := TurretActor.new()
	var post := TauntPost.new(turret)
	post.radius = 5.0
	field.publish(post)
	turret.free()
	assert_null(field.post_for(Vector3.ZERO, false))
	assert_false(field.has_posts(), "The stale post was dropped on the lookup")

func test_hook_anchor_needs_a_timer_for_that_owner() -> void:
	var enemy: CombatActor = autofree(CombatActor.new())
	enemy.position = Vector3(1, 0, 0)
	var near := _post(1, Vector3.ZERO, 5.0)
	var far := _post(2, Vector3(4, 0, 0), 5.0)
	assert_null(field.hook_anchor(enemy), "No hook yet")
	enemy.statuses.apply_timed(TauntField.HOOKED, 60.0, 2)
	assert_same(field.hook_anchor(enemy), far, "Only the owner that hooked it can anchor it")
	enemy.statuses.apply_timed(TauntField.HOOKED, 60.0, 1)
	assert_same(field.hook_anchor(enemy), near, "With two hooks the nearer Decoy anchors")
	field.withdraw(1)
	assert_same(field.hook_anchor(enemy), far, "A Decoy that left the field lets go")
