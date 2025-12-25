extends Node2D

## Tunnel Door entity for TUNNELING game modes
## Door that must be damaged by turrets to unlock/breach and complete the wave.

@export var base_health: float = GameConstants.TUNNEL_DOOR_BASE_HEALTH
var max_health: float
var current_health: float

# Visual feedback
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D
@onready var area: Area2D = $Area2D

var is_breached: bool = false
var current_wave: int = 1

func _ready() -> void:
	add_to_group("tunnel_doors")
	
	# Connect area signals for turret projectile collision
	if area:
		area.area_entered.connect(_on_area_entered)

func _on_area_entered(other_area: Area2D) -> void:
	"""Handle projectiles hitting the door."""
	if is_breached:
		return
	
	# Check if it's a projectile from a turret (not player)
	var projectile = other_area.get_parent()
	if projectile and "damage" in projectile:
		var damage = projectile.damage
		var is_player_proj = projectile.get("is_player_projectile") if "is_player_projectile" in projectile else true
		
		# Only turret projectiles can damage the door
		if not is_player_proj and damage > 0:
			take_damage(damage)
			# Destroy the projectile
			if projectile.has_method("queue_free"):
				projectile.queue_free()

func initialize(wave: int, difficulty_config: Dictionary) -> void:
	"""
	Initialize the tunnel door with wave and difficulty scaling.
	User decision: Turret-based damage unlock, scales with wave/difficulty.
	"""
	current_wave = wave
	
	# Scale HP by wave (harder on later waves)
	max_health = base_health + (wave - 1) * GameConstants.TUNNEL_DOOR_HEALTH_SCALE_PER_WAVE
	
	# Scale by difficulty (harder difficulty = more HP needed)
	var health_mult = difficulty_config.get("enemy_health_mult", 1.0)
	max_health *= health_mult
	
	current_health = max_health
	
	# Emit initial HP for UI
	Events.tunnel_door_progress_changed.emit(current_health, max_health)
	Events.tunnel_door_spawned.emit(self, global_position)

func take_damage(amount: float) -> void:
	"""
	Take damage from turret projectiles.
	User decision: Only turrets can damage the door (not player or enemies).
	"""
	if is_breached:
		return
	
	current_health -= amount
	current_health = max(current_health, 0.0)
	
	# Update progress (inverse: HP goes down = progress goes up)
	Events.tunnel_door_progress_changed.emit(current_health, max_health)
	Events.damage_dealt.emit(global_position, amount)
	
	# Visual feedback
	_apply_damage_flash()
	
	if current_health <= 0:
		breach()

func breach() -> void:
	"""Door breached - unlock and trigger wave completion."""
	if is_breached:
		return
	is_breached = true
	
	# Emit breach event (game manager will handle wave completion)
	Events.tunnel_door_breached.emit()
	
	# Play breach animation
	_play_breach_animation()

func get_progress() -> float:
	"""Returns breach progress as 0.0 to 1.0."""
	if max_health <= 0:
		return 0.0
	return 1.0 - (current_health / max_health)

func _apply_damage_flash() -> void:
	"""Flash color when taking damage."""
	if not sprite:
		return
	
	var original_modulate = sprite.modulate
	sprite.modulate = Color(1.0, 1.5, 1.5, 1.0) # Cyan flash
	
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", original_modulate, 0.2)

func _play_breach_animation() -> void:
	"""Breach effect - door opens/disappears."""
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.2, 0.1), 0.5) # Door collapses vertically
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.finished.connect(queue_free)
