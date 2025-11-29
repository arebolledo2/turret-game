extends CharacterBody2D

# Stats from Globals (can be overridden in editor)
@export var max_health: float = 100.0
@export var speed: float = 300.0
@export var pickup_radius: float = 50.0
@export var invincibility_time: float = 0.5
@export var weapon_damage: float = 5.0
@export var weapon_fire_rate: float = 3.0
@export var weapon_range: float = 200.0
@export var projectile_speed: float = 600.0

var current_health: float
var closest_enemy: Node2D = null
var is_invincible: bool = false
var is_dead: bool = false
var can_fire: bool = true
var fire_timer: Timer
var invincibility_timer: Timer
var animation_timer: Timer
var current_frame: int = 0
var is_moving: bool = false

# Turret pickup system
var carried_turret: Node2D = null
var nearby_turret: Node2D = null
var pickup_action_just_pressed: bool = false

# Projectile scene (will be set up)
var projectile_scene: PackedScene

@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_timer: Timer = $AnimationTimer

func _ready() -> void:
	# Initialize from Globals if available
	if Globals:
		max_health = Globals.PLAYER_MAX_HEALTH
		speed = Globals.PLAYER_SPEED
		pickup_radius = Globals.PLAYER_PICKUP_RADIUS
		invincibility_time = Globals.PLAYER_INVINCIBILITY_TIME
		weapon_damage = Globals.PLAYER_WEAPON_DAMAGE
		weapon_fire_rate = Globals.PLAYER_WEAPON_FIRE_RATE
		weapon_range = Globals.PLAYER_WEAPON_RANGE
		projectile_speed = Globals.PLAYER_PROJECTILE_SPEED
	
	current_health = max_health
	add_to_group("player")
	
	# Load projectile scene
	projectile_scene = preload("res://scenes/projectile.tscn")
	
	# Setup fire rate timer
	fire_timer = Timer.new()
	fire_timer.one_shot = true
	fire_timer.wait_time = 1.0 / weapon_fire_rate
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	add_child(fire_timer)
	
	# Setup invincibility timer
	invincibility_timer = Timer.new()
	invincibility_timer.one_shot = true
	invincibility_timer.timeout.connect(_on_invincibility_timeout)
	add_child(invincibility_timer)
	
	# Setup animation timer
	anim_timer.timeout.connect(_on_animation_timer_timeout)

func _physics_process(delta: float) -> void:
	# Don't process if game hasn't started
	if Globals == null or not Globals.is_game_active:
		return
	
	handle_movement(delta)
	clamp_to_arena()
	move_and_slide()

	# Turret pickup/placement system
	handle_turret_interactions()
	
	# Turret range toggle (Tab / Y button)
	if Input.is_action_just_pressed("toggle_range"):
		Globals.show_turret_ranges = not Globals.show_turret_ranges
		Events.turret_range_toggled.emit(Globals.show_turret_ranges)

	# Auto-aim and fire at closest enemy (only if enabled)
	if Globals.player_auto_attack_enabled:
		find_closest_enemy()
		if closest_enemy and can_fire:
			fire_at_enemy()
	
	# Handle invincibility visual
	if is_invincible:
		sprite.modulate.a = 0.5 if fmod(Time.get_ticks_msec(), 100) < 50 else 1.0
	else:
		sprite.modulate.a = 1.0

func handle_movement(_delta: float) -> void:
	var input_vector := Vector2.ZERO
	
	# Keyboard input
	input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vector.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	
	# Gamepad input (left stick)
	var gamepad_input := Input.get_vector("gamepad_left", "gamepad_right", "gamepad_up", "gamepad_down")
	if gamepad_input.length() > 0.1:
		input_vector = gamepad_input
	
	# Normalize and apply speed (instant response, no acceleration)
	input_vector = input_vector.normalized()

	# Apply speed penalty if carrying turret
	var effective_speed := speed
	if carried_turret and is_instance_valid(carried_turret):
		effective_speed *= Globals.TURRET_CARRY_SPEED_PENALTY

	velocity = input_vector * effective_speed
	
	# Handle animation
	if input_vector.length() > 0.1:
		if not is_moving:
			is_moving = true
			anim_timer.start()
		# Flip sprite based on horizontal direction
		if input_vector.x != 0:
			sprite.flip_h = input_vector.x < 0
	else:
		is_moving = false
		anim_timer.stop()
		sprite.frame = 0  # Reset to idle frame

func handle_turret_interactions() -> void:
	# Detect input (check for just_pressed to toggle)
	if Input.is_action_just_pressed("pickup_turret"):
		pickup_action_just_pressed = true

	# If carrying a turret, update its position
	if carried_turret and is_instance_valid(carried_turret):
		update_carried_turret_position()

		# Check for placement input
		if pickup_action_just_pressed:
			place_turret()
			pickup_action_just_pressed = false
	else:
		# Not carrying - look for nearby turrets
		find_nearby_turret()
		update_nearby_turret_indicator()

		# Check for pickup input
		if pickup_action_just_pressed and nearby_turret and is_instance_valid(nearby_turret):
			pickup_turret(nearby_turret)
			pickup_action_just_pressed = false

func find_nearby_turret() -> void:
	var turrets = get_tree().get_nodes_in_group("turrets")
	var closest_distance: float = Globals.TURRET_PICKUP_RANGE
	var previous_nearby := nearby_turret
	nearby_turret = null

	for turret in turrets:
		if not is_instance_valid(turret):
			continue
		var distance := global_position.distance_to(turret.global_position)
		if distance < closest_distance:
			closest_distance = distance
			nearby_turret = turret

	# Manage indicator state changes
	if previous_nearby != nearby_turret:
		if previous_nearby and is_instance_valid(previous_nearby):
			if previous_nearby.has_method("hide_pickup_indicator"):
				previous_nearby.hide_pickup_indicator()
		if nearby_turret and is_instance_valid(nearby_turret):
			if nearby_turret.has_method("show_pickup_indicator"):
				nearby_turret.show_pickup_indicator()

func update_nearby_turret_indicator() -> void:
	pass  # Handled by find_nearby_turret()

func pickup_turret(turret: Node2D) -> void:
	# Quick swap: drop current turret first
	if carried_turret and is_instance_valid(carried_turret):
		place_turret()

	carried_turret = turret

	if turret.has_method("hide_pickup_indicator"):
		turret.hide_pickup_indicator()

	Events.turret_picked_up.emit(turret)

func place_turret() -> void:
	if not carried_turret or not is_instance_valid(carried_turret):
		carried_turret = null
		return

	var placement_pos := carried_turret.global_position
	Events.turret_placed.emit(carried_turret, placement_pos)

	carried_turret = null

func update_carried_turret_position() -> void:
	if not carried_turret or not is_instance_valid(carried_turret):
		carried_turret = null
		return

	carried_turret.global_position = global_position + Globals.TURRET_CARRY_OFFSET

func drop_carried_turret() -> void:
	if carried_turret and is_instance_valid(carried_turret):
		Events.turret_dropped.emit(carried_turret, carried_turret.global_position)
		carried_turret = null

func clamp_to_arena() -> void:
	# Keep player within arena bounds
	var half_width := Globals.ARENA_WIDTH / 2.0
	var half_height := Globals.ARENA_HEIGHT / 2.0
	var margin := 20.0  # Player collision radius
	
	global_position.x = clamp(global_position.x, -half_width + margin, half_width - margin)
	global_position.y = clamp(global_position.y, -half_height + margin, half_height - margin)

func find_closest_enemy() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		closest_enemy = null
		return
	
	var closest_distance := weapon_range
	closest_enemy = null
	
	for enemy in enemies:
		var distance := global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy

func fire_at_enemy() -> void:
	if closest_enemy == null or projectile_scene == null:
		return
	
	can_fire = false
	fire_timer.start()
	
	# Create projectile
	var projectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position
	var dir = global_position.direction_to(closest_enemy.global_position)
	projectile.setup(dir, projectile_speed, weapon_damage, true)
	
	# Rotate weapon pivot to face enemy
	weapon_pivot.look_at(closest_enemy.global_position)

func _on_fire_timer_timeout() -> void:
	can_fire = true

func take_damage(amount: float) -> void:
	if is_invincible or is_dead:
		return
	
	current_health -= amount
	is_invincible = true
	invincibility_timer.wait_time = invincibility_time
	invincibility_timer.start()
	
	# Visual feedback - flash red
	sprite.modulate = Color(1, 0.3, 0.3, 1)
	
	# Screen shake (if camera exists)
	var camera = get_node_or_null("Camera2D")
	if camera and camera.has_method("shake"):
		camera.shake(0.2, 5)
	
	# Emit signal
	Events.player_damaged.emit(current_health, max_health)
	
	if current_health <= 0:
		die()

func _on_invincibility_timeout() -> void:
	is_invincible = false
	sprite.modulate = Color.WHITE  # Reset to normal color

func _on_animation_timer_timeout() -> void:
	# Cycle through walk animation frames (0-15 for 4x4 grid)
	sprite.frame = (sprite.frame + 1) % 16

func die() -> void:
	if is_dead:
		return
	is_dead = true

	# Drop carried turret before death
	drop_carried_turret()

	Events.player_died.emit()
	# Don't queue_free - let GameManager handle game over

func heal(amount: float) -> void:
	current_health = min(current_health + amount, max_health)
	Events.player_damaged.emit(current_health, max_health)

func reset_health() -> void:
	current_health = max_health
	Events.player_damaged.emit(current_health, max_health)

func get_health_percent() -> float:
	return current_health / max_health

