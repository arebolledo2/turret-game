class_name BossExpansionBrain
extends RefCounted

## Boss-specific patterns share EnemyBrain's warning, ordnance and lifecycle helpers.
## Targets lock before damage. All attacks remain hero-only, including in core modes.
var _brain_ref: WeakRef
var brain: EnemyBrain:
	get: return _brain_ref.get_ref() as EnemyBrain
var actor: CombatActor
var heading := Vector3.FORWARD
var salvo: Array[Dictionary] = []
var salvo_lines: Array[MeshInstance3D] = []
var drop_clock := 0.0
var drops := 0
const CANNONS := ["FL", "FR", "RL", "RR"]

func _init(owner_brain: EnemyBrain) -> void:
	_brain_ref = weakref(owner_brain)
	actor = brain.actor

func contact_allowed() -> bool:
	return brain.kind == "crownwheel_colossus" and brain.state == EnemyBrain.State.ATTACK

func pose() -> void:
	if brain.kind != "broadside_baron" or brain.state != EnemyBrain.State.WARNING: return
	for shot in salvo:
		var pivot := actor.visual.find_child("Cannon_" + str(shot.corner), true, false) as Node3D
		if pivot:
			var direction := WorldGeometry.planar(shot.target - pivot.global_position).normalized()
			pivot.global_rotation.y += WorldGeometry.planar(-pivot.global_basis.z).signed_angle_to(direction, Vector3.UP)

func move(delta: float, hero: Vector3, speed: float) -> Vector3:
	brain.phase = 2 if actor.health <= actor.max_health * .5 else 1
	match brain.kind:
		"broadside_baron": return _airship(hero, speed)
		"frostforge_yeti": return _yeti(hero, speed)
		"skyfall_kestrel": return _bomber(delta, hero, speed)
		"crucible_crab": return _crab(hero, speed)
		"pendulum_regent": return _regent(hero, speed)
		"crownwheel_colossus": return _wheel(hero, speed)
	return Vector3.ZERO

func _ready_attack() -> bool:
	return brain.clock <= 0.0 and brain._visible() and brain._warning_slot(false)

func _lock(hero: Vector3, duration: float) -> void:
	brain.locked_target = WorldGeometry.planar(hero)
	heading = WorldGeometry.planar(hero - actor.position).normalized()
	if heading.is_zero_approx(): heading = Vector3.FORWARD
	brain.state = EnemyBrain.State.WARNING
	brain.clock = duration
	actor.world.audio.play_cue("warning", actor.position)

func _recover(duration: float) -> void:
	brain._hide_warning()
	brain.state = EnemyBrain.State.RELOAD
	brain.clock = duration
	brain.attacks += 1

## Canonical outward axes in model-local Godot coordinates: front is -Z.
static func cannon_axis(index: int) -> Vector3:
	return Vector3(-1 if index % 2 == 0 else 1, 0, -1 if index < 2 else 1).normalized()

static func within_cannon_arc(outward: Vector3, target_direction: Vector3) -> bool:
	return not target_direction.is_zero_approx() and WorldGeometry.planar(outward).normalized().dot(WorldGeometry.planar(target_direction).normalized()) >= cos(PI / 3.0)

func _airship(hero: Vector3, speed: float) -> Vector3:
	if brain.state == EnemyBrain.State.WARNING:
		for line in salvo_lines: Telegraph.set_progress(line, brain.warning_progress())
		if brain.clock <= 0.0:
			for shot in salvo:
				var bolt := EnemyOrdnance.launch(actor, "bolt", shot.origin, shot.target, 7.0)
				bolt.shot_speed = 5.5
				actor.world.actor_root.add_child(bolt)
			for line in salvo_lines: line.queue_free()
			salvo_lines.clear()
			salvo.clear()
			_recover(1.8 if brain.phase == 2 else 2.5)
		return Vector3.ZERO
	if _ready_attack() and actor.position.distance_to(hero) < 8.0:
		_lock(hero, 1.1)
		for index in 4:
			var outward := actor.visual.global_basis * cannon_axis(index)
			var pivot := actor.visual.find_child("Cannon_" + CANNONS[index], true, false) as Node3D
			var muzzle := actor.visual.find_child("Muzzle_" + CANNONS[index], true, false) as Node3D
			var origin := actor.position + outward * .9 + Vector3.UP * .8
			if pivot: origin = pivot.global_position
			if not within_cannon_arc(outward, hero - origin): continue
			var direction := WorldGeometry.planar(hero - origin).normalized()
			# Pivots' base direction comes from their corner, not a full-circle turret.
			if pivot:
				pivot.global_rotation.y += WorldGeometry.planar(-pivot.global_basis.z).signed_angle_to(direction, Vector3.UP)
			if muzzle: origin = muzzle.global_position
			salvo.append({"origin": origin, "target": brain.locked_target, "corner": CANNONS[index]})
			var line := Telegraph.create(actor, Telegraph.Shape.LINE, Telegraph.SHOT)
			Telegraph.place_line(line, origin, direction, WorldGeometry.planar(origin).distance_to(brain.locked_target), .3)
			salvo_lines.append(line)
		if salvo.is_empty(): _recover(.5)
		return Vector3.ZERO
	return brain._range_motion(hero - actor.position, speed, 3.5, 5.0)

func _yeti(hero: Vector3, speed: float) -> Vector3:
	if brain.state == EnemyBrain.State.WARNING:
		if brain.clock <= 0.0: _recover(1.4)
		return Vector3.ZERO
	if _ready_attack() and actor.position.distance_to(hero) < 3.4:
		_lock(hero, 1.15)
		var side := heading.cross(Vector3.UP) * .65
		brain._area(brain.locked_target + side * (-1.0 if brain.attacks % 2 == 0 else 1.0), 1.0, 1.15, 9.0)
		if brain.phase == 2:
			brain._area(brain.locked_target - side * (-1.0 if brain.attacks % 2 == 0 else 1.0), 1.0, 1.65, 9.0)
		brain._ring(1.1, Telegraph.BLAST)
		return Vector3.ZERO
	return brain._range_motion(hero - actor.position, speed, 1.2, 2.0)

func _bomber(delta: float, hero: Vector3, speed: float) -> Vector3:
	if brain.state == EnemyBrain.State.WARNING:
		if brain.clock <= 0.0:
			brain._hide_warning()
			brain.state = EnemyBrain.State.ATTACK
			brain.clock = 2.0
			drop_clock = 0.0
			drops = 0
		return Vector3.ZERO
	if brain.state == EnemyBrain.State.ATTACK:
		drop_clock -= delta
		if drop_clock <= 0.0 and drops < (5 if brain.phase == 2 else 4):
			brain._area(WorldGeometry.clamp_position(actor.position + heading * .45), .8, 1.1, 8.0)
			drop_clock = .4
			drops += 1
		if brain.clock <= 0.0:
			_recover(2.0)
			return Vector3.ZERO
		return heading * speed * 1.45
	if _ready_attack() and actor.position.distance_to(hero) < 8.0:
		_lock(hero, 1.0)
		brain._line(actor.position, heading, 8.0, .45, Telegraph.CHARGE)
		return Vector3.ZERO
	return brain._range_motion(hero - actor.position, speed, 4.0, 5.5)

func _crab(hero: Vector3, speed: float) -> Vector3:
	if brain.state == EnemyBrain.State.WARNING:
		if brain.clock <= 0.0:
			if brain.attack_mode == "furnace": _sweep(4.5, .55, 6.0, 1.6)
			else: _recover(2.0)
		return Vector3.ZERO
	if brain.state == EnemyBrain.State.ATTACK:
		if brain.clock <= 0.0: _recover(2.2)
		return Vector3.ZERO
	if _ready_attack() and actor.position.distance_to(hero) < 5.0:
		_lock(hero, 1.25)
		brain.attack_mode = "furnace" if brain.attacks % 2 else "shells"
		if brain.attack_mode == "furnace":
			brain._sector(heading, 4.5, .55, false, Telegraph.SWEEP)
		else:
			var side := heading.cross(Vector3.UP)
			var offsets: Array = [-1.6, -.8, 0.0, .8, 1.6] if brain.phase == 2 else [-1.2, 0.0, 1.2]
			for offset: float in offsets:
				brain._area(WorldGeometry.clamp_position(hero + side * offset), .65, 1.25 + absf(offset) * .2, 8.0)
		return Vector3.ZERO
	return brain._range_motion(hero - actor.position, speed, 2.5, 3.8)

func _regent(hero: Vector3, speed: float) -> Vector3:
	if brain.state == EnemyBrain.State.WARNING:
		if brain.clock <= 0.0:
			if brain.attack_mode == "pendulum": _sweep(5.0, .8, 8.0, 1.8)
			else: _recover(1.8)
		return Vector3.ZERO
	if brain.state == EnemyBrain.State.ATTACK:
		if brain.clock <= 0.0: _recover(1.8)
		return Vector3.ZERO
	if _ready_attack() and actor.position.distance_to(hero) < 5.5:
		_lock(hero, 1.3)
		brain.attack_mode = "pendulum" if brain.attacks % 2 else "hammer"
		if brain.attack_mode == "pendulum": brain._sector(heading, 5.0, .8, false, Telegraph.SWEEP)
		else:
			brain._area(hero, 1.15, 1.3, 11.0)
			if brain.phase == 2: brain._area(hero, 1.55, 2.0, 7.0)
		return Vector3.ZERO
	return brain._range_motion(hero - actor.position, speed, 2.0, 3.5)

func _sweep(length: float, half_angle: float, damage: float, duration: float) -> void:
	brain._hide_warning()
	var start := heading.rotated(Vector3.UP, -half_angle)
	var beam := EnemyOrdnance.launch(actor, "beam", actor.position, actor.position + start, damage)
	beam.warning_time = .01
	beam.beam_length = length
	beam.lifetime = duration
	beam.angular_speed = half_angle * 2.0 / duration
	actor.world.actor_root.add_child(beam)
	brain.state = EnemyBrain.State.ATTACK
	brain.clock = duration + .1

func _wheel(hero: Vector3, speed: float) -> Vector3:
	if brain.state == EnemyBrain.State.WARNING:
		if brain.clock <= 0.0:
			brain._hide_warning()
			if brain.attack_mode == "roll":
				brain.state = EnemyBrain.State.ATTACK
				brain.clock = 1.25
			else:
				# The hero-facing gap shown in the warning remains safe.
				var angles: Array[float] = []
				for index in range(2, 11): angles.append(float(index) * TAU / 12.0)
				brain._volley(brain.locked_target, angles, 8.0)
				_recover(1.6)
		return Vector3.ZERO
	if brain.state == EnemyBrain.State.ATTACK:
		if brain.clock <= 0.0:
			_recover(1.5)
			return Vector3.ZERO
		return heading * speed * (3.4 if brain.phase == 2 else 2.8)
	if _ready_attack() and actor.position.distance_to(hero) < 9.0:
		_lock(hero, 1.2)
		brain.attack_mode = "roll" if brain.attacks % 2 == 0 else "pulse"
		if brain.attack_mode == "roll": brain._line(actor.position, heading, speed * 3.4 * 1.25, actor.hurtbox_radius() * 2.0 + .46, Telegraph.CHARGE)
		else: brain._sector(heading, 3.5, PI - .5, true, Telegraph.BLAST)
		return Vector3.ZERO
	return brain._range_motion(hero - actor.position, speed, 3.0, 4.5)
