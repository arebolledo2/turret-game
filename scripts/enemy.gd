extends CharacterBody2D

const StatusEffect = preload("res://scripts/status_effect.gd")

@export var max_health: float = 30.0
@export var speed: float = 150.0
@export var contact_damage: float = 33.0
@export var xp_value: int = 10

var current_health: float
var player: Node2D = null

# Status effects - keyed by DamageType, only strongest of each type is active
var active_effects: Dictionary = {}  # DamageType -> StatusEffect
var is_dying: bool = false

func _ready() -> void:
	current_health = max_health
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if is_dying:
		return
		
	# Process status effects
	_process_status_effects(delta)
	
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	
	# Move towards player (simple chase AI)
	var direction := global_position.direction_to(player.global_position)
	velocity = direction * speed
	move_and_slide()
	
	# Check for collision with player
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider = collision.get_collider()
		if collider.is_in_group("player") and collider.has_method("take_damage"):
			collider.take_damage(contact_damage)

func initialize(wave: int) -> void:
	# Scale stats based on wave number
	max_health = Globals.get_enemy_health(wave)
	speed = Globals.get_enemy_speed(wave)
	contact_damage = Globals.ENEMY_CONTACT_DAMAGE
	current_health = max_health

func take_damage(amount: float) -> void:
	current_health -= amount
	
	# Emit damage event for damage numbers
	Events.damage_dealt.emit(global_position, amount)
	
	# Visual feedback - flash white
	$Sprite2D.modulate = Color.WHITE
	var tween = create_tween()
	tween.tween_property($Sprite2D, "modulate", Color(1, 0.3, 0.3, 1), 0.1)
	
	if current_health <= 0:
		die()

func die() -> void:
	if is_dying:
		return
	is_dying = true
	
	# Clear status effects
	active_effects.clear()
	
	# Emit signals for XP drop and kill tracking
	Events.enemy_killed.emit(self, global_position)
	Events.xp_dropped.emit(global_position, xp_value)
	Globals.total_kills += 1
	
	# Death effect (scale down and fade)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property($Sprite2D, "scale", Vector2.ZERO, 0.15)
	tween.tween_property($Sprite2D, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(queue_free)

# =============================================================================
# STATUS EFFECT SYSTEM
# =============================================================================

func _process_status_effects(delta: float) -> void:
	var expired_types: Array = []
	var total_dot_damage: float = 0.0
	
	for dtype in active_effects:
		var effect: StatusEffect = active_effects[dtype]
		var tick_damage: float = effect.process(delta)
		if tick_damage > 0:
			total_dot_damage += tick_damage
		if effect.is_expired():
			expired_types.append(dtype)
	
	# Apply accumulated DoT damage
	if total_dot_damage > 0:
		take_dot_damage(total_dot_damage)
	
	# Remove expired effects
	for dtype in expired_types:
		active_effects.erase(dtype)
		_update_status_visual()

## Apply a status effect (DoT). Uses strongest-per-damage-type logic.
func apply_status_effect(damage_type: Globals.DamageType, dot_damage: float, dot_duration: float, dot_tick_rate: float = 1.0) -> void:
	if is_dying or dot_damage <= 0 or dot_duration <= 0:
		return
	
	var new_effect := StatusEffect.new(damage_type, dot_damage, dot_duration, dot_tick_rate)
	
	if active_effects.has(damage_type):
		var existing: StatusEffect = active_effects[damage_type]
		# Refresh with potentially stronger damage
		existing.refresh(dot_damage, dot_duration)
	else:
		active_effects[damage_type] = new_effect
		Events.status_effect_applied.emit(self, damage_type)
	
	_update_status_visual()

## Take DoT damage (separate from regular damage for potential future differentiation)
func take_dot_damage(amount: float) -> void:
	if is_dying:
		return
	
	current_health -= amount
	
	# Emit damage event for damage numbers (could use different color for DoT)
	Events.dot_damage_dealt.emit(global_position, amount)
	
	if current_health <= 0:
		die()

## Update visual tint based on active status effects
func _update_status_visual() -> void:
	if active_effects.is_empty():
		# Reset to default red tint
		$Sprite2D.modulate = Color(1, 0.3, 0.3, 1)
		return
	
	# Blend colors based on active effects
	var final_color := Color(1, 0.3, 0.3, 1)
	
	if active_effects.has(Globals.DamageType.FIRE):
		final_color = final_color.lerp(Color(1.0, 0.5, 0.2, 1), 0.5)  # Orange tint
	if active_effects.has(Globals.DamageType.ELECTRIC):
		final_color = final_color.lerp(Color(0.5, 0.8, 1.0, 1), 0.5)  # Blue tint
	if active_effects.has(Globals.DamageType.PLASMA):
		final_color = final_color.lerp(Color(0.8, 0.4, 1.0, 1), 0.5)  # Purple tint
	
	$Sprite2D.modulate = final_color

## Check if enemy has a specific status effect
func has_status_effect(damage_type: Globals.DamageType) -> bool:
	return active_effects.has(damage_type)

