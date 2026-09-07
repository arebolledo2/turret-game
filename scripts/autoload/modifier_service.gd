extends Node

## Modifier Service Autoload
## Singleton wrapper that delegates to an internal ModifierSystem instance
## This provides global access while keeping ModifierSystem testable as a class

var _system: ModifierSystem = ModifierSystem.new()


# =============================================================================
# DELEGATED PROPERTIES
# =============================================================================

var active_modifiers: Array:
	get: return _system.get_all_modifiers()


func load_modifiers(modifiers: Array) -> void:
	"""Replace all modifiers with a new set. Use this instead of setting active_modifiers directly."""
	_system.clear_modifiers()
	for modifier in modifiers:
		_system.add_modifier(modifier)
	Events.modifiers_changed.emit()


# =============================================================================
# DELEGATED METHODS - BASIC OPERATIONS
# =============================================================================

func add_modifier(modifier: Dictionary) -> Dictionary:
	var added := _system.add_modifier(modifier)
	Events.modifiers_changed.emit()
	return added


func remove_modifier(modifier_id: String) -> bool:
	var removed := _system.remove_modifier(modifier_id)
	if removed:
		Events.modifiers_changed.emit()
	return removed


func clear_modifiers() -> void:
	_system.clear_modifiers()
	Events.modifiers_changed.emit()


func get_all_modifiers() -> Array:
	return _system.get_all_modifiers()


# =============================================================================
# DELEGATED METHODS - STAT CALCULATIONS
# =============================================================================

func apply_modifiers_to_stat(base_value: float, stat_name: String, entity_type: String = "player") -> float:
	return _system.apply_to_stat(base_value, stat_name, entity_type)


func get_turret_stats(turret_type: String, difficulty_config: Dictionary) -> Dictionary:
	return _system.get_turret_stats(turret_type, difficulty_config, SpecialEffectService.apply_static_effects)


func get_player_speed(base_speed: float) -> float:
	return _system.get_player_speed(base_speed)


func get_player_max_health(base_health: float) -> float:
	return _system.get_player_max_health(base_health)


func get_player_weapon_damage(base_damage: float) -> float:
	return _system.get_player_weapon_damage(base_damage)


func get_player_luck(base_luck: float) -> float:
	return _system.get_player_luck(base_luck)


func get_reroll_cost_multiplier() -> float:
	return _system.get_reroll_cost_multiplier()


func add_modifiers(modifiers: Array) -> void:
	for modifier in modifiers:
		_system.add_modifier(modifier)
	if not modifiers.is_empty():
		Events.modifiers_changed.emit()
