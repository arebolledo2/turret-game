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
	set(value):
		_system.clear_modifiers()
		for modifier in value:
			_system.add_modifier(modifier)


# =============================================================================
# DELEGATED METHODS - BASIC OPERATIONS
# =============================================================================

func add_modifier(modifier: Dictionary) -> Dictionary:
	return _system.add_modifier(modifier)


func remove_modifier(modifier_id: String) -> bool:
	return _system.remove_modifier(modifier_id)


func clear_modifiers() -> void:
	_system.clear_modifiers()


func get_all_modifiers() -> Array:
	return _system.get_all_modifiers()


# =============================================================================
# DELEGATED METHODS - STAT CALCULATIONS
# =============================================================================

func apply_modifiers_to_stat(base_value: float, stat_name: String, entity_type: String = "player") -> float:
	return _system.apply_to_stat(base_value, stat_name, entity_type)


func get_turret_stats(turret_type: String, difficulty_config: Dictionary) -> Dictionary:
	return _system.get_turret_stats(turret_type, difficulty_config)


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
