extends Node
class_name EnemyCombat

## Handles enemy ranged combat (projectile shooting).
##
## Responsibilities:
## - Find player target within range
## - Fire projectiles on cooldown interval
## - Manage fire rate timer

# State
var can_fire: bool = true
var player_target: Node2D = null

# Timers
var fire_timer: Timer

# Dependencies (set via initialize)
var enemy: CharacterBody2D = null

# Config (from enemy type definition)
var fire_rate: float = 0.25  # fires per second (0.25 = every 4 seconds)
var projectile_speed: float = 175.0
var projectile_damage: float = 8.0
var firing_range: float = 350.0

# Scene
var projectile_scene: PackedScene

func initialize(p_enemy: CharacterBody2D, combat_params: Dictionary) -> void:
	"""Initialize component with enemy reference and combat parameters."""
	enemy = p_enemy
	assert(enemy != null, "EnemyCombat: enemy reference required")

	# Load combat parameters from type definition
	fire_rate = combat_params.get("fire_rate", 0.25)
	projectile_speed = combat_params.get("projectile_speed", 175.0)
	projectile_damage = combat_params.get("projectile_damage", 8.0)
	firing_range = combat_params.get("firing_range", 350.0)

	# Load projectile scene
	projectile_scene = preload("res://scenes/projectile.tscn")

	# Create fire timer
	fire_timer = Timer.new()
	fire_timer.one_shot = true
	fire_timer.wait_time = 1.0 / fire_rate
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	add_child(fire_timer)

	# Randomize initial fire delay to avoid synchronized volleys
	var initial_delay = randf_range(0.5, 2.0)
	fire_timer.start(initial_delay)

func process(_delta: float) -> void:
	"""Main update function - call from enemy's _physics_process."""
	if not enemy or enemy.is_dying:
		return

	find_player_target()
	if player_target and can_fire:
		fire_at_player()

func find_player_target() -> void:
	"""Find player target within firing range."""
	# Get player reference (enemy.player handles Tech Defense mode)
	var potential_target = enemy.player
	if not potential_target or not is_instance_valid(potential_target):
		player_target = null
		return

	# Check if in range
	var distance = enemy.global_position.distance_to(potential_target.global_position)
	if distance <= firing_range:
		player_target = potential_target
	else:
		player_target = null

func fire_at_player() -> void:
	"""Fire a projectile at the player."""
	if player_target == null or projectile_scene == null:
		return

	can_fire = false
	fire_timer.start()

	# Create projectile
	var projectile := ProjectilePool.acquire(enemy.get_tree().current_scene)
	if projectile == null:
		return
	projectile.global_position = enemy.global_position

	# Calculate direction to player
	var direction = enemy.global_position.direction_to(player_target.global_position)

	# Setup as ENEMY projectile (is_player_projectile = false)
	projectile.setup(direction, projectile_speed, projectile_damage, false, false)
	_spawn_attack_feedback(enemy.global_position, player_target.global_position)


func _spawn_attack_feedback(origin: Vector2, target_position: Vector2) -> void:
	"""Make ranged enemy shots readable without adding a gameplay delay."""
	if enemy == null or not enemy.is_inside_tree():
		return

	var scene_root := enemy.get_tree().current_scene
	if scene_root == null:
		return

	var direction := origin.direction_to(target_position)
	if direction == Vector2.ZERO:
		return

	# A short red firing line confirms where the projectile came from and gives
	# the player a clean visual read even when the projectile crosses a crowd.
	var firing_line := Line2D.new()
	firing_line.points = PackedVector2Array([origin, target_position])
	firing_line.width = 2.5
	firing_line.default_color = Color(1.0, 0.2, 0.16, 0.45)
	firing_line.z_index = 7
	firing_line.antialiased = true
	scene_root.add_child(firing_line)
	var line_tween := firing_line.create_tween()
	line_tween.tween_property(firing_line, "modulate:a", 0.0, 0.12)
	line_tween.tween_callback(firing_line.queue_free)

	# A small directional muzzle diamond makes the firing origin legible without
	# requiring another enemy sprite or a texture asset.
	var muzzle_flash := Polygon2D.new()
	muzzle_flash.polygon = PackedVector2Array([
		Vector2(12.0, 0.0),
		Vector2(0.0, 4.0),
		Vector2(-4.0, 0.0),
		Vector2(0.0, -4.0),
	])
	muzzle_flash.position = origin + direction * 12.0
	muzzle_flash.rotation = direction.angle()
	muzzle_flash.color = Color(1.0, 0.68, 0.24, 0.85)
	muzzle_flash.z_index = 8
	scene_root.add_child(muzzle_flash)
	var flash_tween := muzzle_flash.create_tween()
	flash_tween.set_trans(Tween.TRANS_QUAD)
	flash_tween.set_ease(Tween.EASE_OUT)
	flash_tween.tween_property(muzzle_flash, "scale", Vector2(1.5, 1.5), 0.1)
	flash_tween.parallel().tween_property(muzzle_flash, "modulate:a", 0.0, 0.1)
	flash_tween.tween_callback(muzzle_flash.queue_free)

func _on_fire_timer_timeout() -> void:
	"""Re-enable firing after cooldown."""
	can_fire = true

func cleanup() -> void:
	"""Clean up timers and resources."""
	if fire_timer:
		fire_timer.stop()
