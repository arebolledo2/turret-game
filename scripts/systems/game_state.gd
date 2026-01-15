class_name RuntimeGameState
extends RefCounted

## Runtime game state - all mutable data that changes during gameplay
## This is the core data that would need to be serialized for save games

# Current difficulty
var current_difficulty: GameEnums.Difficulty = GameEnums.Difficulty.EASY

# Wave progress
var current_wave: int = 0
var is_game_active: bool = false

# Player stats
var total_scrap: int = 0
var total_kills: int = 0
var turrets_spawned: int = 0
var time_survived: float = 0.0
var player_level: int = 1

# Economy (Note: total_scrap is also tracked in player stats above for legacy reasons)
var shop_reroll_count: int = 0
var current_shop_offers: Array = []
var pending_turret_purchases: Array[String] = []

# Inventory
var collected_items: Array[String] = []
var turret_counts: Dictionary = {} # {"normal": 2, "fire": 1, etc.}
var selected_turret_type: String = ""

# Settings
var show_damage_numbers: bool = true
var player_auto_attack_enabled: bool = false
var show_turret_ranges: bool = false

# Modifier system instance (for isolated state, e.g., save games)
var modifiers: ModifierSystem = ModifierSystem.new()


## Get the current difficulty configuration
func get_difficulty_config() -> Dictionary:
	return GameConstants.DIFFICULTY_CONFIG[current_difficulty]


## Get the name of the current difficulty
func get_difficulty_name() -> String:
	return get_difficulty_config()["name"]


## Set the difficulty level
func set_difficulty(difficulty: GameEnums.Difficulty) -> void:
	current_difficulty = difficulty


## Get total turret count across all types
func get_total_turret_count() -> int:
	var total := 0
	for count in turret_counts.values():
		total += count
	return total


## Get player max health with difficulty and modifiers applied
func get_player_max_health() -> float:
	var base_health: float = GameConstants.PLAYER_BASE_MAX_HEALTH * get_difficulty_config()["player_health_mult"]
	return modifiers.get_player_max_health(base_health)


## Get player speed with modifiers applied
func get_player_speed() -> float:
	return modifiers.get_player_speed(GameConstants.PLAYER_SPEED)


## Get player weapon damage with modifiers applied
func get_player_weapon_damage() -> float:
	return modifiers.get_player_weapon_damage(GameConstants.PLAYER_WEAPON_DAMAGE)


## Get turret stats with difficulty and modifiers applied
func get_turret_stats(turret_type: String) -> Dictionary:
	return modifiers.get_turret_stats(turret_type, get_difficulty_config())


## Get wave duration for a specific wave
func get_wave_duration(wave: int) -> float:
	# Linear scaling: 30s, 35s, 40s, 45s, 50s, 55s, 60s (capped at wave 7+)
	if wave >= GameConstants.WAVE_DURATION_CAP_THRESHOLD:
		return GameConstants.WAVE_DURATION_CAP
	var duration: float = GameConstants.WAVE_DURATION_BASE + (wave - 1) * GameConstants.WAVE_DURATION_INCREMENT
	return duration


## Get enemy count for a specific wave
func get_wave_enemy_count(wave: int) -> int:
	var base_count := GameConstants.WAVE_BASE_ENEMY_COUNT + (wave - 1) * GameConstants.WAVE_ENEMY_INCREMENT
	return int(base_count * get_difficulty_config()["enemy_count_mult"])


## Get spawn interval for a specific wave
func get_spawn_interval(wave: int) -> float:
	var duration := get_wave_duration(wave)
	var count := get_wave_enemy_count(wave)
	return duration / float(count)


## Get enemy health for a specific wave (using base enemy stats)
func get_enemy_health(wave: int) -> float:
	var config: Dictionary = get_difficulty_config()
	var base: float = GameConstants.ENEMY_BASE_HEALTH * float(config["enemy_health_mult"])
	return base * pow(float(config["enemy_hp_scale_per_wave"]), wave - 1)


## Get enemy speed for a specific wave
func get_enemy_speed(wave: int) -> float:
	var config: Dictionary = get_difficulty_config()
	var base: float = GameConstants.ENEMY_BASE_SPEED * float(config["enemy_speed_mult"])
	return base * pow(float(config["enemy_speed_scale_per_wave"]), wave - 1)


## Get enemy contact damage with difficulty applied
func get_enemy_contact_damage() -> float:
	return GameConstants.ENEMY_BASE_CONTACT_DAMAGE * get_difficulty_config()["enemy_damage_mult"]


## Reset all state for a new game
func reset() -> void:
	current_wave = 0
	total_scrap = 0
	total_kills = 0
	turrets_spawned = 0
	time_survived = 0.0
	is_game_active = false
	player_level = 1
	turret_counts.clear()
	selected_turret_type = ""
	collected_items.clear()
	modifiers.clear_modifiers()
	shop_reroll_count = 0
	current_shop_offers.clear()
	pending_turret_purchases.clear()
