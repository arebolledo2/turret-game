extends Node

## Player Stats Service
## Manages player health, speed, luck, and stat modifiers

# Core player stats
var player_luck: float = GameConstants.PLAYER_BASE_LUCK

# Modifier system reference (lazy loaded)
var _modifier_service: ModifierService = null

func _get_modifier_service() -> ModifierService:
	if _modifier_service == null:
		_modifier_service = get_node("/root/ModifierService")
	return _modifier_service


func reset_state() -> void:
	player_luck = GameConstants.PLAYER_BASE_LUCK


## Get player speed with modifiers applied
func get_player_speed() -> float:
	return _get_modifier_service().apply_modifiers_to_stat(GameConstants.PLAYER_SPEED, "player_speed")


## Get player max health with modifiers applied
func get_player_max_health(difficulty_mult: float) -> float:
	var base_health := GameConstants.PLAYER_BASE_MAX_HEALTH * difficulty_mult
	return _get_modifier_service().apply_modifiers_to_stat(base_health, "player_max_health")


## Get player weapon damage with modifiers applied
func get_player_weapon_damage() -> float:
	return _get_modifier_service().apply_modifiers_to_stat(GameConstants.PLAYER_WEAPON_DAMAGE, "player_weapon_damage")


## Get player luck with modifiers applied, clamped to valid range
func get_player_luck() -> float:
	var modified_luck := _get_modifier_service().apply_modifiers_to_stat(player_luck, "player_luck")
	return clampf(modified_luck, 0.0, GameConstants.PLAYER_MAX_LUCK)


## Get player luck as display integer (0.11 -> 11)
func get_player_luck_display() -> int:
	return int(get_player_luck() * 100.0)


## Get pickup radius with modifiers applied
func get_pickup_radius() -> float:
	return _get_modifier_service().apply_modifiers_to_stat(GameConstants.PLAYER_PICKUP_RADIUS, "pickup_radius")
