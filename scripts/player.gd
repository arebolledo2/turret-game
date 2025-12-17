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
var facing_direction: int = 0  # 0=S, 1=SW, 2=W, 3=NW, 4=N, 5=NE, 6=E, 7=SE

# Melee attack system
var can_melee: bool = true
var is_meleeing: bool = false
var is_winding_up: bool = false
var melee_target_enemy: Node2D = null  # Track the locked-on target
var melee_hit_enemies: Array = []  # Track enemies hit in current attack to prevent double-hits
var melee_timer: Timer
var melee_animation_timer: Timer
var melee_windup_timer: Timer
var melee_damage_timer: Timer

# Melee configuration (export for easy tuning)
@export var melee_damage: float = 35.0
@export var melee_range: float = 80.0  # Increased to better match visual arc and large enemies
@export var melee_arc_degrees: float = 120.0
@export var melee_cooldown: float = 0.7
@export var melee_windup_time: float = 0.15  # Reduced for snappier feel
@export var melee_animation_duration: float = 0.15  # Reduced for snappier feel

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
		max_health = Globals.get_player_max_health()
		speed = Globals.get_player_speed()
		pickup_radius = Globals.PLAYER_PICKUP_RADIUS
		invincibility_time = Globals.PLAYER_INVINCIBILITY_TIME
		weapon_damage = Globals.get_player_weapon_damage()
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

	# Setup melee cooldown timer
	melee_timer = Timer.new()
	melee_timer.one_shot = true
	melee_timer.wait_time = melee_cooldown
	melee_timer.timeout.connect(_on_melee_timer_timeout)
	add_child(melee_timer)

	# Setup melee animation timer
	melee_animation_timer = Timer.new()
	melee_animation_timer.one_shot = true
	melee_animation_timer.wait_time = melee_animation_duration
	melee_animation_timer.timeout.connect(_on_melee_animation_timeout)
	add_child(melee_animation_timer)

	# Setup melee windup timer
	melee_windup_timer = Timer.new()
	melee_windup_timer.one_shot = true
	melee_windup_timer.wait_time = melee_windup_time
	melee_windup_timer.timeout.connect(_on_melee_windup_timeout)
	add_child(melee_windup_timer)

	# Setup melee damage timer (very short delay to sync with animation start)
	melee_damage_timer = Timer.new()
	melee_damage_timer.one_shot = true
	melee_damage_timer.wait_time = 0.05  # Nearly instant - just enough for visual sync
	melee_damage_timer.timeout.connect(_on_melee_damage_timeout)
	add_child(melee_damage_timer)

	# Connect melee hitbox signal
	var melee_hitbox = $MeleeVisuals/MeleeHitbox
	if melee_hitbox:
		melee_hitbox.enemy_hit.connect(_on_melee_hitbox_enemy_hit)

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

	# Melee auto-attack (only when not carrying turret)
	if can_melee and carried_turret == null:
		attempt_melee_attack()

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
	
	# Handle 8-direction sprite based on movement
	if input_vector.length() > 0.1:
		is_moving = true
		facing_direction = get_direction_from_vector(input_vector)
		sprite.frame = facing_direction
		sprite.flip_h = false  # No flip needed with 8-dir sprites
	else:
		is_moving = false
		# Keep facing last direction when stopped
		sprite.frame = facing_direction

func get_direction_from_vector(dir: Vector2) -> int:
	# Convert movement vector to 8-direction index
	# Frame order: S(0), SW(1), W(2), NW(3), N(4), NE(5), E(6), SE(7)
	var angle := dir.angle()
	# Normalize angle to 0-2PI range
	if angle < 0:
		angle += TAU
	# Divide circle into 8 sectors (each 45 degrees = PI/4)
	# Offset by 22.5 degrees so each direction is centered
	var sector := int(round(angle / (TAU / 8))) % 8
	# Map: 0=E, 1=SE, 2=S, 3=SW, 4=W, 5=NW, 6=N, 7=NE
	# We need: 0=S, 1=SW, 2=W, 3=NW, 4=N, 5=NE, 6=E, 7=SE
	var direction_map := [6, 7, 0, 1, 2, 3, 4, 5]  # Maps angle sector to frame index
	return direction_map[sector]

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

	# Defensive pulse - knockback nearby enemies
	apply_defensive_pulse()

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

# Melee attack methods
func attempt_melee_attack() -> void:
	# Don't start windup if already winding up or attacking
	if is_winding_up or is_meleeing:
		return

	# Find closest enemy in melee range (any direction for auto-attack)
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest_enemy_in_range: Node2D = null
	var closest_distance := melee_range

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance <= melee_range and distance < closest_distance:
			closest_distance = distance
			closest_enemy_in_range = enemy

	# Start windup if any enemy is in range
	if closest_enemy_in_range:
		# Lock onto this target for the entire attack
		melee_target_enemy = closest_enemy_in_range
		# Update facing direction to face the enemy
		var to_enemy := global_position.direction_to(closest_enemy_in_range.global_position)
		facing_direction = get_direction_from_vector(to_enemy)
		start_melee_windup()

func start_melee_windup() -> void:
	"""Start the windup phase with visual indicator."""
	can_melee = false
	is_winding_up = true
	melee_windup_timer.start()

	# Show windup visual indicator
	show_melee_windup_indicator()

func perform_melee_attack() -> void:
	"""Execute the actual attack after windup completes."""
	is_winding_up = false
	is_meleeing = true
	melee_timer.start()
	melee_animation_timer.start()

	# Clear hit tracking for new attack
	melee_hit_enemies.clear()

	# Calculate attack direction - use locked target if still valid
	var attack_direction := get_current_melee_direction()

	# Enable and animate the melee hitbox
	var melee_hitbox = $MeleeVisuals/MeleeHitbox
	if melee_hitbox:
		melee_hitbox.update_direction(attack_direction)
		melee_hitbox.enable_hitbox()
		melee_hitbox.animate_expansion(melee_animation_duration, 0.3)

	# Visual feedback - attack swing (starts animation)
	play_melee_swing_animation(attack_direction)

func get_current_melee_direction() -> Vector2:
	"""Get the direction for melee attack, prioritizing locked target."""
	# If we have a valid locked target, always face it
	if melee_target_enemy and is_instance_valid(melee_target_enemy):
		return global_position.direction_to(melee_target_enemy.global_position)
	# Otherwise fall back to facing direction
	return get_attack_direction_from_facing()

func _on_melee_hitbox_enemy_hit(enemy: Node2D) -> void:
	"""Handle enemy hit by melee hitbox (physics-based detection)."""
	# Prevent double-hits on same enemy
	if enemy in melee_hit_enemies:
		return

	# Check if enemy is dying (don't hit dead enemies)
	if "is_dying" in enemy and enemy.is_dying:
		return

	melee_hit_enemies.append(enemy)

	# Apply damage
	if enemy.has_method("take_damage"):
		enemy.take_damage(melee_damage)

	# Apply knockback
	if enemy.has_method("apply_knockback"):
		var knockback_dir := global_position.direction_to(enemy.global_position)
		enemy.apply_knockback(Globals.PLAYER_MELEE_KNOCKBACK_FORCE, knockback_dir)

	# Screen shake on hit (first hit triggers shake)
	if melee_hit_enemies.size() == 1:
		var camera = get_node_or_null("Camera2D")
		if camera and camera.has_method("shake"):
			camera.shake(0.15, 3)

func apply_melee_damage_and_knockback() -> void:
	"""Legacy function - now handled by melee hitbox signal.
	Kept for compatibility but does nothing."""
	# Damage is now applied via _on_melee_hitbox_enemy_hit signal
	pass

func is_enemy_in_melee_arc(enemy: Node2D, attack_dir: Vector2) -> bool:
	# Distance check
	var distance := global_position.distance_to(enemy.global_position)
	if distance > melee_range:
		return false

	# Angle check - 120-degree cone
	var to_enemy := global_position.direction_to(enemy.global_position)
	var angle_to_enemy := attack_dir.angle_to(to_enemy)
	var half_arc := deg_to_rad(melee_arc_degrees / 2.0)

	return abs(angle_to_enemy) <= half_arc

func get_attack_direction_from_facing() -> Vector2:
	# Convert 8-directional facing (0-7) to Vector2
	var angle_map := [
		PI / 2,      # 0: South
		PI * 3 / 4,  # 1: Southwest
		PI,          # 2: West
		-PI * 3 / 4, # 3: Northwest
		-PI / 2,     # 4: North
		-PI / 4,     # 5: Northeast
		0,           # 6: East
		PI / 4       # 7: Southeast
	]

	var angle: float = angle_map[facing_direction]
	return Vector2(cos(angle), sin(angle))

func show_melee_windup_indicator() -> void:
	"""Show pulsing indicator during windup phase."""
	var melee_arc = get_node_or_null("MeleeVisuals/MeleeArc")
	if not melee_arc:
		push_warning("MeleeArc node not found!")
		return

	# Rotate arc to attack direction (using locked target)
	var attack_direction := get_current_melee_direction()
	melee_arc.rotation = attack_direction.angle()

	# Make sure arc is visible with starting opacity
	melee_arc.visible = true
	melee_arc.modulate = Color(1, 1, 1, 0.3)

	# Pulse effect during windup
	var tween = create_tween()
	tween.tween_property(melee_arc, "modulate:a", 0.6, melee_windup_time * 0.5)
	tween.tween_property(melee_arc, "modulate:a", 0.3, melee_windup_time * 0.5)

func play_melee_swing_animation(attack_dir: Vector2) -> void:
	var melee_arc = get_node_or_null("MeleeVisuals/MeleeArc")
	if not melee_arc:
		push_warning("MeleeArc node not found for swing!")
		return

	# Rotate arc to attack direction
	melee_arc.rotation = attack_dir.angle()
	melee_arc.visible = true

	# Bright flash effect for the attack
	melee_arc.modulate = Color(1, 1, 1, 1.0)
	
	var tween = create_tween()
	tween.tween_property(melee_arc, "modulate:a", 0.0, melee_animation_duration)

	# Player sprite flash - yellow tint for attack
	sprite.modulate = Color(1.3, 1.2, 0.8, 1.0)
	var sprite_tween = create_tween()
	sprite_tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)

func _on_melee_timer_timeout() -> void:
	can_melee = true

func _on_melee_animation_timeout() -> void:
	is_meleeing = false

	# Disable the melee hitbox
	var melee_hitbox = $MeleeVisuals/MeleeHitbox
	if melee_hitbox:
		melee_hitbox.disable_hitbox()

	# Hide the melee arc after animation completes
	var melee_arc = get_node_or_null("MeleeVisuals/MeleeArc")
	if melee_arc:
		melee_arc.modulate.a = 0.0

func _on_melee_windup_timeout() -> void:
	"""Called when windup phase completes - execute the attack."""
	if is_winding_up:
		perform_melee_attack()

func _on_melee_damage_timeout() -> void:
	"""Called mid-animation to apply damage in sync with visual swing."""
	apply_melee_damage_and_knockback()
	# Clear the locked target after damage is applied
	melee_target_enemy = null

# =============================================================================
# DEFENSIVE PULSE SYSTEM
# =============================================================================

func apply_defensive_pulse() -> void:
	"""Knockback enemies when player takes damage."""
	var enemies = get_tree().get_nodes_in_group("enemies")
	var pulse_radius: float = Globals.PLAYER_DEFENSIVE_PULSE_RADIUS
	var pulse_force: float = Globals.PLAYER_DEFENSIVE_PULSE_KNOCKBACK_FORCE

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var distance := global_position.distance_to(enemy.global_position)
		if distance <= pulse_radius:
			if enemy.has_method("apply_knockback"):
				var knockback_dir := global_position.direction_to(enemy.global_position)
				enemy.apply_knockback(pulse_force, knockback_dir)

	# Visual feedback - pulse ring
	spawn_defensive_pulse_visual()

func spawn_defensive_pulse_visual() -> void:
	"""Create visual effect for defensive pulse."""
	var viz = Polygon2D.new()
	var points = PackedVector2Array()
	var segments = 32
	for i in range(segments):
		var angle = i * TAU / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * Globals.PLAYER_DEFENSIVE_PULSE_RADIUS)
	viz.polygon = points
	viz.color = Color(1.0, 0.8, 0.3)  # Golden defensive color
	viz.color.a = 0.5
	viz.global_position = global_position

	get_tree().current_scene.add_child(viz)

	var tween = viz.create_tween()
	tween.set_parallel(true)
	tween.tween_property(viz, "scale", Vector2.ONE * 1.4, 0.3)
	tween.tween_property(viz, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(viz.queue_free)
