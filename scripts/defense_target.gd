extends Node2D

## Defense Target entity for TECH_DEFENSE game mode
## Static target with HP that enemies can damage. If destroyed, player loses.

@export var max_health: float = GameConstants.DEFENSE_TARGET_BASE_HEALTH
var current_health: float

# Visual feedback
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D
@onready var area: Area2D = $Area2D

var is_destroyed: bool = false

func _ready() -> void:
	print("DEBUG DefenseTarget: _ready() called")
	add_to_group("defense_targets")
	current_health = max_health
	
	print("DEBUG DefenseTarget: Position = ", global_position)
	print("DEBUG DefenseTarget: Visible = ", visible)
	print("DEBUG DefenseTarget: Sprite exists = ", sprite != null)
	if sprite:
		print("DEBUG DefenseTarget: Sprite visible = ", sprite.visible)
		print("DEBUG DefenseTarget: Sprite modulate = ", sprite.modulate)
		print("DEBUG DefenseTarget: Sprite scale = ", sprite.scale)
	
	# Connect area signals for enemy collision
	if area:
		area.body_entered.connect(_on_body_entered)
		print("DEBUG DefenseTarget: Area connected")
	else:
		print("DEBUG DefenseTarget: WARNING - Area2D not found!")

func initialize(_wave: int, difficulty_config: Dictionary) -> void:
	"""
	Initialize the defense target with wave and difficulty scaling.
	User decision: 500 HP base, scaled by difficulty.
	"""
	print("DEBUG DefenseTarget: initialize() called")
	print("DEBUG DefenseTarget: Wave = ", _wave)
	print("DEBUG DefenseTarget: Difficulty config = ", difficulty_config)
	
	# Scale HP by difficulty
	var health_mult = difficulty_config.get("enemy_health_mult", 1.0) # Use enemy mult as inverse
	max_health = GameConstants.DEFENSE_TARGET_BASE_HEALTH / health_mult # Harder difficulty = less HP
	
	current_health = max_health
	
	print("DEBUG DefenseTarget: Max HP = ", max_health)
	print("DEBUG DefenseTarget: Current HP = ", current_health)
	
	# Emit initial HP for UI
	Events.defense_target_hp_changed.emit(current_health, max_health)
	print("DEBUG DefenseTarget: HP changed event emitted")

func _on_body_entered(body: Node) -> void:
	"""Handle enemies reaching the target."""
	print("DEBUG DefenseTarget: Body entered: ", body)
	print("DEBUG DefenseTarget: Is in enemies group: ", body.is_in_group("enemies"))
	
	if is_destroyed:
		return
		
	if body.is_in_group("enemies"):
		var enemy = body as CharacterBody2D
		if enemy:
			# Get contact damage from enemy property (not method)
			var damage: float = enemy.contact_damage if "contact_damage" in enemy else 33.0
			print("DEBUG DefenseTarget: Taking ", damage, " damage from enemy")
			take_damage(damage)
			
			# Apply knockback to the enemy (push them away from target)
			if enemy.has_method("apply_knockback"):
				var knockback_direction = (enemy.global_position - global_position).normalized()
				var knockback_force = 300.0 # Adjust as needed
				enemy.apply_knockback(knockback_force, knockback_direction)
				print("DEBUG DefenseTarget: Applied knockback to enemy")

func take_damage(amount: float) -> void:
	"""Take damage and emit events."""
	if is_destroyed:
		return
	
	current_health -= amount
	current_health = max(current_health, 0.0)
	
	# Emit damage event for UI update
	Events.defense_target_hp_changed.emit(current_health, max_health)
	Events.damage_dealt.emit(global_position, amount)
	
	# Visual feedback
	_apply_damage_flash()
	
	if current_health <= 0:
		destroy()

func destroy() -> void:
	"""Target destroyed - trigger game over."""
	if is_destroyed:
		return
	is_destroyed = true
	
	# Emit destruction event
	Events.defense_target_destroyed.emit()
	
	# Play destruction animation
	_play_destruction_animation()

func _apply_damage_flash() -> void:
	"""Flash white when taking damage."""
	if not sprite:
		return
	
	var original_modulate = sprite.modulate
	sprite.modulate = Color(1.5, 1.5, 1.5, 1.0)
	
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", original_modulate, 0.2)

func _play_destruction_animation() -> void:
	"""Destruction effect - scale down and fade."""
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.5)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.finished.connect(queue_free)
