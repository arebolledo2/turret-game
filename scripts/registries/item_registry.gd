class_name ItemRegistry
extends RefCounted

## Registry of all items and helper functions

# Rarity color scheme
const RARITY_COLORS: Dictionary = {
	GameEnums.ItemRarity.COMMON: Color.WHITE,
	GameEnums.ItemRarity.UNCOMMON: Color.GREEN,
	GameEnums.ItemRarity.RARE: Color.CORNFLOWER_BLUE,
	GameEnums.ItemRarity.EPIC: Color.PURPLE,
	GameEnums.ItemRarity.LEGENDARY: Color.ORANGE,
	GameEnums.ItemRarity.UNIQUE: Color.RED,
}

const RARITY_NAMES: Dictionary = {
	GameEnums.ItemRarity.COMMON: "Common",
	GameEnums.ItemRarity.UNCOMMON: "Uncommon",
	GameEnums.ItemRarity.RARE: "Rare",
	GameEnums.ItemRarity.EPIC: "Epic",
	GameEnums.ItemRarity.LEGENDARY: "Legendary",
	GameEnums.ItemRarity.UNIQUE: "Unique",
}

const BASE_PRICES: Dictionary = {
	GameEnums.ItemRarity.COMMON: 40,
	GameEnums.ItemRarity.UNCOMMON: 70,
	GameEnums.ItemRarity.RARE: 110,
	GameEnums.ItemRarity.EPIC: 160,
	GameEnums.ItemRarity.LEGENDARY: 240,
	GameEnums.ItemRarity.UNIQUE: 350,
}

const ITEMS: Dictionary = {
	"swift_boots": {
		"name": "Swift Boots",
		"icon": "👟",
		"description": "Move faster, shoot weaker",
		"rarity": GameEnums.ItemRarity.COMMON,
		"modifiers": [
			{"stat": "player_speed", "operation": "multiply", "value": 1.05},
			{"stat": "damage", "operation": "multiply", "value": 0.97, "filter": {"turret_type": ["all"]}}
		]
	},
	"heavy_ammunition": {
		"name": "Heavy Ammunition",
		"icon": "💥",
		"description": "Powerful rounds, but heavy to carry",
		"rarity": GameEnums.ItemRarity.COMMON,
		"modifiers": [
			{"stat": "damage", "operation": "multiply", "value": 1.04, "filter": {"turret_type": ["all"]}},
			{"stat": "player_max_health", "operation": "add", "value": -5.0}
		]
	},
	"lightweight_frame": {
		"name": "Lightweight Frame",
		"icon": "🪶",
		"description": "Speed at the cost of protection",
		"rarity": GameEnums.ItemRarity.COMMON,
		"modifiers": [
			{"stat": "player_speed", "operation": "multiply", "value": 1.03},
			{"stat": "player_max_health", "operation": "add", "value": -3.0}
		]
	},
	"reinforced_plating": {
		"name": "Reinforced Plating",
		"icon": "🛡️",
		"description": "Sturdy but sluggish",
		"rarity": GameEnums.ItemRarity.COMMON,
		"modifiers": [
			{"stat": "player_max_health", "operation": "add", "value": 10.0},
			{"stat": "player_speed", "operation": "multiply", "value": 0.96}
		]
	},
	"precision_optics": {
		"name": "Precision Optics",
		"icon": "🔭",
		"description": "Better aim, more focus required",
		"rarity": GameEnums.ItemRarity.COMMON,
		"modifiers": [
			{"stat": "fire_rate", "operation": "multiply", "value": 1.03, "filter": {"turret_type": ["all"]}},
			{"stat": "player_speed", "operation": "multiply", "value": 0.98}
		]
	}
}


## Get the definition for an item
static func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})


## Get all item IDs
static func get_all_item_ids() -> Array:
	return ITEMS.keys()


## Check if an item exists
static func has_item(item_id: String) -> bool:
	return ITEMS.has(item_id)


## Get item rarity
static func get_rarity(item_id: String) -> GameEnums.ItemRarity:
	if not ITEMS.has(item_id):
		return GameEnums.ItemRarity.COMMON
	return ITEMS[item_id].get("rarity", GameEnums.ItemRarity.COMMON)


## Get rarity color
static func get_rarity_color(rarity: GameEnums.ItemRarity) -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)


## Get rarity name
static func get_rarity_name(rarity: GameEnums.ItemRarity) -> String:
	return RARITY_NAMES.get(rarity, "Common")


## Get base price for a rarity
static func get_rarity_price(rarity: GameEnums.ItemRarity) -> int:
	return BASE_PRICES.get(rarity, 40)


## Get price for an item
static func get_item_price(item_id: String) -> int:
	var rarity := get_rarity(item_id)
	return get_rarity_price(rarity)


## Get item modifiers
static func get_modifiers(item_id: String) -> Array:
	if not ITEMS.has(item_id):
		return []
	return ITEMS[item_id].get("modifiers", [])
