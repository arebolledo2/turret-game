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

const FLASH_DURATION: float = .18
const ENEMY_FLASH_COLOR := Color(1.0, .92, .8)
const PLAYER_FLASH_COLOR := Color(1.0, .28, .22)
var weapon_clock: float = 0.0

func _ready() -> void:
	collision_layer = 0 if is_enemy else WorldGeometry.PLAYER_LAYER
	collision_mask = WorldGeometry.WORLD_LAYER
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
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
		var model: Node3D
		if enemy_type == "charger":
			model = preload("res://assets/models/game/charger_drone.glb").instantiate()
			charge = ChargeController3D.new()
			charge.configure(EnemyRegistry.TYPES["charger"]["behavior_params"])
		else:
			model = preload("res://assets/models/game/spider_drone.glb").instantiate()
		EnemyVariants.apply_tint(model, enemy_type)
		visual.add_child(model)
		visual.scale = Vector3.ONE * body_scale
		for side in ["L", "R"]:
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
		marker = WorldGeometry.ring(self, .36 * body_scale, Color("f5a447") if charge else Color("9c545e"))
		marker.position.y = .025
		slow_marker = WorldGeometry.ring(self, .43 * body_scale, Color("55dcff"))
		slow_marker.position.y = .04
		slow_marker.visible = false
		if charge:
			_build_warning()
	else:
		var model := preload("res://assets/models/game/player_bot.glb").instantiate()
		visual.add_child(model)
		weapon_muzzle = model.find_child("Muzzle", true, false) as Node3D
		marker = WorldGeometry.ring(self, .3, Color("58ece1"))
		marker.position.y = .025

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
	var direction := Vector3.ZERO
	if is_enemy:
		statuses.advance(delta)
		slow_marker.visible = statuses.speed_multiplier() < 1.0
		var effective_speed := speed * statuses.speed_multiplier()
		var movement := WorldGeometry.planar(world.player.position - position).normalized() * effective_speed
		if charge:
			var previous_phase := charge.phase
			movement = charge.advance(delta, position, world.player.position, effective_speed)
			if charge.phase == ChargeController3D.Phase.WINDUP and previous_phase != charge.phase:
				world.audio.play_cue("warning", position)
			warning.visible = charge.phase in [ChargeController3D.Phase.WINDUP, ChargeController3D.Phase.DASH]
			if warning.visible:
				warning.global_position = charge.origin
				warning.rotation.y = atan2(-charge.heading.x, -charge.heading.z)
				visual.rotation.y = warning.rotation.y
		if not charge or charge.phase in [ChargeController3D.Phase.APPROACH, ChargeController3D.Phase.RECOVER]:
			movement += world.crowd.separation(self)
		direction = movement.normalized()
		velocity = movement + knockback_velocity
		knockback_velocity *= exp(-GameConstants.KNOCKBACK_DECAY_RATE * delta)
	else:
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var stick := Input.get_vector("gamepad_left", "gamepad_right", "gamepad_up", "gamepad_down")
		if stick.length() > GameConstants.PLAYER_MOVEMENT_DEADZONE:
			input = stick
		var camera: Camera3D = world.camera
		direction = (WorldGeometry.planar(camera.global_basis.x).normalized() * input.x +
			WorldGeometry.planar(camera.global_basis.z).normalized() * input.y).limit_length()
		var carrying: bool = is_instance_valid(world.carried_turret)
		var desired_speed := PlayerStatsService.get_player_speed() * WorldGeometry.METRES_PER_PIXEL
		if carrying:
			desired_speed *= GameConstants.TURRET_CARRY_SPEED_PENALTY
		var acceleration := GameConstants.PLAYER_ACCELERATION if direction.length_squared() > 0 else GameConstants.PLAYER_DECELERATION
		velocity = velocity.move_toward(direction * desired_speed, acceleration * WorldGeometry.METRES_PER_PIXEL * delta)
	var previous_position := position
	if is_enemy:
		# Enemies only collide with the arena bounds, which clamp_position enforces, so skip the physics-server sweep.
		position += velocity * delta
	else:
		move_and_slide()
	position = WorldGeometry.clamp_position(position)
	if charge and charge.phase == ChargeController3D.Phase.DASH and velocity.length_squared() > .000001 and position.distance_squared_to(previous_position) < .000001:
		charge.interrupt()
		warning.visible = false
	if direction.length_squared() > 0.001:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), minf(delta * 14.0, 1.0))
	gait += velocity.length() * delta * 10.0
	visual.position.y = 0.0 if reduced_motion else sin(gait * 2.0) * 0.025
	# Leg posing is cosmetic: pose each enemy every other physics tick, staggered by instance.
	var pose_legs := not is_enemy or (Engine.get_physics_frames() + get_instance_id()) % 2 == 0
	for index in range(legs.size() if pose_legs else 0):
		if legs[index]:
			legs[index].rotation.y = 0.0 if reduced_motion else sin(gait + float(index % 2) * PI) * 0.24
			legs[index].rotation.z = 0.0 if reduced_motion else cos(gait + float(index % 2) * PI) * 0.12
	if is_enemy:
		var closest := Geometry3D.get_closest_point_to_segment(world.player.position, previous_position, position)
		if WorldGeometry.planar(world.player.position - closest).length_squared() < .5 * .5 * body_scale * body_scale:
			world.combat.apply_hit(world.player, CombatHit3D.new(contact_damage, position))
	else:
		weapon_clock -= delta
		if weapon_clock <= 0.0:
			var target: CombatActor = world.nearest_enemy(position, GameConstants.PLAYER_TURRET_RANGE * WorldGeometry.METRES_PER_PIXEL)
			if target:
				var shot := CombatShot3D.from_stats({"damage": PlayerStatsService.get_player_weapon_damage(),
					"projectile_speed": GameConstants.PLAYER_TURRET_PROJECTILE_SPEED})
				if PlayerStatsService.roll_player_crit():
					shot.damage = PlayerStatsService.calculate_player_crit_damage(shot.damage)
				world.fire_shot(weapon_muzzle.global_position, target, shot)
				weapon_clock = 1.0 / maxf(PlayerStatsService.get_player_fire_rate(), .01)

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
