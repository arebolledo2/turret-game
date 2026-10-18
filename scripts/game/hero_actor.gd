class_name HeroActor
extends CombatActor

## The player's hull: camera-relative steering, the auto-fire weapon, and damage reduction with invulnerability frames.
func _configure_body() -> void:
	collision_layer = WorldGeometry.PLAYER_LAYER
	collision_mask = WorldGeometry.WORLD_LAYER
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.23
	capsule.height = 0.8
	shape.shape = capsule
	shape.position.y = 0.4
	add_child(shape)

func _build_visuals() -> void:
	var model := ClockworkModels.instantiate("hero") if ClockworkModels.available("hero") else preload("res://assets/models/game/player_bot.glb").instantiate()
	visual.add_child(model)
	if ClockworkModels.available("hero"):
		clockwork_motion = ClockworkMotion.new(model, "hero")
	weapon_muzzle = model.find_child("Muzzle", true, false) as Node3D
	marker = WorldGeometry.ring(self, .3, Color("58ece1"))
	marker.position.y = .025

## Accelerates the hero toward the stick/keys input (camera-relative) and returns the input direction.
func _steer(delta: float) -> Vector3:
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

func _move(_delta: float) -> void:
	move_and_slide()
	position = WorldGeometry.clamp_position(position)

func _act(delta: float, _previous_position: Vector3) -> void:
	_tick_player_weapon(delta)

## The hero's auto-fire at the nearest enemy in range.
func _tick_player_weapon(delta: float) -> void:
	weapon_clock -= delta
	if is_instance_valid(world.carried_turret):
		weapon_target = null
		if clockwork_motion:
			clockwork_motion.aim_hero(Vector3.ZERO)
		return
	var weapon_stats := PlayerStatsService.get_weapon_stats(world.run_config.hero).duplicate(true)
	world.item_effects.modify_stats(weapon_stats, 0, "kinetic" in world.run_config.hero.families)
	var weapon_range := float(weapon_stats.range) * WorldGeometry.METRES_PER_PIXEL
	if weapon_clock <= 0.0:
		weapon_target = world.nearest_enemy(position, weapon_range)
	if is_instance_valid(weapon_target) and (weapon_target.dead or not weapon_target.overlaps_attack_range(position, weapon_range)):
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
		var shot := CombatShot3D.from_stats(weapon_stats, world.run_config.hero.damage_type)
		shot.attack_families.assign(world.run_config.hero.families)
		if PlayerStatsService.roll_player_crit():
			shot.critical = true
			shot.damage = PlayerStatsService.calculate_player_crit_damage(shot.damage)
		world.fire_shot(weapon_muzzle.global_position, weapon_target, shot)
		if clockwork_motion:
			clockwork_motion.fire(FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION))
		weapon_clock = 1.0 / maxf(float(weapon_stats.fire_rate), .01)

func _is_immune() -> bool:
	return world.god_mode

func _scale_damage(hit: CombatHit3D) -> float:
	invulnerability = GameConstants.PLAYER_INVINCIBILITY_TIME
	return hit.damage * PlayerStatsService.get_damage_reduction()
