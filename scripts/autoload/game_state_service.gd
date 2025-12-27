extends Node

## Game State Service
## Manages wave progression, XP, kills, time, and game lifecycle

# Wave system
var current_wave: int = 0

# XP and progression
var total_xp: int = 0
var total_kills: int = 0
var player_level: int = 1

# Time tracking
var time_survived: float = 0.0
var is_game_active: bool = false

# Turret spawning
var turrets_spawned: int = 0


func reset_state() -> void:
	current_wave = 0
	total_xp = 0
	total_kills = 0
	turrets_spawned = 0
	time_survived = 0.0
	is_game_active = false
	player_level = 1


## Get wave duration in seconds
func get_wave_duration(wave: int) -> float:
	# Uses linear scaling defined in GameConstants:
	# Wave 1: EARLY (40s)
	# Waves 2: lerp to MID (45s)
	# Wave 3: MID (50s)
	# Wave 4: lerp to LATE (55s)
	# Wave 5+: CAP (60s)
	if wave <= 1:
		return GameConstants.WAVE_DURATION_EARLY
	elif wave < GameConstants.WAVE_DURATION_MID_THRESHOLD:
		# Linear interpolation between EARLY and MID over waves 1 to MID_THRESHOLD
		var t: float = float(wave - 1) / float(GameConstants.WAVE_DURATION_MID_THRESHOLD - 1)
		return lerpf(GameConstants.WAVE_DURATION_EARLY, GameConstants.WAVE_DURATION_MID, t)
	elif wave < GameConstants.WAVE_DURATION_LATE_THRESHOLD:
		# Linear interpolation between MID and LATE over waves MID_THRESHOLD to LATE_THRESHOLD
		var t: float = float(wave - GameConstants.WAVE_DURATION_MID_THRESHOLD) / float(GameConstants.WAVE_DURATION_LATE_THRESHOLD - GameConstants.WAVE_DURATION_MID_THRESHOLD)
		return lerpf(GameConstants.WAVE_DURATION_MID, GameConstants.WAVE_DURATION_LATE, t)
	else:
		return GameConstants.WAVE_DURATION_CAP


## Get total enemy count for a wave (includes difficulty and item modifiers)
func get_wave_enemy_count(wave: int, difficulty_mult: float, item_mult: float) -> int:
	var base_count := GameConstants.WAVE_BASE_ENEMY_COUNT + (wave - 1) * GameConstants.WAVE_ENEMY_INCREMENT
	return int(base_count * difficulty_mult * item_mult)


## Get spawn interval (time between enemy spawns)
func get_spawn_interval(wave: int, difficulty_mult: float, item_mult: float) -> float:
	var duration := get_wave_duration(wave)
	var count := get_wave_enemy_count(wave, difficulty_mult, item_mult)
	return duration / float(count)
