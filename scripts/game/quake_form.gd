class_name QuakeForm
extends TurretForm

## Quake / Aftershock / Tectonic / Cataclysm: the slow stomp. One class serves the unevolved Quake and its three forms.
## It extends the Shock's `FIRE_PULSE` path: `TurretActor` calls `fire_pulse` when the cooldown is up and an enemy is in
## range, and the form takes over from there.
##   Pulse (Quake, Aftershock, Cataclysm): a ground telegraph fills for `QUAKE_TELEGRAPH_SECONDS`, then a `ShockwaveRing`
##     runs out from the turret at `QUAKE_RING_SPEED`. Each enemy is struck once, when the ring reaches it, so the near ones
##     are hit first and the far ones are shoved apart. Aftershock queues a second, half-damage ring; Cataclysm queues up to
##     `CATACLYSM_REPEATS` wider rings while enemies stay in range, with stagger that stacks.
##   Tectonic: instead of a ring, two fissures (S7 `GroundZones` lines) open in an X at the densest cluster; whatever stands
##     in them is hit once as they open, and they slow enemies inside for `TECTONIC_SECONDS`.
## Everything queued here is dropped by `clear()` when combat stops, so nothing fires after a pause or at wave end.
const TINT: Color = CombatEffects3D.QUAKE_TINT

## Pulses waiting to release: {"left": seconds, "damage": share of the shot, "radius": share of the reach, "repeat": bool}.
var beats: Array[Dictionary] = []
## Rings travelling outward right now.
var rings: Array[ShockwaveRing] = []
## Fissures waiting to open: {"left": seconds, "axes": [[from, to], ...], "half_width": metres, "focus": centre of the X}.
var fissures: Array[Dictionary] = []
## Cataclysm: true from the first trigger until the last repeat has released (or been cancelled); the cooldown starts then.
var salvo_open: bool = false
var telegraph_left: float = 0.0
var telegraph_total: float = 0.0
var telegraph_circle: MeshInstance3D
var telegraph_lines: Array[MeshInstance3D] = []
var telegraph_radius: float = 0.0
## Pulses released (rings and fissure openings) since this form was created; tests and tools read it.
var pulses_released: int = 0
var _dirty: bool = false

func rebuilt() -> void:
	# A replaced form (the Quake evolving) leaves its telegraph quads under the actor; start from a clean holder.
	var holder := actor.get_node_or_null("QuakeTelegraphs")
	if holder:
		for child in holder.get_children():
			child.queue_free()
	telegraph_circle = null
	telegraph_lines.clear()

## True while a trigger is still playing out: a new one will not start until it has.
func busy() -> bool:
	return not beats.is_empty() or not fissures.is_empty() or telegraph_left > 0.0

func fire_pulse(stats: TurretStats, range_metres: float, _target: CombatActor) -> void:
	if busy():
		return
	if form_id == "tectonic":
		_begin_tectonic(stats, range_metres)
	else:
		_begin_pulse(stats, range_metres)

# --- Pulse forms ---

func _begin_pulse(stats: TurretStats, range_metres: float) -> void:
	_queue(TurretEvolution.QUAKE_TELEGRAPH_SECONDS, 1.0, 1.0, false)
	match form_id:
		"aftershock":
			_queue(TurretEvolution.QUAKE_TELEGRAPH_SECONDS + TurretEvolution.AFTERSHOCK_DELAY, TurretEvolution.AFTERSHOCK_DAMAGE, 1.0, false)
		"cataclysm":
			for repeat in range(1, TurretEvolution.CATACLYSM_REPEATS + 1):
				var growth := minf(1.0 + TurretEvolution.CATACLYSM_GROWTH * float(repeat), TurretEvolution.CATACLYSM_MAX_RADIUS_SCALE)
				_queue(TurretEvolution.QUAKE_TELEGRAPH_SECONDS + TurretEvolution.CATACLYSM_INTERVAL * float(repeat), 1.0, growth, true)
	if form_id == "cataclysm":
		# The recharge begins when the salvo ends, not when it starts.
		salvo_open = true
	else:
		actor._reset_cooldown(stats)
	telegraph_radius = range_metres
	_start_telegraph(TurretEvolution.QUAKE_TELEGRAPH_SECONDS)
	_show_circle(range_metres)

func _queue(left: float, damage: float, radius: float, repeat: bool) -> void:
	beats.append({"left": left, "damage": damage, "radius": radius, "repeat": repeat})
	_dirty = true

func _release(beat: Dictionary) -> void:
	var stats := actor._current_view(0.0)
	# A repeat only happens while something is still in reach; otherwise the rest of the salvo is cancelled.
	if bool(beat["repeat"]) and actor.world.nearest_enemy(actor.position, actor.effective_range(stats)) == null:
		beats.clear()
		return
	var radius := actor.effective_range(stats) * float(beat["radius"])
	var shot := actor._new_shot(stats)
	shot.damage *= float(beat["damage"])
	# The ring resolves its own targets; the radius is only what area items (Reactor Overload) read from the hit.
	shot.splash_radius = radius
	if form_id == "cataclysm":
		shot.stagger_cap = StatusEffects3D.STAGGER_CAP
	var ring := ShockwaveRing.new(actor.position, radius, TurretEvolution.QUAKE_RING_SPEED, shot)
	shot.attack_targets = ring.attack_targets
	rings.append(ring)
	pulses_released += 1
	var effects := actor.world.effects
	effects.show_wave(actor.position, radius, TurretEvolution.QUAKE_RING_SPEED)
	effects.show_burst(actor.position + Vector3(0, .15, 0), "scrap")
	actor.world.audio.play_cue("plasma", actor.position)
	_strike(ring, ring.advance(0.0, actor.world.enemies))

## Hits every enemy the ring just reached. Earlier hits can kill (and chain), so each target is checked again.
func _strike(ring: ShockwaveRing, reached: Array[CombatActor]) -> void:
	var combat := actor.world.combat
	for enemy in reached:
		if is_instance_valid(enemy) and not enemy.dead:
			combat.apply_hit(enemy, combat.hit_from_shot(enemy, ring.origin, Vector3(0, 0, -1), ring.shot))

# --- Tectonic ---

func _begin_tectonic(stats: TurretStats, range_metres: float) -> void:
	var world := actor.world
	var focus := world.combat.select_target(actor.position, range_metres, world.enemies, TurretEvolution.TECTONIC_CLUSTER_RADIUS, world.crowd)
	if not focus:
		return
	var centre := WorldGeometry.planar(focus.position)
	var heading := WorldGeometry.planar(centre - actor.position)
	heading = heading.normalized() if heading.length_squared() > .0001 else Vector3(0, 0, -1)
	var half_length := range_metres * TurretEvolution.TECTONIC_REACH
	var half_width := TurretEvolution.TECTONIC_HALF_WIDTH * stats.area_size
	var axes: Array = []
	for side: float in [1.0, -1.0]:
		var axis := heading.rotated(Vector3.UP, TurretEvolution.TECTONIC_ANGLE * side)
		axes.append([centre - axis * half_length, centre + axis * half_length])
	fissures.append({"left": TurretEvolution.QUAKE_TELEGRAPH_SECONDS, "axes": axes, "half_width": half_width, "focus": centre})
	_dirty = true
	_start_telegraph(TurretEvolution.QUAKE_TELEGRAPH_SECONDS)
	for index in axes.size():
		_show_line(index, axes[index][0], axes[index][1], half_width)
	actor._reset_cooldown(stats)

## Opens both fissures: lays the two zones, then hits each enemy standing in either one, once.
func _open(fissure: Dictionary) -> void:
	var world := actor.world
	var stats := actor._current_view(0.0)
	var shot := actor._new_shot(stats)
	var half_width := float(fissure["half_width"])
	shot.splash_radius = actor.effective_range(stats) * TurretEvolution.TECTONIC_REACH
	shot.attack_targets = {}
	var zones: Array[GroundZone] = []
	for axis: Array in fissure["axes"]:
		zones.append(world.ground_zones.add_line(axis[0], axis[1], half_width, TurretEvolution.TECTONIC_SECONDS,
			TurretEvolution.TECTONIC_SLOW, actor.turret_id))
	pulses_released += 1
	world.effects.show_burst(Vector3(fissure["focus"].x, .15, fissure["focus"].z), "scrap")
	world.audio.play_cue("plasma", fissure["focus"])
	var struck: Dictionary = {}
	for zone in zones:
		for enemy in world.ground_zones.enemies_in(zone, world.enemies):
			if struck.has(enemy.get_instance_id()):
				continue
			struck[enemy.get_instance_id()] = true
			# Shoved sideways, away from the nearer of the two cracks.
			var from := zone.closest_point(enemy.position)
			for other in zones:
				var candidate := other.closest_point(enemy.position)
				if WorldGeometry.planar(enemy.position - candidate).length_squared() < WorldGeometry.planar(enemy.position - from).length_squared():
					from = candidate
			if is_instance_valid(enemy) and not enemy.dead:
				world.combat.apply_hit(enemy, world.combat.hit_from_shot(enemy, from, Vector3(0, 0, -1), shot))

# --- Per tick ---

func tick(delta: float) -> void:
	if not _dirty:
		return
	_tick_telegraph(delta)
	for beat in beats.duplicate():
		beat["left"] = float(beat["left"]) - delta
		if float(beat["left"]) <= 0.0 and beats.has(beat):
			beats.erase(beat)
			_release(beat)
	for fissure in fissures.duplicate():
		fissure["left"] = float(fissure["left"]) - delta
		if float(fissure["left"]) <= 0.0:
			fissures.erase(fissure)
			_open(fissure)
	for ring in rings.duplicate():
		_strike(ring, ring.advance(delta, actor.world.enemies))
		if ring.is_finished():
			rings.erase(ring)
	if salvo_open and beats.is_empty():
		salvo_open = false
		actor._reset_cooldown(actor._current_view(0.0))
	_dirty = not (beats.is_empty() and fissures.is_empty() and rings.is_empty() and telegraph_left <= 0.0)

## Combat stopped (wave end, pause, defeat): nothing queued may fire later.
func clear() -> void:
	if not _dirty and telegraph_left <= 0.0:
		return
	beats.clear()
	fissures.clear()
	rings.clear()
	salvo_open = false
	telegraph_left = 0.0
	_hide_telegraphs()
	_dirty = false

# --- Telegraphs ---

func _holder() -> Node3D:
	var holder := actor.get_node_or_null("QuakeTelegraphs") as Node3D
	if not holder:
		holder = Node3D.new()
		holder.name = "QuakeTelegraphs"
		actor.add_child(holder)
	return holder

func _start_telegraph(seconds: float) -> void:
	telegraph_total = maxf(seconds, .01)
	telegraph_left = seconds

func _show_circle(radius: float) -> void:
	if not telegraph_circle:
		telegraph_circle = Telegraph.create(_holder(), Telegraph.Shape.CIRCLE, TINT)
	Telegraph.place_circle(telegraph_circle, actor.position, radius)
	Telegraph.set_progress(telegraph_circle, 0.0)

func _show_line(index: int, from: Vector3, to: Vector3, half_width: float) -> void:
	while telegraph_lines.size() <= index:
		telegraph_lines.append(Telegraph.create(_holder(), Telegraph.Shape.LINE, TINT))
	var span := WorldGeometry.planar(to - from)
	Telegraph.place_line(telegraph_lines[index], from, span.normalized(), span.length(), half_width * 2.0)
	Telegraph.set_progress(telegraph_lines[index], 0.0)

func _tick_telegraph(delta: float) -> void:
	if telegraph_left <= 0.0:
		return
	telegraph_left = maxf(0.0, telegraph_left - delta)
	var progress := 1.0 - telegraph_left / telegraph_total
	if telegraph_circle and telegraph_circle.visible:
		# A carried turret moves; the warning stays under it.
		Telegraph.place_circle(telegraph_circle, actor.position, telegraph_radius)
		Telegraph.set_progress(telegraph_circle, progress)
	for line in telegraph_lines:
		if line.visible:
			Telegraph.set_progress(line, progress)
	if telegraph_left <= 0.0:
		_hide_telegraphs()

func _hide_telegraphs() -> void:
	if telegraph_circle:
		telegraph_circle.visible = false
	for line in telegraph_lines:
		line.visible = false
