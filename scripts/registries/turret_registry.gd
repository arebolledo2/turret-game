class_name TurretRegistry
extends RefCounted

## Registry of all turret types and helper functions

# Color tints for turret types
const COLORS: Dictionary = {
	"normal": Color("66CC66"),
	"sniper": Color("4466AA"),
	"fire": Color("FF6633"),
	"plasma": Color("AA44DD"),
	"shock": Color("DDDD44"),
	"tesla": Color("44DDDD"),
}

# Base prices for turret types
const BASE_PRICES: Dictionary = {
	"normal": 65,
	"sniper": 150,
	"fire": 105,
	"plasma": 130,
	"shock": 118,
	"tesla": 143,
}

const TYPES: Dictionary = {
	"normal": {
		"name": "Normal Turret",
		"icon": "🗼",
		"description": "Standard auto-targeting turret. Reliable and consistent.",
		"attack_styles": [GameEnums.AttackStyle.PROJECTILE],
		"damage_types": [GameEnums.DamageType.PHYSICAL],
		"base_stats": {
			"damage": 50.0,
			"fire_rate": 1.2,
			"range": 160.0,
			"rotation_speed": 300.0,
			"projectile_speed": 700.0,
			"pierce": 0,
		}
	},
	"sniper": {
		"name": "Sniper Turret",
		"icon": "🎯",
		"description": "Long-range instant-hit turret. High damage, slow fire rate.",
		"attack_styles": [GameEnums.AttackStyle.INSTANT],
		"damage_types": [GameEnums.DamageType.PHYSICAL],
		"targeting": "farthest",
		"base_stats": {
			"damage": 70.0,
			"fire_rate": 0.5,
			"range": 500.0,
			"rotation_speed": 120.0,
		}
	},
	"fire": {
		"name": "Fire Turret",
		"icon": "🔥",
		"description": "Incendiary turret that ignites enemies.",
		"attack_styles": [GameEnums.AttackStyle.PROJECTILE],
		"damage_types": [GameEnums.DamageType.FIRE],
		"base_stats": {
			"damage": 18.0,
			"fire_rate": 2.0,
			"range": 140.0,
			"rotation_speed": 300.0,
			"projectile_speed": 600.0,
			"pierce": 99,
			"dot_damage": 8.0,
			"dot_duration": 3.0,
			"dot_tick_rate": 1.0,
		}
	},
	"plasma": {
		"name": "Plasma Turret",
		"icon": "💠",
		"description": "Fires explosive plasma orbs that damage an area.",
		"attack_styles": [GameEnums.AttackStyle.PROJECTILE, GameEnums.AttackStyle.AOE],
		"damage_types": [GameEnums.DamageType.PLASMA],
		"targeting": "cluster",
		"base_stats": {
			"damage": 40.0,
			"fire_rate": 1.0,
			"range": 170.0,
			"rotation_speed": 280.0,
			"projectile_speed": 550.0,
			"pierce": 0,
			"aoe_radius": 100.0,
			"knockback_force": 120.0,
		}
	},
	"shock": {
		"name": "Shock Turret",
		"icon": "⚡",
		"description": "Pulses electric damage around itself.",
		"attack_styles": [GameEnums.AttackStyle.AOE],
		"damage_types": [GameEnums.DamageType.ELECTRIC],
		"base_stats": {
			"damage": 25.0,
			"fire_rate": 1.5,
			"range": 100.0,
			"rotation_speed": 0.0,
			"slow_intensity": 0.25,
			"slow_duration": 0.5,
		}
	},
	"tesla": {
		"name": "Tesla Turret",
		"icon": "⛓️",
		"description": "Fires chain lightning that jumps between enemies.",
		"attack_styles": [GameEnums.AttackStyle.INSTANT, GameEnums.AttackStyle.CHAIN],
		"damage_types": [GameEnums.DamageType.ELECTRIC],
		"base_stats": {
			"damage": 38.0,
			"fire_rate": 1.2,
			"range": 150.0,
			"rotation_speed": 200.0,
			"chain_count": 3,
			"chain_range": 150.0,
			"chain_decay": 0.7,
		}
	},
}


## Get the definition for a turret type
static func get_type(type_id: String) -> Dictionary:
	return TYPES.get(type_id, TYPES["normal"])


## Get all type IDs
static func get_all_type_ids() -> Array:
	return TYPES.keys()


## Get base stats for a turret type
static func get_base_stats(type_id: String) -> Dictionary:
	if not TYPES.has(type_id):
		return TYPES["normal"]["base_stats"].duplicate(true)
	return TYPES[type_id]["base_stats"].duplicate(true)


## Get turret color tint
static func get_color(type_id: String) -> Color:
	return COLORS.get(type_id, Color.WHITE)


## Get turret base price
static func get_base_price(type_id: String) -> int:
	return BASE_PRICES.get(type_id, 50)


## Check if turret has a specific attack style
static func has_attack_style(type_id: String, style: GameEnums.AttackStyle) -> bool:
	if not TYPES.has(type_id):
		return false
	return style in TYPES[type_id].get("attack_styles", [])


## Check if turret has a specific damage type
static func has_damage_type(type_id: String, dtype: GameEnums.DamageType) -> bool:
	if not TYPES.has(type_id):
		return false
	return dtype in TYPES[type_id].get("damage_types", [])


## Get targeting strategy for a turret type
static func get_targeting(type_id: String) -> String:
	if not TYPES.has(type_id):
		return "closest"
	return TYPES[type_id].get("targeting", "closest")
