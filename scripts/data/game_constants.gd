class_name GameConstants
extends RefCounted

## All game constants in one place for easy tuning

# =============================================================================
# ARENA
# =============================================================================
const ARENA_WIDTH: int = 1400
const ARENA_HEIGHT: int = 900
const MAX_WAVES: int = 10

# =============================================================================
# CAMERA
# =============================================================================
const CAMERA_DEFAULT_ZOOM_BOOST: float = 1.15 # Slightly zoomed in by default

# =============================================================================
# PLAYER
# =============================================================================
const PLAYER_BASE_MAX_HEALTH: float = 100.0
const PLAYER_SPEED: float = 250.0
const PLAYER_PICKUP_RADIUS: float = 50.0
const PLAYER_INVINCIBILITY_TIME: float = 0.5
const PLAYER_WEAPON_DAMAGE: float = 5.0
const PLAYER_WEAPON_FIRE_RATE: float = 3.0 # shots per second
const PLAYER_WEAPON_RANGE: float = 200.0
const PLAYER_PROJECTILE_SPEED: float = 600.0

# =============================================================================
# KNOCKBACK
# =============================================================================
const PLAYER_MELEE_KNOCKBACK_FORCE: float = 180.0
const PLASMA_TURRET_KNOCKBACK_FORCE: float = 120.0
const PLAYER_DEFENSIVE_PULSE_KNOCKBACK_FORCE: float = 250.0
const PLAYER_DEFENSIVE_PULSE_RADIUS: float = 120.0
const KNOCKBACK_DECAY_RATE: float = 8.0 # Per second
const KNOCKBACK_MIN_VELOCITY: float = 5.0 # Stop when below this

# =============================================================================
# TURRET
# =============================================================================
const TURRET_BASE_DAMAGE: float = 15.0
const TURRET_FIRE_RATE: float = 2.0 # shots per second
const TURRET_RANGE: float = 400.0
const TURRET_PROJECTILE_SPEED: float = 500.0
const TURRET_ROTATION_SPEED: float = 180.0 # degrees per second
const TURRET_MIN_DISTANCE: float = 100.0 # from other turrets
const TURRET_PLAYER_EXCLUSION: float = 150.0 # won't spawn on player

# Turret Pickup System
const TURRET_PICKUP_RANGE: float = 60.0
const TURRET_CARRY_OFFSET: Vector2 = Vector2(0, -40)
const TURRET_CARRY_SPEED_PENALTY: float = 0.7
const TURRET_IN_RANGE_INDICATOR_ALPHA: float = 0.5

# =============================================================================
# ENEMY (Base values for Wave 1)
# =============================================================================
const ENEMY_BASE_HEALTH: float = 30.0
const ENEMY_BASE_SPEED: float = 100.0
const ENEMY_BASE_CONTACT_DAMAGE: float = 33.0

# =============================================================================
# WAVE TIMING
# =============================================================================
const WAVE_ANNOUNCEMENT_TIME: float = 1.5
const TURRET_SPAWN_TIME: float = 0.5
const BETWEEN_WAVE_PAUSE: float = 0.5
const WAVE_BASE_DURATION: float = 25.0 # wave 1
const WAVE_DURATION_INCREMENT: float = 4.0 # per wave
const WAVE_BASE_ENEMY_COUNT: int = 10
const WAVE_ENEMY_INCREMENT: int = 4

# Wave duration scaling (non-linear curve)
const WAVE_DURATION_EARLY: float = 25.0 # Waves 1
const WAVE_DURATION_MID: float = 50.0 # Waves 2-4 target
const WAVE_DURATION_LATE: float = 60.0 # Waves 5-6 target
const WAVE_DURATION_CAP: float = 60.0 # Wave 7+ cap
const WAVE_DURATION_MID_THRESHOLD: int = 5
const WAVE_DURATION_LATE_THRESHOLD: int = 7

# =============================================================================
# ECONOMY
# =============================================================================
const STARTING_GOLD: int = 0
const GOLD_PER_ENEMY: int = 1
const GOLD_WAVE_BONUS_BASE: int = 0
const SHOP_OFFER_COUNT: int = 4
const REROLL_BASE_COST: int = 1
const REROLL_COST_INCREMENT: int = 1
# Removed MAX_REROLLS_PER_WAVE - infinite rerolls allowed (cost still scales)
const WAVE_PRICE_SCALE: float = 0.15
const TURRET_PURCHASE_PENALTY: float = 0.25 # +25% per turret owned
const SHOP_ITEM_CHANCE: float = 0.65 # 65% item, 35% turret

# =============================================================================
# TECH DROP
# =============================================================================
const TECH_DROP_SPAWN_INTERVAL: float = 5.0
const TECH_DROP_SPAWN_CHANCE: float = 0.20
const TECH_DROP_BASE_HEALTH: float = 60.0
const TECH_DROP_XP_REWARD: int = 100
const TECH_DROP_GOLD_REWARD: int = 0
const TECH_DROP_SCATTER_COUNT: int = 5
const TECH_DROP_SCATTER_RADIUS: float = 80.0

# =============================================================================
# RARITY / LUCK SYSTEM
# =============================================================================

# Base rarity weights (higher = more common)
# These are the weights when luck = 0 and wave = 1
const RARITY_BASE_WEIGHTS: Dictionary = {
	GameEnums.ItemRarity.COMMON: 100.0,
	GameEnums.ItemRarity.UNCOMMON: 40.0,
	GameEnums.ItemRarity.RARE: 15.0,
	GameEnums.ItemRarity.EPIC: 5.0,
	GameEnums.ItemRarity.LEGENDARY: 1.0,
	GameEnums.ItemRarity.UNIQUE: 0.0, # Special drops only
}

# How much each point of luck (0.0-1.0) shifts weight toward higher rarities
# At luck=1.0, apply these multipliers to base weights
const LUCK_WEIGHT_MULTIPLIERS: Dictionary = {
	GameEnums.ItemRarity.COMMON: 0.5, # Common becomes less likely
	GameEnums.ItemRarity.UNCOMMON: 0.8, # Uncommon slightly less likely
	GameEnums.ItemRarity.RARE: 1.5, # Rare more likely
	GameEnums.ItemRarity.EPIC: 2.5, # Epic much more likely
	GameEnums.ItemRarity.LEGENDARY: 4.0, # Legendary very boosted
	GameEnums.ItemRarity.UNIQUE: 1.0, # Unique unchanged (special only)
}

# Wave-based rarity unlocks (items below min_wave can't appear)
const RARITY_MIN_WAVE: Dictionary = {
	GameEnums.ItemRarity.COMMON: 1,
	GameEnums.ItemRarity.UNCOMMON: 1,
	GameEnums.ItemRarity.RARE: 2,
	GameEnums.ItemRarity.EPIC: 4,
	GameEnums.ItemRarity.LEGENDARY: 6,
	GameEnums.ItemRarity.UNIQUE: 1, # Special conditions only
}

# Wave-based weight bonus (per wave after min_wave)
const RARITY_WAVE_BONUS_PER_WAVE: float = 0.05 # +5% weight per wave past min

# Player luck configuration
const PLAYER_BASE_LUCK: float = 0.0
const PLAYER_MAX_LUCK: float = 2.0 # Cap at 200% for sanity

# =============================================================================
# DIFFICULTY CONFIGURATIONS
# =============================================================================
const DIFFICULTY_CONFIG: Dictionary = {
	GameEnums.Difficulty.EASY: {
		"name": "Easy",
		"description": "Relaxed gameplay for learning",
		"enemy_health_mult": 1.0,
		"enemy_speed_mult": 1.0,
		"enemy_damage_mult": 1.0,
		"enemy_count_mult": 1.0,
		"enemy_hp_scale_per_wave": 1.10,
		"enemy_speed_scale_per_wave": 1.0,
		"player_health_mult": 1.0,
		"turret_damage_mult": 1.0,
	},
	GameEnums.Difficulty.MEDIUM: {
		"name": "Medium",
		"description": "Balanced challenge",
		"enemy_health_mult": 1.25,
		"enemy_speed_mult": 1.0,
		"enemy_damage_mult": 1.2,
		"enemy_count_mult": 1.2,
		"enemy_hp_scale_per_wave": 1.12,
		"enemy_speed_scale_per_wave": 1.0,
		"player_health_mult": 1.0,
		"turret_damage_mult": 1.0,
	},
	GameEnums.Difficulty.HARD: {
		"name": "Hard",
		"description": "For experienced survivors",
		"enemy_health_mult": 1.5,
		"enemy_speed_mult": 1.0,
		"enemy_damage_mult": 1.5,
		"enemy_count_mult": 1.4,
		"enemy_hp_scale_per_wave": 1.15,
		"enemy_speed_scale_per_wave": 1.0,
		"player_health_mult": 0.8,
		"turret_damage_mult": 0.9,
	},
}
