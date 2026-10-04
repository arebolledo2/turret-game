class_name GameConstants
extends RefCounted

## All game constants in one place for easy tuning

# =============================================================================
# CAMERA
# =============================================================================
# 3D follow camera (orthographic). Size is the vertical view extent in metres at zoom 1.0.
const CAMERA_BASE_SIZE: float = 10.0
const CAMERA_DEFAULT_ZOOM: float = 1.5
const CAMERA_ZOOM_MIN: float = 0.5
const CAMERA_ZOOM_MAX: float = 2.0
const CAMERA_ZOOM_SPEED: float = 10.0 # smoothing rate toward the target zoom
const CAMERA_ZOOM_WHEEL_STEP: float = 1.12 # multiplier per wheel notch
const CAMERA_ZOOM_HELD_RATE: float = 1.6 # exp rate/second while a zoom key or trigger is held
const CAMERA_FOLLOW_SPEED: float = 8.0 # smoothing rate toward the player
const CAMERA_EDGE_MARGIN: float = 0.5 # metres of floor rim allowed past the arena bounds
# Enemies appear this far outside the default-zoom view, never closer than SPAWN_MIN_DISTANCE to the player.
const ENEMY_SPAWN_VIEW_MARGIN: float = 2.0
const ENEMY_SPAWN_MIN_DISTANCE: float = 6.0

# =============================================================================
# PLAYER
# =============================================================================
const PLAYER_BASE_MAX_HEALTH: float = 25.0
const PLAYER_SPEED: float = 250.0
const PLAYER_ACCELERATION: float = 1400.0
const PLAYER_DECELERATION: float = 1800.0
const PLAYER_MOVEMENT_DEADZONE: float = 0.1
const PLAYER_PICKUP_RADIUS: float = 50.0
const PLAYER_INVINCIBILITY_TIME: float = 0.5

# Player Turret Combat
const PLAYER_TURRET_DAMAGE: float = 12.0
const PLAYER_FIRE_RATE: float = 1.2 # Standardized key for services
const PLAYER_TURRET_RANGE: float = 375.0
const PLAYER_TURRET_PROJECTILE_SPEED: float = 700.0

# Health Regeneration
const PLAYER_BASE_HEALTH_REGEN: int = 0 # Whole number, 0 = no healing
const PLAYER_BASE_HEAL_INTERVAL: float = 10.0 # Seconds at regen=1

# =============================================================================
# KNOCKBACK
# =============================================================================
const KNOCKBACK_DECAY_RATE: float = 8.0 # Per second
const KNOCKBACK_MAX_VELOCITY: float = 900.0 # Prevent stacked hits from launching enemies

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
const TURRET_SPLASH_AOE_RADIUS: float = 40.0 # Base radius granted by Splash Damage tech
const TURRET_MIN_DISTANCE: float = 100.0 # from other turrets

# Turret Pickup System
const TURRET_CARRY_SPEED_PENALTY: float = 0.7

# ITEM CONDITIONS
const LAST_STAND_HULL_FRACTION: float = 0.3
const STORM_LINK_RANGE: float = 4.0 # metres between linked electric turrets
const REACTOR_BLAST_DAMAGE_FRACTION: float = 0.4
const REACTOR_BLAST_RADIUS_FRACTION: float = 0.6
const REACTOR_MAX_CHAIN_DEPTH: int = 3

# ENTRENCH (turrets earn stacks by staying put; picking one up resets them)
const ENTRENCH_STACK_SECONDS: float = 4.0
const ENTRENCH_MAX_STACKS: int = 5
const ENTRENCH_DAMAGE_PER_STACK: float = 0.06
const ENTRENCH_FIRE_RATE_PER_STACK: float = 0.04

# =============================================================================
# ENEMY (Base values for Wave 1)
# =============================================================================
const ENEMY_BASE_HEALTH: float = 8.0

# =============================================================================
# WAVE TIMING
# =============================================================================
const WAVE_BASE_ENEMY_COUNT: int = 22
const WAVE_ENEMY_INCREMENT: int = 8

# Wave duration scaling (linear progression: 30s, 35s, 40s, 45s, 50s, 55s, 60s+)
const WAVE_DURATION_BASE: float = 30.0 # Wave 1
const WAVE_DURATION_INCREMENT: float = 5.0 # Per wave
const WAVE_DURATION_CAP: float = 60.0 # Wave 7+ cap
const WAVE_DURATION_CAP_THRESHOLD: int = 7

# Run length (RunConfig default). Wave duration above caps at one minute from wave 7.
const RUN_DEFAULT_WAVE_LIMIT: int = 20
const RUN_MAX_WAVE_LIMIT: int = 100

# =============================================================================
# ECONOMY
# =============================================================================
const STARTING_SCRAP: int = 20
const SCRAP_WAVE_BONUS_BASE: int = 0
const SCRAP_WAVE_BONUS_PER_WAVE: int = 5 # added to the wave bonus for each wave number
const REPAIR_COST: int = 5
const REPAIR_HEAL_AMOUNT: float = 10.0

# =============================================================================
# PROTECT THE CORE (core mode)
# =============================================================================
const CORE_HEALTH_MULT: float = 6.0 # core hit points = base hull x this x the difficulty's core_health_mult
const CORE_RADIUS: float = 1.1 # metres; enemies stop at its edge
const CORE_PLACEMENT_CLEARANCE: float = .7 # turrets keep this far outside the core's radius
const CORE_HIT_INTERVAL: float = 1.0 # seconds between one enemy's hits on the core
const CORE_DAMAGE_FRACTION: float = .25 # share of an enemy's contact damage the core takes
const CORE_AGGRO_RANGE: float = 2.5 # an enemy this close to the hero chases the hero (the 2D game's 250 px)
const CORE_DEAGGRO_RANGE: float = 5.0 # ...and gives up and returns to the core beyond this (2D: 500 px)
const CORE_SPAWN_BOX: float = .6 # enemies spawn on this fraction of the arena's half-size, so they reach the fight in time
const CORE_START_OFFSET: float = 2.5 # hero and first turret start this far from the core
const SHOP_OFFER_COUNT: int = 4
# 3D shop layout: one weapon choice and three upgrades (SHOP_TURRET_SLOTS + SHOP_ITEM_SLOTS = SHOP_OFFER_COUNT)
const SHOP_TURRET_SLOTS: int = 1
const SHOP_ITEM_SLOTS: int = 3
const REROLL_COST_INCREMENT: int = 1
const REROLL_WAVE_BASE_MULTIPLIER: float = 1.5 # Wave-based base cost multiplier
const WAVE_PRICE_SCALE: float = 0.2
const TURRET_PURCHASE_PENALTY: float = 0.5 # +50% per turret owned

# =============================================================================
# ITEM EFFECT RANGES (proximity-based turret item effects)
# =============================================================================
const PERSONAL_SPACE_MIN_DISTANCE: float = 200.0

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
