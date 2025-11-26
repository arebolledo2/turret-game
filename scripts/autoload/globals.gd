extends Node

# Autoload singleton for global game state
# Add to Project Settings > Autoload as "Globals"

# Game Constants (from MVP spec)
const ARENA_WIDTH: int = 1920
const ARENA_HEIGHT: int = 1080
const MAX_WAVES: int = 10

# Player Constants
const PLAYER_MAX_HEALTH: float = 100.0
const PLAYER_SPEED: float = 300.0
const PLAYER_PICKUP_RADIUS: float = 50.0
const PLAYER_INVINCIBILITY_TIME: float = 0.5
const PLAYER_WEAPON_DAMAGE: float = 5.0
const PLAYER_WEAPON_FIRE_RATE: float = 3.0  # shots per second
const PLAYER_WEAPON_RANGE: float = 200.0
const PLAYER_PROJECTILE_SPEED: float = 600.0

# Turret Constants
const TURRET_DAMAGE: float = 15.0
const TURRET_FIRE_RATE: float = 2.0  # shots per second
const TURRET_RANGE: float = 400.0
const TURRET_PROJECTILE_SPEED: float = 500.0
const TURRET_ROTATION_SPEED: float = 180.0  # degrees per second
const TURRET_MIN_DISTANCE: float = 100.0  # from other turrets
const TURRET_PLAYER_EXCLUSION: float = 150.0  # won't spawn on player

# Enemy Base Constants (Wave 1)
const ENEMY_BASE_HEALTH: float = 30.0
const ENEMY_BASE_SPEED: float = 150.0
const ENEMY_CONTACT_DAMAGE: float = 33.0
const ENEMY_HP_SCALE: float = 1.10  # 10% per wave
const ENEMY_SPEED_SCALE: float = 1.03  # 3% per wave

# Wave Timing
const WAVE_ANNOUNCEMENT_TIME: float = 1.5
const TURRET_SPAWN_TIME: float = 0.5
const BETWEEN_WAVE_PAUSE: float = 2.0
const WAVE_BASE_DURATION: float = 20.0  # wave 1
const WAVE_DURATION_INCREMENT: float = 4.0  # per wave
const WAVE_BASE_ENEMY_COUNT: int = 10
const WAVE_ENEMY_INCREMENT: int = 4

# Runtime State
var current_wave: int = 0
var total_xp: int = 0
var total_kills: int = 0
var turrets_spawned: int = 0
var time_survived: float = 0.0
var is_game_active: bool = false

# Helper Functions
func get_wave_duration(wave: int) -> float:
	return WAVE_BASE_DURATION + (wave - 1) * WAVE_DURATION_INCREMENT

func get_wave_enemy_count(wave: int) -> int:
	return WAVE_BASE_ENEMY_COUNT + (wave - 1) * WAVE_ENEMY_INCREMENT

func get_enemy_health(wave: int) -> float:
	return ENEMY_BASE_HEALTH * pow(ENEMY_HP_SCALE, wave - 1)

func get_enemy_speed(wave: int) -> float:
	return ENEMY_BASE_SPEED * pow(ENEMY_SPEED_SCALE, wave - 1)

func get_spawn_interval(wave: int) -> float:
	var duration := get_wave_duration(wave)
	var count := get_wave_enemy_count(wave)
	return duration / float(count)

func reset_stats() -> void:
	current_wave = 0
	total_xp = 0
	total_kills = 0
	turrets_spawned = 0
	time_survived = 0.0
	is_game_active = false
