class_name EnemyActor
extends CombatActor

## A hostile body: brain-driven or chasing, with a hurtbox, ground marker and optional charge telegraph.
## Seconds a hook lasts: far longer than any wave, so it ends only when the enemy dies or its Decoy lets go.
const HOOK_SECONDS: float = 3600.0
## Hooked enemies circle their Decoy on this many lanes, `HOOK_LANE_GAP` metres apart (the Decoy sets the innermost radius),
## walking round it at `HOOK_ORBIT_SPEED` of their speed; farther than `HOOK_LANE_TOLERANCE` metres from its lane an enemy is
## pulled toward it first.
const HOOK_LANES: int = 3
const HOOK_LANE_GAP: float = .35
const HOOK_ORBIT_SPEED: float = .75
const HOOK_LANE_TOLERANCE: float = 1.2

## Cached `EnemyEcology.taunt_kind` (-1 until first asked).
var _taunt_kind: int = -1
## The taunt `chase_position` last chose (null when it chose the hero or the objective).
var taunt_target: TauntPost

func _init() -> void:
	is_enemy = true

func _configure_body() -> void:
	# Enemies never sweep through the physics server (the hurtbox Area3D handles hits), so they have no body shape.
	collision_layer = 0
	collision_mask = 0

func _build_visuals() -> void:
	var model := _build_enemy_model()
	if EnemyEcology.TYPES.has(enemy_type):
		brain = EnemyBrain.new(self)
	if ClockworkModels.available(enemy_type) and not stationary:
		if brain:
			ecology_motion = EcologyMotion.new(model)
		else:
			clockwork_motion = ClockworkMotion.new(model, enemy_type)
	else:
		EnemyVariants.apply_tint(model, enemy_type)
	if elite:
		EnemyVariants.tint_model(model, enemy_type + "_elite", Color(1.0, .85, .45), .7)
	visual.add_child(model)
	weapon_muzzle = model.find_child("Muzzle", true, false) as Node3D
	visual.scale = Vector3.ONE * body_scale
	if clockwork_motion:
		legs.assign(clockwork_motion.limbs)
	else:
		for side in _leg_sides():
			for index in range(3):
				legs.append(model.find_child("Leg_%s_%d" % [side, index], true, false) as Node3D)
	hurtbox = Area3D.new()
	hurtbox.collision_layer = WorldGeometry.ENEMY_HURTBOX_LAYER
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	var hit_shape := CollisionShape3D.new()
	var hit_capsule := CapsuleShape3D.new()
	hit_capsule.radius = hurtbox_radius()
	hit_capsule.height = 1.3 * body_scale
	hit_shape.shape = hit_capsule
	hit_shape.position.y = 0.6 * body_scale
	hurtbox.add_child(hit_shape)
	add_child(hurtbox)
	var marker_colour := Color("f5a447") if charge else Color("9c545e")
	if elite:
		marker_colour = Color("ffd23d")
	elif ignores_hero:
		marker_colour = Color("ff3b3b")
	marker = WorldGeometry.ring(self, .36 * body_scale, marker_colour)
	marker.position.y = .025
	slow_marker = WorldGeometry.ring(self, .43 * body_scale, Color("55dcff"))
	slow_marker.position.y = .04
	slow_marker.visible = false
	if charge:
		_build_warning()

## Builds the enemy's body model; specialised actors (the tech-drop crate) override this.
func _build_enemy_model() -> Node3D:
	var model: Node3D
	if enemy_type == "charger":
		model = ClockworkModels.instantiate(enemy_type) if ClockworkModels.available(enemy_type) else preload("res://assets/models/game/charger_drone.glb").instantiate()
		charge = ChargeController3D.new()
		charge.configure(EnemyRegistry.TYPES["charger"]["behavior_params"])
	else:
		model = ClockworkModels.instantiate(enemy_type) if ClockworkModels.available(enemy_type) else preload("res://assets/models/game/spider_drone.glb").instantiate()
	return model

## Which sides of the model carry animated legs (`Leg_<side>_<0..2>`).
func _leg_sides() -> Array[String]:
	return ["L", "R"]

func _build_warning() -> void:
	warning = Telegraph.create(self, Telegraph.Shape.LINE, Telegraph.CHARGE)
	warning.name = "ChargeWarning"

func _tick_statuses(delta: float) -> bool:
	_tick_mark(delta)
	_tick_stagger(delta)
	_tick_hooked(delta)
	if statuses.is_burning():
		for burn_hit in statuses.advance_burn(delta):
			world.combat.apply_hit(self, burn_hit)
			if dead:
				return false
	return true

## The mark timer runs here rather than in `_steer`, so stationary enemies (tech-drop crates) lose their mark too.
func _tick_mark(delta: float) -> void:
	if statuses.is_marked():
		statuses.advance_mark(delta)
	var marked := statuses.is_marked()
	if marked and not mark_marker:
		mark_marker = WorldGeometry.ring(self, .52 * body_scale, Color("ffb02e"))
		mark_marker.position.y = .05
	if mark_marker and mark_marker.visible != marked:
		mark_marker.visible = marked

## The stagger timer runs here (like the mark timer, so stationary crates tick it too) and a ground ring shows while the
## enemy is down. The moment it goes down its pending actions are cut short, even when the stagger was applied without a hit.
func _tick_stagger(delta: float) -> void:
	if statuses.is_staggered():
		statuses.advance_stagger(delta)
	var down := statuses.is_staggered()
	if down and not stagger_marker:
		stagger_marker = WorldGeometry.ring(self, .6 * body_scale, Color("fff2b0"))
		stagger_marker.position.y = .055
		stagger_marker.visible = false # so the first frame down counts as the transition below
	if stagger_marker and stagger_marker.visible != down:
		stagger_marker.visible = down
		if down:
			_interrupt_actions()

## The Maelstrom hook (a generic timed status, one timer per Decoy) runs here like the mark, so it is ticked whenever the
## enemy is alive. A hook whose Decoy is gone or fighting no more (no post holds a timer for this enemy) is dropped.
func _tick_hooked(delta: float) -> void:
	if not statuses.is_active(TauntField.HOOKED):
		return
	statuses.advance_timed(TauntField.HOOKED, delta)
	if not world.taunts.hook_anchor(self):
		statuses.clear_all_timed(TauntField.HOOKED)

## Hooks this enemy for the Decoy `owner` until it dies, and drops whatever it was winding up, the way a stagger does.
func hook(owner: int) -> void:
	var fresh := not statuses.is_active(TauntField.HOOKED)
	statuses.apply_timed(TauntField.HOOKED, HOOK_SECONDS, owner)
	if fresh:
		_interrupt_actions()

func is_hooked() -> bool:
	return statuses.is_active(TauntField.HOOKED)

## Charges, pounces and wound-up shots end; bosses keep going (they are never staggered).
func _interrupt_actions() -> void:
	if brain and not EnemyEcology.is_boss(enemy_type):
		brain.stagger()
	if charge:
		charge.interrupt()
		warning.visible = false
		world.mark_warning(self, false)

## A staggered enemy stands still: no chase, charge, shot or summon (its brain is not advanced), though a knockback still
## slides it and its slow keeps running down.
func _stagger_steer(delta: float) -> Vector3:
	velocity = knockback_velocity
	knockback_velocity *= exp(-GameConstants.KNOCKBACK_DECAY_RATE * delta)
	return Vector3.ZERO

## Sets the enemy's velocity for this tick (chase, charge windup/dash, separation, knockback) and returns its heading.
func _steer(delta: float) -> Vector3:
	var speed_factor := 1.0
	if not statuses.effects.is_empty() or statuses.exposed_remaining > 0.0:
		statuses.advance(delta)
		speed_factor = statuses.speed_multiplier()
	# Enemy-only ground zones (Quake fissures): the stronger slow wins, slows from different sources never multiply.
	if world.ground_zones and world.ground_zones.has_zones():
		speed_factor = minf(speed_factor, world.ground_zones.speed_factor_at(position, hurtbox_radius()))
	if world.terrain:
		speed_factor = maxf(1.0 - GameConstants.ZONE_MUD_MAX_SLOW, speed_factor * world.terrain.mud_factor_at(position))
	var slowed := speed_factor < 1.0
	if slow_marker.visible != slowed:
		slow_marker.visible = slowed
	if statuses.is_staggered():
		return _stagger_steer(delta)
	var effective_speed := speed * speed_factor
	if statuses.is_active(TauntField.HOOKED):
		return _hooked_steer(delta, effective_speed)
	if brain:
		var movement := brain.move(delta, effective_speed)
		if (not brain.pounce or brain.pounce.phase == ChargeController3D.Phase.APPROACH) and not (brain.expansion and brain.state in [EnemyBrain.State.WARNING, EnemyBrain.State.ATTACK]):
			movement += world.crowd.separation(self)
		velocity = movement + knockback_velocity
		knockback_velocity *= exp(-GameConstants.KNOCKBACK_DECAY_RATE * delta)
		return movement.normalized()
	var goal := chase_position()
	var at_core := false
	if world.core and not taunt_target:
		var stop := world.core.radius + .4 * body_scale
		at_core = not chasing_hero and WorldGeometry.planar(goal - position).length_squared() < stop * stop
	var movement := WorldGeometry.planar(goal - position).normalized() * effective_speed
	if charge:
		var previous_phase := charge.phase
		movement = charge.advance(delta, position, goal, effective_speed)
		if charge.phase == ChargeController3D.Phase.WINDUP and previous_phase != charge.phase:
			world.audio.play_cue("warning", position)
		world.mark_warning(self, charge.phase == ChargeController3D.Phase.WINDUP)
		warning.visible = charge.phase in [ChargeController3D.Phase.WINDUP, ChargeController3D.Phase.DASH]
		if warning.visible:
			if charge.phase == ChargeController3D.Phase.WINDUP:
				# The swept contact width and the locked path fill up as the wind-up elapses.
				var lane := speed * charge.speed_multiplier * charge.dash_duration
				Telegraph.place_line(warning, charge.origin, charge.heading, lane, 1.0)
				Telegraph.set_progress(warning, 1.0 - charge.remaining / maxf(charge.windup_duration, .001))
			else:
				Telegraph.set_progress(warning, 1.0)
			visual.rotation.y = atan2(-charge.heading.x, -charge.heading.z)
	if not charge or charge.phase in [ChargeController3D.Phase.APPROACH, ChargeController3D.Phase.RECOVER]:
		if at_core:
			movement = Vector3.ZERO
		movement += world.crowd.separation(self)
	velocity = movement + knockback_velocity
	knockback_velocity *= exp(-GameConstants.KNOCKBACK_DECAY_RATE * delta)
	return movement.normalized()

## A hooked enemy circles its Decoy: pulled onto its own lane (the post's ring radius plus a lane offset by instance), then
## walking round it in one direction, spread by the usual crowd separation. It ignores the hero, so it neither chases nor shoots;
## a knockback still slides it, and touching the hero still hurts the hero.
func _hooked_steer(delta: float, effective_speed: float) -> Vector3:
	var anchor := world.taunts.hook_anchor(self)
	var movement := Vector3.ZERO
	if anchor:
		var offset := WorldGeometry.planar(position - anchor.origin())
		var distance := offset.length()
		var radial := offset / distance if distance > .001 else Vector3(1, 0, 0)
		var lane := anchor.hook_ring + float(get_instance_id() % HOOK_LANES) * HOOK_LANE_GAP
		var pull := clampf((lane - distance) / HOOK_LANE_TOLERANCE, -1.0, 1.0)
		var tangent := Vector3(-radial.z, 0, radial.x)
		movement = (radial * pull + tangent * HOOK_ORBIT_SPEED * (1.0 - absf(pull))).limit_length(1.0) * effective_speed
	movement += world.crowd.separation(self)
	velocity = movement + knockback_velocity
	knockback_velocity *= exp(-GameConstants.KNOCKBACK_DECAY_RATE * delta)
	return movement.normalized()

func _move(delta: float) -> void:
	# Enemies only collide with the arena bounds, which clamp_position enforces, so skip the physics-server sweep.
	position = WorldGeometry.clamp_position(position + velocity * delta)

func _after_move(previous_position: Vector3) -> void:
	if charge and charge.phase == ChargeController3D.Phase.DASH and velocity.length_squared() > .000001 and position.distance_squared_to(previous_position) < .000001:
		charge.interrupt()
		warning.visible = false

func _act(delta: float, previous_position: Vector3) -> void:
	if statuses.is_staggered():
		return
	_apply_contact_damage(delta, previous_position)

## Enemy touch damage to the hero (swept along this tick's step) and, in core mode, to the core on a timer.
func _apply_contact_damage(delta: float, previous_position: Vector3) -> void:
	if brain and not brain.contact_allowed():
		return
	var player_position: Vector3 = world.player.position
	var reach := .5 * body_scale
	var near_x := absf(player_position.x - position.x)
	var near_z := absf(player_position.z - position.z)
	# Skip the segment test unless the player is within reach of the step's bounding box.
	var step_x := absf(position.x - previous_position.x)
	var step_z := absf(position.z - previous_position.z)
	var may_touch := near_x < reach + step_x and near_z < reach + step_z
	var closest := Geometry3D.get_closest_point_to_segment(player_position, previous_position, position) if may_touch else position
	if may_touch and WorldGeometry.planar(player_position - closest).length_squared() < reach * reach:
		world.combat.apply_hit(world.player, CombatHit3D.new(contact_damage, position))
	if world.core and not EnemyEcology.hero_only(enemy_type):
		core_clock -= delta
		if core_clock <= 0.0:
			var core_reach := world.core.radius + reach
			if WorldGeometry.planar(world.core.position - position).length_squared() < core_reach * core_reach:
				core_clock = GameConstants.CORE_HIT_INTERVAL
				world.damage_core(contact_damage * GameConstants.CORE_DAMAGE_FRACTION)

## Where an enemy is heading: a Decoy whose taunt reaches it (S1), else the hero while within aggro range, otherwise the
## objective. Survive mode has no objective, so the hero is the goal there.
func chase_position() -> Vector3:
	# Without a Decoy in the run this is one empty-list check.
	taunt_target = null if world.taunts.posts.is_empty() else taunt_post()
	if taunt_target:
		return taunt_target.origin()
	if not world.core:
		return world.player.position
	var range_limit := GameConstants.CORE_DEAGGRO_RANGE if chasing_hero else GameConstants.CORE_AGGRO_RANGE
	chasing_hero = not ignores_hero and WorldGeometry.planar(world.player.position - position).length_squared() <= range_limit * range_limit
	return world.player.position if chasing_hero else world.core.position

## The nearest Decoy whose taunt reaches this enemy (S1), or null. Cheap by design: a run without a Decoy costs one empty-list
## check, and a run with one asks a list of a few posts. Bosses and their summons, crates and core seekers never answer.
func taunt_post() -> TauntPost:
	if world.taunts.posts.is_empty() or stationary or ignores_hero:
		return null
	if _taunt_kind < 0:
		_taunt_kind = EnemyEcology.taunt_kind(enemy_type)
	if _taunt_kind == EnemyEcology.Taunt.NONE:
		return null
	return world.taunts.post_for(position, _taunt_kind == EnemyEcology.Taunt.RANGED)

func _scale_damage(hit: CombatHit3D) -> float:
	return hit.damage * statuses.exposure_multiplier(hit) * statuses.mark_multiplier(hit)

func _after_hit(hit: CombatHit3D) -> void:
	statuses.apply(hit)
	# Bosses are never staggered (the same rule that keeps `EnemyBrain.interrupt` from cutting their pounces short).
	if hit.stagger_duration > 0.0 and not stationary and not EnemyEcology.is_boss(enemy_type):
		if hit.stagger_cap > 0.0:
			statuses.extend_stagger(hit.stagger_duration, hit.stagger_cap, hit.source_id)
		else:
			statuses.stagger(hit.stagger_duration, hit.source_id)
	slow_marker.visible = statuses.speed_multiplier() < 1.0
	if not hit.impulse.is_zero_approx():
		knockback_velocity = (knockback_velocity + hit.impulse / maxf(mass, .1)).limit_length(GameConstants.KNOCKBACK_MAX_VELOCITY * WorldGeometry.METRES_PER_PIXEL)
		if brain:
			brain.interrupt()
		if charge:
			charge.interrupt()
			warning.visible = false
