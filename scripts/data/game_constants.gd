class_name GameConstants
extends RefCounted

## All game constants in one place for easy tuning

# =============================================================================
# ARENA
# =============================================================================
const ARENA_WIDTH: int = 1920
const ARENA_HEIGHT: int = 1080
const MAX_WAVES: int = 10

# =============================================================================
# CAMERA
# =============================================================================
const CAMERA_DEFAULT_ZOOM_BOOST: float = 2 # Zoomed in for better visibility

# =============================================================================
# PLAYER
# =============================================================================
const PLAYER_BASE_MAX_HEALTH: float = 25.0
const PLAYER_SPEED: float = 250.0
const PLAYER_PICKUP_RADIUS: float = 50.0
const PLAYER_INVINCIBILITY_TIME: float = 0.5
const PLAYER_WEAPON_DAMAGE: float = 1.0 # Legacy - used by PlayerStatsService for item bonuses

# Player Turret Combat
const PLAYER_TURRET_DAMAGE: float = 12.0
const PLAYER_TURRET_FIRE_RATE: float = 1.2 # shots per second (matches basic turret)
const PLAYER_TURRET_RANGE: float = 375.0
const PLAYER_TURRET_PROJECTILE_SPEED: float = 700.0

# Health Regeneration
const PLAYER_BASE_HEALTH_REGEN: int = 0 # Whole number, 0 = no healing
const PLAYER_BASE_HEAL_INTERVAL: float = 10.0 # Seconds at regen=1
const PLAYER_HEAL_AMOUNT: float = 1.0 # HP per healing pip (kept at minimum for gameplay)

# =============================================================================
# KNOCKBACK
# =============================================================================
const PLASMA_TURRET_KNOCKBACK_FORCE: float = 120.0
const PLAYER_DEFENSIVE_PULSE_KNOCKBACK_FORCE: float = 250.0
const PLAYER_DEFENSIVE_PULSE_RADIUS: float = 120.0
const KNOCKBACK_DECAY_RATE: float = 8.0 # Per second
const KNOCKBACK_MIN_VELOCITY: float = 5.0 # Stop when below this

# =============================================================================
# CRITICAL HIT SYSTEM
# =============================================================================
const PLAYER_BASE_CRIT_CHANCE: float = 0.05 # 5%
const PLAYER_BASE_CRIT_MULTIPLIER: float = 2.0 # 200% damage (100% bonus)
const TURRET_BASE_CRIT_CHANCE: float = 0.05 # 5%
const TURRET_BASE_CRIT_MULTIPLIER: float = 2.0 # 200% damage (100% bonus)

# =============================================================================
# TURRET
# =============================================================================
const TURRET_BASE_DAMAGE: float = 15.0
const TURRET_FIRE_RATE: float = 2.0 # shots per second
const TURRET_RANGE: float = 600.0
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
const ENEMY_BASE_HEALTH: float = 8.0
const ENEMY_BASE_SPEED: float = 100.0
const ENEMY_BASE_CONTACT_DAMAGE: float = 8.0

# Enemy Ranks
const ENEMY_RANK_LT_HP_MULT: float = 8.0
const ENEMY_RANK_LT_SCALE_MULT: float = 1.5
const ENEMY_RANK_LT_SPEED_MULT: float = 0.8
const ENEMY_RANK_LT_SCRAP_DROP_COUNT: int = 10 # Number of 1-scrap pickups to scatter
const ENEMY_RANK_LT_MASS_MULT: float = 3.0
const ENEMY_RANK_LT_COLOR: Color = Color(1.0, 0.8, 0.4, 1.0) # Golden hue

const ENEMY_RANK_CAPT_HP_MULT: float = 25.0
const ENEMY_RANK_CAPT_SCALE_MULT: float = 2.5
const ENEMY_RANK_CAPT_SPEED_MULT: float = 0.6
const ENEMY_RANK_CAPT_SCRAP_DROP_COUNT: int = 50 # Number of 1-scrap pickups to scatter
const ENEMY_RANK_CAPT_MASS_MULT: float = 10.0
const ENEMY_RANK_CAPT_COLOR: Color = Color(1.0, 0.3, 0.3, 1.0) # Bright red hue

const ENEMY_RANK_LT_MIN_WAVE: int = 5
const ENEMY_RANK_LT_PER_WAVE_MIN: int = 0
const ENEMY_RANK_LT_PER_WAVE_MAX: int = 2
const ENEMY_RANK_CAPT_WAVE: int = 10

# =============================================================================
# WAVE TIMING
# =============================================================================
const WAVE_ANNOUNCEMENT_TIME: float = 1.5
const TURRET_SPAWN_TIME: float = 0.5
const BETWEEN_WAVE_PAUSE: float = 0.5
const WAVE_BASE_ENEMY_COUNT: int = 22
const WAVE_ENEMY_INCREMENT: int = 8

# Wave duration scaling (linear progression: 30s, 35s, 40s, 45s, 50s, 55s, 60s+)
const WAVE_DURATION_BASE: float = 30.0 # Wave 1
const WAVE_DURATION_INCREMENT: float = 5.0 # Per wave
const WAVE_DURATION_CAP: float = 60.0 # Wave 7+ cap
const WAVE_DURATION_CAP_THRESHOLD: int = 7

# =============================================================================
# ECONOMY
# =============================================================================
const STARTING_SCRAP: int = 20
const SCRAP_PER_ENEMY: int = 1
const SCRAP_WAVE_BONUS_BASE: int = 0
const SHOP_OFFER_COUNT: int = 4
const REROLL_BASE_COST: int = 1
const REROLL_COST_INCREMENT: int = 1
const REROLL_WAVE_BASE_MULTIPLIER: float = 1.5 # Wave-based base cost multiplier
# Removed MAX_REROLLS_PER_WAVE - infinite rerolls allowed (cost still scales)
const WAVE_PRICE_SCALE: float = 0.2
const TURRET_PURCHASE_PENALTY: float = 0.5 # +50% per turret owned
const SHOP_ITEM_CHANCE: float = 0.65 # 65% item, 35% turret

# =============================================================================
# TECH DROP
# =============================================================================
const TECH_DROP_SPAWN_INTERVAL: float = 5.0
const TECH_DROP_SPAWN_CHANCE: float = 0.20
const TECH_DROP_BASE_HEALTH: float = 15.0
const TECH_DROP_SCRAP_REWARD: int = 5
const TECH_DROP_SCATTER_COUNT: int = 5
const TECH_DROP_SCATTER_RADIUS: float = 80.0
const TECH_DROP_ITEM_DROP_CHANCE: float = 0.30 # 30% chance to drop item when destroyed

# =============================================================================
# GAME MODE ENTITIES
# =============================================================================
# Tech Defense
const DEFENSE_TARGET_BASE_HEALTH: float = 125.0
const DEFENSE_TARGET_REFLECT_PERCENT: float = 0.50 # 50% damage reflected
const DEFENSE_TARGET_KNOCKBACK_MULTIPLIER: float = 1.5 # 1.5x base knockback
const DEFENSE_TARGET_SLOW_INTENSITY: float = 0.30 # 30% slow
const DEFENSE_TARGET_SLOW_DURATION: float = 3.0 # 3 seconds
const DEFENSE_TARGET_BARRIER_DURATION: float = 5.0 # 5 seconds immunity
const DEFENSE_TARGET_BARRIER_COOLDOWN: float = 10.0 # 10 seconds between barriers
const DEFENSE_TARGET_HEAL_BETWEEN_WAVES: float = 25.0 # HP healed between waves
const DEFENSE_MODE_PLAYER_AGGRO_RANGE: float = 250.0 # Enemies switch from defense target to player if within this range
const DEFENSE_MODE_PLAYER_DEAGGRO_RANGE: float = 500.0 # Enemies switch back to defense target if player beyond this range
const ESCORT_ARRIVAL_TIME_RATIO: float = 1.0 # Payload arrives exactly at wave end (Perfect Sync)

# Tunneling
const TUNNEL_DOOR_BASE_HEALTH: float = 50.0 # HP that must be damaged by turrets
const TUNNEL_DOOR_HEALTH_SCALE_PER_WAVE: float = 13.0 # +50 HP per wave
const TUNNELING_ALERT_SOFT_TIMER_MULTIPLIER: float = 1.5 # Alert starts at 150% of normal wave time
const TUNNELING_ALERT_ESCALATION_RATE: float = 0.30 # +30% spawn rate
const TUNNELING_ALERT_ESCALATION_INTERVAL: float = 8.0 # Every 8 seconds

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
		"enemy_count_mult": 1.8,
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
		"enemy_count_mult": 2.2,
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
		"enemy_count_mult": 2.6,
		"enemy_hp_scale_per_wave": 1.15,
		"enemy_speed_scale_per_wave": 1.0,
		"player_health_mult": 0.8,
		"turret_damage_mult": 0.9,
	},
}
