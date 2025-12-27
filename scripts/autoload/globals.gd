extends Node

## Autoload singleton for global game state
## REFACTORED: Now delegates to focused service singletons using facade pattern
##
## ARCHITECTURE OVERVIEW:
## This file acts as a unified facade providing convenient access to:
## 1. Service layer (autoloaded singletons in /root/)
## 2. Scene managers (nodes in /root/Main/ scene tree)
## 3. Legacy constants (forwarded from GameConstants)
## 4. Runtime settings (UI preferences, debug flags)
##
## WHY USE THIS FACADE?
## - Simplifies access: Use Globals.shop_manager instead of get_node("/root/Main/ShopManager")
## - Lazy loading: Services/managers loaded only when first accessed
## - Single point of change: If service paths change, update only here
## - Backwards compatibility: Gradual migration from old Globals to services
##
## SERVICE ARCHITECTURE:
## - DifficultyService: Difficulty settings and multipliers
## - GameStateService: Wave, XP, kills, time tracking
## - EconomyService: Gold, shop, rerolls, turret purchases
## - PlayerStatsService: Player health, speed, luck
## - TurretStatsService: Turret counts, stats, calculations
## - ItemTrackingService: Items collected, item-based modifiers
## - ModifierService: Active modifiers system
##
## SCENE MANAGERS (in /root/Main/ scene):
## - ShopManager: Shop offers, rerolls, purchases
## - TurretManager: Turret spawning, tracking, proximity queries
## - GameManager: Game phases, wave transitions
##
## USAGE GUIDELINES:
## - For services: Use Globals.property or Globals.method() (facade forwards)
## - For scene managers: Use Globals.shop_manager, Globals.turret_manager, etc.
## - For constants: Prefer GameConstants directly unless runtime-mutable (like ARENA_WIDTH)
## - Never use hard-coded paths like get_node("/root/Main/...") - use this facade instead

# Service references (lazy loaded on first access)
var _difficulty_service: Node = null
var _game_state_service: Node = null
var _economy_service: Node = null
var _player_stats_service: Node = null
var _turret_stats_service: Node = null
var _item_tracking_service: Node = null
var _modifier_service: Node = null
var _game_mode_service: Node = null

# Scene manager references (lazy loaded on first access)
var _shop_manager: Node = null
var _turret_manager: Node = null
var _game_manager: Node = null

# Lazy getters for services
func _get_difficulty_service() -> Node:
	if _difficulty_service == null:
		_difficulty_service = get_node("/root/DifficultyService")
	return _difficulty_service

func _get_game_state_service() -> Node:
	if _game_state_service == null:
		_game_state_service = get_node("/root/GameStateService")
	return _game_state_service

func _get_economy_service() -> Node:
	if _economy_service == null:
		_economy_service = get_node("/root/EconomyService")
	return _economy_service

func _get_player_stats_service() -> Node:
	if _player_stats_service == null:
		_player_stats_service = get_node("/root/PlayerStatsService")
	return _player_stats_service

func _get_turret_stats_service() -> Node:
	if _turret_stats_service == null:
		_turret_stats_service = get_node("/root/TurretStatsService")
	return _turret_stats_service

func _get_item_tracking_service() -> Node:
	if _item_tracking_service == null:
		_item_tracking_service = get_node("/root/ItemTrackingService")
	return _item_tracking_service

func _get_modifier_service() -> Node:
	if _modifier_service == null:
		_modifier_service = get_node("/root/ModifierService")
	return _modifier_service

func _get_game_mode_service() -> Node:
	if _game_mode_service == null:
		_game_mode_service = get_node("/root/GameModeService")
	return _game_mode_service

# Lazy getters for scene managers
func _get_shop_manager() -> Node:
	if _shop_manager == null:
		_shop_manager = get_node_or_null("/root/Main/ShopManager")
	return _shop_manager

func _get_turret_manager() -> Node:
	if _turret_manager == null:
		_turret_manager = get_node_or_null("/root/Main/TurretManager")
	return _turret_manager

func _get_game_manager() -> Node:
	if _game_manager == null:
		_game_manager = get_node_or_null("/root/Main/GameManager")
	return _game_manager


# =============================================================================
# NOTE: Settings have been migrated to SettingsService
# Use SettingsService directly for: show_damage_numbers, player_auto_attack_enabled,
# show_turret_ranges, isometric_debug_enabled, debug_hitbox_flags
# =============================================================================

# =============================================================================
# CONSTANTS (forwarded from GameConstants for backward compatibility)
# =============================================================================
var ARENA_WIDTH: int = GameConstants.ARENA_WIDTH
var ARENA_HEIGHT: int = GameConstants.ARENA_HEIGHT
const MAX_WAVES: int = GameConstants.MAX_WAVES
const WAVE_ANNOUNCEMENT_TIME: float = GameConstants.WAVE_ANNOUNCEMENT_TIME
const TURRET_SPAWN_TIME: float = GameConstants.TURRET_SPAWN_TIME
const BETWEEN_WAVE_PAUSE: float = GameConstants.BETWEEN_WAVE_PAUSE
const WAVE_BASE_DURATION: float = GameConstants.WAVE_BASE_DURATION
const WAVE_DURATION_INCREMENT: float = GameConstants.WAVE_DURATION_INCREMENT
const WAVE_BASE_ENEMY_COUNT: int = GameConstants.WAVE_BASE_ENEMY_COUNT
const WAVE_ENEMY_INCREMENT: int = GameConstants.WAVE_ENEMY_INCREMENT
const PLAYER_BASE_MAX_HEALTH: float = GameConstants.PLAYER_BASE_MAX_HEALTH
const PLAYER_SPEED: float = GameConstants.PLAYER_SPEED
const PLAYER_PICKUP_RADIUS: float = GameConstants.PLAYER_PICKUP_RADIUS
const PLAYER_INVINCIBILITY_TIME: float = GameConstants.PLAYER_INVINCIBILITY_TIME
const PLAYER_WEAPON_DAMAGE: float = GameConstants.PLAYER_WEAPON_DAMAGE
const PLAYER_WEAPON_FIRE_RATE: float = GameConstants.PLAYER_WEAPON_FIRE_RATE
const PLAYER_WEAPON_RANGE: float = GameConstants.PLAYER_WEAPON_RANGE
const PLAYER_PROJECTILE_SPEED: float = GameConstants.PLAYER_PROJECTILE_SPEED
const PLAYER_MELEE_DAMAGE: float = GameConstants.PLAYER_MELEE_DAMAGE
const PLAYER_MELEE_RANGE: float = GameConstants.PLAYER_MELEE_RANGE
const PLAYER_MELEE_ARC_DEGREES: float = GameConstants.PLAYER_MELEE_ARC_DEGREES
const PLAYER_MELEE_COOLDOWN: float = GameConstants.PLAYER_MELEE_COOLDOWN
const PLAYER_MELEE_WINDUP_TIME: float = GameConstants.PLAYER_MELEE_WINDUP_TIME
const PLAYER_MELEE_ANIMATION_DURATION: float = GameConstants.PLAYER_MELEE_ANIMATION_DURATION
const PLAYER_MELEE_KNOCKBACK_FORCE: float = GameConstants.PLAYER_MELEE_KNOCKBACK_FORCE
const PLASMA_TURRET_KNOCKBACK_FORCE: float = GameConstants.PLASMA_TURRET_KNOCKBACK_FORCE
const PLAYER_DEFENSIVE_PULSE_KNOCKBACK_FORCE: float = GameConstants.PLAYER_DEFENSIVE_PULSE_KNOCKBACK_FORCE
const PLAYER_DEFENSIVE_PULSE_RADIUS: float = GameConstants.PLAYER_DEFENSIVE_PULSE_RADIUS
const KNOCKBACK_DECAY_RATE: float = GameConstants.KNOCKBACK_DECAY_RATE
const KNOCKBACK_MIN_VELOCITY: float = GameConstants.KNOCKBACK_MIN_VELOCITY
const TURRET_BASE_DAMAGE: float = GameConstants.TURRET_BASE_DAMAGE
const TURRET_FIRE_RATE: float = GameConstants.TURRET_FIRE_RATE
const TURRET_RANGE: float = GameConstants.TURRET_RANGE
const TURRET_PROJECTILE_SPEED: float = GameConstants.TURRET_PROJECTILE_SPEED
const TURRET_ROTATION_SPEED: float = GameConstants.TURRET_ROTATION_SPEED
const TURRET_MIN_DISTANCE: float = GameConstants.TURRET_MIN_DISTANCE
const TURRET_PLAYER_EXCLUSION: float = GameConstants.TURRET_PLAYER_EXCLUSION
const TURRET_PICKUP_RANGE: float = GameConstants.TURRET_PICKUP_RANGE
const TURRET_CARRY_OFFSET: Vector2 = GameConstants.TURRET_CARRY_OFFSET
const TURRET_CARRY_SPEED_PENALTY: float = GameConstants.TURRET_CARRY_SPEED_PENALTY
const TURRET_IN_RANGE_INDICATOR_ALPHA: float = GameConstants.TURRET_IN_RANGE_INDICATOR_ALPHA
const ENEMY_BASE_HEALTH: float = GameConstants.ENEMY_BASE_HEALTH
const ENEMY_BASE_SPEED: float = GameConstants.ENEMY_BASE_SPEED
const ENEMY_BASE_CONTACT_DAMAGE: float = GameConstants.ENEMY_BASE_CONTACT_DAMAGE
const STARTING_GOLD: int = GameConstants.STARTING_GOLD
const GOLD_PER_ENEMY: int = GameConstants.GOLD_PER_ENEMY
const GOLD_WAVE_BONUS_BASE: int = GameConstants.GOLD_WAVE_BONUS_BASE
const SHOP_OFFER_COUNT: int = GameConstants.SHOP_OFFER_COUNT
const REROLL_BASE_COST: int = GameConstants.REROLL_BASE_COST
const REROLL_COST_INCREMENT: int = GameConstants.REROLL_COST_INCREMENT
# Removed MAX_REROLLS_PER_WAVE - infinite rerolls allowed
const WAVE_PRICE_SCALE: float = GameConstants.WAVE_PRICE_SCALE
const TECH_DROP_SPAWN_INTERVAL: float = GameConstants.TECH_DROP_SPAWN_INTERVAL
const TECH_DROP_SPAWN_CHANCE: float = GameConstants.TECH_DROP_SPAWN_CHANCE
const TECH_DROP_BASE_HEALTH: float = GameConstants.TECH_DROP_BASE_HEALTH
const TECH_DROP_XP_REWARD: int = GameConstants.TECH_DROP_XP_REWARD
const TECH_DROP_GOLD_REWARD: int = GameConstants.TECH_DROP_GOLD_REWARD
const TECH_DROP_SCATTER_COUNT: int = GameConstants.TECH_DROP_SCATTER_COUNT
const TECH_DROP_SCATTER_RADIUS: float = GameConstants.TECH_DROP_SCATTER_RADIUS

# =============================================================================
# LEGACY DATA REMOVAL NOTE
# =============================================================================
# The following data has been removed from this file as it was duplicated:
# - ENEMY_TYPES: Use EnemyRegistry.TYPES instead
# - RARITY_COLORS: Use ItemRegistry.RARITY_COLORS instead
# - RARITY_NAMES: Use ItemRegistry.RARITY_NAMES instead
# - ITEM_BASE_PRICES: Use ItemRegistry.RARITY_BASE_PRICES instead
#
# See: scripts/registries/enemy_registry.gd
# See: scripts/registries/item_registry.gd

# =============================================================================
# DIFFICULTY SERVICE FORWARDS
# =============================================================================
var current_difficulty: GameEnums.Difficulty:
	get: return (_get_difficulty_service()).current_difficulty
	set(value): (_get_difficulty_service()).current_difficulty = value

func get_difficulty_config() -> Dictionary:
	return (_get_difficulty_service()).get_difficulty_config()

func get_difficulty_name() -> String:
	return (_get_difficulty_service()).get_difficulty_name()

func set_difficulty(difficulty: GameEnums.Difficulty) -> void:
	(_get_difficulty_service()).set_difficulty(difficulty)

# =============================================================================
# GAME STATE SERVICE FORWARDS
# =============================================================================
var current_wave: int:
	get: return (_get_game_state_service()).current_wave
	set(value): (_get_game_state_service()).current_wave = value

var total_xp: int:
	get: return (_get_game_state_service()).total_xp
	set(value): (_get_game_state_service()).total_xp = value

var total_kills: int:
	get: return (_get_game_state_service()).total_kills
	set(value): (_get_game_state_service()).total_kills = value

var turrets_spawned: int:
	get: return (_get_game_state_service()).turrets_spawned
	set(value): (_get_game_state_service()).turrets_spawned = value

var time_survived: float:
	get: return (_get_game_state_service()).time_survived
	set(value): (_get_game_state_service()).time_survived = value

var is_game_active: bool:
	get: return (_get_game_state_service()).is_game_active
	set(value): (_get_game_state_service()).is_game_active = value

var player_level: int:
	get: return (_get_game_state_service()).player_level
	set(value): (_get_game_state_service()).player_level = value

func get_wave_duration(wave: int) -> float:
	return (_get_game_state_service()).get_wave_duration(wave)

func get_wave_enemy_count(wave: int) -> int:
	var difficulty_mult = get_difficulty_config()["enemy_count_mult"]
	var item_mult = get_enemy_count_multiplier()
	return (_get_game_state_service()).get_wave_enemy_count(wave, difficulty_mult, item_mult)

func get_spawn_interval(wave: int) -> float:
	var difficulty_mult = get_difficulty_config()["enemy_count_mult"]
	var item_mult = get_enemy_count_multiplier()
	return (_get_game_state_service()).get_spawn_interval(wave, difficulty_mult, item_mult)

# =============================================================================
# ECONOMY SERVICE FORWARDS
# =============================================================================
var total_gold: int:
	get: return (_get_economy_service()).total_gold
	set(value): (_get_economy_service()).total_gold = value

var shop_reroll_count: int:
	get: return (_get_economy_service()).shop_reroll_count
	set(value): (_get_economy_service()).shop_reroll_count = value

var current_shop_offers: Array:
	get: return (_get_economy_service()).current_shop_offers
	set(value): (_get_economy_service()).current_shop_offers = value

var pending_turret_purchases: Array[String]:
	get: return (_get_economy_service()).pending_turret_purchases
	set(value): (_get_economy_service()).pending_turret_purchases = value

var turrets_purchased: int:
	get: return (_get_economy_service()).turrets_purchased
	set(value): (_get_economy_service()).turrets_purchased = value

# =============================================================================
# PLAYER STATS SERVICE FORWARDS
# =============================================================================
var player_luck: float:
	get: return (_get_player_stats_service()).player_luck
	set(value): (_get_player_stats_service()).player_luck = value

var PLAYER_MAX_HEALTH: float:
	get:
		var difficulty_mult = get_difficulty_config()["player_health_mult"]
		return (_get_player_stats_service()).get_player_max_health(difficulty_mult)

func get_player_speed() -> float:
	return (_get_player_stats_service()).get_player_speed()

func get_player_max_health() -> float:
	var difficulty_mult = get_difficulty_config()["player_health_mult"]
	return (_get_player_stats_service()).get_player_max_health(difficulty_mult)

func get_player_weapon_damage() -> float:
	return (_get_player_stats_service()).get_player_weapon_damage()

func get_player_luck() -> float:
	return (_get_player_stats_service()).get_player_luck()

func get_player_luck_display() -> int:
	return (_get_player_stats_service()).get_player_luck_display()

func get_pickup_radius() -> float:
	return (_get_player_stats_service()).get_pickup_radius()

func get_player_health_regen() -> int:
	return (_get_player_stats_service()).get_player_health_regen()

func get_heal_interval() -> float:
	return (_get_player_stats_service()).get_heal_interval()

# =============================================================================
# TURRET STATS SERVICE FORWARDS
# =============================================================================
var turret_counts: Dictionary:
	get: return (_get_turret_stats_service()).turret_counts
	set(value): (_get_turret_stats_service()).turret_counts = value

var selected_turret_type: String:
	get: return (_get_turret_stats_service()).selected_turret_type
	set(value): (_get_turret_stats_service()).selected_turret_type = value

func get_turret_stats(turret_type: String) -> Dictionary:
	var difficulty_turret_damage_mult = get_difficulty_config()["turret_damage_mult"]
	return (_get_turret_stats_service()).get_turret_stats(turret_type, difficulty_turret_damage_mult)

func get_turret_color(turret_type: String) -> Color:
	return (_get_turret_stats_service()).get_turret_color(turret_type)

func turret_has_attack_style(turret_type: String, style: GameEnums.AttackStyle) -> bool:
	return (_get_turret_stats_service()).turret_has_attack_style(turret_type, style)

func turret_has_damage_type(turret_type: String, dtype: GameEnums.DamageType) -> bool:
	return (_get_turret_stats_service()).turret_has_damage_type(turret_type, dtype)

func get_total_turret_count() -> int:
	return (_get_turret_stats_service()).get_total_turret_count()

func get_turret_type_diversity() -> int:
	return (_get_turret_stats_service()).get_turret_type_diversity()

func get_damage_type_diversity() -> int:
	return (_get_turret_stats_service()).get_damage_type_diversity()

func get_most_common_turret_type() -> String:
	return (_get_turret_stats_service()).get_most_common_turret_type()

func get_turret_min_distance() -> float:
	return (_get_turret_stats_service()).get_turret_min_distance(item_counts)

func get_turret_purchase_penalty() -> float:
	return (_get_turret_stats_service()).get_turret_purchase_penalty()

# =============================================================================
# ITEM TRACKING SERVICE FORWARDS
# =============================================================================
var collected_items: Array[String]:
	get: return (_get_item_tracking_service()).collected_items
	set(value): (_get_item_tracking_service()).collected_items = value

var item_counts: Dictionary:
	get: return (_get_item_tracking_service()).item_counts
	set(value): (_get_item_tracking_service()).item_counts = value

func get_reroll_cost_multiplier() -> float:
	return (_get_item_tracking_service()).get_reroll_cost_multiplier()

func get_gold_earn_multiplier() -> float:
	return (_get_item_tracking_service()).get_gold_earn_multiplier()

func get_enemy_count_multiplier() -> float:
	return (_get_item_tracking_service()).get_enemy_count_multiplier()

func get_shop_price_multiplier() -> float:
	return (_get_item_tracking_service()).get_shop_price_multiplier()

func get_wave_bonus_multiplier() -> float:
	return (_get_item_tracking_service()).get_wave_bonus_multiplier()

func get_shop_offer_count() -> int:
	return (_get_item_tracking_service()).get_shop_offer_count()

# =============================================================================
# MODIFIER SERVICE FORWARDS
# =============================================================================
var active_modifiers: Array:
	get: return (_get_modifier_service()).active_modifiers
	set(value): (_get_modifier_service()).active_modifiers = value

func add_modifier(modifier: Dictionary) -> Dictionary:
	return (_get_modifier_service()).add_modifier(modifier)

func remove_modifier(modifier_id: String) -> bool:
	return (_get_modifier_service()).remove_modifier(modifier_id)

func clear_modifiers() -> void:
	(_get_modifier_service()).clear_modifiers()

# =============================================================================
# GAME MODE SERVICE FORWARDS
# =============================================================================
var game_mode_service: Node:
	get: return _get_game_mode_service()

func set_game_mode(mode: GameEnums.GameMode) -> void:
	(_get_game_mode_service()).set_mode(mode)

func is_game_mode_active(mode: GameEnums.GameMode) -> bool:
	return (_get_game_mode_service()).is_mode_active(mode)

# =============================================================================
# ENEMY HELPERS (delegate to EnemyRegistry)
# =============================================================================
func get_enemy_type_stats(enemy_type: String) -> Dictionary:
	return EnemyRegistry.get_base_stats(enemy_type)

func get_enemy_stats_for_wave(enemy_type: String, wave: int) -> Dictionary:
	var config: Dictionary = get_difficulty_config()
	return EnemyRegistry.get_stats_for_wave(enemy_type, wave, config)

func get_available_enemy_types(wave: int) -> Array:
	return EnemyRegistry.get_available_types(wave)

func select_random_enemy_type(wave: int) -> String:
	return EnemyRegistry.select_random_type(wave)

func enemy_has_behavior(enemy_type: String, behavior: GameEnums.EnemyBehavior) -> bool:
	return EnemyRegistry.has_behavior(enemy_type, behavior)

func get_enemy_spawn_count(enemy_type: String) -> int:
	return EnemyRegistry.get_spawn_count(enemy_type)

func get_enemy_color(enemy_type: String) -> Color:
	return EnemyRegistry.get_color(enemy_type)

func get_enemy_sprite_folder(enemy_type: String) -> String:
	return EnemyRegistry.get_sprite_folder(enemy_type)

func get_enemy_health(wave: int) -> float:
	var config: Dictionary = get_difficulty_config()
	var base: float = GameConstants.ENEMY_BASE_HEALTH * float(config["enemy_health_mult"])
	return base * pow(float(config["enemy_hp_scale_per_wave"]), wave - 1)

func get_enemy_speed(wave: int) -> float:
	var config: Dictionary = get_difficulty_config()
	var base: float = GameConstants.ENEMY_BASE_SPEED * float(config["enemy_speed_mult"])
	return base * pow(float(config["enemy_speed_scale_per_wave"]), wave - 1)

# =============================================================================
# COMPUTED PROPERTIES (difficulty-adjusted constants)
# =============================================================================
var ENEMY_HP_SCALE: float:
	get: return get_difficulty_config()["enemy_hp_scale_per_wave"]

var ENEMY_SPEED_SCALE: float:
	get: return get_difficulty_config()["enemy_speed_scale_per_wave"]

var ENEMY_CONTACT_DAMAGE: float:
	get: return GameConstants.ENEMY_BASE_CONTACT_DAMAGE * get_difficulty_config()["enemy_damage_mult"]

var TURRET_DAMAGE: float:
	get: return GameConstants.TURRET_BASE_DAMAGE * get_difficulty_config()["turret_damage_mult"]

# =============================================================================
# SCENE MANAGER FACADES (for nodes in /root/Main scene tree)
# =============================================================================
var shop_manager: Node:
	get: return _get_shop_manager()

var turret_manager: Node:
	get: return _get_turret_manager()

var game_manager: Node:
	get: return _get_game_manager()

# =============================================================================
# RESET FUNCTION
# =============================================================================
func reset_stats() -> void:
	(_get_difficulty_service()).reset_state()
	(_get_game_state_service()).reset_state()
	(_get_economy_service()).reset_state()
	(_get_player_stats_service()).reset_state()
	(_get_turret_stats_service()).reset_state()
	(_get_item_tracking_service()).reset_state()
	(_get_modifier_service()).clear_modifiers()
	(_get_game_mode_service()).reset_state()
