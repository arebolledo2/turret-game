class_name LaserForm
extends TurretForm

## Laser / Focus Beam / Halo Cutter / Sunpiercer: the turret that holds a beam on its target (`FIRE_BEAM`), on engine piece S11
## (`ContinuousBeam` for the state and the crowd-grid queries, `BeamLines` for the drawn beam). One class serves the unevolved
## laser and its three forms; the rows in `TurretForms` only change numbers and params. The stats are per damage tick:
## `damage` is one tick's hit and `fire_rate` the ticks per second (so level speed, Entrench and attack-speed items quicken it
## and damage items strengthen it, as for any other turret). While combat runs it
##   Laser, Focus Beam   locks the nearest enemy in reach and keeps the beam on it until it dies or leaves reach. The longer the
##                 beam stays on one enemy the harder it hits: x1 rising to `ramp_peak` over `ramp_seconds` (3 s to x3 for the
##                 laser, 2 s for Focus Beam). Losing the target resets the ramp, so the beam rewards focus and punishes churn.
##   Sunpiercer    the same single beam with a taller ramp (x6 over 4 s). Once it is at full ramp a flare runs the whole line
##                 through the target out to full range every `flare_interval` seconds, hitting every enemy on it for
##                 `flare_scale` full-ramp ticks.
##   Halo Cutter   no single target: while an enemy is in reach `beams` arms (four, a cross) turn at `spin_degrees` per second
##                 about the turret and cut every enemy they cross on each tick. Nothing to focus on, so no ramp (`ramp_peak` 1).
## Every tick is built as the other instant-hit turrets build theirs (`TurretActor._new_shot`: damage type, attack families
## "instant", source id, crit rolled per hit) and goes through `Combat3D.impact`, so crits, Exposed, Marked, burn, kill credit and
## the item hooks all apply as for a Sniper shot. A shot's damage is the tick damage times the ramp.
## Cost: per physics step one `ContinuousBeam.advance`; a search of the crowd grid only when the beam has nothing (at most 5 times
## a second) or lost its target; a cross makes one crowd query on each step that has a tick due, and strikes at most
## `MAX_VICTIMS` enemies per tick. Nothing here scans the whole enemy list.
## State: the beam, a spin angle, two timers and the `BeamLines` set. All of it is dropped when combat stops (`clear`, run every
## idle frame), when the turret is removed or evolves (`removed`, which frees the lines) and on a run reset (the turret leaves the
## tree). A carried laser keeps beaming, like every turret that keeps attacking while carried; the hero is never struck.
const DEFAULT_RAMP_PEAK: float = 3.0
const DEFAULT_RAMP_SECONDS: float = 3.0
## Most enemies one tick of a cross or a flare strikes (the nearest ones when more are touching).
const MAX_VICTIMS: int = 24
## Metres either side of a cross arm that still cuts, and either side of a flare (each body's own radius is added).
const ARM_HALF_WIDTH: float = .16
const FLARE_HALF_WIDTH: float = .3
## Drawn widths (metres): a beam at rest and at full ramp, a flare, and how long a flare stays drawn.
const BEAM_WIDTH: float = .06
const BEAM_WIDTH_FULL: float = .16
const FLARE_WIDTH: float = .5
const FLARE_FLASH: float = .2
## Metres from the centre at which a cross arm is drawn from (the ring of emitters), and the beam's height when the chassis has no muzzle.
const ARM_START: float = .9

var beam := ContinuousBeam.new()
var lines: BeamLines
## The cross's angle (radians, the way `Aim` is turned).
var spin: float = 0.0
var search_clock: float = 0.0
var flare_clock: float = 0.0
var flare_flash: float = 0.0
## What this laser has done since it was made (tests and tools read them).
var strikes: int = 0
var flares: int = 0

func beam_count() -> int:
	return maxi(int(param("beams", 1)), 1)

func is_cross() -> bool:
	return beam_count() > 1

func ramp_peak() -> float:
	return maxf(float(param("ramp_peak", DEFAULT_RAMP_PEAK)), 1.0)

func ramp_seconds() -> float:
	return maxf(float(param("ramp_seconds", DEFAULT_RAMP_SECONDS)), .01)

func flare_scale() -> float:
	return maxf(float(param("flare_scale", 0.0)), 0.0)

func flare_interval() -> float:
	return maxf(float(param("flare_interval", 2.0)), .1)

func spin_rate() -> float:
	return deg_to_rad(float(param("spin_degrees", 0.0)))

## The damage multiplier the beam is dealing now.
func ramp_now() -> float:
	return ContinuousBeam.ramp(beam.heat, ramp_seconds(), ramp_peak())

## Whether the beam is on something (a locked enemy, or a cross with an enemy in reach).
func is_beaming() -> bool:
	return beam.engaged

## Single-target damage per second averaged over the ramp (x1 rising to the peak): the figure the shop and inspector show.
## A fully ramped beam deals `ramp_peak` times the rate; Sunpiercer's flare and Halo Cutter's reach over a crowd come on top, and a
## cross only strikes a lone enemy while an arm is on it.
func estimate_dps(stats: TurretStats) -> float:
	return stats.damage * stats.fire_rate * (1.0 + ramp_peak()) * .5

# --- Per tick ---

func tick(delta: float) -> void:
	var stats := actor._current_view(0.0)
	var reach := actor.effective_range(stats)
	_ensure_lines()
	if flare_flash > 0.0:
		flare_flash = maxf(0.0, flare_flash - delta)
		if flare_flash <= 0.0:
			lines.hide_slot(beam_count())
	if is_cross():
		_tick_cross(delta, stats, reach)
	else:
		_tick_single(delta, stats, reach)

func _ensure_lines() -> void:
	if is_instance_valid(lines):
		return
	lines = BeamLines.new(beam_count() + (1 if flare_scale() > 0.0 else 0))
	actor.add_child(lines)

## Where the beam leaves the chassis: the muzzle for a single beam, the centre column at the muzzle's height for a cross.
func _origin(centred: bool) -> Vector3:
	var at := actor.muzzle.global_position if is_instance_valid(actor.muzzle) else actor.global_position + Vector3(0, .8, 0)
	return Vector3(actor.global_position.x, at.y, actor.global_position.z) if centred else at

func _tick_single(delta: float, stats: TurretStats, reach: float) -> void:
	var world := actor.world
	var centre := actor.position
	if not beam.holds(centre, reach):
		if beam.engaged:
			beam.release()
			actor.target = null
			search_clock = 0.0
			_hide_beam()
		search_clock -= delta
		if search_clock > 0.0:
			return
		search_clock = ContinuousBeam.SEARCH_INTERVAL
		var found := ContinuousBeam.nearest(world.crowd, centre, reach)
		if found == null:
			return
		beam.lock(found)
		flare_clock = 0.0
	var enemy := beam.target
	actor.target = enemy
	var heading := WorldGeometry.planar(enemy.position - centre)
	if heading.length_squared() > .000001:
		actor.aim.rotation.y = atan2(-heading.x, -heading.z)
	# Ticks deal the ramp as it stood when the step began, so the beam that lands is exactly x1.
	var multiplier := ramp_now()
	var ticks := beam.advance(delta, stats.fire_rate)
	for i in ticks:
		if not beam.holds(centre, reach):
			break
		_strike(enemy, stats, multiplier)
	if flare_scale() > 0.0 and beam.holds(centre, reach):
		_tick_flare(delta, stats, reach, heading)
	if not beam.holds(centre, reach):
		# The target fell this step: the beam lets go, and the next step looks for another.
		beam.release()
		actor.target = null
		search_clock = 0.0
		_hide_beam()
		return
	var from := _origin(false)
	var width := lerpf(BEAM_WIDTH, BEAM_WIDTH_FULL, clampf((multiplier - 1.0) / maxf(ramp_peak() - 1.0, .001), 0.0, 1.0))
	lines.set_segment(0, from, Vector3(enemy.position.x, from.y, enemy.position.z), width)

## Sunpiercer: at full ramp, flare along the whole line through the target; again every `flare_interval` while the ramp holds.
func _tick_flare(delta: float, stats: TurretStats, reach: float, heading: Vector3) -> void:
	if beam.heat < ramp_seconds():
		return
	flare_clock -= delta
	if flare_clock > 0.0 or heading.length_squared() < .000001:
		return
	flare_clock = flare_interval()
	flares += 1
	var direction := heading.normalized()
	var centre := actor.position
	var victims := ContinuousBeam.touching(actor.world.crowd, centre, [direction] as Array[Vector3], reach, FLARE_HALF_WIDTH, MAX_VICTIMS)
	for victim in victims:
		_strike(victim, stats, ramp_peak() * flare_scale())
	var from := _origin(false)
	lines.set_segment(beam_count(), from, from + direction * reach, FLARE_WIDTH, true)
	flare_flash = FLARE_FLASH

func _tick_cross(delta: float, stats: TurretStats, reach: float) -> void:
	var centre := actor.position
	if not actor.world.crowd.any_within(centre, reach):
		if beam.engaged:
			beam.release()
			_hide_beam()
		return
	beam.engage()
	spin = fposmod(spin + spin_rate() * delta, TAU)
	actor.aim.rotation.y = spin
	var directions := arm_directions()
	var multiplier := ramp_now()
	var ticks := beam.advance(delta, stats.fire_rate)
	if ticks > 0:
		var victims := ContinuousBeam.touching(actor.world.crowd, centre, directions, reach, ARM_HALF_WIDTH, MAX_VICTIMS)
		for i in ticks:
			for victim in victims:
				if is_instance_valid(victim) and not victim.dead:
					_strike(victim, stats, multiplier)
	var from := _origin(true)
	for index in directions.size():
		var direction := directions[index]
		lines.set_segment(index, from + direction * ARM_START, from + direction * reach, BEAM_WIDTH + .02)

## The arms' unit directions on the ground now (the first is the way `Aim` faces, the rest follow evenly round).
func arm_directions() -> Array[Vector3]:
	var result: Array[Vector3] = []
	var count := beam_count()
	for index in count:
		var angle := spin + float(index) * TAU / float(count)
		result.append(Vector3(-sin(angle), 0.0, -cos(angle)))
	return result

## One damage tick on `enemy`: built like any other turret shot (crit rolled for this hit) and scaled by `multiplier`.
func _strike(enemy: CombatActor, stats: TurretStats, multiplier: float) -> void:
	if not is_instance_valid(enemy) or enemy.dead:
		return
	var shot := actor._new_shot(stats)
	shot.damage *= multiplier
	var heading := WorldGeometry.planar(enemy.position - actor.position).normalized()
	actor.world.combat.impact(enemy, enemy.position, heading, shot, [] as Array[CombatActor])
	strikes += 1

func _hide_beam() -> void:
	if is_instance_valid(lines):
		lines.hide_all()
	flare_flash = 0.0

# --- Clean-up ---

## Combat stopped (wave end, pause, defeat): the beam goes out and forgets its target and ramp.
func clear() -> void:
	if beam.engaged or beam.target != null:
		beam.release()
	search_clock = 0.0
	flare_clock = 0.0
	if is_instance_valid(actor):
		actor.target = null
	_hide_beam()

## The turret left the arena or took another form: the lines go with it.
func removed() -> void:
	beam.release()
	if is_instance_valid(lines):
		lines.free_lines()
	lines = null
