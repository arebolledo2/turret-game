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
	var projectile = projectile_scene.instantiate()
	enemy.get_tree().current_scene.add_child(projectile)
	projectile.global_position = enemy.global_position

	# Calculate direction to player
	var direction = enemy.global_position.direction_to(player_target.global_position)

	# Setup as ENEMY projectile (is_player_projectile = false)
	projectile.setup(direction, projectile_speed, projectile_damage, false, false)

func _on_fire_timer_timeout() -> void:
	"""Re-enable firing after cooldown."""
	can_fire = true

func cleanup() -> void:
	"""Clean up timers and resources."""
	if fire_timer:
		fire_timer.stop()
