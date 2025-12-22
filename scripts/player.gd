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
var is_invincible: bool = false
var is_dead: bool = false
var invincibility_timer: Timer
var animation_timer: Timer
var current_frame: int = 0

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

# Projectile scene (will be set up)
var projectile_scene: PackedScene

@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_timer: Timer = $AnimationTimer

# Components
@onready var turret_handler: PlayerTurretHandler = $Components/PlayerTurretHandler
@onready var movement: PlayerMovement = $Components/PlayerMovement
@onready var combat: PlayerCombat = $Components/PlayerCombat

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

	# Connect to debug toggle event
	Events.hitbox_debug_toggled.connect(_on_debug_toggled)

	# Initialize components
	turret_handler.initialize(self)
	movement.initialize(self, sprite)
	combat.initialize(self, weapon_pivot)

func _on_debug_toggled(type: int, _enabled: bool) -> void:
	if type == GameEnums.HitboxType.PHYSICS:
		queue_redraw()

func _draw() -> void:
	if not Globals.debug_hitbox_flags[GameEnums.HitboxType.PHYSICS]:
		return
	
	if has_node("CollisionShape2D"):
		var col_shape = $CollisionShape2D
		if col_shape.shape:
			var shape = col_shape.shape
			var offset = col_shape.position
			var color = Color(1.0, 1.0, 1.0, 0.4) # White for physics
			var outline_color = Color(1.0, 1.0, 1.0, 0.8)

			if shape is CircleShape2D:
				draw_circle(offset, shape.radius, color)
				draw_arc(offset, shape.radius, 0, TAU, 32, outline_color, 1.0)
			elif shape is RectangleShape2D:
				var rect = Rect2(offset - shape.size / 2.0, shape.size)
				draw_rect(rect, color, true)
				draw_rect(rect, outline_color, false, 1.0)

func _physics_process(delta: float) -> void:
	# Don't process if game hasn't started
	if Globals == null or not Globals.is_game_active:
		return
	
	velocity = movement.process(delta)
	clamp_to_arena()
	move_and_slide()

	# Turret pickup/placement system
	turret_handler.process(delta)
	
	# Turret range toggle (Tab / Y button)
	if Input.is_action_just_pressed("toggle_range"):
		Globals.show_turret_ranges = not Globals.show_turret_ranges
		Events.turret_range_toggled.emit(Globals.show_turret_ranges)

	# Ranged combat
	combat.process(delta)

	# Melee auto-attack (only when not carrying turret)
	if can_melee and not turret_handler.is_carrying_turret():
		attempt_melee_attack()
	
	# Handle invincibility visual
	if is_invincible:
		sprite.modulate.a = 0.5 if fmod(Time.get_ticks_msec(), 100) < 50 else 1.0
	else:
		sprite.modulate.a = 1.0

# Temporary facades for tests (will be removed later)
var facing_direction: int:
	get:
		return movement.facing_direction if movement else 0
	set(value):
		if movement:
			movement.facing_direction = value

var is_moving: bool:
	get:
		return movement.is_moving if movement else false

func get_direction_from_vector(dir: Vector2) -> int:
	return movement.get_direction_from_vector(dir)

var can_fire: bool:
	get:
		return combat.can_fire if combat else true

var closest_enemy: Node2D:
	get:
		return combat.closest_enemy if combat else null

var carried_turret: Node2D:
	get:
		return turret_handler.carried_turret if turret_handler else null
	set(value):
		if turret_handler:
			turret_handler.carried_turret = value

var nearby_turret: Node2D:
	get:
		return turret_handler.nearby_turret if turret_handler else null
	set(value):
		if turret_handler:
			turret_handler.nearby_turret = value

func pickup_turret(turret: Node2D) -> void:
	turret_handler.pickup_turret(turret)

func find_nearby_turret() -> void:
	turret_handler.find_nearby_turret()

func place_turret() -> void:
	turret_handler.place_turret()

func update_carried_turret_position() -> void:
	turret_handler.update_carried_turret_position()

func drop_carried_turret() -> void:
	turret_handler.force_drop()

func clamp_to_arena() -> void:
	# Keep player within arena bounds
	var half_width := Globals.ARENA_WIDTH / 2.0
	var half_height := Globals.ARENA_HEIGHT / 2.0
	var margin := 20.0  # Player collision radius

	global_position.x = clamp(global_position.x, -half_width + margin, half_width - margin)
	global_position.y = clamp(global_position.y, -half_height + margin, half_height - margin)

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
