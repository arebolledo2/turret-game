class_name CombatActor
extends CharacterBody3D

var world: ArenaWorld
var is_enemy: bool = false
var enemy_type: String = "basic"
var mass: float = 1.0
var scrap_value: int = 1
var knockback_velocity: Vector3 = Vector3.ZERO
var charge: ChargeController3D
var warning: Node3D
var marker: MeshInstance3D
var weapon_muzzle: Node3D
var statuses := StatusEffects3D.new()
var slow_marker: MeshInstance3D
var health: float = 25.0
var max_health: float = 25.0
var speed: float = 2.5
var contact_damage: float = 8.0
var body_scale: float = 1.0
var explosion_radius: float = 0.0
var explosion_damage: float = 0.0
var dead: bool = false
var invulnerability: float = 0.0
var visual: Node3D
var hurtbox: Area3D
var legs: Array[Node3D] = []
var gait: float = 0.0
var flash_time: float = 0.0
var hit_flash: HitFlash
## Core mode: true while this enemy is chasing the hero instead of the core (hysteresis between the aggro ranges).
var chasing_hero: bool = false
## Core mode: this enemy never switches to the hero.
var ignores_hero: bool = false
var core_clock: float = 0.0
## Tech drops: never moves, never attacks. Built from a crate model instead of a spider.
var stationary: bool = false
## Difficulty rules: tougher, faster, gold-tinted. A seeker (`ignores_hero`) gets a red marker.
var elite: bool = false

const FLASH_DURATION: float = .18
const ENEMY_FLASH_COLOR := Color(1.0, .92, .8)
const PLAYER_FLASH_COLOR := Color(1.0, .28, .22)
var weapon_clock: float = 0.0
var weapon_target: CombatActor
var clockwork_motion: ClockworkMotion

func _ready() -> void:
	collision_layer = 0 if is_enemy else WorldGeometry.PLAYER_LAYER
	collision_mask = 0 if is_enemy else WorldGeometry.WORLD_LAYER
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	# Enemies never sweep through the physics server (the hurtbox Area3D handles hits), so they skip the body shape.
	if not is_enemy:
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.23
		capsule.height = 0.8
		shape.shape = capsule
		shape.position.y = 0.4
		add_child(shape)
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	if is_enemy:
		var model := _build_enemy_model()
		if ClockworkModels.available(enemy_type) and not stationary:
			clockwork_motion = ClockworkMotion.new(model, enemy_type)
		else:
			EnemyVariants.apply_tint(model, enemy_type)
		if elite:
			EnemyVariants.tint_model(model, enemy_type + "_elite", Color(1.0, .85, .45), .7)
		visual.add_child(model)
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
		hit_capsule.radius = 0.36 * body_scale
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
	else:
		var model := ClockworkModels.instantiate("hero") if ClockworkModels.available("hero") else preload("res://assets/models/game/player_bot.glb").instantiate()
		visual.add_child(model)
		if ClockworkModels.available("hero"):
			clockwork_motion = ClockworkMotion.new(model, "hero")
		weapon_muzzle = model.find_child("Muzzle", true, false) as Node3D
		marker = WorldGeometry.ring(self, .3, Color("58ece1"))
		marker.position.y = .025

	SettingsService.ground_markers_changed.connect(_refresh_ground_marker)
	_refresh_ground_marker()

func _refresh_ground_marker() -> void:
	if marker:
		var mode := SettingsService.ground_markers
		marker.visible = mode == SettingsService.GroundMarkers.ALL or (mode == SettingsService.GroundMarkers.CONTEXTUAL and is_enemy and (elite or ignores_hero or charge != null))

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

## Called after damage lands and health has changed; overridden by actors that show health in the world.
func _on_health_changed() -> void:
	pass

func _build_warning() -> void:
	warning = Node3D.new()
	warning.name = "ChargeWarning"
	add_child(warning)
	warning.top_level = true
	var length := speed * charge.speed_multiplier * charge.dash_duration
	var mat := WorldGeometry.material(Color("ff963d"), true)
	# The two rails show the swept contact width; the arrow shows the locked path.
	for side: float in [-.5, .5]:
		WorldGeometry.box(warning, Vector3(.035, .012, length), Vector3(side, .035, -length / 2.0), mat)
	for side: float in [-1.0, 1.0]:
		var arrow := WorldGeometry.box(warning, Vector3(.045, .014, .4), Vector3(side * .13, .037, -length + .13), mat)
		arrow.rotation.y = side * -.75
	warning.visible = false

func clear_transients() -> void:
	statuses.clear()
	if slow_marker:
		slow_marker.visible = false
	knockback_velocity = Vector3.ZERO
	velocity = Vector3.ZERO
	flash_time = 0.0
	if hit_flash:
		hit_flash.clear()
	visual.visible = true
	if warning:
		warning.visible = false
	if charge:
		charge.interrupt()

func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(world) or not world.is_combat():
		return
	invulnerability = maxf(0.0, invulnerability - delta)
	flash_time = maxf(0.0, flash_time - delta)
	var reduced_motion := FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION)
	if hit_flash:
		hit_flash.update(flash_time / FLASH_DURATION, reduced_motion)
	if stationary:
		return
	var direction := _steer_enemy(delta) if is_enemy else _steer_player(delta)
	var previous_position := position
	if is_enemy:
		# Enemies only collide with the arena bounds, which clamp_position enforces, so skip the physics-server sweep.
		position = WorldGeometry.clamp_position(position + velocity * delta)
	else:
		move_and_slide()
		position = WorldGeometry.clamp_position(position)
	if charge and charge.phase == ChargeController3D.Phase.DASH and velocity.length_squared() > .000001 and position.distance_squared_to(previous_position) < .000001:
		charge.interrupt()
		warning.visible = false
	_animate(delta, direction, reduced_motion)
	if is_enemy:
		_apply_contact_damage(delta, previous_position)
	else:
		_tick_player_weapon(delta)

## Sets the enemy's velocity for this tick (chase, charge windup/dash, separation, knockback) and returns its heading.
func _steer_enemy(delta: float) -> Vector3:
	var speed_factor := 1.0
	if not statuses.effects.is_empty():
		statuses.advance(delta)
		speed_factor = statuses.speed_multiplier()
	if world.terrain:
		speed_factor = maxf(1.0 - GameConstants.ZONE_MUD_MAX_SLOW, speed_factor * world.terrain.mud_factor_at(position))
	var slowed := speed_factor < 1.0
	if slow_marker.visible != slowed:
		slow_marker.visible = slowed
	var effective_speed := speed * speed_factor
	var goal: Vector3 = world.player.position
	var at_core := false
	if world.core:
		goal = chase_position()
		var stop := world.core.radius + .4 * body_scale
		at_core = not chasing_hero and WorldGeometry.planar(goal - position).length_squared() < stop * stop
	var movement := WorldGeometry.planar(goal - position).normalized() * effective_speed
	if charge:
		var previous_phase := charge.phase
		movement = charge.advance(delta, position, goal, effective_speed)
		if charge.phase == ChargeController3D.Phase.WINDUP and previous_phase != charge.phase:
			world.audio.play_cue("warning", position)
		warning.visible = charge.phase in [ChargeController3D.Phase.WINDUP, ChargeController3D.Phase.DASH]
		if warning.visible:
			warning.global_position = charge.origin
			warning.rotation.y = atan2(-charge.heading.x, -charge.heading.z)
			visual.rotation.y = warning.rotation.y
	if not charge or charge.phase in [ChargeController3D.Phase.APPROACH, ChargeController3D.Phase.RECOVER]:
		if at_core:
			movement = Vector3.ZERO
		movement += world.crowd.separation(self)
	velocity = movement + knockback_velocity
	knockback_velocity *= exp(-GameConstants.KNOCKBACK_DECAY_RATE * delta)
	return movement.normalized()

## Accelerates the hero toward the stick/keys input (camera-relative) and returns the input direction.
func _steer_player(delta: float) -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var stick := Input.get_vector("gamepad_left", "gamepad_right", "gamepad_up", "gamepad_down")
	if stick.length() > GameConstants.PLAYER_MOVEMENT_DEADZONE:
		input = stick
	var camera: Camera3D = world.camera
	var direction := (WorldGeometry.planar(camera.global_basis.x).normalized() * input.x +
		WorldGeometry.planar(camera.global_basis.z).normalized() * input.y).limit_length()
	var carrying: bool = is_instance_valid(world.carried_turret)
	var desired_speed := PlayerStatsService.get_player_speed() * WorldGeometry.METRES_PER_PIXEL
	if carrying:
		desired_speed *= GameConstants.TURRET_CARRY_SPEED_PENALTY * ModifierService.apply_modifiers_to_stat(1.0, "carry_speed")
	if world.terrain:
		desired_speed *= world.terrain.mud_factor_at(position)
	velocity = steer_velocity(velocity, direction, desired_speed, delta)
	return direction

## One step of hero movement: accelerate toward `direction * desired_speed`, or brake when there is no input. Turning or
## reversing accelerates harder than speeding up, so direction changes feel precise: the more the input points away
## from the current velocity, the bigger the boost (1x when already heading that way, and none from a standstill).
static func steer_velocity(current: Vector3, direction: Vector3, desired_speed: float, delta: float) -> Vector3:
	var acceleration := GameConstants.PLAYER_DECELERATION
	if direction.length_squared() > 0.0:
		acceleration = GameConstants.PLAYER_ACCELERATION
		if current.length_squared() > 0.0001:
			var opposition := (1.0 - current.normalized().dot(direction.normalized())) * .5 # 0 aligned .. 1 reversing
			acceleration *= lerpf(1.0, GameConstants.PLAYER_TURN_BOOST, opposition)
	return current.move_toward(direction * desired_speed, acceleration * WorldGeometry.METRES_PER_PIXEL * delta)

## Turns toward the heading and bobs/poses the legs. Purely cosmetic.
func _animate(delta: float, direction: Vector3, reduced_motion: bool) -> void:
	if direction.length_squared() > 0.001:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), minf(delta * 14.0, 1.0))
	if clockwork_motion:
		visual.position.y = 0.0
		clockwork_motion.tick(delta, velocity.length(), reduced_motion, not is_enemy and is_instance_valid(world.carried_turret))
		return
	gait += velocity.length() * delta * 10.0
	if not reduced_motion or visual.position.y != 0.0:
		visual.position.y = 0.0 if reduced_motion else sin(gait * 2.0) * 0.025
	# Leg posing is cosmetic: pose each enemy every other physics tick, staggered by instance.
	var pose_legs := not is_enemy or (Engine.get_physics_frames() + get_instance_id()) % 2 == 0
	for index in range(legs.size() if pose_legs else 0):
		var leg: Node3D = legs[index]
		if leg:
			var phase := gait + float(index % 2) * PI
			leg.rotation = Vector3(leg.rotation.x, 0.0, 0.0) if reduced_motion else Vector3(leg.rotation.x, sin(phase) * 0.24, cos(phase) * 0.12)

## Enemy touch damage to the hero (swept along this tick's step) and, in core mode, to the core on a timer.
func _apply_contact_damage(delta: float, previous_position: Vector3) -> void:
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
	if world.core:
		core_clock -= delta
		if core_clock <= 0.0:
			var core_reach := world.core.radius + reach
			if WorldGeometry.planar(world.core.position - position).length_squared() < core_reach * core_reach:
				core_clock = GameConstants.CORE_HIT_INTERVAL
				world.damage_core(contact_damage * GameConstants.CORE_DAMAGE_FRACTION)

## The hero's auto-fire at the nearest enemy in range.
func _tick_player_weapon(delta: float) -> void:
	weapon_clock -= delta
	if is_instance_valid(world.carried_turret):
		weapon_target = null
		if clockwork_motion:
			clockwork_motion.aim_hero(Vector3.ZERO)
		return
	var weapon_range := GameConstants.PLAYER_TURRET_RANGE * WorldGeometry.METRES_PER_PIXEL
	if weapon_clock <= 0.0:
		weapon_target = world.nearest_enemy(position, weapon_range)
	if is_instance_valid(weapon_target) and (weapon_target.dead or WorldGeometry.planar(weapon_target.position - position).length() > weapon_range):
		weapon_target = null
	if clockwork_motion:
		var heading := WorldGeometry.planar(weapon_target.position - position) if is_instance_valid(weapon_target) else Vector3.ZERO
		if heading.length_squared() > .0001:
			var yaw := atan2(-heading.x, -heading.z)
			var twist := wrapf(yaw - visual.global_rotation.y, -PI, PI)
			if absf(twist) > PI / 3.0:
				visual.global_rotation.y = yaw - clampf(twist, -PI / 3.0, PI / 3.0)
		clockwork_motion.aim_hero(heading)
	if weapon_clock <= 0.0 and is_instance_valid(weapon_target):
		var shot := CombatShot3D.from_stats({"damage": PlayerStatsService.get_player_weapon_damage(),
			"projectile_speed": GameConstants.PLAYER_TURRET_PROJECTILE_SPEED})
		if PlayerStatsService.roll_player_crit():
			shot.damage = PlayerStatsService.calculate_player_crit_damage(shot.damage)
		world.fire_shot(weapon_muzzle.global_position, weapon_target, shot)
		if clockwork_motion:
			clockwork_motion.fire(FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION))
		weapon_clock = 1.0 / maxf(PlayerStatsService.get_player_fire_rate(), .01)

## Where an enemy is heading when the run has an objective: the hero while within aggro range, otherwise the objective.
## Survive mode has no objective and never calls this (the hero is always the goal).
func chase_position() -> Vector3:
	var range_limit := GameConstants.CORE_DEAGGRO_RANGE if chasing_hero else GameConstants.CORE_AGGRO_RANGE
	chasing_hero = not ignores_hero and WorldGeometry.planar(world.player.position - position).length_squared() <= range_limit * range_limit
	return world.player.position if chasing_hero else world.core.position

func take_damage(amount: float) -> void:
	world.combat.apply_hit(self, CombatHit3D.new(amount, position))

func receive_hit(hit: CombatHit3D) -> float:
	if dead or invulnerability > 0.0 or hit.damage <= 0.0 or not world.is_combat():
		return 0.0
	if not is_enemy and world.god_mode:
		return 0.0
	var amount := hit.damage
	if not is_enemy:
		amount *= PlayerStatsService.get_damage_reduction()
		invulnerability = GameConstants.PLAYER_INVINCIBILITY_TIME
	var applied := minf(health, amount)
	health = maxf(0.0, health - amount)
	_on_health_changed()
	if is_enemy:
		statuses.apply(hit)
		slow_marker.visible = statuses.speed_multiplier() < 1.0
	if is_enemy and not hit.impulse.is_zero_approx():
		knockback_velocity = (knockback_velocity + hit.impulse / maxf(mass, .1)).limit_length(GameConstants.KNOCKBACK_MAX_VELOCITY * WorldGeometry.METRES_PER_PIXEL)
		if charge:
			charge.interrupt()
			warning.visible = false
	flash_time = FLASH_DURATION
	if not hit_flash:
		hit_flash = HitFlash.new(visual, ENEMY_FLASH_COLOR if is_enemy else PLAYER_FLASH_COLOR)
	if health <= 0.0:
		dead = true
		statuses.clear()
		if slow_marker:
			slow_marker.visible = false
		if hurtbox:
			hurtbox.set_deferred("collision_layer", 0)
		if hit_flash:
			hit_flash.clear()
		visible = false
		if warning:
			warning.visible = false
	return applied
