class_name TurretOffenseTechs
extends Object

## Turret Offense Tech Path
## Focuses on: Damage, Fire Rate, Range, Crit

static func get_techs() -> Array:
	return [
		# =================================================================
		# TIER 1 - STARTER
		# =================================================================
		{
			"id": "turret_damage_1",
			"name": "Enhanced Ammunition",
			"icon": "💥",
			"description": "+15% turret damage",
			"path": "turret_offense",
			"tier": 1,
			"cost": 10,
			"prerequisites": [],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "damage",
				"operation": "multiply",
				"value": 1.15,
				"filter": {"entity_type": ["turret"]}
			}],
			"special_effect": ""
		},

		# =================================================================
		# TIER 2 - BRANCHING OPTIONS
		# =================================================================
		{
			"id": "rapid_fire_1",
			"name": "Rapid Fire Protocols",
			"icon": "⚡",
			"description": "+20% turret fire rate",
			"path": "turret_offense",
			"tier": 2,
			"cost": 25,
			"prerequisites": ["turret_damage_1"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "fire_rate",
				"operation": "multiply",
				"value": 1.20,
				"filter": {"entity_type": ["turret"]}
			}],
			"special_effect": ""
		},
		{
			"id": "heavy_caliber_1",
			"name": "Heavy Caliber Rounds",
			"icon": "🔫",
			"description": "+25% turret damage",
			"path": "turret_offense",
			"tier": 2,
			"cost": 25,
			"prerequisites": ["turret_damage_1"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "damage",
				"operation": "multiply",
				"value": 1.25,
				"filter": {"entity_type": ["turret"]}
			}],
			"special_effect": ""
		},
		{
			"id": "extended_barrel_1",
			"name": "Extended Barrel",
			"icon": "🎯",
			"description": "+20% turret range",
			"path": "turret_offense",
			"tier": 2,
			"cost": 25,
			"prerequisites": ["turret_damage_1"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "range",
				"operation": "multiply",
				"value": 1.20,
				"filter": {"entity_type": ["turret"]}
			}],
			"special_effect": ""
		},

		# =================================================================
		# TIER 3 - SPECIALIZATION
		# =================================================================
		{
			"id": "overclocked_systems",
			"name": "Overclocked Systems",
			"icon": "⚙️",
			"description": "+30% turret fire rate",
			"path": "turret_offense",
			"tier": 3,
			"cost": 50,
			"prerequisites": ["rapid_fire_1"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "fire_rate",
				"operation": "multiply",
				"value": 1.30,
				"filter": {"entity_type": ["turret"]}
			}],
			"special_effect": ""
		},
		{
			"id": "armor_piercing",
			"name": "Armor Piercing Rounds",
			"icon": "🛡️",
			"description": "+35% turret damage",
			"path": "turret_offense",
			"tier": 3,
			"cost": 50,
			"prerequisites": ["heavy_caliber_1"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "damage",
				"operation": "multiply",
				"value": 1.35,
				"filter": {"entity_type": ["turret"]}
			}],
			"special_effect": ""
		},
		{
			"id": "sniper_scope",
			"name": "Sniper Scope",
			"icon": "🔭",
			"description": "+30% turret range",
			"path": "turret_offense",
			"tier": 3,
			"cost": 50,
			"prerequisites": ["extended_barrel_1"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "range",
				"operation": "multiply",
				"value": 1.30,
				"filter": {"entity_type": ["turret"]}
			}],
			"special_effect": ""
		},

		# =================================================================
		# TIER 4 - DEEP SPECIALIZATION
		# =================================================================
		{
			"id": "critical_systems",
			"name": "Critical Strike Systems",
			"icon": "💢",
			"description": "+15% turret critical hit chance",
			"path": "turret_offense",
			"tier": 4,
			"cost": 80,
			"prerequisites": ["overclocked_systems"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "crit_chance",
				"operation": "add",
				"value": 0.15,
				"filter": {"entity_type": ["turret"]}
			}],
			"special_effect": ""
		},
		{
			"id": "devastating_impact",
			"name": "Devastating Impact",
			"icon": "💣",
			"description": "+50% turret damage",
			"path": "turret_offense",
			"tier": 4,
			"cost": 80,
			"prerequisites": ["armor_piercing"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "damage",
				"operation": "multiply",
				"value": 1.50,
				"filter": {"entity_type": ["turret"]}
			}],
			"special_effect": ""
		},

		# =================================================================
		# TIER 5 - CAPSTONE
		# =================================================================
		{
			"id": "ultimate_firepower",
			"name": "Ultimate Firepower",
			"icon": "🌟",
			"description": "+25% turret damage and fire rate",
			"path": "turret_offense",
			"tier": 5,
			"cost": 120,
			"prerequisites": ["critical_systems", "devastating_impact"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [
				{
					"stat": "damage",
					"operation": "multiply",
					"value": 1.25,
					"filter": {"entity_type": ["turret"]}
				},
				{
					"stat": "fire_rate",
					"operation": "multiply",
					"value": 1.25,
					"filter": {"entity_type": ["turret"]}
				}
			],
			"special_effect": ""
		},
	]
