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

# =============================================================================
# SETTINGS
# =============================================================================
var show_damage_numbers: bool = true
var player_auto_attack_enabled: bool = false  # Player default attack disabled
var show_turret_ranges: bool = false  # Toggle turret range indicators

# =============================================================================
# TURRET TYPE SYSTEM
# =============================================================================

# Attack style tags - how damage is delivered
enum AttackStyle { PROJECTILE, INSTANT, AOE, CHAIN }

# Damage type tags - elemental classification
enum DamageType { PHYSICAL, FIRE, ELECTRIC, PLASMA }

# Enemy behavior tags - how enemies move/attack
enum EnemyBehavior { CHASE, RANGED, SWARM, TANK, EXPLOSIVE }

# =============================================================================
# ENEMY TYPE SYSTEM
# =============================================================================

# Enemy type registry - add new enemy types here
const ENEMY_TYPES: Dictionary = {
	"tiny": {
		"name": "Tiny Bot",
		"icon": "🤖",
		"description": "Small robot enemy. Quick and numerous.",
		"behaviors": [EnemyBehavior.CHASE, EnemyBehavior.SWARM],
		"sprite_folder": "res://assets/sprites/enemy_tiny",
		"base_stats": {
			"health": 15.0,
			"speed": 120.0,
			"contact_damage": 15.0,
			"xp_value": 5,
			"scale": 1.0,
		},
		"spawn_weight": 80,
		"min_wave": 1,
		"spawn_count": 2,  # Spawns in pairs
	},
	"basic": {
		"name": "Robot Grunt",
		"icon": "🤖",
		"description": "Standard enemy that chases the player.",
		"behaviors": [EnemyBehavior.CHASE],
		"sprite_folder": "res://assets/sprites/enemy_tiny",  # TODO: Replace with 64px sprites
		"base_stats": {
			"health": 30.0,
			"speed": 100.0,
			"contact_damage": 33.0,
			"xp_value": 10,
			"scale": 1.5,  # Scale up the tiny sprite for now
		},
		"spawn_weight": 100,
		"min_wave": 1,
	},
	"fast": {
		"name": "Scout Bot",
		"icon": "⚡",
		"description": "Quick but fragile enemy.",
		"behaviors": [EnemyBehavior.CHASE, EnemyBehavior.SWARM],
		"sprite_folder": "res://assets/sprites/enemy_tiny",
		"color_tint": Color(0.6, 0.9, 1.0),  # Light blue tint
		"base_stats": {
			"health": 15.0,
			"speed": 170.0,
			"contact_damage": 20.0,
			"xp_value": 8,
			"scale": 1.2,
		},
		"spawn_weight": 60,
		"min_wave": 2,
	},
	"tank": {
		"name": "Heavy Bot",
		"icon": "🛡️",
		"description": "Slow but very tough enemy.",
		"behaviors": [EnemyBehavior.CHASE, EnemyBehavior.TANK],
		"sprite_folder": "res://assets/sprites/enemy_tiny",
		"color_tint": Color(0.8, 0.5, 0.3),  # Brown/rust tint
		"base_stats": {
			"health": 120.0,
			"speed": 55.0,
			"contact_damage": 50.0,
			"xp_value": 25,
			"scale": 2.0,  # Much bigger
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
		"color_tint": Color(1.0, 0.4, 0.2),  # Orange/red tint
		"base_stats": {
			"health": 20.0,
			"speed": 120.0,
			"contact_damage": 25.0,
			"xp_value": 15,
			"scale": 1.3,
			"explosion_radius": 100.0,
			"explosion_damage": 40.0,
		},
		"spawn_weight": 25,
		"min_wave": 4,
	},
	"swarm": {
		"name": "Mini Bot",
		"icon": "🐜",
		"description": "Tiny but spawns in groups.",
		"behaviors": [EnemyBehavior.CHASE, EnemyBehavior.SWARM],
		"sprite_folder": "res://assets/sprites/enemy_tiny",
		"color_tint": Color(0.7, 1.0, 0.7),  # Light green tint
		"base_stats": {
			"health": 8.0,
			"speed": 135.0,
			"contact_damage": 10.0,
			"xp_value": 3,
			"scale": 0.5,
		},
		"spawn_weight": 40,
		"min_wave": 2,
		"spawn_count": 3,  # Spawns multiple at once
	},
}

# Color tints for turret types (Phase 1 visual differentiation)
const TURRET_COLORS: Dictionary = {
	"normal": Color("66CC66"),
	"sniper": Color("4466AA"),
	"fire": Color("FF6633"),
	"plasma": Color("AA44DD"),
	"shock": Color("DDDD44"),
	"tesla": Color("44DDDD"),
}

# Turret type registry - add new turret types here
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
			"rotation_speed": 300.0,
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
		"targeting": "farthest",  # Prioritizes back-line enemies
		"base_stats": {
			"damage": 45.0,
			"fire_rate": 0.5,
			"range": 500.0,
			"rotation_speed": 120.0,
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
			"rotation_speed": 300.0,
			"projectile_speed": 600.0,
			"pierce": 99,  # Effectively infinite - passes through enemies
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
		"targeting": "cluster",  # Prefers groups of enemies
		"base_stats": {
			"damage": 20.0,
			"fire_rate": 1.0,
			"range": 280.0,
			"rotation_speed": 280.0,
			"projectile_speed": 550.0,
			"pierce": 0,  # Explodes on first enemy
			"aoe_radius": 80.0,
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
			"fire_rate": 1.5,  # Pulse interval
			"range": 150.0,  # Pulse radius
			"rotation_speed": 0.0,  # Doesn't rotate
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
			"rotation_speed": 200.0,
			"chain_count": 3,
			"chain_range": 120.0,
			"chain_decay": 0.7,
		}
	},
}

# Runtime turret counts by type
var turret_counts: Dictionary = {}  # {"normal": 2, "fire": 1, etc.}
var selected_turret_type: String = ""  # Currently selected in pause menu

# =============================================================================
# MODIFIER SYSTEM
# =============================================================================
# Active modifiers from items - each modifier is a Dictionary:
# {
#   "id": String,           # Unique identifier
#   "stat": String,         # Which stat to modify (damage, fire_rate, etc.)
#   "operation": String,    # "add" or "multiply"
#   "value": float,         # The modification value
#   "filter": {             # Optional filters (OR logic within each array)
#     "damage_type": [],    # Array of DamageType enums
#     "attack_style": [],   # Array of AttackStyle enums
#     "turret_type": [],    # Array of turret type IDs
#   }
# }
var active_modifiers: Array = []

# Check if a turret matches a modifier's filter
func _modifier_matches_turret(modifier: Dictionary, turret_type: String) -> bool:
	if not TURRET_TYPES.has(turret_type):
		return false
	
	var turret_def: Dictionary = TURRET_TYPES[turret_type]
	var filter: Dictionary = modifier.get("filter", {})
	
	# Empty filter matches all turrets
	if filter.is_empty():
		return true
	
	# Check turret_type filter
	if filter.has("turret_type") and not filter["turret_type"].is_empty():
		if turret_type in filter["turret_type"]:
			return true
	
	# Check damage_type filter (OR logic)
	if filter.has("damage_type") and not filter["damage_type"].is_empty():
		for dtype in filter["damage_type"]:
			if dtype in turret_def.get("damage_types", []):
				return true
	
	# Check attack_style filter (OR logic)
	if filter.has("attack_style") and not filter["attack_style"].is_empty():
		for astyle in filter["attack_style"]:
			if astyle in turret_def.get("attack_styles", []):
				return true
	
	# If filters were specified but none matched
	var has_filters := filter.has("turret_type") or filter.has("damage_type") or filter.has("attack_style")
	return not has_filters

# Get turret stats with all modifiers applied
func get_turret_stats(turret_type: String) -> Dictionary:
	if not TURRET_TYPES.has(turret_type):
		return {}
	
	var base_stats: Dictionary = TURRET_TYPES[turret_type]["base_stats"].duplicate(true)
	
	# Apply difficulty modifier to damage
	base_stats["damage"] = base_stats["damage"] * get_difficulty_config()["turret_damage_mult"]
	
	# Collect applicable modifiers
	var add_mods: Dictionary = {}  # stat -> total add value
	var mult_mods: Dictionary = {}  # stat -> array of multipliers
	
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
	
	# Apply modifiers: first add, then multiply
	for stat in add_mods:
		base_stats[stat] = base_stats.get(stat, 0.0) + add_mods[stat]
	
	for stat in mult_mods:
		var combined_mult: float = 1.0
		for mult in mult_mods[stat]:
			combined_mult *= mult
		base_stats[stat] = base_stats.get(stat, 0.0) * combined_mult
	
	return base_stats

# Add a modifier (returns the modifier for chaining)
func add_modifier(modifier: Dictionary) -> Dictionary:
	active_modifiers.append(modifier)
	return modifier

# Remove a modifier by ID
func remove_modifier(modifier_id: String) -> bool:
	for i in range(active_modifiers.size() - 1, -1, -1):
		if active_modifiers[i].get("id", "") == modifier_id:
			active_modifiers.remove_at(i)
			return true
	return false

# Clear all modifiers
func clear_modifiers() -> void:
	active_modifiers.clear()

# Get turret color tint
func get_turret_color(turret_type: String) -> Color:
	return TURRET_COLORS.get(turret_type, Color.WHITE)

# Check if turret has a specific attack style
func turret_has_attack_style(turret_type: String, style: AttackStyle) -> bool:
	if not TURRET_TYPES.has(turret_type):
		return false
	return style in TURRET_TYPES[turret_type].get("attack_styles", [])

# Check if turret has a specific damage type
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

## Get base stats for an enemy type (before wave scaling)
func get_enemy_type_stats(enemy_type: String) -> Dictionary:
	if not ENEMY_TYPES.has(enemy_type):
		return ENEMY_TYPES["basic"]["base_stats"].duplicate(true)
	return ENEMY_TYPES[enemy_type]["base_stats"].duplicate(true)

## Get scaled stats for an enemy type at a specific wave
func get_enemy_stats_for_wave(enemy_type: String, wave: int) -> Dictionary:
	var base_stats := get_enemy_type_stats(enemy_type)
	var config := get_difficulty_config()
	
	# Apply difficulty multipliers
	base_stats["health"] = base_stats["health"] * config["enemy_health_mult"]
	base_stats["speed"] = base_stats["speed"] * config["enemy_speed_mult"]
	base_stats["contact_damage"] = base_stats["contact_damage"] * config["enemy_damage_mult"]
	
	# Apply wave scaling
	base_stats["health"] = base_stats["health"] * pow(config["enemy_hp_scale_per_wave"], wave - 1)
	base_stats["speed"] = base_stats["speed"] * pow(config["enemy_speed_scale_per_wave"], wave - 1)
	
	return base_stats

## Get available enemy types for a given wave (respects min_wave)
func get_available_enemy_types(wave: int) -> Array:
	var available: Array = []
	for enemy_type in ENEMY_TYPES:
		if ENEMY_TYPES[enemy_type].get("min_wave", 1) <= wave:
			available.append(enemy_type)
	return available

## Select a random enemy type based on spawn weights
func select_random_enemy_type(wave: int) -> String:
	var available := get_available_enemy_types(wave)
	if available.is_empty():
		return "basic"
	
	# Calculate total weight
	var total_weight: float = 0.0
	for enemy_type in available:
		total_weight += ENEMY_TYPES[enemy_type].get("spawn_weight", 100)
	
	# Random selection based on weight
	var roll := randf() * total_weight
	var cumulative: float = 0.0
	
	for enemy_type in available:
		cumulative += ENEMY_TYPES[enemy_type].get("spawn_weight", 100)
		if roll <= cumulative:
			return enemy_type
	
	return available[-1]  # Fallback to last

## Check if enemy type has a specific behavior
func enemy_has_behavior(enemy_type: String, behavior: EnemyBehavior) -> bool:
	if not ENEMY_TYPES.has(enemy_type):
		return false
	return behavior in ENEMY_TYPES[enemy_type].get("behaviors", [])

## Get spawn count for an enemy type (for swarm types)
func get_enemy_spawn_count(enemy_type: String) -> int:
	if not ENEMY_TYPES.has(enemy_type):
		return 1
	return ENEMY_TYPES[enemy_type].get("spawn_count", 1)

## Get color tint for an enemy type
func get_enemy_color(enemy_type: String) -> Color:
	if not ENEMY_TYPES.has(enemy_type):
		return Color.WHITE
	return ENEMY_TYPES[enemy_type].get("color_tint", Color.WHITE)

## Get sprite folder path for an enemy type
func get_enemy_sprite_folder(enemy_type: String) -> String:
	if not ENEMY_TYPES.has(enemy_type):
		return ENEMY_TYPES["basic"]["sprite_folder"]
	return ENEMY_TYPES[enemy_type].get("sprite_folder", ENEMY_TYPES["basic"]["sprite_folder"])

# =============================================================================
# ITEMS SYSTEM (Placeholder for future implementation)
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

# Collected items array - each item is a Dictionary with: name, description, rarity, icon_path
var collected_items: Array = []

# Helper to get current difficulty config
func get_difficulty_config() -> Dictionary:
	return DIFFICULTY_CONFIG[current_difficulty]

func get_difficulty_name() -> String:
	return get_difficulty_config()["name"]

# =============================================================================
# GAME CONSTANTS (Base values - modified by difficulty)
# =============================================================================
const ARENA_WIDTH: int = 1400
const ARENA_HEIGHT: int = 900
const MAX_WAVES: int = 10

# Player Constants
const PLAYER_BASE_MAX_HEALTH: float = 100.0
const PLAYER_SPEED: float = 200.0
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

# Turret Pickup System
const TURRET_PICKUP_RANGE: float = 60.0  # Player can pick up turrets within this radius
const TURRET_CARRY_OFFSET: Vector2 = Vector2(0, -40)  # Offset from player center (sits on head)
const TURRET_CARRY_SPEED_PENALTY: float = 0.7  # 30% speed reduction (multiply by 0.7)
const TURRET_IN_RANGE_INDICATOR_ALPHA: float = 0.5  # Subtle glow for nearby turrets

# Computed turret values
var TURRET_DAMAGE: float:
	get: return TURRET_BASE_DAMAGE * get_difficulty_config()["turret_damage_mult"]

# Enemy Base Constants (Wave 1)
const ENEMY_BASE_HEALTH: float = 30.0
const ENEMY_BASE_SPEED: float = 100.0
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
var player_level: int = 1  # Display-only for now

# =============================================================================
# ECONOMY SYSTEM
# =============================================================================

# Currency
var total_gold: int = 0
const STARTING_GOLD: int = 120  # Enough to buy any single turret
const GOLD_PER_ENEMY: int = 1
const GOLD_WAVE_BONUS_BASE: int = 20

# Shop State
var shop_reroll_count: int = 0
var current_shop_offers: Array = []
var pending_turret_purchases: Array[String] = []  # Turret IDs to spawn at wave start

# Shop Constants
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
	player_level = 1
	turret_counts.clear()
	selected_turret_type = ""
	collected_items.clear()
	active_modifiers.clear()
	total_gold = STARTING_GOLD
	shop_reroll_count = 0
	current_shop_offers.clear()
	pending_turret_purchases.clear()
