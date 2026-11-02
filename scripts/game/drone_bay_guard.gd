class_name DroneBayGuard
extends RefCounted

## Guardian Wing's shoot-down job for one bay: looks at the hostile bolts and shells in flight (ten times a second), sends a ready
## drone at each one aimed at the hero, steers it there and shoots the shot down. What it protects is the hero and only the hero: a
## bolt aimed at the hero, or a shell whose blast would reach the hero's spot, within the form's `intercept_reach` of the hero. Boss
## ground slams (no shell to shoot), beams and anything aimed at the core are left alone. Each drone shoots down at most one in
## `intercept_cooldown` seconds. Owned by a `DroneBayForm`, which reads its numbers and drone list.
const INTERCEPT_INTERVAL: float = .1
## A drone shoots a hostile shot down from this close. A bolt counts as aimed at the hero when its path passes within `GUARD_PAD`
## metres of the hero, and a shell when its blast would come within `GUARD_PAD` metres of the hero (the hero may step out of it).
const FLAK_RANGE: float = 2.4
const GUARD_PAD: float = .8
## How far ahead along a bolt's path a drone flies to meet it, in seconds of the bolt's travel.
const LEAD_SECONDS: float = .25

## Weak, so the form and its guard do not hold each other alive.
var _form: WeakRef
var form: DroneBayForm:
	get:
		return _form.get_ref() as DroneBayForm
## Drones on a shoot-down job and the hostile shot each is after.
var jobs: Dictionary = {}
var clock: float = 0.0
## Shots shot down since the bay was made (tests and tools read it).
var intercepts: int = 0

func _init(owner: DroneBayForm) -> void:
	_form = weakref(owner)

func is_guarding(drone: Drone) -> bool:
	return jobs.has(drone)

## Forgets a drone's job (it is gone or came down).
func forget(drone: Drone) -> void:
	jobs.erase(drone)

func reset() -> void:
	jobs.clear()
	clock = 0.0

func is_idle() -> bool:
	return jobs.is_empty()

func tick(delta: float) -> void:
	clock -= delta
	if clock <= 0.0:
		clock = INTERCEPT_INTERVAL
		scan()

## Looks at the hostile shots in flight and sends a ready drone at each one that is aimed at the hero.
func scan() -> void:
	var hero := form.actor.world.player
	if not is_instance_valid(hero) or hero.dead:
		return
	var threats: Array[EnemyOrdnance] = []
	for node in form.actor.get_tree().get_nodes_in_group("hostile_ordnance"):
		var shot := node as EnemyOrdnance
		if shot != null and is_threat(shot, hero.position):
			threats.append(shot)
	if threats.is_empty():
		return
	threats.sort_custom(func(a: EnemyOrdnance, b: EnemyOrdnance) -> bool:
		return _hero_gap(a, hero.position) < _hero_gap(b, hero.position))
	for shot in threats:
		if _guarded(shot):
			continue
		var drone := _ready_guard(shot)
		if drone == null:
			break
		jobs[drone] = shot

## True when `shot` (a hostile bolt or shell) is aimed at the hero's spot, within the wing's reach of the hero.
func is_threat(shot: EnemyOrdnance, hero_at: Vector3) -> bool:
	if shot.world != form.actor.world or shot.is_queued_for_deletion() or shot.to_core:
		return false
	var reach := form.intercept_reach()
	match shot.kind:
		"bolt":
			var offset := WorldGeometry.planar(hero_at - shot.position)
			if offset.length() > reach or shot.heading.length_squared() < .000001:
				return false
			var along := offset.dot(shot.heading)
			if along < -.3:
				return false
			var across := absf(offset.x * shot.heading.z - offset.z * shot.heading.x)
			return across <= GUARD_PAD
		"area":
			if shot.ground_strike:
				return false
			var gap := WorldGeometry.planar(shot.target_at - hero_at).length()
			return gap <= shot.radius + GUARD_PAD and gap <= reach
	return false

func _hero_gap(shot: EnemyOrdnance, hero_at: Vector3) -> float:
	return WorldGeometry.planar((shot.target_at if shot.kind == "area" else shot.position) - hero_at).length()

func _guarded(shot: EnemyOrdnance) -> bool:
	for drone: Drone in jobs:
		if jobs[drone] == shot:
			return true
	return false

## The ready drone nearest to `shot`: not docked, not on a shoot-down, its own cooldown spent.
func _ready_guard(shot: EnemyOrdnance) -> Drone:
	var at := WorldGeometry.planar(shot.position)
	var best: Drone = null
	var best_gap := INF
	for drone in form.live_drones():
		if drone.is_docked() or drone.spent or drone.aux_cooldown > 0.0 or jobs.has(drone):
			continue
		var gap := WorldGeometry.planar(drone.position).distance_squared_to(at)
		if gap < best_gap:
			best = drone
			best_gap = gap
	return best

## Steers a drone on a shoot-down toward its shot and fires when it is close; lets it go back to work when the shot is gone.
func drive(drone: Drone) -> void:
	var shot := jobs[drone] as EnemyOrdnance
	if shot == null or not is_instance_valid(shot) or shot.is_queued_for_deletion():
		_release(drone)
		return
	var at := WorldGeometry.planar(shot.position)
	var gap := WorldGeometry.planar(drone.position).distance_to(at)
	if gap <= FLAK_RANGE:
		_shoot_down(drone, shot)
		return
	# Fly to where the bolt will be a moment from now (a shell stays where it is).
	var lead := shot.heading * shot.shot_speed * LEAD_SECONDS if shot.kind == "bolt" else Vector3.ZERO
	drone.go_to(at + lead)

func _shoot_down(drone: Drone, shot: EnemyOrdnance) -> void:
	var world := form.actor.world
	var from := Vector3(drone.position.x, drone.height(), drone.position.z)
	world.effects.show_tracer(from, shot.global_position)
	world.effects.show_burst(shot.global_position, "ion")
	world.audio.play_cue("shock", from)
	shot.queue_free()
	intercepts += 1
	drone.aux_cooldown = form.intercept_cooldown()
	_release(drone)

func _release(drone: Drone) -> void:
	jobs.erase(drone)
	drone.orbit(form.anchor())
