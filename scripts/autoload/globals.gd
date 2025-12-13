extends Node

## Autoload singleton for global game state
## Add to Project Settings > Autoload as "Globals"
##
## The data and logic has been organized into focused modules:
## - scripts/data/game_enums.gd - All enumerations
## - scripts/data/game_constants.gd - All constant values
## - scripts/registries/enemy_registry.gd - Enemy type definitions
## - scripts/registries/turret_registry.gd - Turret type definitions
## - scripts/registries/item_registry.gd - Item definitions
## - scripts/systems/modifier_system.gd - Modifier logic
## - scripts/systems/game_state.gd - Runtime state

# =============================================================================
# DIFFICULTY SYSTEM
# =============================================================================
enum Difficulty { EASY, MEDIUM, HARD }

const DIFFICULTY_CONFIG: Dictionary = {
	Difficulty.EASY: {
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
	Difficulty.MEDIUM: {
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
	Difficulty.HARD: {
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

var current_difficulty: Difficulty = Difficulty.EASY

# =============================================================================
# SETTINGS
# =============================================================================
var show_damage_numbers: bool = true
var player_auto_attack_enabled: bool = false
var show_turret_ranges: bool = false

# =============================================================================
# TURRET TYPE SYSTEM
# =============================================================================
enum AttackStyle { PROJECTILE, INSTANT, AOE, CHAIN }
enum DamageType { PHYSICAL, FIRE, ELECTRIC, PLASMA }
enum EnemyBehavior { CHASE, RANGED, SWARM, TANK, EXPLOSIVE, WANDER, CHARGE }

# =============================================================================
# ENEMY TYPE SYSTEM
# =============================================================================
const ENEMY_TYPES: Dictionary = {
	"basic": {
		"name": "Robot Grunt",
		"icon": "🤖",
		"description": "Standard enemy that chases the player.",
		"behaviors": [EnemyBehavior.CHASE],
		"sprite_folder": "res://assets/sprites/enemy_tiny",
		"base_stats": {
			"health": 30.0,
			"speed": 75.0,
			"contact_damage": 33.0,
			"xp_value": 10,
			"scale": 1.5,
			"mass": 1.0,
		},
		"spawn_weight": 100,
		"min_wave": 1,
		"spawn_count": 3,
	},
	"fast": {
		"name": "Scout Bot",
		"icon": "⚡",
		"description": "Quick but fragile enemy.",
		"behaviors": [EnemyBehavior.CHASE, EnemyBehavior.SWARM],
		"sprite_folder": "res://assets/sprites/enemy_tiny",
		"color_tint": Color(0.6, 0.9, 1.0),
		"base_stats": {
			"health": 15.0,
			"speed": 130.0,
			"contact_damage": 20.0,
			"xp_value": 8,
			"scale": 1.2,
			"mass": 0.6,
		},
		"spawn_weight": 60,
		"min_wave": 2,
		"spawn_count": 5,
	},
	"tank": {
		"name": "Heavy Bot",
		"icon": "🛡️",
		"description": "Slow but very tough enemy.",
		"behaviors": [EnemyBehavior.CHASE, EnemyBehavior.TANK],
		"sprite_folder": "res://assets/sprites/enemy_tiny",
		"color_tint": Color(0.8, 0.5, 0.3),
		"base_stats": {
			"health": 120.0,
			"speed": 40.0,
			"contact_damage": 50.0,
			"xp_value": 25,
			"scale": 2.0,
			"mass": 3.0,
		},
		"spawn_weight": 20,
		"min_wave": 3,
	},
	"exploder": {
		"name": "Boom Bot",
		"icon": "💥",
		"description": "Explodes on death, damaging nearby enemies and player.",
		"behaviors": [EnemyBehavior.CHASE, EnemyBehavior.EXPLOSIVE],
		"sprite_folder": "res://assets/sprites/enemy_tiny",
		"color_tint": Color(1.0, 0.4, 0.2),
		"base_stats": {
			"health": 20.0,
			"speed": 90.0,
			"contact_damage": 25.0,
			"xp_value": 15,
			"scale": 1.3,
			"explosion_radius": 100.0,
			"explosion_damage": 40.0,
			"mass": 0.8,
		},
		"spawn_weight": 0,
		"min_wave": 4,
		"spawn_count": 3,
	},
	"lazy_wanderer": {
		"name": "Lazy Bot",
		"icon": "😴",
		"description": "Wanders aimlessly, never chases the player.",
		"behaviors": [EnemyBehavior.WANDER],
		"sprite_folder": "res://assets/sprites/enemy_tiny",
		"color_tint": Color(0.7, 0.7, 0.9),
		"behavior_params": {
			"wander_pause_min": 0.0,
			"wander_pause_max": 0.0,
			"wander_move_min": 2.0,
			"wander_move_max": 4.0,
		},
		"base_stats": {
			"health": 25.0,
			"speed": 40.0,
			"contact_damage": 20.0,
			"xp_value": 8,
			"scale": 1.4,
			"mass": 1.2,
		},
		"spawn_weight": 80,
		"min_wave": 2,
		"spawn_count": 2,
	},
	"charger": {
		"name": "Charger Bot",
		"icon": "⚡",
		"description": "Wanders lazily until player is close, then charges aggressively.",
		"behaviors": [EnemyBehavior.CHARGE],
		"sprite_folder": "res://assets/sprites/enemy_tiny",
		"color_tint": Color(1.0, 0.8, 0.3),
		"behavior_params": {
			"wander_pause_min": 1.0,
			"wander_pause_max": 2.0,
			"wander_move_min": 1.5,
			"wander_move_max": 2.5,
			"charge_detect_radius": 200.0,
			"charge_alert_duration": 0.9,
			"charge_speed_multiplier": 3.0,
			"charge_duration": 1.5,
			"charge_cooldown": 2.5,
		},
		"base_stats": {
			"health": 35.0,
			"speed": 60.0,
			"contact_damage": 40.0,
			"xp_value": 15,
			"scale": 1.5,
			"mass": 1.5,
		},
		"spawn_weight": 30,
		"min_wave": 3,
		"spawn_count": 1,
	},
}

const TURRET_COLORS: Dictionary = {
	"normal": Color("66CC66"),
	"sniper": Color("4466AA"),
	"fire": Color("FF6633"),
	"plasma": Color("AA44DD"),
	"shock": Color("DDDD44"),
	"tesla": Color("44DDDD"),
}

const TURRET_TYPES: Dictionary = {
	"normal": {
		"name": "Normal Turret",
		"icon": "🗼",
		"description": "Standard auto-targeting turret. Reliable and consistent.",
		"attack_styles": [AttackStyle.PROJECTILE],
		"damage_types": [DamageType.PHYSICAL],
		"base_stats": {
			"damage": 15.0,
			"fire_rate": 2.0,
			"range": 250.0,
			"rotation_speed": 0.0,
			"projectile_speed": 700.0,
			"pierce": 0,
		}
	},
	"sniper": {
		"name": "Sniper Turret",
		"icon": "🎯",
		"description": "Long-range instant-hit turret. High damage, slow fire rate.",
		"attack_styles": [AttackStyle.INSTANT],
		"damage_types": [DamageType.PHYSICAL],
		"targeting": "farthest",
		"base_stats": {
			"damage": 45.0,
			"fire_rate": 0.5,
			"range": 500.0,
			"rotation_speed": 0.0,
		}
	},
	"fire": {
		"name": "Fire Turret",
		"icon": "🔥",
		"description": "Incendiary turret that ignites enemies.",
		"attack_styles": [AttackStyle.PROJECTILE],
		"damage_types": [DamageType.FIRE],
		"base_stats": {
			"damage": 8.0,
			"fire_rate": 2.5,
			"range": 220.0,
			"rotation_speed": 0.0,
			"projectile_speed": 600.0,
			"pierce": 99,
			"dot_damage": 4.0,
			"dot_duration": 3.0,
			"dot_tick_rate": 1.0,
		}
	},
	"plasma": {
		"name": "Plasma Turret",
		"icon": "💠",
		"description": "Fires explosive plasma orbs that damage an area.",
		"attack_styles": [AttackStyle.PROJECTILE, AttackStyle.AOE],
		"damage_types": [DamageType.PLASMA],
		"targeting": "cluster",
		"base_stats": {
			"damage": 20.0,
			"fire_rate": 1.0,
			"range": 280.0,
			"rotation_speed": 0.0,
			"projectile_speed": 550.0,
			"pierce": 0,
			"aoe_radius": 80.0,
			"knockback_force": 120.0,
		}
	},
	"shock": {
		"name": "Shock Turret",
		"icon": "⚡",
		"description": "Pulses electric damage around itself.",
		"attack_styles": [AttackStyle.AOE],
		"damage_types": [DamageType.ELECTRIC],
		"base_stats": {
			"damage": 12.0,
			"fire_rate": 1.5,
			"range": 150.0,
			"rotation_speed": 0.0,
			"slow_intensity": 0.25,
			"slow_duration": 0.5,
		}
	},
	"tesla": {
		"name": "Tesla Turret",
		"icon": "⛓️",
		"description": "Fires chain lightning that jumps between enemies.",
		"attack_styles": [AttackStyle.INSTANT, AttackStyle.CHAIN],
		"damage_types": [DamageType.ELECTRIC],
		"base_stats": {
			"damage": 18.0,
			"fire_rate": 1.2,
			"range": 220.0,
			"rotation_speed": 0.0,
			"chain_count": 3,
			"chain_range": 120.0,
			"chain_decay": 0.7,
		}
	},
}

var turret_counts: Dictionary = {}
var selected_turret_type: String = ""

# =============================================================================
# MODIFIER SYSTEM
# =============================================================================
var active_modifiers: Array = []

func _modifier_matches_turret(modifier: Dictionary, turret_type: String) -> bool:
	if not TURRET_TYPES.has(turret_type):
		return false

	var turret_def: Dictionary = TURRET_TYPES[turret_type]
	var filter: Dictionary = modifier.get("filter", {})

	if filter.is_empty():
		return true

	if filter.has("turret_type") and not filter["turret_type"].is_empty():
		if turret_type in filter["turret_type"]:
			return true

	if filter.has("damage_type") and not filter["damage_type"].is_empty():
		for dtype in filter["damage_type"]:
			if dtype in turret_def.get("damage_types", []):
				return true

	if filter.has("attack_style") and not filter["attack_style"].is_empty():
		for astyle in filter["attack_style"]:
			if astyle in turret_def.get("attack_styles", []):
				return true

	var has_filters := filter.has("turret_type") or filter.has("damage_type") or filter.has("attack_style")
	return not has_filters

func get_turret_stats(turret_type: String) -> Dictionary:
	if not TURRET_TYPES.has(turret_type):
		return {}

	var base_stats: Dictionary = TURRET_TYPES[turret_type]["base_stats"].duplicate(true)
	base_stats["damage"] = base_stats["damage"] * get_difficulty_config()["turret_damage_mult"]

	var add_mods: Dictionary = {}
	var mult_mods: Dictionary = {}

	for modifier in active_modifiers:
		if not _modifier_matches_turret(modifier, turret_type):
			continue

		var stat: String = modifier.get("stat", "")
		var operation: String = modifier.get("operation", "add")
		var value: float = modifier.get("value", 0.0)

		if operation == "add":
			add_mods[stat] = add_mods.get(stat, 0.0) + value
		elif operation == "multiply":
			if not mult_mods.has(stat):
				mult_mods[stat] = []
			mult_mods[stat].append(value)

	for stat in add_mods:
		base_stats[stat] = base_stats.get(stat, 0.0) + add_mods[stat]

	for stat in mult_mods:
		var combined_mult: float = 1.0
		for mult in mult_mods[stat]:
			combined_mult *= mult
		base_stats[stat] = base_stats.get(stat, 0.0) * combined_mult

	return base_stats

func add_modifier(modifier: Dictionary) -> Dictionary:
	active_modifiers.append(modifier)
	return modifier

func remove_modifier(modifier_id: String) -> bool:
	for i in range(active_modifiers.size() - 1, -1, -1):
		if active_modifiers[i].get("id", "") == modifier_id:
			active_modifiers.remove_at(i)
			return true
	return false

func clear_modifiers() -> void:
	active_modifiers.clear()

func get_player_speed() -> float:
	return _apply_modifiers_to_stat(PLAYER_SPEED, "player_speed")

func get_player_max_health() -> float:
	return _apply_modifiers_to_stat(PLAYER_MAX_HEALTH, "player_max_health")

func get_player_weapon_damage() -> float:
	return _apply_modifiers_to_stat(PLAYER_WEAPON_DAMAGE, "player_weapon_damage")

## Get player luck with modifiers applied, clamped to valid range
func get_player_luck() -> float:
	var modified_luck := _apply_modifiers_to_stat(player_luck, "player_luck")
	return clampf(modified_luck, 0.0, GameConstants.PLAYER_MAX_LUCK)

## Get player luck as display integer (0.11 -> 11)
func get_player_luck_display() -> int:
	return int(get_player_luck() * 100.0)

## Get reroll cost multiplier (from items like Probability Matrix)
func get_reroll_cost_multiplier() -> float:
	return _apply_modifiers_to_stat(1.0, "reroll_cost")

func _apply_modifiers_to_stat(base_value: float, stat_name: String) -> float:
	var add_value: float = 0.0
	var mult_values: Array[float] = []

	for modifier in active_modifiers:
		if modifier.get("stat", "") != stat_name:
			continue

		var operation = modifier.get("operation", "add")
		var value = modifier.get("value", 0.0)

		if operation == "add":
			add_value += value
		elif operation == "multiply":
			mult_values.append(value)

	var result = base_value + add_value
	for mult in mult_values:
		result *= mult

	return result

func get_turret_color(turret_type: String) -> Color:
	return TURRET_COLORS.get(turret_type, Color.WHITE)

func turret_has_attack_style(turret_type: String, style: AttackStyle) -> bool:
	if not TURRET_TYPES.has(turret_type):
		return false
	return style in TURRET_TYPES[turret_type].get("attack_styles", [])

func turret_has_damage_type(turret_type: String, dtype: DamageType) -> bool:
	if not TURRET_TYPES.has(turret_type):
		return false
	return dtype in TURRET_TYPES[turret_type].get("damage_types", [])

func get_total_turret_count() -> int:
	var total := 0
	for count in turret_counts.values():
		total += count
	return total

# =============================================================================
# ENEMY TYPE HELPERS
# =============================================================================
func get_enemy_type_stats(enemy_type: String) -> Dictionary:
	# Delegate to EnemyRegistry
	return EnemyRegistry.get_base_stats(enemy_type)

func get_enemy_stats_for_wave(enemy_type: String, wave: int) -> Dictionary:
	# Delegate to EnemyRegistry (it handles difficulty config internally)
	var config: Dictionary = get_difficulty_config()
	return EnemyRegistry.get_stats_for_wave(enemy_type, wave, config)

func get_available_enemy_types(wave: int) -> Array:
	# Delegate to EnemyRegistry
	return EnemyRegistry.get_available_types(wave)

func select_random_enemy_type(wave: int) -> String:
	# Delegate to EnemyRegistry
	return EnemyRegistry.select_random_type(wave)

func enemy_has_behavior(enemy_type: String, behavior) -> bool:
	# Delegate to EnemyRegistry
	# Accepts both Globals.EnemyBehavior and GameEnums.EnemyBehavior (same values, different namespace)
	return EnemyRegistry.has_behavior(enemy_type, behavior)

func get_enemy_spawn_count(enemy_type: String) -> int:
	# Delegate to EnemyRegistry
	return EnemyRegistry.get_spawn_count(enemy_type)

func get_enemy_color(enemy_type: String) -> Color:
	# Delegate to EnemyRegistry
	return EnemyRegistry.get_color(enemy_type)

func get_enemy_sprite_folder(enemy_type: String) -> String:
	# Delegate to EnemyRegistry
	return EnemyRegistry.get_sprite_folder(enemy_type)

# =============================================================================
# ITEMS SYSTEM
# =============================================================================
enum ItemRarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, UNIQUE }

const RARITY_COLORS: Dictionary = {
	ItemRarity.COMMON: Color.WHITE,
	ItemRarity.UNCOMMON: Color.GREEN,
	ItemRarity.RARE: Color.CORNFLOWER_BLUE,
	ItemRarity.EPIC: Color.PURPLE,
	ItemRarity.LEGENDARY: Color.ORANGE,
	ItemRarity.UNIQUE: Color.RED,
}

const RARITY_NAMES: Dictionary = {
	ItemRarity.COMMON: "Common",
	ItemRarity.UNCOMMON: "Uncommon",
	ItemRarity.RARE: "Rare",
	ItemRarity.EPIC: "Epic",
	ItemRarity.LEGENDARY: "Legendary",
	ItemRarity.UNIQUE: "Unique",
}

# Items are now in ItemRegistry - use ItemRegistry.get_item(id) instead
# Legacy ITEM_BASE_PRICES kept for compatibility
const ITEM_BASE_PRICES: Dictionary = {
	ItemRarity.COMMON: 40,
	ItemRarity.UNCOMMON: 70,
	ItemRarity.RARE: 110,
	ItemRarity.EPIC: 160,
	ItemRarity.LEGENDARY: 240,
	ItemRarity.UNIQUE: 350,
}

var collected_items: Array[String] = []

func get_difficulty_config() -> Dictionary:
	return DIFFICULTY_CONFIG[current_difficulty]

func get_difficulty_name() -> String:
	return get_difficulty_config()["name"]

# =============================================================================
# GAME CONSTANTS
# =============================================================================
const ARENA_WIDTH: int = 1400
const ARENA_HEIGHT: int = 900
const MAX_WAVES: int = 10

const PLAYER_BASE_MAX_HEALTH: float = 100.0
const PLAYER_SPEED: float = 200.0
const PLAYER_PICKUP_RADIUS: float = 50.0
const PLAYER_INVINCIBILITY_TIME: float = 0.5
const PLAYER_WEAPON_DAMAGE: float = 5.0
const PLAYER_WEAPON_FIRE_RATE: float = 3.0
const PLAYER_WEAPON_RANGE: float = 200.0
const PLAYER_PROJECTILE_SPEED: float = 600.0

const PLAYER_MELEE_KNOCKBACK_FORCE: float = 180.0
const PLASMA_TURRET_KNOCKBACK_FORCE: float = 120.0
const PLAYER_DEFENSIVE_PULSE_KNOCKBACK_FORCE: float = 250.0
const PLAYER_DEFENSIVE_PULSE_RADIUS: float = 120.0
const KNOCKBACK_DECAY_RATE: float = 8.0
const KNOCKBACK_MIN_VELOCITY: float = 5.0

var PLAYER_MAX_HEALTH: float:
	get: return PLAYER_BASE_MAX_HEALTH * get_difficulty_config()["player_health_mult"]

const TURRET_BASE_DAMAGE: float = 15.0
const TURRET_FIRE_RATE: float = 2.0
const TURRET_RANGE: float = 400.0
const TURRET_PROJECTILE_SPEED: float = 500.0
const TURRET_ROTATION_SPEED: float = 180.0
const TURRET_MIN_DISTANCE: float = 100.0
const TURRET_PLAYER_EXCLUSION: float = 150.0

const TURRET_PICKUP_RANGE: float = 60.0
const TURRET_CARRY_OFFSET: Vector2 = Vector2(0, -40)
const TURRET_CARRY_SPEED_PENALTY: float = 0.7
const TURRET_IN_RANGE_INDICATOR_ALPHA: float = 0.5

var TURRET_DAMAGE: float:
	get: return TURRET_BASE_DAMAGE * get_difficulty_config()["turret_damage_mult"]

const ENEMY_BASE_HEALTH: float = 30.0
const ENEMY_BASE_SPEED: float = 100.0
const ENEMY_BASE_CONTACT_DAMAGE: float = 33.0

var ENEMY_HP_SCALE: float:
	get: return get_difficulty_config()["enemy_hp_scale_per_wave"]

var ENEMY_SPEED_SCALE: float:
	get: return get_difficulty_config()["enemy_speed_scale_per_wave"]

var ENEMY_CONTACT_DAMAGE: float:
	get: return ENEMY_BASE_CONTACT_DAMAGE * get_difficulty_config()["enemy_damage_mult"]

const WAVE_ANNOUNCEMENT_TIME: float = 1.5
const TURRET_SPAWN_TIME: float = 0.5
const BETWEEN_WAVE_PAUSE: float = 0.5
const WAVE_BASE_DURATION: float = 25.0
const WAVE_DURATION_INCREMENT: float = 4.0
const WAVE_BASE_ENEMY_COUNT: int = 10
const WAVE_ENEMY_INCREMENT: int = 4

var current_wave: int = 0
var total_xp: int = 0
var total_kills: int = 0
var turrets_spawned: int = 0
var turrets_purchased: int = 0  # Tracks turrets bought (for price penalty)
var item_counts: Dictionary = {}  # Tracks item counts for max_stacks
var player_luck: float = GameConstants.PLAYER_BASE_LUCK  # Luck stat for rarity rolls
var time_survived: float = 0.0
var is_game_active: bool = false
var player_level: int = 1

# =============================================================================
# ECONOMY SYSTEM
# =============================================================================
var total_gold: int = 0
const STARTING_GOLD: int = 120
const GOLD_PER_ENEMY: int = 1
const GOLD_WAVE_BONUS_BASE: int = 20

var shop_reroll_count: int = 0
var current_shop_offers: Array = []
var pending_turret_purchases: Array[String] = []

const SHOP_OFFER_COUNT: int = 4
const REROLL_BASE_COST: int = 5
const REROLL_COST_INCREMENT: int = 3
const MAX_REROLLS_PER_WAVE: int = 5

const TURRET_BASE_PRICES: Dictionary = {
	"normal": 50,
	"sniper": 120,
	"fire": 80,
	"plasma": 100,
	"shock": 90,
	"tesla": 110,
}

const WAVE_PRICE_SCALE: float = 0.15

# =============================================================================
# TECH DROP SYSTEM
# =============================================================================
const TECH_DROP_SPAWN_INTERVAL: float = 5.0
const TECH_DROP_SPAWN_CHANCE: float = 0.20
const TECH_DROP_BASE_HEALTH: float = 60.0
const TECH_DROP_XP_REWARD: int = 100
const TECH_DROP_GOLD_REWARD: int = 25
const TECH_DROP_SCATTER_COUNT: int = 5
const TECH_DROP_SCATTER_RADIUS: float = 80.0

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================
func get_wave_duration(wave: int) -> float:
	return WAVE_BASE_DURATION + (wave - 1) * WAVE_DURATION_INCREMENT

func get_wave_enemy_count(wave: int) -> int:
	var base_count := WAVE_BASE_ENEMY_COUNT + (wave - 1) * WAVE_ENEMY_INCREMENT
	return int(base_count * get_difficulty_config()["enemy_count_mult"])

func get_enemy_health(wave: int) -> float:
	var config: Dictionary = get_difficulty_config()
	var base: float = ENEMY_BASE_HEALTH * float(config["enemy_health_mult"])
	return base * pow(float(config["enemy_hp_scale_per_wave"]), wave - 1)

func get_enemy_speed(wave: int) -> float:
	var config: Dictionary = get_difficulty_config()
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
	turrets_purchased = 0
	time_survived = 0.0
	is_game_active = false
	player_level = 1
	player_luck = GameConstants.PLAYER_BASE_LUCK
	turret_counts.clear()
	item_counts.clear()
	selected_turret_type = ""
	collected_items.clear()
	active_modifiers.clear()
	total_gold = STARTING_GOLD
	shop_reroll_count = 0
	current_shop_offers.clear()
	pending_turret_purchases.clear()
