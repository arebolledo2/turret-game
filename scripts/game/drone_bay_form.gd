class_name DroneBayForm
extends TurretForm

## Drone Bay / Escort Drones / Guardian Wing / Reaper Swarm: the turret that attacks with drones (`FIRE_DRONES`), on engine piece S10
## (`Drones` for the flight, the airframe and the drawing; `Drone` for one drone's state). One class serves the unevolved bay and its
## three forms; the rows in `TurretForms` only change numbers and params. The stats are per drone: `damage` is one shot, `fire_rate`
## the shots per second of each drone, `drone_count` how many the bay keeps in the air, and `range` the leash (how far from the
## anchor a drone will go after an enemy). The bay owns `drone_count` slots; each holds one drone, and a slot that loses its drone
## (the airframe wears out) is refilled `rebuild_seconds` later, launched from the bay's dock.
##   Drone Bay     (sortie) the drones wait on the bay's dock; with an enemy within the leash of the BAY a docked drone flies out,
##                 hovers beside it and shoots, and after `sortie_seconds` (or when nothing is left within the leash) flies back and
##                 docks for `dock_seconds` before it goes again.
##   Escort Drones (`escort`) the drones orbit the HERO instead and shoot enemies within the leash of the hero; they stay out.
##   Guardian Wing (`escort` and `intercept`) an escort that also shoots down hostile bolts and shells aimed at the hero. What it
##                 protects is the hero and only the hero: a bolt aimed at the hero, or a shell whose blast would reach the hero's
##                 spot, within `intercept_reach` metres of the hero. Boss ground slams (no shell to shoot), beams and anything
##                 aimed at the core are left alone. Each drone shoots down at most one in `intercept_cooldown` seconds.
##   Reaper Swarm  (`escort` and `hunt`) an escort whose drones all dive at the nearest Kite, Lobber or Tender within `hunt_reach`
##                 of the hero (TurretTargeting.BACKLINE_TYPES) before anything else, for `hunt_bonus` more damage against them.
##                 Each kill by one of its drones launches an extra drone for `kill_drone_seconds`, at most `max_extra` at a time.
## Drones never hurt the hero or a turret: a shot is an instant hit on a chosen enemy, built like any turret shot
## (`TurretActor._new_shot`: damage type, attack families, source id, crit rolled per hit) and delivered through `Combat3D.impact`,
## so crits, Exposed, Marked, burn, item multipliers and kill credit apply. A drone cannot be hurt (enemies attack only the hero
## and the core), so it leaves the arena only when its airframe wears out (`airframe_seconds`), when combat stops or the bay is
## removed or evolves, or (extras) when their few seconds are up.
## Cost: per physics step one pass over the bay's own drones (at most `MAX_PER_BAY` plus its extras) and nothing else; the enemy
## look-up is one crowd-grid query five times a second per bay and the hostile-ordnance scan (Guardian Wing) ten times a second
## over the handful of nodes in the `hostile_ordnance` group. Nothing here scans the whole enemy list.
## State: the slots, their rebuild clocks, the extras and the cached candidates. All of it is dropped when combat stops (`clear`, run
## every idle frame), when the turret is removed or evolves (`removed`) and on a run reset (the turret leaves the tree).
const SCAN_INTERVAL: float = .2
const INTERCEPT_INTERVAL: float = .1
## Most drones one bay's slots may hold, whatever the stat says.
const MAX_PER_BAY: int = 8
const DOCK_RADIUS: float = .95
const DEFAULT_SPEED: float = 8.0
const DEFAULT_HOLD: float = 1.0
const DEFAULT_ORBIT: float = 1.1
const ORBIT_RATE: float = 1.8
const DEFAULT_AIRFRAME: float = 50.0
const DEFAULT_REBUILD: float = 3.0
const DEFAULT_SORTIE: float = 7.0
const DEFAULT_DOCK: float = 1.2
const DEFAULT_INTERCEPT_REACH: float = 4.5
const DEFAULT_INTERCEPT_COOLDOWN: float = 1.0
## A drone fires when it is within this many metres of its enemy's edge beyond its hold distance.
const FIRE_SLACK: float = .9
## A drone drops an enemy that drifts this far past the leash.
const LEASH_SLACK: float = 1.0
## A drone shoots a hostile shot down from this close. A bolt counts as aimed at the hero when its path passes within `GUARD_PAD`
## metres of the hero, and a shell when its blast would come within `GUARD_PAD` metres of the hero (the hero may step out of it).
const FLAK_RANGE: float = 2.4
const GUARD_PAD: float = .8
## How far ahead along a bolt's path a drone flies to meet it, in seconds of the bolt's travel.
const LEAD_SECONDS: float = .25
const TINT := Color(.55, .95, 1.0)
const REAPER_TINT := Color(1.0, .45, .4)
const GUARD_TINT := Color(.55, 1.0, .7)

## One slot per drone the bay keeps; null while its drone is gone.
var slots: Array[Drone] = []
## Seconds until each empty slot is refilled.
var rebuild_clocks: Array[float] = []
## Temporary drones (Reaper Swarm's kill rewards), newest last.
var extras: Array[Drone] = []
var candidates: Array[CombatActor] = []
## The nearest Kite, Lobber or Tender, nearest first (Reaper Swarm only).
var priority: Array[CombatActor] = []
var scan_clock: float = 0.0
var intercept_clock: float = 0.0
## Drones on a shoot-down job and the hostile shot each is after.
var guarding: Dictionary = {}
## What this bay has done since it was made (tests and tools read them).
var shots: int = 0
var kills: int = 0
var intercepts: int = 0
var replaced: int = 0
var extras_launched: int = 0
var extras_refused: int = 0

# --- Numbers from the row ---

func is_escort() -> bool:
	return bool(param("escort", false))

func can_intercept() -> bool:
	return bool(param("intercept", false))

func is_hunter() -> bool:
	return float(param("hunt_bonus", 0.0)) > 0.0

func hunt_bonus() -> float:
	return maxf(float(param("hunt_bonus", 0.0)), 0.0)

## Metres from the hero within which a hunter's drones go after a ranged enemy.
func hunt_reach() -> float:
	return maxf(float(param("hunt_reach", 0.0)), 0.0)

func kill_drone_seconds() -> float:
	return maxf(float(param("kill_drone_seconds", 0.0)), 0.0)

func max_extra() -> int:
	return maxi(int(param("max_extra", 0)), 0)

func drone_speed() -> float:
	return maxf(float(param("drone_speed", DEFAULT_SPEED)), 1.0)

func hold_distance() -> float:
	return maxf(float(param("hold", DEFAULT_HOLD)), .2)

func orbit_radius() -> float:
	return maxf(float(param("orbit_radius", DEFAULT_ORBIT)), .3)

func airframe_seconds() -> float:
	return maxf(float(param("airframe_seconds", DEFAULT_AIRFRAME)), 0.0)

func rebuild_seconds() -> float:
	return maxf(float(param("rebuild_seconds", DEFAULT_REBUILD)), .1)

func sortie_seconds() -> float:
	return maxf(float(param("sortie_seconds", DEFAULT_SORTIE)), 1.0)

func dock_seconds() -> float:
	return maxf(float(param("dock_seconds", DEFAULT_DOCK)), 0.0)

func intercept_reach() -> float:
	return maxf(float(param("intercept_reach", DEFAULT_INTERCEPT_REACH)), 1.0)

func intercept_cooldown() -> float:
	return maxf(float(param("intercept_cooldown", DEFAULT_INTERCEPT_COOLDOWN)), .1)

func drone_tint() -> Color:
	if can_intercept():
		return GUARD_TINT
	return REAPER_TINT if is_hunter() else TINT

## How many drones the bay keeps (the stat, at least one and at most `MAX_PER_BAY`).
func drone_count() -> int:
	return clampi(int(actor._current_view(0.0).values.get("drone_count", 2)), 1, MAX_PER_BAY)

## Drones in the air now: slots and extras, docked ones included.
func live_drones() -> Array[Drone]:
	var result: Array[Drone] = []
	for drone in slots:
		if drone != null and not drone.spent:
			result.append(drone)
	for drone in extras:
		if not drone.spent:
			result.append(drone)
	return result

## Every drone shooting at once: the shop's figure. The real rate is lower while drones fly out, return and dock.
func estimate_dps(stats: TurretStats) -> float:
	return stats.damage * stats.fire_rate * float(clampi(int(stats.values.get("drone_count", 2)), 1, MAX_PER_BAY))

# --- Per tick ---

func tick(delta: float) -> void:
	var world := actor.world
	if world.drones == null:
		return
	var stats := actor._current_view(0.0)
	_fit_slots(clampi(int(stats.values.get("drone_count", 2)), 1, MAX_PER_BAY))
	_fill_slots(delta)
	_prune_extras()
	scan_clock -= delta
	if scan_clock <= 0.0:
		scan_clock = SCAN_INTERVAL
		_rescan(stats)
	var anchor := _anchor()
	for drone in slots:
		if drone != null:
			_step_drone(drone, delta, stats, anchor)
	for drone in extras:
		_step_drone(drone, delta, stats, anchor)
	if can_intercept():
		intercept_clock -= delta
		if intercept_clock <= 0.0:
			intercept_clock = INTERCEPT_INTERVAL
			_scan_ordnance()
	_face_work()

func _step_drone(drone: Drone, delta: float, stats: TurretStats, anchor: Vector3) -> void:
	if drone.spent:
		return
	drone.cooldown = maxf(0.0, drone.cooldown - delta)
	drone.aux_cooldown = maxf(0.0, drone.aux_cooldown - delta)
	if not drone.temporary:
		drone.home = dock_point(drone.slot)
	if guarding.has(drone):
		_guard(drone, stats)
	elif is_escort():
		_drive_escort(drone, stats, anchor)
	else:
		_drive_sortie(drone, delta, stats)

## Where the hero-or-bay centre of a drone's work is: the hero for an escort (the bay when the hero is gone), else the bay.
func _anchor() -> Vector3:
	var hero := actor.world.player
	if is_escort() and is_instance_valid(hero) and not hero.dead:
		return WorldGeometry.planar(hero.position)
	return WorldGeometry.planar(actor.position)

## Where slot `slot` of `count` docks, as an angle round the bay (turned off the barrel side so a drone never rests on it).
static func dock_angle(slot: int, count: int) -> float:
	return (float(maxi(slot, 0)) + .5) * TAU / float(maxi(count, 1)) + .6

func dock_point(slot: int) -> Vector3:
	var angle := dock_angle(slot, slots.size())
	return WorldGeometry.planar(actor.position) + Vector3(cos(angle), 0.0, sin(angle)) * DOCK_RADIUS

## Grows or shrinks the slot list to the stat; a drone in a slot that goes is taken down.
func _fit_slots(count: int) -> void:
	while slots.size() < count:
		slots.append(null)
		rebuild_clocks.append(float(slots.size() - 1) * .25)
	while slots.size() > count:
		var gone: Drone = slots.pop_back()
		rebuild_clocks.pop_back()
		if gone != null:
			actor.world.drones.destroy(gone)

## Refills each empty slot once its clock runs out (staggered at the start of combat, `rebuild_seconds` after a loss).
func _fill_slots(delta: float) -> void:
	for index in slots.size():
		var drone := slots[index]
		if drone != null and drone.spent:
			guarding.erase(drone)
			slots[index] = null
			rebuild_clocks[index] = rebuild_seconds()
			replaced += 1
			drone = null
		if drone != null:
			continue
		rebuild_clocks[index] -= delta
		if rebuild_clocks[index] > 0.0:
			continue
		if _launch_slot(index):
			rebuild_clocks[index] = 0.0
		else:
			# The arena is full: try again in a second rather than every step.
			rebuild_clocks[index] = 1.0

func _launch_slot(index: int) -> bool:
	var drone := _new_drone()
	drone.slot = index
	drone.temporary = false
	drone.home = dock_point(index)
	drone.position = drone.home
	drone.cooldown = .15 * float(index)
	drone.bob_phase = float(index)
	# The first airframes wear out a couple of seconds apart, so the slots do not all go at once.
	drone.life = 0.0
	if airframe_seconds() > 0.0:
		drone.life = airframe_seconds() + (2.0 * float(index) if replaced == 0 else 0.0)
	drone.orbit_angle = float(index) * TAU / float(maxi(slots.size(), 1))
	drone.job_clock = dock_seconds()
	if not actor.world.drones.launch(drone):
		return false
	slots[index] = drone
	return true

func _new_drone() -> Drone:
	var drone := Drone.new()
	drone.owner_id = actor.turret_id
	drone.owner_cap = slots.size() + max_extra()
	drone.speed = drone_speed()
	drone.orbit_radius = orbit_radius()
	drone.orbit_rate = ORBIT_RATE
	drone.hold_distance = hold_distance()
	drone.tint = drone_tint()
	return drone

func _prune_extras() -> void:
	var index := extras.size() - 1
	while index >= 0:
		if extras[index].spent:
			guarding.erase(extras[index])
			extras.remove_at(index)
		index -= 1

# --- Looking for work (five times a second) ---

func _rescan(stats: TurretStats) -> void:
	var anchor := _anchor()
	var leash := stats.range_metres
	candidates.clear()
	priority.clear()
	var reach := maxf(leash, hunt_reach()) if is_hunter() else leash
	var found := actor.world.crowd.query_radius(anchor, reach, true)
	for enemy in found:
		var near := WorldGeometry.planar(enemy.position - anchor).length_squared() <= pow(leash + enemy.hurtbox_radius(), 2)
		if is_hunter() and enemy.enemy_type in TurretTargeting.BACKLINE_TYPES:
			priority.append(enemy)
		elif near:
			candidates.append(enemy)
	if is_hunter():
		priority.sort_custom(func(a: CombatActor, b: CombatActor) -> bool:
			return WorldGeometry.planar(a.position - anchor).length_squared() < WorldGeometry.planar(b.position - anchor).length_squared())
		# A ranged enemy within the ordinary leash is ordinary prey too once the priority list is empty.
	var claims := _claims()
	for drone in live_drones():
		if guarding.has(drone):
			continue
		if is_hunter() and not priority.is_empty():
			if not (drone.mode == Drone.Mode.HOLD and drone.has_target() and drone.target.enemy_type in TurretTargeting.BACKLINE_TYPES):
				_dive(drone)
			continue
		if drone.mode == Drone.Mode.HOLD and drone.has_target():
			continue
		if _can_start_job(drone):
			var prey := _nearest_candidate(drone, claims)
			if prey != null:
				# A sortie starts its clock as it leaves the dock.
				drone.job_clock = 0.0
				drone.engage(prey, hold_distance())
				claims[prey] = int(claims.get(prey, 0)) + 1

func _claims() -> Dictionary:
	var claims := {}
	for drone in live_drones():
		if drone.mode == Drone.Mode.HOLD and drone.has_target():
			claims[drone.target] = int(claims.get(drone.target, 0)) + 1
	return claims

## True for a drone that may start a new job from where it is: any escort that is not mid-job, a sortie drone rested on its dock.
func _can_start_job(drone: Drone) -> bool:
	if is_escort():
		return true
	return drone.mode == Drone.Mode.DOCKED and drone.job_clock >= dock_seconds()

## Sends `drone` at the nearest priority enemy (every drone of a hunt picks the same one: they dive together).
func _dive(drone: Drone) -> void:
	var prey: CombatActor = null
	for enemy in priority:
		if is_instance_valid(enemy) and not enemy.dead:
			prey = enemy
			break
	if prey != null:
		drone.engage(prey, hold_distance())

## The nearest candidate to `drone`, leaving enemies no other drone is working on first, or null when none is left.
func _nearest_candidate(drone: Drone, claims: Dictionary) -> CombatActor:
	var best: CombatActor = null
	var best_score := INF
	for enemy in candidates:
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var distance := WorldGeometry.planar(enemy.position - drone.position).length_squared()
		# An enemy someone else is working on is a last resort: its distance counts for much more.
		var score := distance + float(claims.get(enemy, 0)) * 1000.0
		if score < best_score:
			best = enemy
			best_score = score
	return best

# --- Driving a drone (every step) ---

func _drive_escort(drone: Drone, stats: TurretStats, anchor: Vector3) -> void:
	drone.anchor = anchor
	match drone.mode:
		Drone.Mode.DOCKED, Drone.Mode.RETURN, Drone.Mode.SEEK:
			drone.orbit(anchor)
		Drone.Mode.HOLD:
			if _on_job(drone, anchor, stats.range_metres):
				_shoot_if_ready(drone, stats)
			else:
				_next_job(drone, anchor)

## A sortie drone: rests on the dock, flies out when a rescan hands it an enemy, shoots until its sortie is up or nothing is left
## within the leash of the bay, then returns.
func _drive_sortie(drone: Drone, delta: float, stats: TurretStats) -> void:
	var bay := WorldGeometry.planar(actor.position)
	match drone.mode:
		Drone.Mode.DOCKED:
			drone.job_clock += delta
		Drone.Mode.HOLD:
			drone.job_clock += delta
			if drone.job_clock >= sortie_seconds():
				drone.recall()
			elif _on_job(drone, bay, stats.range_metres):
				_shoot_if_ready(drone, stats)
			else:
				var prey := _nearest_candidate(drone, _claims())
				if prey != null:
					# Its enemy is gone or out of the leash: the next one, on the same sortie clock.
					drone.target = prey
				else:
					drone.recall()
		Drone.Mode.ORBIT, Drone.Mode.SEEK:
			drone.recall()

## True while the drone's enemy is alive and within the leash of `anchor`.
func _on_job(drone: Drone, anchor: Vector3, leash: float) -> bool:
	if not drone.has_target():
		return false
	var enemy := drone.target
	return WorldGeometry.planar(enemy.position - anchor).length_squared() <= pow(leash + enemy.hurtbox_radius() + LEASH_SLACK, 2)

## The escort's next job when its enemy is gone: the nearest candidate from the last look, else back to orbit.
func _next_job(drone: Drone, anchor: Vector3) -> void:
	var prey: CombatActor = null
	if is_hunter():
		for enemy in priority:
			if is_instance_valid(enemy) and not enemy.dead:
				prey = enemy
				break
	if prey == null:
		prey = _nearest_candidate(drone, _claims())
	if prey != null:
		drone.engage(prey, hold_distance())
	else:
		drone.orbit(anchor)

func _shoot_if_ready(drone: Drone, stats: TurretStats) -> void:
	if drone.cooldown > 0.0 or not drone.has_target():
		return
	var enemy := drone.target
	var gap := WorldGeometry.planar(enemy.position - drone.position).length()
	if gap > drone.hold_distance + enemy.hurtbox_radius() + FIRE_SLACK:
		return
	drone.cooldown = stats.cooldown_seconds
	_shoot(drone, enemy, stats)

func _shoot(drone: Drone, enemy: CombatActor, stats: TurretStats) -> void:
	var world := actor.world
	var shot := actor._new_shot(stats)
	if is_hunter() and enemy.enemy_type in TurretTargeting.BACKLINE_TYPES:
		shot.damage *= 1.0 + hunt_bonus()
	var from := Vector3(drone.position.x, drone.height(), drone.position.z)
	var heading := WorldGeometry.planar(enemy.position - drone.position).normalized()
	world.effects.show_tracer(from, Vector3(enemy.position.x, .5, enemy.position.z))
	world.audio.play_cue("ion", from)
	shots += 1
	world.combat.impact(enemy, enemy.position, heading, shot, [] as Array[CombatActor])
	if enemy.dead:
		kills += 1
		_reward_kill(drone)

## Reaper Swarm: a kill launches an extra drone from where the killer hovers, for a few seconds. At most `max_extra` at a time, and
## never past the arena cap (`Drones.launch` refuses and the extra is not made).
func _reward_kill(killer: Drone) -> void:
	var seconds := kill_drone_seconds()
	if seconds <= 0.0 or max_extra() <= 0 or extras.size() >= max_extra():
		return
	var drone := _new_drone()
	drone.temporary = true
	drone.life = seconds
	drone.position = killer.position
	drone.altitude = Drone.HEIGHT
	drone.home = killer.position
	drone.mode = Drone.Mode.ORBIT
	drone.anchor = _anchor()
	drone.orbit_angle = killer.orbit_angle + PI
	if actor.world.drones.launch(drone):
		extras.append(drone)
		extras_launched += 1
	else:
		extras_refused += 1

# --- Shooting down hostile shots (Guardian Wing) ---

## Looks at the hostile shots in flight (ten times a second) and sends a ready drone at each one that is aimed at the hero.
func _scan_ordnance() -> void:
	var hero := actor.world.player
	if not is_instance_valid(hero) or hero.dead:
		return
	var threats: Array[EnemyOrdnance] = []
	for node in actor.get_tree().get_nodes_in_group("hostile_ordnance"):
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
		guarding[drone] = shot

## True when `shot` (a hostile bolt or shell) is aimed at the hero's spot, within the wing's reach of the hero.
func is_threat(shot: EnemyOrdnance, hero_at: Vector3) -> bool:
	if shot.world != actor.world or shot.is_queued_for_deletion() or shot.to_core:
		return false
	var reach := intercept_reach()
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
	for drone: Drone in guarding:
		if guarding[drone] == shot:
			return true
	return false

## The ready drone nearest to `shot`: not docked, not on a shoot-down, its own cooldown spent.
func _ready_guard(shot: EnemyOrdnance) -> Drone:
	var at := WorldGeometry.planar(shot.position)
	var best: Drone = null
	var best_gap := INF
	for drone in live_drones():
		if drone.is_docked() or drone.spent or drone.aux_cooldown > 0.0 or guarding.has(drone):
			continue
		var gap := WorldGeometry.planar(drone.position).distance_squared_to(at)
		if gap < best_gap:
			best = drone
			best_gap = gap
	return best

## Steers a drone on a shoot-down toward its shot and fires when it is close; lets it go back to work when the shot is gone.
func _guard(drone: Drone, _stats: TurretStats) -> void:
	var shot := guarding[drone] as EnemyOrdnance
	if shot == null or not is_instance_valid(shot) or shot.is_queued_for_deletion():
		_release_guard(drone)
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
	var world := actor.world
	var from := Vector3(drone.position.x, drone.height(), drone.position.z)
	world.effects.show_tracer(from, shot.global_position)
	world.effects.show_burst(shot.global_position, "ion")
	world.audio.play_cue("shock", from)
	shot.queue_free()
	intercepts += 1
	drone.aux_cooldown = intercept_cooldown()
	_release_guard(drone)

func _release_guard(drone: Drone) -> void:
	guarding.erase(drone)
	drone.orbit(_anchor())

# --- Look ---

## The head turns toward whatever the first working drone is after, so the bay looks busy.
func _face_work() -> void:
	if not is_instance_valid(actor.aim):
		return
	for drone in slots:
		if drone != null and not drone.spent and drone.has_target():
			var look := WorldGeometry.planar(drone.target.position - actor.position)
			if look.length_squared() > .01:
				actor.aim.rotation.y = lerp_angle(actor.aim.rotation.y, atan2(-look.x, -look.z), .2)
			return

# --- Clean-up ---

## Combat stopped (wave end, pause, defeat): the drones come down and the slots start over.
func clear() -> void:
	if slots.is_empty() and extras.is_empty() and guarding.is_empty():
		return
	_reset()

## The turret left the arena or took another form: its drones go with it.
func removed() -> void:
	_reset()

func _reset() -> void:
	if is_instance_valid(actor) and is_instance_valid(actor.world) and actor.world.drones != null:
		actor.world.drones.clear_owner(actor.turret_id)
	slots.clear()
	rebuild_clocks.clear()
	extras.clear()
	guarding.clear()
	candidates.clear()
	priority.clear()
	scan_clock = 0.0
	intercept_clock = 0.0
