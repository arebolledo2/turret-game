class_name MineLayerForm
extends TurretForm

## Mine Layer / Minefield / Dead Zone / Chain Reaction: the turret that attacks with what it leaves behind. One class serves the
## unevolved layer and its three forms; the rows in `TurretForms` only change numbers and params. It never fires a projectile
## (`FIRE_DEPLOY`): while combat runs it lays one deployable every `1 / fire_rate` seconds (the stat, so level speed bonuses, Entrench
## and attack-speed items quicken it) until `max_mines` of its own are out, through engine piece S8 (`Deployables`).
##   Mine Layer    up to 5 proximity mines within `range` of it (2.25 m): damage 15 in a 0.7 m blast, armed after 0.8 s, gone if
##                 unused after `lifetime` seconds.
##   Minefield     eight smaller mines over a wider patch (more, quicker to lay, a smaller blast and less damage each).
##   Dead Zone     fourteen mines that re-arm `rearm_seconds` after each blast and never expire, and a blast chains to the armed
##                 mines beside it (`chain_reach` metres), `chain_depth` links deep, a beat apart.
##   Chain Reaction  no mines on the floor: it launches limpets at the nearest large enemy (`large_scale` body size or more; any
##                 enemy when none is large). A limpet flies, sticks, goes off after `fuse_seconds` (at once if its host dies) and
##                 its blast sticks a new limpet on up to `stick` neighbours, once. At most `max_mines` launched limpets are out.
## Where a mine goes: on the side of the nearest enemy (within `SCOUT_EXTRA` of the reach), roughly on the way to it, otherwise any
## side; the best of a few random spots, so a layer spreads its mines out. Never inside `CLEARANCE` of the turret (enemies cannot
## walk there), and always inside the arena. Mines hit enemies only, never the hero or a turret.
## Cost: placing is one scan of the enemy list per lay (every couple of seconds); the field does the rest (see `Deployables`).
## State: only a seeded generator and counters. Its mines belong to the field, which drops them when combat stops (and every idle
## frame this form calls `clear`), when the layer is removed or evolves, and on a run reset. Another layer's are untouched.
## Like every turret it keeps working while the hero carries it, so a carried layer drops a trail of mines round the hero as it
## walks (mines never hurt the hero), and the mines it already laid stay where they are.
## Metres from the turret's centre inside which no mine is laid: the chassis (0.63 m), its spare-mine dish (out to 1.1 m) and the
## ring enemies cannot reach.
const CLEARANCE: float = 1.1
## How far past the placement reach the layer looks for an enemy to lay toward (metres).
const SCOUT_EXTRA: float = 6.0
## Random spots tried per mine; the one farthest from the layer's other mines is kept.
const CANDIDATES: int = 4
## Half the angle (radians) of the cone toward the nearest enemy that mines are scattered in.
const CONE_HALF_ANGLE: float = .5
## A spot this far from every other mine of the layer is as good as any (metres).
const SPACING: float = .8
const DEFAULT_ARM_SECONDS: float = .8
const DEFAULT_LIFETIME: float = 40.0
const DEFAULT_FUSE_SECONDS: float = 1.5
const DEFAULT_LAUNCH_SPEED: float = 14.0
const DEFAULT_LARGE_SCALE: float = 1.25
const MINE_TINT := Color("e83a1c")
const LIMPET_TINT := Color("ffb02e")

var rng := RandomNumberGenerator.new()
var _seeded: bool = false
## What this layer has laid or launched since it was made (tests and tools read them).
var laid: int = 0
var launched: int = 0

func is_limpet_layer() -> bool:
	return bool(param("limpet", false))

## Own mines (or launched limpets) allowed out at once.
func max_mines(stats: TurretStats) -> int:
	return maxi(int(stats.values.get("max_mines", 5)), 1)

func out_now() -> int:
	var world := actor.world
	return world.deployables.count_of(actor.turret_id) if is_instance_valid(world) and is_instance_valid(world.deployables) else 0

func estimate_dps(stats: TurretStats) -> float:
	# One blast per lay at the lay rate; re-arming, chaining and sticking add to it when enemies bunch up (see the form's header).
	return stats.damage * stats.fire_rate

# --- Per tick ---

func tick(_delta: float) -> void:
	if actor.cooldown > 0.0:
		return
	var world := actor.world
	var field := world.deployables
	var stats := actor._current_view(0.0)
	if field.count_of(actor.turret_id) >= max_mines(stats) or field.count() >= GameConstants.DEPLOYABLE_MAX:
		return
	if is_limpet_layer():
		_launch(stats, field)
	else:
		_lay(stats, field)

func _lay(stats: TurretStats, field: Deployables) -> void:
	var item := _build(stats, Deployable.KIND_MINE)
	item.position = _pick_spot(stats, field)
	if not field.lay(item):
		return
	laid += 1
	_face(item.position)
	actor.world.effects.show_burst(item.position + Vector3(0, .1, 0), "ion")
	# The barrel mouth puffs as the mine is dropped, so it reads as coming from the layer's own barrel.
	if is_instance_valid(actor.muzzle):
		actor.world.effects.show_burst(actor.muzzle.global_position, "ion")
	actor.world.audio.play_cue("impact", item.position)
	actor._reset_cooldown(stats)

func _launch(stats: TurretStats, field: Deployables) -> void:
	var host := _pick_host(stats, field)
	if not host:
		return
	var item := _build(stats, Deployable.KIND_LIMPET)
	item.state = Deployable.State.FLYING
	item.host = host
	item.position = actor.muzzle.global_position if is_instance_valid(actor.muzzle) else actor.position
	if not field.lay(item):
		return
	launched += 1
	_face(host.position)
	actor.world.audio.play_cue("plasma", actor.position)
	actor._reset_cooldown(stats)

## A deployable carrying this layer's current numbers (the blast is struck now, crit included).
func _build(stats: TurretStats, kind: String) -> Deployable:
	var item := Deployable.new()
	item.kind = kind
	item.owner_id = actor.turret_id
	item.shot = actor._new_shot(stats)
	item.trigger_radius = float(stats.values.get("proximity_radius", 40.0)) * WorldGeometry.METRES_PER_PIXEL
	item.arm_seconds = float(param("arm_seconds", DEFAULT_ARM_SECONDS))
	item.lifetime = float(param("lifetime", DEFAULT_LIFETIME))
	item.rearm_seconds = float(param("rearm_seconds", 0.0))
	item.chain_depth = int(param("chain_depth", 0))
	item.chain_reach = float(param("chain_reach", 0.0))
	item.fuse_seconds = float(param("fuse_seconds", DEFAULT_FUSE_SECONDS))
	item.stick_count = int(param("stick", 0))
	item.speed = float(param("launch_speed", DEFAULT_LAUNCH_SPEED))
	item.tint = LIMPET_TINT if kind == Deployable.KIND_LIMPET else MINE_TINT
	return item

# --- Where it goes ---

func _pick_spot(stats: TurretStats, field: Deployables) -> Vector3:
	_seed_once()
	var origin := actor.position
	var reach := maxf(stats.range_metres, CLEARANCE + .3)
	var scouted := actor.world.nearest_enemy(origin, reach + SCOUT_EXTRA)
	var mine_spots: Array[Vector3] = []
	for other in field.of_owner(actor.turret_id):
		mine_spots.append(other.position)
	var best := origin
	var best_score := -1.0
	for attempt in CANDIDATES:
		var spot := _candidate(origin, reach, scouted)
		var score := SPACING
		for other_spot in mine_spots:
			score = minf(score, WorldGeometry.planar(other_spot - spot).length())
		if score > best_score:
			best_score = score
			best = spot
	return best

func _candidate(origin: Vector3, reach: float, scouted: CombatActor) -> Vector3:
	if scouted:
		# On the way to the enemy: toward it, within a cone, as far along as it is (no farther than the reach).
		var heading := WorldGeometry.planar(scouted.position - origin)
		var angle := atan2(heading.z, heading.x) + rng.randf_range(-CONE_HALF_ANGLE, CONE_HALF_ANGLE)
		var distance := clampf(heading.length() + rng.randf_range(-.3, .3), CLEARANCE, reach)
		return origin + Vector3(cos(angle), 0, sin(angle)) * distance
	# Nothing to lay toward: any side, spread evenly over the ring's area.
	var around := rng.randf() * TAU
	var radius := sqrt(lerpf(CLEARANCE * CLEARANCE, reach * reach, rng.randf()))
	return origin + Vector3(cos(around), 0, sin(around)) * radius

## The enemy a limpet goes for: the nearest large one in reach that carries no limpet yet, else the nearest such enemy.
func _pick_host(stats: TurretStats, field: Deployables) -> CombatActor:
	var reach := stats.range_metres
	var origin := actor.position
	var large := float(param("large_scale", DEFAULT_LARGE_SCALE))
	var best_large: CombatActor = null
	var large_distance := INF
	var best_any: CombatActor = null
	var any_distance := INF
	for enemy in actor.world.enemies:
		if not is_instance_valid(enemy) or enemy.dead or field.is_ridden(enemy) or not enemy.overlaps_attack_range(origin, reach):
			continue
		var distance := WorldGeometry.planar(enemy.position - origin).length_squared()
		if distance < any_distance:
			any_distance = distance
			best_any = enemy
		if enemy.body_scale >= large and distance < large_distance:
			large_distance = distance
			best_large = enemy
	return best_large if best_large else best_any

func _seed_once() -> void:
	if not _seeded:
		_seeded = true
		rng.seed = (actor.turret_id * 7919) ^ 0x4d494e45

## Turns the head toward `at` (the model's `Aim`).
func _face(at: Vector3) -> void:
	if not is_instance_valid(actor.aim):
		return
	var heading := WorldGeometry.planar(at - actor.position)
	if heading.length_squared() > .0001:
		actor.aim.rotation.y = atan2(-heading.x, -heading.z)

# --- Lifecycle ---

## Combat stopped (wave end, pause, defeat): its mines go. Runs every idle frame, so it returns at once when there is nothing out.
func clear() -> void:
	var world := actor.world
	if not is_instance_valid(world) or not is_instance_valid(world.deployables):
		return
	world.deployables.clear_owner(actor.turret_id)

## The layer left the arena or took another form: the same.
func removed() -> void:
	clear()
