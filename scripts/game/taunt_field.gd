class_name TauntField
extends RefCounted

## The taunts currently standing in the arena (S1), one per Decoy. Enemies do not scan turrets: the Decoy publishes a
## `TauntPost` here and `EnemyActor.taunt_post` asks this short list, which is empty (one `posts.is_empty()` check per
## enemy per tick) in every run without a Decoy.
## A post is withdrawn when its Decoy stops fighting (wave end, pause, removal, run reset); `clear()` drops them all.
## Hooked enemies ('hooked' timed status, one timer per owning Decoy) find their orbit centre through `hook_anchor`.
const HOOKED: String = "hooked"

var posts: Array[TauntPost] = []

func has_posts() -> bool:
	return not posts.is_empty()

## Adds `post`, replacing the one its Decoy published before.
func publish(post: TauntPost) -> void:
	withdraw(post.owner_id)
	posts.append(post)

func withdraw(owner_id: int) -> void:
	for index in range(posts.size() - 1, -1, -1):
		if posts[index].owner_id == owner_id:
			posts.remove_at(index)

func post_of(owner_id: int) -> TauntPost:
	for post in posts:
		if post.owner_id == owner_id:
			return post
	return null

## The nearest live post whose radius covers `position`. A ranged enemy only answers posts that say `ranged`.
func post_for(position: Vector3, ranged_enemy: bool) -> TauntPost:
	var best: TauntPost = null
	var best_distance := INF
	var px := position.x
	var pz := position.z
	for post in posts:
		if ranged_enemy and not post.ranged:
			continue
		var dx := px - post.x
		var dz := pz - post.z
		var distance := dx * dx + dz * dz
		if distance <= post.radius_squared and distance < best_distance:
			# The turret is only touched once a post is in reach: a freed one is pruned here, a carried one is skipped.
			if not is_instance_valid(post.turret):
				posts.erase(post)
				return post_for(position, ranged_enemy)
			if not post.turret.carried:
				best = post
				best_distance = distance
	return best

## The nearest live post that holds a hook on `enemy`, or null when none does (the hook is orphaned).
func hook_anchor(enemy: CombatActor) -> TauntPost:
	var best: TauntPost = null
	var best_distance := INF
	for post in posts:
		if not post.is_live() or enemy.statuses.remaining_for_owner(HOOKED, post.owner_id) <= 0.0:
			continue
		var distance := WorldGeometry.planar(enemy.position - post.turret.position).length_squared()
		if distance < best_distance:
			best = post
			best_distance = distance
	return best

func clear() -> void:
	posts.clear()
