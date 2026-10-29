class_name EnemyBrain
extends RefCounted

## Role-specific decisions; CombatActor retains movement, collision, status and hit ownership.
var actor: CombatActor
var kind: String
var clock: float = 0.0
enum State {IDLE, WAKE, WANDER, CHASE, WARNING, ATTACK, RELOAD, RECOVER, STUNNED, TRANSITION}
var state: State = State.IDLE:
	set(value):
		state = value
		if is_instance_valid(actor) and is_instance_valid(actor.world):
			actor.world.mark_warning(actor, value == State.WARNING)
		if value == State.WARNING:
			warn_total = 0.0
var destination: Vector3
var locked_target: Vector3
var awake: bool = false
var lose_interest: float = 0.0
var deployments: int = 0
var children: Array[CombatActor] = []
var summon_parent: CombatActor
var phase: int = 1
var attacks: int = 0
var marker: MeshInstance3D
var sector: MeshInstance3D
var aim_line: MeshInstance3D
var pounce: ChargeController3D
var age: float = 0.0
var enraged: bool = false
var attack_mode: String = ""
var had_anchors: bool = false
var step_delta: float = 0.0
## Longest warning clock seen since the telegraph started; the fill gauge is 1 - clock / warn_total.
var warn_total: float = 0.0
var expansion: BossExpansionBrain

func _init(owner_actor: CombatActor) -> void:
	actor = owner_actor
	kind = actor.enemy_type
	if kind in EnemyEcology.EXPANSION_BOSSES:
		expansion = BossExpansionBrain.new(self)
	clock = .5 + GameRandom.gameplay.randf()
	destination = actor.position
	if kind in ["hopper", "brass_ram", "grand_marionettist"]:
		pounce = ChargeController3D.new()
		pounce.configure({"charge_detect_radius": 140.0 if kind == "hopper" else 650.0,
			"charge_alert_duration": .6 if kind == "hopper" else 1.1,
			"charge_duration": .3 if kind == "hopper" else .8,
			"charge_cooldown": .8 if kind == "hopper" else 1.5,
			"charge_speed_multiplier": 2.2 if kind == "hopper" else 5.0})

func disturbed() -> void:
	if kind == "drowse" and not awake:
		awake = true
		state = State.WAKE
		clock = .25

func contact_allowed() -> bool:
	if expansion: return expansion.contact_allowed()
	if kind == "drowse":
		return awake and state != State.WAKE
	if pounce:
		return pounce.phase == ChargeController3D.Phase.DASH
	return kind in ["skitter", "puppet", "grand_marionettist"]

func interrupt() -> void:
	if pounce and not EnemyEcology.is_boss(kind):
		pounce.interrupt()
		_hide_warning()

## A stagger (Quake) drops whatever the brain was winding up, on top of the knockback that comes with it. A pounce is cut
## short like a knockback does it; a warning (shot, artillery, summon) is cancelled with its telegraph and any shot already
## in flight from it, and the brain waits `STAGGER_REARM` seconds before it may start another. Never called for bosses.
const STAGGER_REARM: float = 1.0

func stagger() -> void:
	interrupt()
	if pounce:
		state = State.RECOVER
		return
	if state == State.WARNING:
		_cancel_attacks()
		_hide_warning()
		state = State.IDLE
		clock = maxf(clock, STAGGER_REARM)

func move(delta: float, speed: float) -> Vector3:
	step_delta = delta
	age += delta
	clock -= delta
	_tick_telegraph()
	if not children.is_empty():
		# Untyped parameter: a freed child cannot be passed to a CombatActor-typed lambda.
		children.assign(children.filter(func(child: Variant) -> bool: return is_instance_valid(child) and not child.dead))
	# A Decoy's taunt (S1) replaces the hero as the target of everything that answers it. A sleeping Drowse Beetle does not:
	# it stays asleep until something disturbs it.
	var post: TauntPost = null if kind == "drowse" and not awake else actor.taunt_post()
	var hero := post.origin() if post else actor.world.player.position
	var toward := WorldGeometry.planar(hero - actor.position)
	actor.chasing_hero = EnemyEcology.hero_only(kind)
	if expansion:
		return expansion.move(delta, hero, speed)
	if state == State.WARNING and not pounce:
		var aim := WorldGeometry.planar(locked_target - actor.position)
		if not aim.is_zero_approx(): actor.visual.rotation.y = atan2(-aim.x, -aim.z)
	match kind:
		"drowse": return _drowse(delta, toward, speed)
		"hopper", "brass_ram": return _charge(delta, hero, speed)
		"kite": return _ranged(hero, speed, false)
		"lens":
			if not is_instance_valid(summon_parent) or summon_parent.dead:
				_expire()
				return Vector3.ZERO
			if summon_parent.brain.state in [State.WARNING, State.ATTACK, State.STUNNED]:
				state = State.IDLE
				clock = maxf(clock, .9)
				_hide_warning()
			else:
				var shooting := _ranged(hero, 0.0, false)
				if state == State.WARNING: return shooting
			var orbit := summon_parent.position + Vector3(cos(age * .5 + get_instance_id()), 0, sin(age * .5 + get_instance_id())) * 1.7
			return (orbit - actor.position).limit_length(speed)
		"lobber": return _ranged(hero if post or not actor.world.core else actor.world.core.position, speed, true)
		"tender": return _tender(hero, speed)
		"prism_conductor": return _prism(hero, speed)
		"grand_marionettist": return _marionettist(hero, speed)
		"anchor":
			if age > 8.0 or not is_instance_valid(summon_parent) or summon_parent.dead:
				if age > 8.0 and is_instance_valid(summon_parent): summon_parent.brain.had_anchors = false
				_expire()
			return Vector3.ZERO
		"puppet":
			if not is_instance_valid(summon_parent) or summon_parent.dead:
				_expire()
				return Vector3.ZERO
			return toward.normalized() * speed
		_: return toward.normalized() * speed

func _drowse(delta: float, toward: Vector3, speed: float) -> Vector3:
	# React to the nearest body, including the core, without becoming a global seeker.
	var target_radius := actor.world.player.hurtbox_radius()
	actor.chasing_hero = true
	if is_instance_valid(actor.world.core) and not actor.world.core.dead:
		var to_core := WorldGeometry.planar(actor.world.core.position - actor.position)
		if to_core.length() - actor.world.core.radius < toward.length() - target_radius:
			toward = to_core
			target_radius = actor.world.core.radius
			actor.chasing_hero = false
	var gap := maxf(0.0, toward.length() - target_radius)
	if gap <= 2.0:
		disturbed()
	if awake:
		lose_interest = lose_interest + delta if gap > 3.0 else 0.0
		if lose_interest >= 3.0:
			awake = false
			state = State.IDLE
			clock = 1.0
			lose_interest = 0.0
		elif state == State.WAKE:
			if clock <= 0.0:
				state = State.CHASE
			return Vector3.ZERO
		else:
			return toward.normalized() * speed
	if clock <= 0.0:
		if state == State.WANDER:
			state = State.IDLE
			clock = GameRandom.gameplay.randf_range(.25, .65)
		else:
			state = State.WANDER
			clock = GameRandom.gameplay.randf_range(2.0, 4.0)
			var angle := GameRandom.gameplay.randf() * TAU
			destination = WorldGeometry.clamp_position(actor.position + Vector3(cos(angle), 0, sin(angle)) * 2.8, 1.0)
	var offset := destination - actor.position
	return offset.normalized() * speed * .7 if state == State.WANDER and offset.length() > .15 else Vector3.ZERO

func _charge(delta: float, hero: Vector3, speed: float) -> Vector3:
	if pounce.phase == ChargeController3D.Phase.APPROACH and (not _visible() or not _warning_slot(false)):
		return (hero - actor.position).normalized() * speed * .3
	var previous := pounce.phase
	var movement := pounce.advance(delta, actor.position, hero, speed)
	if pounce.phase == ChargeController3D.Phase.WINDUP:
		state = State.WARNING
		_line(pounce.origin, pounce.heading, speed * pounce.speed_multiplier * pounce.dash_duration, .25 if kind == "hopper" else .6, Telegraph.CHARGE)
	elif pounce.phase == ChargeController3D.Phase.DASH:
		state = State.ATTACK
	elif previous == ChargeController3D.Phase.DASH:
		state = State.RECOVER
		_hide_warning()
		attacks += 1
		if kind == "brass_ram" and attacks % 2 == 0:
			_area(actor.position, 1.6, .9, actor.contact_damage)
		if kind == "brass_ram" and actor.health < actor.max_health * .5 and attacks % 2 == 1:
			pounce.remaining = .25
	elif pounce.phase == ChargeController3D.Phase.APPROACH:
		state = State.IDLE
	return movement

func _ranged(target: Vector3, speed: float, artillery: bool) -> Vector3:
	var low := 4.0 if artillery else 3.0
	var high := 5.0 if artillery else 4.0
	var toward := WorldGeometry.planar(target - actor.position)
	if state == State.WARNING:
		if not artillery and clock > .25:
			locked_target = target
		_line(actor.position, (locked_target - actor.position).normalized(), minf(toward.length(), 8.0), .025)
		if clock <= 0.0:
			if not artillery:
				_bolt(locked_target, actor.contact_damage + 5.0)
			_hide_warning()
			state = State.RELOAD
			clock = 4.0 if artillery else 2.5
		return Vector3.ZERO
	if clock <= 0.0 and toward.length() <= high + .75 and _visible() and _warning_slot(artillery):
		locked_target = target
		state = State.WARNING
		clock = 1.2 if artillery else .8
		if artillery:
			var amount := actor.world.core_max_health() * .03 if actor.world.core else 6.0
			_area(target, .65, 1.2, amount, actor.world.core != null)
		return Vector3.ZERO
	return _range_motion(toward, speed, low, high)

func _tender(hero: Vector3, speed: float) -> Vector3:
	if state == State.WARNING:
		if clock <= 0.0:
			for index in 2:
				if children.size() < 4 and actor.world.waves.active_count("skitter") < 8:
					_summon("skitter", index * PI)
			deployments += 1
			state = State.RELOAD
			clock = 5.0
			_hide_warning()
		return Vector3.ZERO
	if clock <= 0.0 and deployments < 3 and children.size() < 4 and actor.world.waves.active_count("skitter") < 8 and _visible():
		state = State.WARNING
		clock = 1.0
		_ring(.85, Telegraph.SUMMON)
		return Vector3.ZERO
	return _range_motion(hero - actor.position, speed, 4.0, 5.0)

func _prism(hero: Vector3, speed: float) -> Vector3:
	if actor.health < actor.max_health * .6 and phase == 1:
		phase = 2
		_summon("lens", 0.0)
		_summon("lens", PI)
	if phase == 2 and children.is_empty():
		phase = 3
		_cancel_attacks()
		_hide_warning()
		clock = 2.0
		state = State.STUNNED
	if state == State.WARNING:
		if clock <= 0.0:
			_hide_warning()
			if attack_mode == "volley":
				_volley(locked_target, [-.22, 0.0, .22], 7.0)
				clock = 2.5
				state = State.RELOAD
			else:
				# Begin at the warned left boundary and sweep the marked sector.
				var heading := (locked_target - actor.position).normalized().rotated(Vector3.UP, -.45)
				var beam := EnemyOrdnance.launch(actor, "beam", actor.position, actor.position + heading, 8.0)
				beam.warning_time = .01
				beam.lifetime = 2.0
				beam.angular_speed = .45
				actor.world.actor_root.add_child(beam)
				clock = 2.1
				state = State.ATTACK
			attacks += 1
		return Vector3.ZERO
	if state == State.ATTACK:
		if clock <= 0.0:
			state = State.RELOAD
			clock = 2.0
		return Vector3.ZERO
	if state == State.STUNNED and clock > 0.0: return Vector3.ZERO
	if clock <= 0.0 and _visible() and _warning_slot(false):
		locked_target = hero
		attack_mode = "volley" if attacks % 2 == 0 else "beam"
		state = State.WARNING
		clock = 1.0
		_sector((hero - actor.position).normalized(), 7.0, .45 if attack_mode == "beam" else .22, false, Telegraph.SWEEP if attack_mode == "beam" else Telegraph.SHOT)
		for child in children:
			child.brain.clock = 4.0
			child.brain.state = State.IDLE
			child.brain._hide_warning()
		return Vector3.ZERO
	return _range_motion(hero - actor.position, speed, 3.0, 4.0)

func _marionettist(hero: Vector3, speed: float) -> Vector3:
	var next_phase := 1 if actor.health > actor.max_health * .65 else (2 if actor.health > actor.max_health * .3 else 3)
	if next_phase != phase:
		phase = next_phase
		_cancel_attacks()
		_hide_warning()
		for child in children:
			if child.enemy_type == "anchor": child.brain._expire()
		pounce.interrupt()
		clock = 1.2
		state = State.TRANSITION
		attack_mode = ""
	if state == State.TRANSITION and clock > 0.0: return Vector3.ZERO
	if phase == 2 and had_anchors:
		var anchors_left := children.any(func(child: CombatActor) -> bool: return child.enemy_type == "anchor")
		if not anchors_left:
			had_anchors = false
			clock = 2.0
			state = State.STUNNED
	if state == State.STUNNED and clock > 0.0: return Vector3.ZERO
	if state == State.WARNING and attack_mode != "charge":
		if clock <= 0.0:
			_hide_warning()
			if attack_mode == "volley":
				_volley(locked_target, [-.4, 0.0, .4], 8.0)
			elif attack_mode == "puppets":
				if deployments < 2:
					for index in 2:
						if actor.world.waves.active_count("puppet") < 4: _summon("puppet", index * PI)
					deployments += 1
				for index in 2:
					if actor.world.waves.active_count("anchor") < 2:
						var anchor := _summon("anchor", index * PI + .6, 2.4)
						if not anchor: continue
						var tether := EnemyOrdnance.launch(anchor, "beam", anchor.position, actor.position, 7.0)
						tether.warning_time = 1.2
						tether.beam_length = anchor.position.distance_to(actor.position)
						tether.lifetime = 6.8
						actor.world.actor_root.add_child(tether)
						had_anchors = true
			else:
				var angles: Array[float] = []
				for index in range(2, 11): angles.append(float(index) * TAU / 12.0)
				_volley(locked_target, angles, 9.0)
			attacks += 1
			clock = 9.0 if attack_mode == "puppets" else 2.8
			state = State.RELOAD
		return Vector3.ZERO
	if phase == 3 and attacks % 2 == 1:
		attack_mode = "charge"
		var previous := pounce.phase
		var movement := _charge(step_delta, hero, speed)
		if previous == ChargeController3D.Phase.DASH and pounce.phase == ChargeController3D.Phase.RECOVER:
			clock = 1.2
		return movement
	if clock <= 0.0 and _visible() and _warning_slot(false):
		state = State.WARNING
		locked_target = hero
		clock = 1.2
		attack_mode = "volley" if phase == 1 else ("puppets" if phase == 2 else "pulse")
		if attack_mode == "pulse":
			_sector((hero - actor.position).normalized(), 3.5, PI - .5, true, Telegraph.BLAST)
		else:
			_line(actor.position, (hero - actor.position).normalized(), 5.0, .3)
		return Vector3.ZERO
	return Vector3.ZERO if phase == 2 and had_anchors else _range_motion(hero - actor.position, speed, 2.5, 3.5)

func _volley(target: Vector3, angles: Array, amount: float) -> void:
	for angle: float in angles:
		_bolt(actor.position + (target - actor.position).rotated(Vector3.UP, angle), amount)

func _expire() -> void:
	_cancel_attacks()
	actor.dead = true
	actor.world.enemies.erase(actor)
	actor.queue_free()

func _range_motion(toward: Vector3, speed: float, low: float, high: float) -> Vector3:
	var distance := toward.length()
	if distance > high:
		return toward.normalized() * speed
	if distance < low:
		var retreat := -toward.normalized() * speed * .55
		var next := WorldGeometry.clamp_position(actor.position + retreat)
		return (next - actor.position).limit_length(speed * .55)
	return Vector3.ZERO

func _visible() -> bool:
	var camera := actor.world.camera
	return camera != null and not camera.is_position_behind(actor.position) and camera.get_viewport().get_visible_rect().has_point(camera.unproject_position(actor.position))

func _warning_slot(area: bool) -> bool:
	var count := 0
	var stale: Array = []
	for other: Variant in actor.world.warning_actors:
		if not is_instance_valid(other) or other.dead:
			stale.append(other)
			continue
		if other == actor or other.position.distance_squared_to(actor.position) > 64.0:
			continue
		if not area and other.charge and other.charge.phase == ChargeController3D.Phase.WINDUP:
			count += 1
		if not other.brain: continue
		if other.brain.state == State.WARNING and (other.enemy_type == "lobber") == area:
			count += 1
	for gone in stale:
		actor.world.warning_actors.erase(gone)
	return count < (1 if area else 2)

func _bolt(target: Vector3, amount: float) -> void:
	var attack := EnemyOrdnance.launch(actor, "bolt", actor.weapon_muzzle.global_position if is_instance_valid(actor.weapon_muzzle) else actor.position + Vector3(0, .5, 0), target, amount)
	actor.world.actor_root.add_child(attack)

func _area(at: Vector3, size: float, delay: float, amount: float, core_target: bool = false) -> void:
	var attack := EnemyOrdnance.launch(actor, "area", actor.position, at, amount, core_target)
	attack.radius = size
	attack.warning_time = delay
	actor.world.actor_root.add_child(attack)

func _summon(type_id: String, angle: float, distance: float = 1.0) -> CombatActor:
	var at := WorldGeometry.clamp_position(actor.position + Vector3(cos(angle), 0, sin(angle)) * distance)
	if actor.world.waves.convoy_spawn_blocked(at):
		return null # Summoned enemies obey the same route and core exclusion as arrivals.
	var child := actor.world.spawn_enemy(at, type_id)
	child.brain.summon_parent = actor
	children.append(child)
	return child

func _ring(size: float, color: Color = Telegraph.BLAST) -> void:
	if not marker:
		marker = Telegraph.create(actor, Telegraph.Shape.CIRCLE, color)
	Telegraph.recolor(marker, color)
	Telegraph.place_circle(marker, actor.position, size)
	_tick_telegraph()

func _line(at: Vector3, direction: Vector3, length: float, width: float, color: Color = Telegraph.SHOT) -> void:
	if not aim_line:
		aim_line = Telegraph.create(actor, Telegraph.Shape.LINE, color)
	Telegraph.recolor(aim_line, color)
	Telegraph.place_line(aim_line, at, direction, length, width)
	_tick_telegraph()

## 0..1 fill of the current wind-up, from the charge controller or the warning clock.
func warning_progress() -> float:
	if pounce and pounce.phase == ChargeController3D.Phase.WINDUP:
		return 1.0 - pounce.remaining / maxf(pounce.windup_duration, .001)
	if state != State.WARNING:
		return 1.0
	warn_total = maxf(warn_total, clock)
	return 1.0 - clampf(clock / maxf(warn_total, .001), 0.0, 1.0)

func _tick_telegraph() -> void:
	var progress := warning_progress()
	for gauge: MeshInstance3D in [marker, sector, aim_line]:
		if gauge and gauge.visible:
			Telegraph.set_progress(gauge, progress)

func _hide_warning() -> void:
	if sector: sector.visible = false
	if marker: marker.visible = false
	if aim_line: aim_line.visible = false

func _cancel_attacks() -> void:
	for node in actor.get_tree().get_nodes_in_group("hostile_ordnance"):
		if node.world == actor.world and node.source == actor:
			node.queue_free()

## A filled sector makes the entire future beam sweep / pulse gap readable before damage starts.
func _sector(direction: Vector3, radius: float, half_angle: float, rear: bool = false, color: Color = Telegraph.SWEEP) -> void:
	if not sector:
		sector = Telegraph.create(actor, Telegraph.Shape.SECTOR, color)
	Telegraph.recolor(sector, color)
	Telegraph.place_sector(sector, actor.position, direction, radius, half_angle, rear)
	_tick_telegraph()
