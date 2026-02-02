extends Node
class_name PlayerCombat

## Handles player ranged weapon combat.
##
## Responsibilities:
## - Find closest enemy within weapon range
## - Fire projectiles on cooldown
## - Rotate weapon pivot toward target
## - Apply weapon damage

# State
var can_fire: bool = true
var closest_enemy: Node2D = null

# Timers
var fire_timer: Timer

# Dependencies (set via initialize)
var player: CharacterBody2D = null
var weapon_pivot: Node2D = null

# Config
var weapon_damage: float = 5.0
var weapon_fire_rate: float = 3.0
var weapon_range: float = 200.0
var projectile_speed: float = 600.0

# Scene
var projectile_scene: PackedScene

func initialize(p_player: CharacterBody2D, p_weapon_pivot: Node2D) -> void:
	"""Initialize component with required references."""
	player = p_player
	weapon_pivot = p_weapon_pivot
	assert(player != null, "PlayerCombat: player reference required")
	assert(weapon_pivot != null, "PlayerCombat: weapon_pivot reference required")

	# Load stats
	weapon_damage = GameConstants.PLAYER_TURRET_DAMAGE
	weapon_fire_rate = GameConstants.PLAYER_TURRET_FIRE_RATE
	weapon_range = GameConstants.PLAYER_TURRET_RANGE
	projectile_speed = GameConstants.PLAYER_TURRET_PROJECTILE_SPEED

	# Load projectile scene
	projectile_scene = preload("res://scenes/projectile.tscn")

	# Create fire timer
	fire_timer = Timer.new()
	fire_timer.one_shot = true
	fire_timer.wait_time = 1.0 / weapon_fire_rate
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	add_child(fire_timer)

func process(_delta: float) -> void:
	"""Main update function - call from player's _physics_process."""
	# Update stats dynamically
	weapon_damage = PlayerStatsService.get_player_weapon_damage()
	weapon_fire_rate = PlayerStatsService.get_player_fire_rate()
	
	# Update fire timer wait time if fire rate changed
	var target_wait_time = 1.0 / weapon_fire_rate
	if not is_equal_approx(fire_timer.wait_time, target_wait_time):
		fire_timer.wait_time = target_wait_time

	if not SettingsService.player_auto_attack_enabled:
		return

	find_closest_enemy()
	if closest_enemy and can_fire:
		fire_at_enemy()

func find_closest_enemy() -> void:
	"""Find the closest enemy within weapon range."""
	var enemies = player.get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		closest_enemy = null
		return

	var closest_distance := weapon_range
	closest_enemy = null

	for enemy in enemies:
		var distance := player.global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy

func fire_at_enemy() -> void:
	"""Fire a projectile at the closest enemy."""
	if closest_enemy == null or projectile_scene == null:
		return

	can_fire = false
	fire_timer.start()

	# Roll for crit
	var is_crit := PlayerStatsService.roll_player_crit()
	var final_damage := weapon_damage
	if is_crit:
		final_damage = PlayerStatsService.calculate_player_crit_damage(weapon_damage)

	# Create projectile
	var projectile = projectile_scene.instantiate()
	player.get_tree().current_scene.add_child(projectile)
	projectile.global_position = player.global_position
	var dir = player.global_position.direction_to(closest_enemy.global_position)
	projectile.setup(dir, projectile_speed, final_damage, true, is_crit)

	# Rotate weapon pivot to face enemy
	weapon_pivot.look_at(closest_enemy.global_position)

func _on_fire_timer_timeout() -> void:
	"""Re-enable firing after cooldown."""
	can_fire = true

func is_attacking() -> bool:
	"""Returns true if currently attacking."""
	return not can_fire
