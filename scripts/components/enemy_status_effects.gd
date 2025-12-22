extends Node
class_name EnemyStatusEffects

## Handles enemy status effects (DoT and slow).
##
## Responsibilities:
## - Track active status effects by damage type
## - Process DoT tick damage
## - Calculate movement speed multipliers from slow effects
## - Emit signals for status changes

# Status effects - keyed by DamageType, only strongest of each type is active
var active_effects: Dictionary = {}  # DamageType -> StatusEffect

# Dependencies (set via initialize)
var enemy: CharacterBody2D = null

# Signal for visual updates
signal status_visual_changed(effects: Dictionary)

func initialize(p_enemy: CharacterBody2D) -> void:
	"""Initialize component with required references."""
	enemy = p_enemy
	assert(enemy != null, "EnemyStatusEffects: enemy reference required")

func process(delta: float) -> float:
	"""Process all active status effects, returns total DoT damage."""
	var expired_types: Array = []
	var total_dot_damage: float = 0.0

	for dtype in active_effects:
		var effect: StatusEffect = active_effects[dtype] as StatusEffect
		var tick_damage: float = effect.process(delta)
		if tick_damage > 0:
			total_dot_damage += tick_damage
		if effect.is_expired():
			expired_types.append(dtype)

	# Remove expired effects
	for dtype in expired_types:
		active_effects.erase(dtype)
		status_visual_changed.emit(active_effects)

	return total_dot_damage

func apply_status_effect(damage_type: GameEnums.DamageType, dot_damage: float, dot_duration: float, dot_tick_rate: float = 1.0, slow_intensity: float = 0.0) -> void:
	"""Apply a status effect (DoT and/or slow). Uses strongest-per-damage-type logic."""
	if (dot_damage <= 0 and slow_intensity <= 0) or dot_duration <= 0:
		return

	var new_effect := StatusEffect.new(damage_type, dot_damage, dot_duration, dot_tick_rate, slow_intensity)

	if active_effects.has(damage_type):
		var existing: StatusEffect = active_effects[damage_type] as StatusEffect
		# Refresh with potentially stronger damage/slow
		existing.refresh(dot_damage, dot_duration, slow_intensity)
	else:
		active_effects[damage_type] = new_effect
		Events.status_effect_applied.emit(enemy, damage_type)

	status_visual_changed.emit(active_effects)

func get_movement_speed_multiplier() -> float:
	"""Get movement speed multiplier from status effects (slow)."""
	var multiplier: float = 1.0

	# Apply strongest slow effect
	var strongest_slow: float = 0.0
	for effect in active_effects.values():
		if effect.slow_intensity > strongest_slow:
			strongest_slow = effect.slow_intensity

	# Slow intensity reduces speed: 0.3 slow = 0.7x speed
	if strongest_slow > 0:
		multiplier *= (1.0 - strongest_slow)

	return multiplier

func has_status_effect(damage_type: GameEnums.DamageType) -> bool:
	"""Check if enemy has a specific status effect."""
	return active_effects.has(damage_type)

func clear_all_effects() -> void:
	"""Clear all active status effects."""
	active_effects.clear()
	status_visual_changed.emit(active_effects)

func get_active_effects() -> Dictionary:
	"""Get reference to active effects dictionary."""
	return active_effects
