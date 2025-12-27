extends Node
class_name PlayerMeleeCombat

## Handles player melee attack system with windup and animation phases.
##
## Responsibilities:
## - Auto-attack melee when close to enemies
## - Windup phase with visual indicator
## - Attack execution with arc-based hit detection
## - Track hit enemies (prevent multi-hit)
## - Sync animations with damage application

# State
var can_melee: bool = true
var is_meleeing: bool = false
var is_winding_up: bool = false
var melee_target_enemy: Node2D = null # Locked-on target
var melee_hit_enemies: Array = [] # Track hit enemies to prevent double-hits

# Timers (5 total!)
var melee_timer: Timer
var melee_animation_timer: Timer
var melee_windup_timer: Timer
var melee_damage_timer: Timer

# Dependencies (set via initialize)
var player: CharacterBody2D = null
var sprite: Sprite2D = null
var movement: PlayerMovement = null
var melee_hitbox: Area2D = null
var melee_arc: Polygon2D = null

# Config
var melee_damage: float = GameConstants.PLAYER_MELEE_DAMAGE
var melee_range: float = GameConstants.PLAYER_MELEE_RANGE
var melee_arc_degrees: float = GameConstants.PLAYER_MELEE_ARC_DEGREES
var melee_cooldown: float = GameConstants.PLAYER_MELEE_COOLDOWN
var melee_windup_time: float = GameConstants.PLAYER_MELEE_WINDUP_TIME
var melee_animation_duration: float = GameConstants.PLAYER_MELEE_ANIMATION_DURATION

# Signals
signal melee_hit() # Parent handles camera shake

func initialize(p_player: CharacterBody2D, p_sprite: Sprite2D, p_movement: PlayerMovement) -> void:
	"""Initialize component with required references."""
	player = p_player
	sprite = p_sprite
	movement = p_movement
	assert(player != null, "PlayerMeleeCombat: player reference required")
	assert(sprite != null, "PlayerMeleeCombat: sprite reference required")
	assert(movement != null, "PlayerMeleeCombat: movement reference required")

	# Load stats from Globals (facade provides access to GameConstants defaults)
	melee_damage = GameConstants.PLAYER_MELEE_DAMAGE
	melee_range = GameConstants.PLAYER_MELEE_RANGE
	melee_arc_degrees = GameConstants.PLAYER_MELEE_ARC_DEGREES
	melee_cooldown = GameConstants.PLAYER_MELEE_COOLDOWN
	melee_windup_time = GameConstants.PLAYER_MELEE_WINDUP_TIME
	melee_animation_duration = GameConstants.PLAYER_MELEE_ANIMATION_DURATION
# ... (rest of the file uses GameConstants)

	# Get MeleeVisuals nodes (sibling to Components)
	melee_hitbox = player.get_node_or_null("MeleeVisuals/MeleeHitbox")
	melee_arc = player.get_node_or_null("MeleeVisuals/MeleeArc")

	if melee_hitbox:
		melee_hitbox.enemy_hit.connect(_on_melee_hitbox_enemy_hit)

	# Create 5 timers
	melee_timer = Timer.new()
	melee_timer.one_shot = true
	melee_timer.wait_time = melee_cooldown
	melee_timer.timeout.connect(_on_melee_timer_timeout)
	add_child(melee_timer)

	melee_animation_timer = Timer.new()
	melee_animation_timer.one_shot = true
	melee_animation_timer.wait_time = melee_animation_duration
	melee_animation_timer.timeout.connect(_on_melee_animation_timeout)
	add_child(melee_animation_timer)

	melee_windup_timer = Timer.new()
	melee_windup_timer.one_shot = true
	melee_windup_timer.wait_time = melee_windup_time
	melee_windup_timer.timeout.connect(_on_melee_windup_timeout)
	add_child(melee_windup_timer)

	melee_damage_timer = Timer.new()
	melee_damage_timer.one_shot = true
	melee_damage_timer.wait_time = 0.05 # Nearly instant - just enough for visual sync
	melee_damage_timer.timeout.connect(_on_melee_damage_timeout)
	add_child(melee_damage_timer)

func process(_delta: float, can_attack: bool) -> void:
	"""Main update function - only attack when can_attack is true (not carrying turret)."""
	if can_melee and can_attack:
		attempt_melee_attack()

func attempt_melee_attack() -> void:
	"""Try to start a melee attack if an enemy or tunnel door is in range."""
	# Don't start windup if already winding up or attacking
	if is_winding_up or is_meleeing:
		return

	var closest_target: Node2D = null
	var closest_distance := melee_range
	
	# In Tunneling mode, also check for tunnel door as a target
	if GameModeService.should_spawn_tunnel_door():
		var doors = player.get_tree().get_nodes_in_group("tunnel_doors")
		for door in doors:
			if not is_instance_valid(door):
				continue
			var distance := player.global_position.distance_to(door.global_position)
			if distance <= melee_range and distance < closest_distance:
				closest_distance = distance
				closest_target = door

	# Find closest enemy in melee range (any direction for auto-attack)
	var enemies = player.get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var distance := player.global_position.distance_to(enemy.global_position)
		if distance <= melee_range and distance < closest_distance:
			closest_distance = distance
			closest_target = enemy

	# Start windup if any target is in range
	if closest_target:
		# Lock onto this target for the entire attack
		melee_target_enemy = closest_target
		# Update facing direction to face the target
		var to_target := player.global_position.direction_to(closest_target.global_position)
		movement.facing_direction = movement.get_direction_from_vector(to_target)
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
		return player.global_position.direction_to(melee_target_enemy.global_position)
	# Otherwise fall back to facing direction
	return get_attack_direction_from_facing()

func get_attack_direction_from_facing() -> Vector2:
	"""Convert 8-directional facing to Vector2."""
	return movement.get_facing_vector()

func show_melee_windup_indicator() -> void:
	"""Show pulsing indicator during windup phase."""
	if not melee_arc:
		return

	# Rotate arc to attack direction (using locked target)
	var attack_direction := get_current_melee_direction()
	melee_arc.rotation = attack_direction.angle()

	# Make sure arc is visible with starting opacity
	melee_arc.visible = true
	melee_arc.modulate = Color(1, 1, 1, 0.3)

	# Pulse effect during windup
	var tween = player.create_tween()
	tween.tween_property(melee_arc, "modulate:a", 0.6, melee_windup_time * 0.5)
	tween.tween_property(melee_arc, "modulate:a", 0.3, melee_windup_time * 0.5)

func play_melee_swing_animation(attack_dir: Vector2) -> void:
	"""Animate the melee swing."""
	if not melee_arc:
		return

	# Rotate arc to attack direction
	melee_arc.rotation = attack_dir.angle()
	melee_arc.visible = true

	# Bright flash effect for the attack
	melee_arc.modulate = Color(1, 1, 1, 1.0)

	var tween = player.create_tween()
	tween.tween_property(melee_arc, "modulate:a", 0.0, melee_animation_duration)

	# Player sprite flash - yellow tint for attack
	sprite.modulate = Color(1.3, 1.2, 0.8, 1.0)
	var sprite_tween = player.create_tween()
	sprite_tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)

func _on_melee_hitbox_enemy_hit(enemy: Node2D) -> void:
	"""Handle enemy or tunnel door hit by melee hitbox (physics-based detection)."""
	# Prevent double-hits on same target
	if enemy in melee_hit_enemies:
		return

	# Check if enemy is dying (don't hit dead enemies) - skip for tunnel doors
	if "is_dying" in enemy and enemy.is_dying:
		return
	
	# Skip tunnel doors that are already breached
	if "is_breached" in enemy and enemy.is_breached:
		return

	melee_hit_enemies.append(enemy)

	# Apply damage with crit roll
	if enemy.has_method("take_damage"):
		var is_crit := PlayerStatsService.roll_player_crit()
		var final_damage := melee_damage
		if is_crit:
			final_damage = PlayerStatsService.calculate_player_crit_damage(melee_damage)
		enemy.take_damage(final_damage, is_crit)

	# Apply knockback (only for enemies, not doors)
	if enemy.has_method("apply_knockback") and enemy.is_in_group("enemies"):
		var knockback_dir := player.global_position.direction_to(enemy.global_position)
		enemy.apply_knockback(Globals.PLAYER_MELEE_KNOCKBACK_FORCE, knockback_dir)

	# Emit signal for camera shake (first hit triggers shake)
	if melee_hit_enemies.size() == 1:
		melee_hit.emit()

func _on_melee_timer_timeout() -> void:
	"""Re-enable melee after cooldown."""
	can_melee = true

func _on_melee_animation_timeout() -> void:
	"""Animation complete - disable hitbox."""
	is_meleeing = false

	# Disable the melee hitbox
	if melee_hitbox:
		melee_hitbox.disable_hitbox()

	# Hide the melee arc after animation completes
	if melee_arc:
		melee_arc.modulate.a = 0.0

func _on_melee_windup_timeout() -> void:
	"""Windup complete - execute the attack."""
	if is_winding_up:
		perform_melee_attack()

func _on_melee_damage_timeout() -> void:
	"""Damage timing (legacy - now handled by hitbox signal)."""
	# Clear the locked target after damage is applied
	melee_target_enemy = null

func is_attacking() -> bool:
	"""Returns true if currently in melee attack."""
	return is_meleeing or is_winding_up

func is_enemy_in_melee_arc(enemy: Node2D, attack_dir: Vector2) -> bool:
	"""Check if an enemy is within the melee arc."""
	# Distance check
	var distance := player.global_position.distance_to(enemy.global_position)
	if distance > melee_range:
		return false

	# Angle check - 120-degree cone
	var to_enemy := player.global_position.direction_to(enemy.global_position)
	var angle_to_enemy := attack_dir.angle_to(to_enemy)
	var half_arc := deg_to_rad(melee_arc_degrees / 2.0)

	return abs(angle_to_enemy) <= half_arc
