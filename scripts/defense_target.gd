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

# Barrier state
var barrier_active: bool = false
var barrier_timer: Timer
var barrier_cooldown_timer: Timer
var barrier_cooldown_ready: bool = true

# Visual components
@onready var health_bar: ProgressBar = $HealthBar
@onready var barrier_visual: Node2D = $BarrierVisual

func _ready() -> void:
	print("DEBUG DefenseTarget: _ready() called")
	add_to_group("defense_targets")
	current_health = max_health
	_setup_timers()

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

	# Connect to wave_ended event for healing between rounds
	Events.wave_ended.connect(_on_wave_ended)

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

	# Initialize health bar
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

	print("DEBUG DefenseTarget: Max HP = ", max_health)
	print("DEBUG DefenseTarget: Current HP = ", current_health)

	# Emit initial HP for UI
	Events.defense_target_hp_changed.emit(current_health, max_health)
	print("DEBUG DefenseTarget: HP changed event emitted")

func _on_body_entered(body: Node) -> void:
	"""Handle enemies reaching the target."""
	print("DEBUG DefenseTarget: Body entered: ", body)
	print("DEBUG DefenseTarget: Is in enemies group: ", body.is_in_group("enemies"))

	# If barrier is active, block enemy collision
	if barrier_active:
		if body.has_method("apply_knockback"):
			var knockback_direction = (body.global_position - global_position).normalized()
			var knockback_force = 800.0  # Very strong barrier knockback
			body.apply_knockback(knockback_force, knockback_direction)
			print("DEBUG DefenseTarget: Barrier blocked enemy - strong knockback applied")
		return

	if is_destroyed:
		return

	if body.is_in_group("enemies"):
		var enemy = body as CharacterBody2D
		if enemy:
			# Get contact damage from enemy property (not method)
			var damage: float = enemy.contact_damage if "contact_damage" in enemy else 33.0
			print("DEBUG DefenseTarget: Taking ", damage, " damage from enemy")

			# Apply enhanced knockback to the enemy (push them away from target)
			if enemy.has_method("apply_knockback"):
				var knockback_direction = (enemy.global_position - global_position).normalized()
				var knockback_force = 300.0 * GameConstants.DEFENSE_TARGET_KNOCKBACK_MULTIPLIER
				enemy.apply_knockback(knockback_force, knockback_direction)
				print("DEBUG DefenseTarget: Applied enhanced knockback to enemy (", knockback_force, ")")

			# Reflect damage back to enemy
			_reflect_damage(enemy, damage)

			# Apply status effects (slow)
			_apply_status_effects(enemy)

			# Take damage and activate barrier
			take_damage(damage)

func take_damage(amount: float) -> void:
	"""Take damage and emit events."""
	if is_destroyed or barrier_active:
		return

	current_health -= amount
	current_health = max(current_health, 0.0)

	# Update health bar
	if health_bar:
		health_bar.value = current_health

	# Emit damage event for UI update
	Events.defense_target_hp_changed.emit(current_health, max_health)
	Events.damage_dealt.emit(global_position, amount)

	# Visual feedback
	_apply_damage_flash()

	# Activate barrier on any damage
	_activate_barrier()

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

func _setup_timers() -> void:
	"""Setup barrier duration and cooldown timers."""
	barrier_timer = Timer.new()
	barrier_timer.one_shot = true
	barrier_timer.timeout.connect(_on_barrier_expired)
	add_child(barrier_timer)

	barrier_cooldown_timer = Timer.new()
	barrier_cooldown_timer.one_shot = true
	barrier_cooldown_timer.timeout.connect(_on_barrier_cooldown_ready)
	add_child(barrier_cooldown_timer)

func _activate_barrier() -> void:
	"""Activate the immunity barrier."""
	if not barrier_cooldown_ready:
		return

	barrier_active = true
	barrier_cooldown_ready = false

	if barrier_visual:
		barrier_visual.visible = true
		_play_barrier_animation()

	barrier_timer.wait_time = GameConstants.DEFENSE_TARGET_BARRIER_DURATION
	barrier_timer.start()
	Events.defense_target_barrier_activated.emit(self)

func _on_barrier_expired() -> void:
	"""Handle barrier expiration."""
	barrier_active = false

	if barrier_visual:
		barrier_visual.visible = false

	barrier_cooldown_timer.wait_time = GameConstants.DEFENSE_TARGET_BARRIER_COOLDOWN
	barrier_cooldown_timer.start()
	Events.defense_target_barrier_expired.emit(self)

func _on_barrier_cooldown_ready() -> void:
	"""Handle barrier cooldown completion."""
	barrier_cooldown_ready = true
	Events.defense_target_barrier_cooldown_ready.emit(self)

func _play_barrier_animation() -> void:
	"""Animate barrier activation with pulse effect."""
	if not barrier_visual:
		return

	barrier_visual.scale = Vector2.ZERO
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(barrier_visual, "scale", Vector2.ONE, 0.3)

func _reflect_damage(enemy: Node, damage: float) -> void:
	"""Reflect damage back to the attacking enemy."""
	if not enemy.has_method("take_damage"):
		return

	var reflect_amount = damage * GameConstants.DEFENSE_TARGET_REFLECT_PERCENT
	enemy.take_damage(reflect_amount)
	Events.defense_target_reflect_damage.emit(enemy, reflect_amount)

func _apply_status_effects(enemy: Node) -> void:
	"""Apply slow status effect to the attacking enemy."""
	if not enemy.has_method("apply_status_effect"):
		return

	enemy.apply_status_effect(
		GameEnums.DamageType.PHYSICAL,
		0.0,  # No DoT damage
		GameConstants.DEFENSE_TARGET_SLOW_DURATION,
		1.0,  # tick_rate (irrelevant for slow-only)
		GameConstants.DEFENSE_TARGET_SLOW_INTENSITY
	)

func heal(amount: float) -> void:
	"""Heal the defense target by the specified amount."""
	if is_destroyed:
		return

	var old_health = current_health
	current_health = min(current_health + amount, max_health)
	var actual_heal = current_health - old_health

	if actual_heal > 0:
		# Update health bar
		if health_bar:
			health_bar.value = current_health

		# Emit events
		Events.defense_target_hp_changed.emit(current_health, max_health)
		Events.defense_target_healed.emit(current_health, max_health, actual_heal)

		print("DEBUG DefenseTarget: Healed ", actual_heal, " HP (", current_health, "/", max_health, ")")

func _on_wave_ended(_wave_number: int) -> void:
	"""Heal the defense target between waves."""
	if is_destroyed:
		return

	heal(GameConstants.DEFENSE_TARGET_HEAL_BETWEEN_WAVES)
	print("DEBUG DefenseTarget: Wave ", _wave_number, " ended - healing between rounds")
