class_name GameConstants
extends RefCounted

## All game constants in one place for easy tuning

# =============================================================================
# CAMERA
# =============================================================================
# 3D follow camera (orthographic). Size is the vertical view extent in metres at zoom 1.0.
const CAMERA_BASE_SIZE: float = 10.0
## Continuous, informational motion (walk cycles, rotors, flame shaders) runs at this fraction of full speed with Reduced Motion on.
const REDUCED_MOTION_SPEED: float = 0.2
const CAMERA_DEFAULT_ZOOM: float = 0.85 / 0.9 # tracks the 10% arena shrink so the arena fills the same share of the screen
const CAMERA_ZOOM_MIN: float = 0.6
const CAMERA_ZOOM_MAX: float = 2.0
const CAMERA_ZOOM_SPEED: float = 10.0 # smoothing rate toward the target zoom
const CAMERA_ZOOM_WHEEL_STEP: float = 1.12 # multiplier per wheel notch
const CAMERA_ZOOM_HELD_RATE: float = 1.6 # exp rate/second while a zoom key or trigger is held
const CAMERA_FOLLOW_SPEED: float = 8.0 # smoothing rate toward the player
const CAMERA_EDGE_MARGIN: float = 0.5 # metres of floor rim allowed past the arena bounds
# Enemies appear this far outside the default-zoom view, never closer than SPAWN_MIN_DISTANCE to the player.
const ENEMY_SPAWN_MIN_DISTANCE: float = 6.0

# =============================================================================
# PLAYER
# =============================================================================
const PLAYER_BASE_MAX_HEALTH: float = 25.0
const PLAYER_SPEED: float = 375.0
const PLAYER_ACCELERATION: float = 2800.0 # px/s^2 toward the input direction (full speed in ~0.13 s)
const PLAYER_DECELERATION: float = 3600.0 # px/s^2 when no input is held
const PLAYER_TURN_BOOST: float = 2.5 # acceleration multiplier when the input opposes the current velocity (scales down to 1x when aligned)
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
# Hard body separation (metres). Radii stay below CrowdGrid3D.SPACING / 2 so the soft push leads and this is the backstop.
const ENEMY_BODY_RADIUS: float = 0.3 # Multiplied by the enemy's body_scale
const TURRET_BODY_RADIUS: float = 0.35
const SEPARATION_MAX_CORRECTION: float = 0.5 # Fraction of an overlap resolved per tick
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

# Abandoned scrap (progression runs): scrap left on the floor at wave end permanently raises the scrap earn multiplier.
const ABANDON_DEADZONE: float = .10 # fraction of a wave's drops that can be missed without counting
const ABANDON_GAIN: float = .12 # earn multiplier bonus per fully abandoned wave
const ABANDON_BONUS_CAP: float = 2.0 # maximum bonus (+200%)

# Scrap income (S5, the Scrap Press): a turret that makes scrap, deposits it or turns it into XP.
const SCRAP_PRESS_WAVES_PER_STEP: int = 5 # a drop is worth one more scrap every this many waves (1 on waves 1-5, 2 on 6-10, ...)
const SCRAP_PRESS_STACK_YIELD: Array[float] = [1.0, .6, .4] # output of the first, second and third (and later) press on the field

# =============================================================================
# PROTECT THE CORE (core mode)
# =============================================================================
const CORE_HEALTH_MULT: float = 6.0 # core hit points = base hull x this x the difficulty's core_health_mult
const CORE_RADIUS: float = .55 # metres; enemies stop at its edge
const CORE_PLACEMENT_CLEARANCE: float = .7 # turrets keep this far outside the core's radius
const CORE_HIT_INTERVAL: float = 1.0 # seconds between one enemy's hits on the core
const CORE_DAMAGE_FRACTION: float = .25 # share of an enemy's contact damage the core takes
const CORE_AGGRO_RANGE: float = 2.5 # an enemy this close to the hero chases the hero (the 2D game's 250 px)
const CORE_DEAGGRO_RANGE: float = 5.0 # ...and gives up and returns to the core beyond this (2D: 500 px)
const CORE_SPAWN_BOX: float = .6 # enemies spawn on this fraction of the arena's half-size, so they reach the fight in time
const CORE_START_OFFSET: float = 2.5 # hero and first turret start this far from the core

# Convoy mode: the core drives door to door along a route that is regenerated (and previewed) every round.
const CORE_MOVE_SPEED: float = 1.2 # metres per second between doors; items change it via the `core_move_speed` stat
const CORE_MIN_MOVE_SPEED: float = .15 # floor so slowing items can never freeze the convoy
const CONVOY_PAUSE_TIME: float = 4.0 # seconds the core waits at each intermediate door
const CONVOY_MIN_LEG: float = 9.0 # metres; doors closer than this to the previous door are rejected
const CONVOY_EDGE_MARGIN: float = 1.1 # core clearance from the wall at door centres
const CONVOY_SAFETY_FACTOR: float = 2.5 # the round timer is the route's duration times this; hitting it just ends the round

# =============================================================================
# TECH DROPS (destructible reward crates; 2D tech drop rules)
# =============================================================================
const TECH_DROP_ROLL_INTERVAL: float = 5.0 # seconds between spawn rolls during a wave
const TECH_DROP_SPAWN_CHANCE: float = .20
const TECH_DROP_MAX_ACTIVE: int = 1 # alive drops plus pending warnings
const TECH_DROP_MIN_TIME_LEFT: float = 10.0 # no new drops in the last seconds of a wave
const TECH_DROP_WARNING_TIME: float = 1.5
const TECH_DROP_HEALTH_FRACTION: float = .5 # of a tank at the current wave and difficulty
const TECH_DROP_BODY_SCALE: float = 1.0
const TECH_DROP_MIN_CORE_DISTANCE: float = 12.0 # metres from the core (core mode)
const TECH_DROP_MIN_TURRET_DISTANCE: float = 8.0 # metres from every turret (and from the hero in survive mode)
const TECH_DROP_EDGE_MARGIN: float = 3.0
const TECH_DROP_SCRAP_PICKUPS: int = 5
const TECH_DROP_SCRAP_EACH: int = 2
const TECH_DROP_SCATTER_RADIUS: float = 1.2
const TECH_DROP_ITEM_CHANCE: float = .25 # chance a destroyed drop also grants a free item

# =============================================================================
# BUILD ZONES (stand in a zone to build a turret or an item; leftover scrap feeds the next wave's zones)
# =============================================================================
const BUILD_ZONE_RADIUS: float = 1.6 # metres; the hero must stand inside it to build
const BUILD_ZONE_BUILD_TIME: float = 6.0 # seconds of standing inside for a tier 0 zone
const BUILD_ZONE_TIER_SPEEDUP: float = .15 # each tier shortens the build by this fraction
const BUILD_ZONE_GRACE_TIME: float = 2.0 # progress holds this long after the hero leaves...
const BUILD_ZONE_DECAY_RATE: float = .1 # ...then drains by this fraction of the build per second
const BUILD_ZONE_LIFETIME: float = 40.0 # an unfinished zone fades after this many seconds
const BUILD_ZONE_WARNING_TIME: float = 1.5
const BUILD_ZONE_ROLL_INTERVAL: float = 6.0 # seconds between spawn rolls during a wave
const BUILD_ZONE_SPAWN_CHANCE: float = .35
const BUILD_ZONE_BASE_ACTIVE: int = 1 # alive zones plus pending warnings, before any leftover-scrap bonus
const BUILD_ZONE_MIN_TIME_LEFT: float = 12.0 # no new zones in the last seconds of a wave
const BUILD_ZONE_ITEM_CHANCE: float = .35 # chance a zone builds an item instead of a turret
const BUILD_ZONE_SCRAP_PER_BONUS: int = 10 # leftover scrap per extra concurrent zone next wave
const BUILD_ZONE_MAX_BONUS: int = 2
const BUILD_ZONE_SCRAP_PER_TIER: int = 25 # leftover scrap per quality tier next wave
const BUILD_ZONE_MAX_TIER: int = 3
const BUILD_ZONE_TIER_LUCK: float = .35 # extra item luck per tier
const BUILD_ZONE_EDGE_MARGIN: float = 3.0
const BUILD_ZONE_MIN_CORE_DISTANCE: float = 4.0 # metres from the core (core mode)
const BUILD_ZONE_MIN_TURRET_DISTANCE: float = 2.5 # metres from every turret
const BUILD_ZONE_MIN_ZONE_DISTANCE: float = 6.0 # metres between zones

# =============================================================================
# TERRAIN ZONES (Phase 4)
# =============================================================================
const ZONE_HIGH_GROUND_RANGE_BONUS: float = .25 # turrets on high ground: +25% range
const ZONE_MUD_SLOW: float = .45 # enemies and the hero move 45% slower in mud
const ZONE_MUD_MAX_SLOW: float = .9 # whatever the layout asks for, mud never slows more than this
const ZONE_POWER_NODE_ENTRENCH_BONUS: float = .5 # Entrench stacks arrive 50% faster on a power node
const ZONE_CENTRE_CLEARANCE: float = 4.0 # layouts keep zones this far from the origin (hero, first turret, core)
const ZONE_LABEL_FULL_RANGE: float = 3.0 # a zone's name and effect are fully visible this close to its edge...
const ZONE_LABEL_FADE_RANGE: float = 9.0 # ...and have faded out completely by this distance
const ZONE_PROP_FILL: float = .5 # a zone prop may cover at most this fraction of the zone's narrowest half-width
const ZONE_PROP_MAX_SCALE: float = 2.0
# Temporary enemy-only ground zones laid by turrets (GroundZones): never slow the hero, never outlast combat.
const GROUND_ZONE_MAX: int = 16 # active zones across the whole arena; the one closest to expiring is recycled beyond it
const GROUND_ZONE_MAX_SLOW: float = .9 # same cap as every other slow
# 3D shop layout: SHOP_OFFER_COUNT cards; 0-SHOP_TURRET_MAX weapons, upgrades fill the rest
const SHOP_OFFER_COUNT: int = 4
const SHOP_TURRET_MAX: int = 4
const SHOP_TURRET_SLOT_CHANCE: float = .375 # each weapon slot stocks independently: averages 1.5 weapons per refresh
const REROLL_COST_INCREMENT: int = 1
const REROLL_WAVE_BASE_MULTIPLIER: float = 1.5 # Wave-based base cost multiplier
const WAVE_PRICE_SCALE: float = 0.2
const TURRET_PURCHASE_PENALTY: float = 0.5 # +50% per turret owned

# =============================================================================
# ITEM EFFECT RANGES (proximity-based turret item effects)
# =============================================================================

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
