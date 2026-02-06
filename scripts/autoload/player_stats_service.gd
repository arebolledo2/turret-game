extends Node

## Player Stats Service
## Manages player health, speed, luck, and stat modifiers

# Core player stats
var player_luck: float = GameConstants.PLAYER_BASE_LUCK

func reset_state() -> void:
	player_luck = GameConstants.PLAYER_BASE_LUCK


## Get player speed with modifiers applied
func get_player_speed() -> float:
	return ModifierService.apply_modifiers_to_stat(GameConstants.PLAYER_SPEED, "player_speed", "player")


## Get player max health with modifiers applied
func get_player_max_health(difficulty_mult: float) -> float:
	var base_health := GameConstants.PLAYER_BASE_MAX_HEALTH * difficulty_mult
	return ModifierService.apply_modifiers_to_stat(base_health, "player_max_health", "player")


## Get player weapon damage with modifiers applied
func get_player_weapon_damage() -> float:
	return ModifierService.apply_modifiers_to_stat(GameConstants.PLAYER_WEAPON_DAMAGE, "player_weapon_damage", "player")


## Get player fire rate with modifiers applied
func get_player_fire_rate() -> float:
	return ModifierService.apply_modifiers_to_stat(GameConstants.PLAYER_FIRE_RATE, "player_fire_rate", "player")


## Get player luck with modifiers applied, clamped to valid range
func get_player_luck() -> float:
	var modified_luck := ModifierService.apply_modifiers_to_stat(player_luck, "player_luck", "player")
	return clampf(modified_luck, 0.0, GameConstants.PLAYER_MAX_LUCK)


## Get player luck as display integer (0.11 -> 11)
func get_player_luck_display() -> int:
	return int(get_player_luck() * 100.0)


## Get pickup radius with modifiers applied
func get_pickup_radius() -> float:
	return ModifierService.apply_modifiers_to_stat(GameConstants.PLAYER_PICKUP_RADIUS, "pickup_radius", "player")


## Get player crit chance with modifiers applied
func get_player_crit_chance() -> float:
	return ModifierService.apply_modifiers_to_stat(GameConstants.PLAYER_BASE_CRIT_CHANCE, "player_crit_chance", "player")


## Get player crit multiplier with modifiers applied
func get_player_crit_multiplier() -> float:
	return ModifierService.apply_modifiers_to_stat(GameConstants.PLAYER_BASE_CRIT_MULTIPLIER, "player_crit_multiplier", "player")


## Roll for critical hit (returns true if crit)
func roll_player_crit() -> bool:
	return randf() < get_player_crit_chance()


## Calculate crit damage
func calculate_player_crit_damage(base_damage: float) -> float:
	return base_damage * get_player_crit_multiplier()


## Get player health regen with modifiers applied (whole number)
func get_player_health_regen() -> int:
	var modified := ModifierService.apply_modifiers_to_stat(
		float(GameConstants.PLAYER_BASE_HEALTH_REGEN), "player_health_regen", "player"
	)
	return int(modified)


## Get healing interval in seconds (-1 if no healing)
func get_heal_interval() -> float:
	var regen := get_player_health_regen()
	if regen <= 0:
		return -1.0
	return GameConstants.PLAYER_BASE_HEAL_INTERVAL / float(regen)


## Get damage reduction multiplier (0.15 reduction -> 0.85 multiplier)
func get_damage_reduction() -> float:
	var reduction := ModifierService.apply_modifiers_to_stat(0.0, "damage_reduction", "player")
	return clampf(1.0 - reduction, 0.0, 1.0)


## Get evasion chance (0.10 -> 10% chance to dodge)
func get_evasion_chance() -> float:
	return ModifierService.apply_modifiers_to_stat(0.0, "player_evasion", "player")
