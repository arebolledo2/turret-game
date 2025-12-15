class_name ItemRegistry
extends RefCounted

## Registry of all items and helper functions
## Shop V2: 19 items (9 interesting + 10 boring trade-off items)

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
	# ==========================================================================
	# COMMON TIER (Price: 40) - 5 items (1 interesting, 4 boring)
	# ==========================================================================
	
	# Interesting
	"scrap_magnet": {
		"name": "Scrap Magnet",
		"icon": "🧲",
		"description": "Increases pickup radius by 30%",
		"rarity": GameEnums.ItemRarity.COMMON,
		"modifiers": [
			{"stat": "pickup_radius", "operation": "multiply", "value": 1.3}
		]
	},
	
	# Boring trade-offs
	"reinforced_hull": {
		"name": "Reinforced Hull",
		"icon": "🛡️",
		"description": "+15 max HP, but 3% slower movement",
		"rarity": GameEnums.ItemRarity.COMMON,
		"modifiers": [
			{"stat": "player_max_health", "operation": "add", "value": 15.0},
			{"stat": "player_speed", "operation": "multiply", "value": 0.97}
		]
	},
	"quick_loader": {
		"name": "Quick Loader",
		"icon": "⏱️",
		"description": "+10% fire rate, but 3% less damage",
		"rarity": GameEnums.ItemRarity.COMMON,
		"modifiers": [
			{"stat": "fire_rate", "operation": "multiply", "value": 1.10, "filter": {"turret_type": ["all"]}},
			{"stat": "damage", "operation": "multiply", "value": 0.97, "filter": {"turret_type": ["all"]}}
		]
	},
	"shock_absorbers": {
		"name": "Shock Absorbers",
		"icon": "🏃",
		"description": "+10% movement speed, but -5 max HP",
		"rarity": GameEnums.ItemRarity.COMMON,
		"modifiers": [
			{"stat": "player_speed", "operation": "multiply", "value": 1.10},
			{"stat": "player_max_health", "operation": "add", "value": -5.0}
		]
	},
	"dense_rounds": {
		"name": "Dense Rounds",
		"icon": "🔩",
		"description": "+10% damage, but 2% slower fire rate",
		"rarity": GameEnums.ItemRarity.COMMON,
		"modifiers": [
			{"stat": "damage", "operation": "multiply", "value": 1.10, "filter": {"turret_type": ["all"]}},
			{"stat": "fire_rate", "operation": "multiply", "value": 0.98, "filter": {"turret_type": ["all"]}}
		]
	},
	
	# ==========================================================================
	# UNCOMMON TIER (Price: 70) - 5 items (1 interesting, 4 boring)
	# ==========================================================================
	
	# Interesting
	"overcharged_cells": {
		"name": "Overcharged Cells",
		"icon": "⚡",
		"description": "Electric turrets deal 30% more damage but chain to fewer targets",
		"rarity": GameEnums.ItemRarity.UNCOMMON,
		"modifiers": [
			{"stat": "damage", "operation": "multiply", "value": 1.3, "filter": {"damage_type": [GameEnums.DamageType.ELECTRIC]}},
			{"stat": "chain_count", "operation": "add", "value": -1, "filter": {"turret_type": ["tesla"]}}
		]
	},
	
	# Boring trade-offs
	"extended_barrel": {
		"name": "Extended Barrel",
		"icon": "📏",
		"description": "+15% turret range, but 10% slower fire rate",
		"rarity": GameEnums.ItemRarity.UNCOMMON,
		"modifiers": [
			{"stat": "range", "operation": "multiply", "value": 1.15, "filter": {"turret_type": ["all"]}},
			{"stat": "fire_rate", "operation": "multiply", "value": 0.90, "filter": {"turret_type": ["all"]}}
		]
	},
	"heavy_plating": {
		"name": "Heavy Plating",
		"icon": "🪨",
		"description": "+20 max HP, but 8% slower movement",
		"rarity": GameEnums.ItemRarity.UNCOMMON,
		"modifiers": [
			{"stat": "player_max_health", "operation": "add", "value": 20.0},
			{"stat": "player_speed", "operation": "multiply", "value": 0.92}
		]
	},
	"rapid_coolant": {
		"name": "Rapid Coolant",
		"icon": "❄️",
		"description": "+15% fire rate, but 10% reduced range",
		"rarity": GameEnums.ItemRarity.UNCOMMON,
		"modifiers": [
			{"stat": "fire_rate", "operation": "multiply", "value": 1.15, "filter": {"turret_type": ["all"]}},
			{"stat": "range", "operation": "multiply", "value": 0.90, "filter": {"turret_type": ["all"]}}
		]
	},
	"nimble_servos": {
		"name": "Nimble Servos",
		"icon": "🦿",
		"description": "+8% movement speed, but 5% less turret damage",
		"rarity": GameEnums.ItemRarity.UNCOMMON,
		"modifiers": [
			{"stat": "player_speed", "operation": "multiply", "value": 1.08},
			{"stat": "damage", "operation": "multiply", "value": 0.95, "filter": {"turret_type": ["all"]}}
		]
	},
	
	# ==========================================================================
	# RARE TIER (Price: 110) - 6 items (4 interesting, 2 boring)
	# ==========================================================================
	
	# Interesting (2 unique)
	"volatile_rounds": {
		"name": "Volatile Rounds",
		"icon": "🔴",
		"description": "Turret projectiles explode on hit, but turrets fire slower",
		"rarity": GameEnums.ItemRarity.RARE,
		"max_stacks": 1,
		"modifiers": [
			{"stat": "aoe_radius", "operation": "add", "value": 40.0, "filter": {"turret_type": ["normal", "fire"]}},
			{"stat": "fire_rate", "operation": "multiply", "value": 0.85, "filter": {"turret_type": ["all"]}}
		]
	},
	"incendiary_gel": {
		"name": "Incendiary Gel",
		"icon": "🩸",
		"description": "Fire effects last twice as long and tick faster",
		"rarity": GameEnums.ItemRarity.RARE,
		"max_stacks": 1,
		"modifiers": [
			{"stat": "dot_duration", "operation": "multiply", "value": 2.0, "filter": {"turret_type": ["fire"]}},
			{"stat": "dot_tick_rate", "operation": "multiply", "value": 0.5, "filter": {"turret_type": ["fire"]}}
		]
	},
	"targeting_matrix": {
		"name": "Targeting Matrix",
		"icon": "🎯",
		"description": "Turrets rotate 100% faster and have 15% increased fire rate",
		"rarity": GameEnums.ItemRarity.RARE,
		"modifiers": [
			{"stat": "rotation_speed", "operation": "multiply", "value": 2.0, "filter": {"turret_type": ["all"]}},
			{"stat": "fire_rate", "operation": "multiply", "value": 1.15, "filter": {"turret_type": ["all"]}}
		]
	},
	"plasma_capacitor": {
		"name": "Plasma Capacitor",
		"icon": "🟣",
		"description": "Plasma explosions are 60% larger with stronger knockback",
		"rarity": GameEnums.ItemRarity.RARE,
		"modifiers": [
			{"stat": "aoe_radius", "operation": "multiply", "value": 1.6, "filter": {"turret_type": ["plasma"]}},
			{"stat": "knockback_force", "operation": "multiply", "value": 1.5, "filter": {"turret_type": ["plasma"]}}
		]
	},
	
	# Boring trade-offs
	"fortified_core": {
		"name": "Fortified Core",
		"icon": "💚",
		"description": "+25 max HP, but 10% less turret damage",
		"rarity": GameEnums.ItemRarity.RARE,
		"modifiers": [
			{"stat": "player_max_health", "operation": "add", "value": 25.0},
			{"stat": "damage", "operation": "multiply", "value": 0.90, "filter": {"turret_type": ["all"]}}
		]
	},
	"overclocked_motors": {
		"name": "Overclocked Motors",
		"icon": "⚙️",
		"description": "+20% turret rotation speed, but 5% slower fire rate",
		"rarity": GameEnums.ItemRarity.RARE,
		"modifiers": [
			{"stat": "rotation_speed", "operation": "multiply", "value": 1.20, "filter": {"turret_type": ["all"]}},
			{"stat": "fire_rate", "operation": "multiply", "value": 0.95, "filter": {"turret_type": ["all"]}}
		]
	},
	
	# ==========================================================================
	# EPIC TIER (Price: 160) - 3 items (all interesting)
	# ==========================================================================
	
	"shrapnel_rounds": {
		"name": "Shrapnel Rounds",
		"icon": "💥",
		"description": "Projectiles pierce through 1 additional enemy",
		"rarity": GameEnums.ItemRarity.EPIC,
		"modifiers": [
			{"stat": "pierce", "operation": "add", "value": 1, "filter": {"attack_style": [GameEnums.AttackStyle.PROJECTILE]}}
		]
	},
	"glass_cannon_core": {
		"name": "Glass Cannon Core",
		"icon": "💎",
		"description": "ALL turrets deal 40% more damage. You have 50% less health.",
		"rarity": GameEnums.ItemRarity.EPIC,
		"max_stacks": 1,
		"modifiers": [
			{"stat": "damage", "operation": "multiply", "value": 1.4, "filter": {"turret_type": ["all"]}},
			{"stat": "player_max_health", "operation": "multiply", "value": 0.5}
		]
	},
	"executioners_mark": {
		"name": "Executioner's Mark",
		"icon": "☠️",
		"description": "Turrets deal 50% bonus damage to enemies below 25% health",
		"rarity": GameEnums.ItemRarity.EPIC,
		"special_effect": "executioner",
		"modifiers": []
	},
	
	# ==========================================================================
	# NEW COMMON ITEMS - Phase 1
	# ==========================================================================

	"shielded_capacitors": {
		"name": "Shielded Capacitors",
		"icon": "⚡",
		"description": "Electric turrets gain +15% fire rate but -5% range",
		"rarity": GameEnums.ItemRarity.COMMON,
		"modifiers": [
			{"stat": "fire_rate", "operation": "multiply", "value": 1.15, "filter": {"damage_type": [GameEnums.DamageType.ELECTRIC]}},
			{"stat": "range", "operation": "multiply", "value": 0.95, "filter": {"damage_type": [GameEnums.DamageType.ELECTRIC]}}
		]
	},
	"heat_vents": {
		"name": "Heat Vents",
		"icon": "🔥",
		"description": "Fire turrets gain +12% range but -8% fire rate",
		"rarity": GameEnums.ItemRarity.COMMON,
		"modifiers": [
			{"stat": "range", "operation": "multiply", "value": 1.12, "filter": {"damage_type": [GameEnums.DamageType.FIRE]}},
			{"stat": "fire_rate", "operation": "multiply", "value": 0.92, "filter": {"damage_type": [GameEnums.DamageType.FIRE]}}
		]
	},
	"ballistic_plating": {
		"name": "Ballistic Plating",
		"icon": "🛡️",
		"description": "Physical turrets gain +10% damage but -5% projectile speed",
		"rarity": GameEnums.ItemRarity.COMMON,
		"modifiers": [
			{"stat": "damage", "operation": "multiply", "value": 1.10, "filter": {"damage_type": [GameEnums.DamageType.PHYSICAL]}},
			{"stat": "projectile_speed", "operation": "multiply", "value": 0.95, "filter": {"damage_type": [GameEnums.DamageType.PHYSICAL]}}
		]
	},
	"plasma_coils": {
		"name": "Plasma Coils",
		"icon": "💠",
		"description": "Plasma turrets gain +8% projectile speed and fire rate, -6% damage",
		"rarity": GameEnums.ItemRarity.COMMON,
		"modifiers": [
			{"stat": "projectile_speed", "operation": "multiply", "value": 1.08, "filter": {"damage_type": [GameEnums.DamageType.PLASMA]}},
			{"stat": "fire_rate", "operation": "multiply", "value": 1.08, "filter": {"damage_type": [GameEnums.DamageType.PLASMA]}},
			{"stat": "damage", "operation": "multiply", "value": 0.94, "filter": {"damage_type": [GameEnums.DamageType.PLASMA]}}
		]
	},
	"salvage_optimizer": {
		"name": "Salvage Optimizer",
		"icon": "💰",
		"description": "+15% gold from enemy kills",
		"rarity": GameEnums.ItemRarity.COMMON,
		"modifiers": [
			{"stat": "gold_earn_mult", "operation": "multiply", "value": 1.15}
		]
	},
	"budget_capacitor": {
		"name": "Budget Capacitor",
		"icon": "🔋",
		"description": "Reroll costs reduced by 20%. All turrets have -5% fire rate",
		"rarity": GameEnums.ItemRarity.COMMON,
		"modifiers": [
			{"stat": "reroll_cost", "operation": "multiply", "value": 0.80},
			{"stat": "fire_rate", "operation": "multiply", "value": 0.95, "filter": {"turret_type": ["all"]}}
		]
	},
	"ammo_surplus": {
		"name": "Ammo Surplus",
		"icon": "📦",
		"description": "Projectile turrets gain +8% fire rate but -5% damage",
		"rarity": GameEnums.ItemRarity.COMMON,
		"modifiers": [
			{"stat": "fire_rate", "operation": "multiply", "value": 1.08, "filter": {"attack_style": [GameEnums.AttackStyle.PROJECTILE]}},
			{"stat": "damage", "operation": "multiply", "value": 0.95, "filter": {"attack_style": [GameEnums.AttackStyle.PROJECTILE]}}
		]
	},
	"targeting_subroutine": {
		"name": "Targeting Subroutine",
		"icon": "🎯",
		"description": "All turrets gain +12% rotation speed but -6% range",
		"rarity": GameEnums.ItemRarity.COMMON,
		"modifiers": [
			{"stat": "rotation_speed", "operation": "multiply", "value": 1.12, "filter": {"turret_type": ["all"]}},
			{"stat": "range", "operation": "multiply", "value": 0.94, "filter": {"turret_type": ["all"]}}
		]
	},
	"overclock_module": {
		"name": "Overclock Module",
		"icon": "⚙️",
		"description": "All turrets gain +6% fire rate and damage. You have -8% max health",
		"rarity": GameEnums.ItemRarity.COMMON,
		"modifiers": [
			{"stat": "fire_rate", "operation": "multiply", "value": 1.06, "filter": {"turret_type": ["all"]}},
			{"stat": "damage", "operation": "multiply", "value": 1.06, "filter": {"turret_type": ["all"]}},
			{"stat": "player_max_health", "operation": "multiply", "value": 0.92}
		]
	},
	"compact_design": {
		"name": "Compact Design",
		"icon": "📐",
		"description": "Turret purchase penalty reduced by 3% per turret. All turrets -4% range",
		"rarity": GameEnums.ItemRarity.COMMON,
		"max_stacks": 3,
		"modifiers": [
			{"stat": "turret_penalty_reduction", "operation": "add", "value": -0.03},
			{"stat": "range", "operation": "multiply", "value": 0.96, "filter": {"turret_type": ["all"]}}
		]
	},

	# ==========================================================================
	# DAMAGE TYPE SPECIALIZATION ITEMS
	# ==========================================================================

	"kinetic_enhancer": {
		"name": "Kinetic Enhancer",
		"icon": "⚙️",
		"description": "Physical turrets +25% damage. Electric turrets -10% damage",
		"rarity": GameEnums.ItemRarity.UNCOMMON,
		"modifiers": [
			{"stat": "damage", "operation": "multiply", "value": 1.25, "filter": {"damage_type": [GameEnums.DamageType.PHYSICAL]}},
			{"stat": "damage", "operation": "multiply", "value": 0.90, "filter": {"damage_type": [GameEnums.DamageType.ELECTRIC]}}
		]
	},
	"insulated_coating": {
		"name": "Insulated Coating",
		"icon": "🛡️",
		"description": "Electric turrets +35% damage and +20% range. Fire turrets -15% fire rate",
		"rarity": GameEnums.ItemRarity.RARE,
		"modifiers": [
			{"stat": "damage", "operation": "multiply", "value": 1.35, "filter": {"damage_type": [GameEnums.DamageType.ELECTRIC]}},
			{"stat": "range", "operation": "multiply", "value": 1.20, "filter": {"damage_type": [GameEnums.DamageType.ELECTRIC]}},
			{"stat": "fire_rate", "operation": "multiply", "value": 0.85, "filter": {"damage_type": [GameEnums.DamageType.FIRE]}}
		]
	},
	"thermal_amplifier": {
		"name": "Thermal Amplifier",
		"icon": "🔥",
		"description": "Fire turrets +50% DoT damage and +1.0s DoT duration. All turrets -8% projectile speed",
		"rarity": GameEnums.ItemRarity.RARE,
		"max_stacks": 2,
		"modifiers": [
			{"stat": "dot_damage", "operation": "multiply", "value": 1.50, "filter": {"damage_type": [GameEnums.DamageType.FIRE]}},
			{"stat": "dot_duration", "operation": "add", "value": 1.0, "filter": {"damage_type": [GameEnums.DamageType.FIRE]}},
			{"stat": "projectile_speed", "operation": "multiply", "value": 0.92, "filter": {"turret_type": ["all"]}}
		]
	},
	"plasma_destabilizer": {
		"name": "Plasma Destabilizer",
		"icon": "💥",
		"description": "Plasma turrets +80% knockback and +25% explosion radius. -20% projectile speed, -15% fire rate",
		"rarity": GameEnums.ItemRarity.EPIC,
		"modifiers": [
			{"stat": "knockback_force", "operation": "multiply", "value": 1.80, "filter": {"damage_type": [GameEnums.DamageType.PLASMA]}},
			{"stat": "aoe_radius", "operation": "multiply", "value": 1.25, "filter": {"damage_type": [GameEnums.DamageType.PLASMA]}},
			{"stat": "projectile_speed", "operation": "multiply", "value": 0.80, "filter": {"damage_type": [GameEnums.DamageType.PLASMA]}},
			{"stat": "fire_rate", "operation": "multiply", "value": 0.85, "filter": {"damage_type": [GameEnums.DamageType.PLASMA]}}
		]
	},
	"elemental_conduit": {
		"name": "Elemental Conduit",
		"icon": "🌀",
		"description": "ALL turrets +15% damage per different damage type owned (max +60% with all 4 types)",
		"rarity": GameEnums.ItemRarity.LEGENDARY,
		"max_stacks": 1,
		"special_effect": "elemental_conduit",
		"modifiers": []
	},

	# ==========================================================================
	# ECONOMY ITEMS
	# ==========================================================================

	"efficient_scavenger": {
		"name": "Efficient Scavenger",
		"icon": "🪙",
		"description": "+30% gold from enemy kills",
		"rarity": GameEnums.ItemRarity.COMMON,
		"modifiers": [
			{"stat": "gold_earn_mult", "operation": "multiply", "value": 1.30}
		]
	},
	"combat_surplus": {
		"name": "Combat Surplus",
		"icon": "📦",
		"description": "Waves spawn +15% more enemies. Gold per enemy +25%",
		"rarity": GameEnums.ItemRarity.UNCOMMON,
		"modifiers": [
			{"stat": "enemy_count_mult", "operation": "multiply", "value": 1.15},
			{"stat": "gold_earn_mult", "operation": "multiply", "value": 1.25}
		]
	},
	"quality_over_quantity": {
		"name": "Quality Over Quantity",
		"icon": "👑",
		"description": "Waves spawn -30% fewer enemies. Gold per enemy +100%. Turret prices +15%",
		"rarity": GameEnums.ItemRarity.RARE,
		"max_stacks": 1,
		"modifiers": [
			{"stat": "enemy_count_mult", "operation": "multiply", "value": 0.70},
			{"stat": "gold_earn_mult", "operation": "multiply", "value": 2.0},
			{"stat": "shop_price_mult", "operation": "multiply", "value": 1.15}
		]
	},
	"bargain_hunter": {
		"name": "Bargain Hunter",
		"icon": "🏷️",
		"description": "Reroll costs -40%. Shop offers +1 slot. All turrets -8% damage",
		"rarity": GameEnums.ItemRarity.RARE,
		"max_stacks": 2,
		"modifiers": [
			{"stat": "reroll_cost", "operation": "multiply", "value": 0.60},
			{"stat": "shop_offer_count", "operation": "add", "value": 1},
			{"stat": "damage", "operation": "multiply", "value": 0.92, "filter": {"turret_type": ["all"]}}
		]
	},
	"war_profiteer": {
		"name": "War Profiteer",
		"icon": "💵",
		"description": "Wave completion bonus gold +100%. Shop prices +25%",
		"rarity": GameEnums.ItemRarity.EPIC,
		"max_stacks": 1,
		"modifiers": [
			{"stat": "wave_bonus_mult", "operation": "multiply", "value": 2.0},
			{"stat": "shop_price_mult", "operation": "multiply", "value": 1.25}
		]
	},

	# ==========================================================================
	# TALL/WIDE ITEMS (Army Size Strategy)
	# ==========================================================================

	"mass_production": {
		"name": "Mass Production",
		"icon": "🏭",
		"description": "Turret purchase penalty reduced from 25% to 15% per turret. All turrets -10% damage",
		"rarity": GameEnums.ItemRarity.UNCOMMON,
		"max_stacks": 2,
		"modifiers": [
			{"stat": "turret_penalty_reduction", "operation": "add", "value": -0.10},
			{"stat": "damage", "operation": "multiply", "value": 0.90, "filter": {"turret_type": ["all"]}}
		]
	},
	"army_doctrine": {
		"name": "Army Doctrine",
		"icon": "🪖",
		"description": "For each turret beyond the 5th, all turrets gain +3% fire rate (max +30%). -10% range",
		"rarity": GameEnums.ItemRarity.RARE,
		"max_stacks": 1,
		"special_effect": "army_doctrine",
		"modifiers": [
			{"stat": "range", "operation": "multiply", "value": 0.90, "filter": {"turret_type": ["all"]}}
		]
	},
	"elite_forces": {
		"name": "Elite Forces",
		"icon": "⭐",
		"description": "If you own ≤5 turrets: all turrets +40% damage, +25% range. Penalty increased to 40% per turret",
		"rarity": GameEnums.ItemRarity.RARE,
		"max_stacks": 1,
		"special_effect": "elite_forces",
		"modifiers": [
			{"stat": "turret_penalty_increase", "operation": "add", "value": 0.15}
		]
	},
	"quantity_discount": {
		"name": "Quantity Discount",
		"icon": "💲",
		"description": "Every 3rd turret purchased costs only 50% of its calculated price",
		"rarity": GameEnums.ItemRarity.EPIC,
		"max_stacks": 1,
		"special_effect": "quantity_discount",
		"modifiers": []
	},
	"focused_investment": {
		"name": "Focused Investment",
		"icon": "🎯",
		"description": "Your most numerous turret type gains +60% damage, +20% fire rate, +15% range. All others -20% damage",
		"rarity": GameEnums.ItemRarity.LEGENDARY,
		"max_stacks": 1,
		"special_effect": "focused_investment",
		"modifiers": []
	},

	# ==========================================================================
	# TURRET VARIETY ITEMS (Mixing Turret Types)
	# ==========================================================================

	"diversity_matrix": {
		"name": "Diversity Matrix",
		"icon": "🔷",
		"description": "For each different turret type owned, all turrets gain +8% damage (max +48%). Penalty +5% per turret",
		"rarity": GameEnums.ItemRarity.UNCOMMON,
		"max_stacks": 2,
		"special_effect": "diversity_matrix",
		"modifiers": [
			{"stat": "turret_penalty_increase", "operation": "add", "value": 0.05}
		]
	},
	"standardized_parts": {
		"name": "Standardized Parts",
		"icon": "🔧",
		"description": "Owning multiple of the same turret type grants +5% fire rate per duplicate. Mixed types -12% range",
		"rarity": GameEnums.ItemRarity.RARE,
		"max_stacks": 1,
		"special_effect": "standardized_parts",
		"modifiers": [
			{"stat": "range", "operation": "multiply", "value": 0.88, "filter": {"turret_type": ["all"]}}
		]
	},
	"cross_training": {
		"name": "Cross-Training",
		"icon": "🎓",
		"description": "For every 2 different turret types owned, all turrets gain +15% rotation speed. -5% damage",
		"rarity": GameEnums.ItemRarity.RARE,
		"special_effect": "cross_training",
		"modifiers": [
			{"stat": "damage", "operation": "multiply", "value": 0.95, "filter": {"turret_type": ["all"]}}
		]
	},
	"mono_type_mastery": {
		"name": "Mono-Type Mastery",
		"icon": "👑",
		"description": "If you own only ONE turret type, those turrets gain +100% damage and +50% fire rate",
		"rarity": GameEnums.ItemRarity.EPIC,
		"max_stacks": 1,
		"special_effect": "mono_type_mastery",
		"modifiers": []
	},
	"synergy_core": {
		"name": "Synergy Core",
		"icon": "✨",
		"description": "ALL turrets +12% damage per different turret type. +25% bonus if you own all 6 types (max +97%)",
		"rarity": GameEnums.ItemRarity.LEGENDARY,
		"max_stacks": 1,
		"special_effect": "synergy_core",
		"modifiers": []
	},

	# ==========================================================================
	# LUCK ITEMS
	# ==========================================================================

	"lucky_charm": {
		"name": "Lucky Charm",
		"icon": "🍀",
		"description": "+10 luck. Better items may appear in shops.",
		"rarity": GameEnums.ItemRarity.COMMON,
		"modifiers": [
			{"stat": "player_luck", "operation": "add", "value": 0.10}
		]
	},
	"probability_matrix": {
		"name": "Probability Matrix",
		"icon": "🎲",
		"description": "+25 luck, but rerolls cost 50% more.",
		"rarity": GameEnums.ItemRarity.RARE,
		"modifiers": [
			{"stat": "player_luck", "operation": "add", "value": 0.25},
			{"stat": "reroll_cost", "operation": "multiply", "value": 1.5}
		]
	},
	"fortunes_favor": {
		"name": "Fortune's Favor",
		"icon": "⭐",
		"description": "+40 luck. Rare+ items cost 15% less.",
		"rarity": GameEnums.ItemRarity.EPIC,
		"max_stacks": 1,
		"modifiers": [
			{"stat": "player_luck", "operation": "add", "value": 0.40}
		],
		"special_effect": "fortune_discount"
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


## Get max stacks for an item (0 = unlimited)
static func get_max_stacks(item_id: String) -> int:
	if not ITEMS.has(item_id):
		return 0
	return ITEMS[item_id].get("max_stacks", 0)


## Check if item is at max stacks based on current counts
static func is_at_max_stacks(item_id: String, item_counts: Dictionary) -> bool:
	var max_stacks := get_max_stacks(item_id)
	if max_stacks == 0:
		return false  # Unlimited stacking
	var current_count := item_counts.get(item_id, 0) as int
	return current_count >= max_stacks


## Get all item IDs that are not at max stacks
static func get_available_item_ids(item_counts: Dictionary) -> Array:
	var available: Array = []
	for item_id in ITEMS.keys():
		if not is_at_max_stacks(item_id, item_counts):
			available.append(item_id)
	return available


## Check if item has a special effect
static func has_special_effect(item_id: String) -> bool:
	if not ITEMS.has(item_id):
		return false
	return ITEMS[item_id].has("special_effect")


## Get special effect type
static func get_special_effect(item_id: String) -> String:
	if not ITEMS.has(item_id):
		return ""
	return ITEMS[item_id].get("special_effect", "")


## Get all items of a specific rarity
static func get_items_by_rarity(rarity: GameEnums.ItemRarity) -> Array:
	var result: Array = []
	for item_id in ITEMS.keys():
		if ITEMS[item_id].get("rarity", GameEnums.ItemRarity.COMMON) == rarity:
			result.append(item_id)
	return result


## Calculate effective rarity weights based on wave and luck
## Returns Dictionary of {GameEnums.ItemRarity: float}
static func calculate_rarity_weights(wave: int, luck: float) -> Dictionary:
	var weights: Dictionary = {}
	var clamped_luck := clampf(luck, 0.0, GameConstants.PLAYER_MAX_LUCK)
	
	for rarity in GameConstants.RARITY_BASE_WEIGHTS.keys():
		var min_wave: int = GameConstants.RARITY_MIN_WAVE.get(rarity, 1)
		
		# Skip rarities not yet unlocked
		if wave < min_wave:
			weights[rarity] = 0.0
			continue
		
		var base_weight: float = GameConstants.RARITY_BASE_WEIGHTS[rarity]
		var luck_mult: float = GameConstants.LUCK_WEIGHT_MULTIPLIERS.get(rarity, 1.0)
		
		# Interpolate based on luck (0.0 = no effect, 1.0+ = full multiplier effect)
		var effective_luck := minf(clamped_luck, 1.0)  # Cap at 1.0 for lerp, but allow >1.0 for extra bonus
		var luck_factor := lerpf(1.0, luck_mult, effective_luck)
		
		# Extra luck bonus beyond 1.0
		if clamped_luck > 1.0:
			var extra_luck := clamped_luck - 1.0
			luck_factor *= (1.0 + extra_luck * (luck_mult - 1.0) * 0.5)
		
		# Wave progression bonus
		var waves_past_min := wave - min_wave
		var wave_bonus := 1.0 + GameConstants.RARITY_WAVE_BONUS_PER_WAVE * waves_past_min
		
		weights[rarity] = base_weight * luck_factor * wave_bonus
	
	return weights


## Get a weighted random item based on wave and luck
## Filters out items already in the shop (excluded_ids) and items at max stacks
static func get_weighted_random_item(wave: int, luck: float, item_counts: Dictionary, excluded_ids: Array) -> String:
	var rarity_weights := calculate_rarity_weights(wave, luck)
	
	# Build pool of available items per rarity
	var rarity_pools: Dictionary = {}  # rarity -> Array of item_ids
	var effective_weights: Dictionary = {}  # rarity -> weight (0 if no items available)
	
	for rarity in rarity_weights.keys():
		var items := get_items_by_rarity(rarity)
		# Filter out excluded and max-stacked items
		var available: Array = []
		for item_id in items:
			if item_id not in excluded_ids and not is_at_max_stacks(item_id, item_counts):
				available.append(item_id)
		
		rarity_pools[rarity] = available
		effective_weights[rarity] = rarity_weights[rarity] if not available.is_empty() else 0.0
	
	# Calculate total weight
	var total_weight: float = 0.0
	for weight in effective_weights.values():
		total_weight += weight
	
	# No items available at all
	if total_weight <= 0.0:
		return ""
	
	# Roll for rarity
	var roll := randf() * total_weight
	var cumulative: float = 0.0
	var selected_rarity: GameEnums.ItemRarity = GameEnums.ItemRarity.COMMON
	
	for rarity in effective_weights.keys():
		cumulative += effective_weights[rarity]
		if roll <= cumulative:
			selected_rarity = rarity
			break
	
	# Pick random item from selected rarity pool
	var pool: Array = rarity_pools[selected_rarity]
	if pool.is_empty():
		return ""
	
	return pool[randi() % pool.size()]
