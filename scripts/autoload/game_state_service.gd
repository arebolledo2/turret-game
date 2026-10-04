extends Node

var state: RunSessionState = RunSessionState.new()

## Game State Service
## Manages wave progression, kills, time, and game lifecycle

# Wave system
var current_wave: int:
	get: return state.current_wave
	set(value): state.current_wave = value

# Stats tracking
var total_kills: int:
	get: return state.total_kills
	set(value): state.total_kills = value
var total_scrap: int:
	get: return state.lifetime_scrap
	set(value): state.lifetime_scrap = value

# Time tracking
var time_survived: float:
	get: return state.time_survived
	set(value): state.time_survived = value
var is_game_active: bool:
	get: return state.is_game_active
	set(value): state.is_game_active = value

# Turret spawning
var turrets_spawned: int:
	get: return state.turrets_spawned
	set(value): state.turrets_spawned = value


func reset_state() -> void:
	current_wave = 0
	total_kills = 0
	total_scrap = 0
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
