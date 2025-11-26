extends Node

# Autoload singleton for global game state
# Add to Project Settings > Autoload as "Globals"

# =============================================================================
# DIFFICULTY SYSTEM
# =============================================================================
enum Difficulty { EASY, MEDIUM, HARD }

# Difficulty configuration - each key modifies base values
# Add new difficulties by adding entries here
const DIFFICULTY_CONFIG: Dictionary = {
	Difficulty.EASY: {
		"name": "Easy",
		"description": "Relaxed gameplay for learning",
		"enemy_health_mult": 1.0,
		"enemy_speed_mult": 1.0,
		"enemy_damage_mult": 1.0,
		"enemy_count_mult": 1.0,
		"enemy_hp_scale_per_wave": 1.10,   # 10% per wave
		"enemy_speed_scale_per_wave": 1.03, # 3% per wave
		"player_health_mult": 1.0,
		"turret_damage_mult": 1.0,
	},
	Difficulty.MEDIUM: {
		"name": "Medium",
		"description": "Balanced challenge",
		"enemy_health_mult": 1.25,
		"enemy_speed_mult": 1.1,
		"enemy_damage_mult": 1.2,
		"enemy_count_mult": 1.2,
		"enemy_hp_scale_per_wave": 1.12,   # 12% per wave
		"enemy_speed_scale_per_wave": 1.04, # 4% per wave
		"player_health_mult": 1.0,
		"turret_damage_mult": 1.0,
	},
	Difficulty.HARD: {
		"name": "Hard",
		"description": "For experienced survivors",
		"enemy_health_mult": 1.5,
		"enemy_speed_mult": 1.2,
		"enemy_damage_mult": 1.5,
		"enemy_count_mult": 1.4,
		"enemy_hp_scale_per_wave": 1.15,   # 15% per wave
		"enemy_speed_scale_per_wave": 1.05, # 5% per wave
		"player_health_mult": 0.8,          # 20% less health
		"turret_damage_mult": 0.9,          # 10% less turret damage
	},
}

var current_difficulty: Difficulty = Difficulty.EASY

# Helper to get current difficulty config
func get_difficulty_config() -> Dictionary:
	return DIFFICULTY_CONFIG[current_difficulty]

func get_difficulty_name() -> String:
	return get_difficulty_config()["name"]

# =============================================================================
# GAME CONSTANTS (Base values - modified by difficulty)
# =============================================================================
const ARENA_WIDTH: int = 1920
const ARENA_HEIGHT: int = 1080
const MAX_WAVES: int = 10

# Player Constants
const PLAYER_BASE_MAX_HEALTH: float = 100.0
const PLAYER_SPEED: float = 300.0
const PLAYER_PICKUP_RADIUS: float = 50.0
const PLAYER_INVINCIBILITY_TIME: float = 0.5
const PLAYER_WEAPON_DAMAGE: float = 5.0
const PLAYER_WEAPON_FIRE_RATE: float = 3.0  # shots per second
const PLAYER_WEAPON_RANGE: float = 200.0
const PLAYER_PROJECTILE_SPEED: float = 600.0

# Computed player values
var PLAYER_MAX_HEALTH: float:
	get: return PLAYER_BASE_MAX_HEALTH * get_difficulty_config()["player_health_mult"]

# Turret Constants
const TURRET_BASE_DAMAGE: float = 15.0
const TURRET_FIRE_RATE: float = 2.0  # shots per second
const TURRET_RANGE: float = 400.0
const TURRET_PROJECTILE_SPEED: float = 500.0
const TURRET_ROTATION_SPEED: float = 180.0  # degrees per second
const TURRET_MIN_DISTANCE: float = 100.0  # from other turrets
const TURRET_PLAYER_EXCLUSION: float = 150.0  # won't spawn on player

# Computed turret values
var TURRET_DAMAGE: float:
	get: return TURRET_BASE_DAMAGE * get_difficulty_config()["turret_damage_mult"]

# Enemy Base Constants (Wave 1)
const ENEMY_BASE_HEALTH: float = 30.0
const ENEMY_BASE_SPEED: float = 150.0
const ENEMY_BASE_CONTACT_DAMAGE: float = 33.0

# Computed enemy scaling factors
var ENEMY_HP_SCALE: float:
	get: return get_difficulty_config()["enemy_hp_scale_per_wave"]

var ENEMY_SPEED_SCALE: float:
	get: return get_difficulty_config()["enemy_speed_scale_per_wave"]

var ENEMY_CONTACT_DAMAGE: float:
	get: return ENEMY_BASE_CONTACT_DAMAGE * get_difficulty_config()["enemy_damage_mult"]

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

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================
func get_wave_duration(wave: int) -> float:
	return WAVE_BASE_DURATION + (wave - 1) * WAVE_DURATION_INCREMENT

func get_wave_enemy_count(wave: int) -> int:
	var base_count := WAVE_BASE_ENEMY_COUNT + (wave - 1) * WAVE_ENEMY_INCREMENT
	return int(base_count * get_difficulty_config()["enemy_count_mult"])

func get_enemy_health(wave: int) -> float:
	var config := get_difficulty_config()
	var base: float = ENEMY_BASE_HEALTH * float(config["enemy_health_mult"])
	return base * pow(float(config["enemy_hp_scale_per_wave"]), wave - 1)

func get_enemy_speed(wave: int) -> float:
	var config := get_difficulty_config()
	var base: float = ENEMY_BASE_SPEED * float(config["enemy_speed_mult"])
	return base * pow(float(config["enemy_speed_scale_per_wave"]), wave - 1)

func get_spawn_interval(wave: int) -> float:
	var duration := get_wave_duration(wave)
	var count := get_wave_enemy_count(wave)
	return duration / float(count)

func set_difficulty(difficulty: Difficulty) -> void:
	current_difficulty = difficulty

func reset_stats() -> void:
	current_wave = 0
	total_xp = 0
	total_kills = 0
	turrets_spawned = 0
	time_survived = 0.0
	is_game_active = false
