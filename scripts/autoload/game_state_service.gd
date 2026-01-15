extends Node

## Game State Service
## Manages wave progression, kills, time, and game lifecycle

# Wave system
var current_wave: int = 0

# Stats tracking
var total_kills: int = 0
var total_scrap: int = 0
var player_level: int = 1

# Time tracking
var time_survived: float = 0.0
var is_game_active: bool = false

# Turret spawning
var turrets_spawned: int = 0
var wave_controller: Node = null # Reference set by GameManager


func reset_state() -> void:
	current_wave = 0
	total_kills = 0
	total_scrap = 0
	player_level = 1
	turrets_spawned = 0
	time_survived = 0.0
	is_game_active = false


## Get wave duration in seconds
func get_wave_duration(wave: int) -> float:
	# Linear scaling: 30s, 35s, 40s, 45s, 50s, 55s, 60s (capped at wave 7+)
	if wave >= GameConstants.WAVE_DURATION_CAP_THRESHOLD:
		return GameConstants.WAVE_DURATION_CAP
	var duration: float = GameConstants.WAVE_DURATION_BASE + (wave - 1) * GameConstants.WAVE_DURATION_INCREMENT
	return duration


## Get total enemy count for a wave (includes difficulty and item modifiers)
func get_wave_enemy_count(wave: int, difficulty_mult: float, item_mult: float) -> int:
	var base_count := GameConstants.WAVE_BASE_ENEMY_COUNT + (wave - 1) * GameConstants.WAVE_ENEMY_INCREMENT
	return int(base_count * difficulty_mult * item_mult)


## Get spawn interval (time between enemy spawns)
func get_spawn_interval(wave: int, difficulty_mult: float, item_mult: float) -> float:
	var duration := get_wave_duration(wave)
	var count := get_wave_enemy_count(wave, difficulty_mult, item_mult)
	return duration / float(count)
