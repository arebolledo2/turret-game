class_name SliceActor
extends CharacterBody3D

signal died(actor: SliceActor)
signal damaged(actor: SliceActor, amount: float)

var world: Node
var is_enemy: bool = false
var enemy_type: String = "basic"
var mass: float = 1.0
var scrap_value: int = 1
var knockback_velocity: Vector3 = Vector3.ZERO
var charge: ChargeController3D
var warning: Node3D
var marker: MeshInstance3D
var weapon_muzzle: Node3D
var health: float = 25.0
var max_health: float = 25.0
var speed: float = 2.5
var contact_damage: float = 8.0
var dead: bool = false
var invulnerability: float = 0.0
var visual: Node3D
var hurtbox: Area3D
var legs: Array[Node3D] = []
var gait: float = 0.0
var flash_time: float = 0.0
var weapon_clock: float = 0.0

func _ready() -> void:
	collision_layer = 0 if is_enemy else SliceGeometry.PLAYER_LAYER
	collision_mask = SliceGeometry.WORLD_LAYER
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
			model = preload("res://assets/models/slice/charger_drone.glb").instantiate()
			charge = ChargeController3D.new()
			charge.configure(EnemyRegistry.TYPES["charger"]["behavior_params"])
		else:
			model = preload("res://assets/models/slice/spider_drone.glb").instantiate()
		visual.add_child(model)
		for side in ["L", "R"]:
			for index in range(3):
				legs.append(model.find_child("Leg_%s_%d" % [side, index], true, false) as Node3D)
		hurtbox = Area3D.new()
		hurtbox.collision_layer = SliceGeometry.ENEMY_HURTBOX_LAYER
		hurtbox.collision_mask = 0
		hurtbox.monitoring = false
		var hit_shape := CollisionShape3D.new()
		var hit_capsule := CapsuleShape3D.new()
		hit_capsule.radius = 0.36
		hit_capsule.height = 1.3
		hit_shape.shape = hit_capsule
		hit_shape.position.y = 0.6
		hurtbox.add_child(hit_shape)
		add_child(hurtbox)
		marker = SliceGeometry.ring(self, .36, Color("f5a447") if charge else Color("9c545e"))
		marker.position.y = .025
		if charge:
			_build_warning()
	else:
		var model := preload("res://assets/models/slice/player_bot.glb").instantiate()
		visual.add_child(model)
		weapon_muzzle = model.find_child("Muzzle", true, false) as Node3D
		marker = SliceGeometry.ring(self, .3, Color("58ece1"))
		marker.position.y = .025

func _build_warning() -> void:
	warning = Node3D.new()
	warning.name = "ChargeWarning"
	add_child(warning)
	warning.top_level = true
	var length := speed * charge.speed_multiplier * charge.dash_duration
	var mat := SliceGeometry.material(Color("ff963d"), true)
	# The two rails show the swept contact width; the arrow shows the locked path.
	for side: float in [-.5, .5]:
		SliceGeometry.box(warning, Vector3(.035, .012, length), Vector3(side, .035, -length / 2.0), mat)
	for side: float in [-1.0, 1.0]:
		var arrow := SliceGeometry.box(warning, Vector3(.045, .014, .4), Vector3(side * .13, .037, -length + .13), mat)
		arrow.rotation.y = side * -.75
	warning.visible = false

func clear_transients() -> void:
	knockback_velocity = Vector3.ZERO
	velocity = Vector3.ZERO
	flash_time = 0.0
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
	visual.visible = flash_time <= 0.0 or int(flash_time * 25.0) % 2 == 0
	var direction := Vector3.ZERO
	if is_enemy:
		var movement := SliceGeometry.planar(world.player.position - position).normalized() * speed
		if charge:
			movement = charge.advance(delta, position, world.player.position, speed)
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
		direction = (SliceGeometry.planar(camera.global_basis.x).normalized() * input.x +
			SliceGeometry.planar(camera.global_basis.z).normalized() * input.y).limit_length()
		var carrying: bool = is_instance_valid(world.carried_turret)
		var desired_speed := PlayerStatsService.get_player_speed() * SliceGeometry.METRES_PER_PIXEL
		if carrying:
			desired_speed *= GameConstants.TURRET_CARRY_SPEED_PENALTY
		var acceleration := GameConstants.PLAYER_ACCELERATION if direction.length_squared() > 0 else GameConstants.PLAYER_DECELERATION
		velocity = velocity.move_toward(direction * desired_speed, acceleration * SliceGeometry.METRES_PER_PIXEL * delta)
	var previous_position := position
	move_and_slide()
	position = SliceGeometry.clamp_position(position)
	if charge and charge.phase == ChargeController3D.Phase.DASH and velocity.length_squared() > .000001 and position.distance_squared_to(previous_position) < .000001:
		charge.interrupt()
		warning.visible = false
	if direction.length_squared() > 0.001:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), minf(delta * 14.0, 1.0))
	gait += velocity.length() * delta * 10.0
	visual.position.y = sin(gait * 2.0) * 0.025
	for index in range(legs.size()):
		if legs[index]:
			legs[index].rotation.y = sin(gait + float(index % 2) * PI) * 0.24
			legs[index].rotation.z = cos(gait + float(index % 2) * PI) * 0.12
	if is_enemy:
		var closest := Geometry3D.get_closest_point_to_segment(world.player.position, previous_position, position)
		if SliceGeometry.planar(world.player.position - closest).length_squared() < .5 * .5:
			world.combat.apply_hit(world.player, CombatHit3D.new(contact_damage, position))
	else:
		weapon_clock -= delta
		if weapon_clock <= 0.0:
			var target: SliceActor = world.nearest_enemy(position, GameConstants.PLAYER_TURRET_RANGE * SliceGeometry.METRES_PER_PIXEL)
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
	var amount := hit.damage
	if not is_enemy:
		amount *= PlayerStatsService.get_damage_reduction()
		invulnerability = GameConstants.PLAYER_INVINCIBILITY_TIME
	var applied := minf(health, amount)
	health = maxf(0.0, health - amount)
	if is_enemy and not hit.impulse.is_zero_approx():
		knockback_velocity = (knockback_velocity + hit.impulse / maxf(mass, .1)).limit_length(GameConstants.KNOCKBACK_MAX_VELOCITY * SliceGeometry.METRES_PER_PIXEL)
		if charge:
			charge.interrupt()
			warning.visible = false
	flash_time = .18
	damaged.emit(self, amount)
	if health <= 0.0:
		dead = true
		if hurtbox:
			hurtbox.set_deferred("collision_layer", 0)
		visible = false
		if warning:
			warning.visible = false
		died.emit(self)
	return applied
