extends Node2D

@export var damage: float = 15.0
@export var fire_rate: float = 2.0
@export var attack_range: float = 250.0
@export var projectile_speed: float = 500.0
@export var rotation_speed: float = 180.0  # degrees per second

var target: Node2D = null
var can_fire: bool = true
var fire_timer: Timer
var projectile_scene: PackedScene

@onready var weapon_sprite: Sprite2D = $WeaponSprite
@onready var range_indicator: Node2D = $RangeIndicator

func _ready() -> void:
	# Initialize from Globals
	damage = Globals.TURRET_DAMAGE
	fire_rate = Globals.TURRET_FIRE_RATE
	attack_range = Globals.TURRET_RANGE
	projectile_speed = Globals.TURRET_PROJECTILE_SPEED
	rotation_speed = Globals.TURRET_ROTATION_SPEED
	
	add_to_group("turrets")
	
	# Load projectile scene
	projectile_scene = preload("res://scenes/projectile.tscn")
	
	# Setup fire rate timer
	fire_timer = Timer.new()
	fire_timer.one_shot = true
	fire_timer.wait_time = 1.0 / fire_rate
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	add_child(fire_timer)
	
	# Setup range indicator
	if range_indicator:
		if range_indicator.has_method("set_radius"):
			range_indicator.set_radius(attack_range)
		range_indicator.modulate.a = 0.0  # Hidden by default
	
	# Spawn animation
	play_spawn_animation()

func _physics_process(delta: float) -> void:
	find_target()
	
	if target and is_instance_valid(target):
		# Rotate the whole turret toward target
		var direction_to_target := global_position.direction_to(target.global_position)
		var target_angle: float = direction_to_target.angle()
		var current_angle: float = rotation
		var angle_diff: float = angle_difference(current_angle, target_angle)
		
		var max_rotation: float = deg_to_rad(rotation_speed) * delta
		var rotation_amount: float = clampf(angle_diff, -max_rotation, max_rotation)
		rotation += rotation_amount
		
		# Check if aimed at target (within tolerance)
		var aim_diff: float = absf(angle_difference(rotation, target_angle))
		if aim_diff < deg_to_rad(20) and can_fire:
			fire()

func find_target() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		target = null
		return
	
	var closest_distance := attack_range
	target = null
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
			target = enemy

func fire() -> void:
	if target == null or projectile_scene == null:
		return
	
	can_fire = false
	fire_timer.start()
	
	# Create projectile
	var projectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position
	projectile.setup(Vector2.RIGHT.rotated(rotation), projectile_speed, damage, false)
	
	# Muzzle flash effect
	flash_muzzle()
	
	Events.turret_fired.emit(self)

func _on_fire_timer_timeout() -> void:
	can_fire = true

func flash_muzzle() -> void:
	if weapon_sprite:
		weapon_sprite.modulate = Color.WHITE
		var tween = create_tween()
		tween.tween_property(weapon_sprite, "modulate", Color(0.3, 0.8, 0.3, 1), 0.1)

func play_spawn_animation() -> void:
	# Scale up from zero
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2.ONE, 0.3)
	
	# Particle burst effect (if we have particles)
	# spawn_particles()

func show_range() -> void:
	if range_indicator:
		range_indicator.modulate.a = 0.3

func hide_range() -> void:
	if range_indicator:
		range_indicator.modulate.a = 0.0
