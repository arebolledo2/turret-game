class_name SliceActor
extends CharacterBody3D

signal died(actor: SliceActor)
signal damaged(actor: SliceActor, amount: float)

var world: Node
var is_enemy: bool = false
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
		var model := preload("res://assets/models/slice/spider_drone.glb").instantiate()
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
	else:
		var silver := SliceGeometry.material(Color("c6dfde"))
		var navy := SliceGeometry.material(Color("193746"))
		var cyan := SliceGeometry.material(Color("52fff0"), true)
		SliceGeometry.box(visual, Vector3(.43, .48, .3), Vector3(0, .5, 0), silver)
		SliceGeometry.box(visual, Vector3(.37, .27, .32), Vector3(0, .87, 0), navy)
		SliceGeometry.box(visual, Vector3(.29, .08, .035), Vector3(0, .9, -.175), cyan)
		for x: float in [-.14, .14]:
			SliceGeometry.box(visual, Vector3(.15, .2, .25), Vector3(x, .13, 0), navy)
		SliceGeometry.box(visual, Vector3(.16, .13, .47), Vector3(.28, .6, -.16), navy)
		SliceGeometry.sphere(visual, .055, Vector3(.28, .6, -.4), cyan)

func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(world) or not world.is_combat():
		return
	invulnerability = maxf(0.0, invulnerability - delta)
	flash_time = maxf(0.0, flash_time - delta)
	visual.visible = flash_time <= 0.0 or int(flash_time * 25.0) % 2 == 0
	var direction := Vector3.ZERO
	if is_enemy:
		direction = SliceGeometry.planar(world.player.position - position).normalized()
		velocity = direction * speed
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
	move_and_slide()
	position = SliceGeometry.clamp_position(position)
	if direction.length_squared() > 0.001:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), minf(delta * 14.0, 1.0))
	gait += velocity.length() * delta * 10.0
	visual.position.y = sin(gait * 2.0) * 0.025
	for index in range(legs.size()):
		if legs[index]:
			legs[index].rotation.y = sin(gait + float(index % 2) * PI) * 0.24
			legs[index].rotation.z = cos(gait + float(index % 2) * PI) * 0.12
	if is_enemy:
		if SliceGeometry.planar(world.player.position - position).length_squared() < 0.5 * 0.5:
			world.player.take_damage(contact_damage)
	else:
		weapon_clock -= delta
		if weapon_clock <= 0.0:
			var target: SliceActor = world.nearest_enemy(position, GameConstants.PLAYER_TURRET_RANGE * SliceGeometry.METRES_PER_PIXEL)
			if target:
				world.fire(position + Vector3(0, .65, 0), target, PlayerStatsService.get_player_weapon_damage(),
					GameConstants.PLAYER_TURRET_PROJECTILE_SPEED * SliceGeometry.METRES_PER_PIXEL)
				weapon_clock = 1.0 / maxf(PlayerStatsService.get_player_fire_rate(), .01)

func take_damage(amount: float) -> void:
	if dead or invulnerability > 0.0 or amount <= 0.0:
		return
	if not is_enemy:
		amount *= PlayerStatsService.get_damage_reduction()
		invulnerability = GameConstants.PLAYER_INVINCIBILITY_TIME
	health = maxf(0.0, health - amount)
	flash_time = .18
	damaged.emit(self, amount)
	if health <= 0.0:
		dead = true
		if hurtbox:
			hurtbox.set_deferred("collision_layer", 0)
		visible = false
		died.emit(self)
