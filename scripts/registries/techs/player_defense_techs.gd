class_name PlayerDefenseTechs
extends Object

## Player Defense Tech Path
## Focuses on: Max Health, Movement Speed, Health Regen, Damage Reduction

static func get_techs() -> Array:
	return [
		# =================================================================
		# TIER 1 - STARTER
		# =================================================================
		{
			"id": "tactical_armor",
			"name": "Tactical Armor",
			"icon": "🛡️",
			"description": "+15% max health",
			"path": "player_defense",
			"tier": 1,
			"cost": 10,
			"prerequisites": [],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "player_max_health",
				"operation": "multiply",
				"value": 1.15,
				"filter": {"entity_type": ["player"]}
			}],
			"special_effect": ""
		},

		# =================================================================
		# TIER 2 - BRANCHING OPTIONS
		# =================================================================
		{
			"id": "reinforced_plating",
			"name": "Reinforced Plating",
			"icon": "🔰",
			"description": "+20% max health",
			"path": "player_defense",
			"tier": 2,
			"cost": 25,
			"prerequisites": ["tactical_armor"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "player_max_health",
				"operation": "multiply",
				"value": 1.20,
				"filter": {"entity_type": ["player"]}
			}],
			"special_effect": ""
		},
		{
			"id": "agile_footwork",
			"name": "Agile Footwork",
			"icon": "👟",
			"description": "+20% movement speed",
			"path": "player_defense",
			"tier": 2,
			"cost": 25,
			"prerequisites": ["tactical_armor"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "player_speed",
				"operation": "multiply",
				"value": 1.20,
				"filter": {"entity_type": ["player"]}
			}],
			"special_effect": ""
		},
		{
			"id": "first_aid_training",
			"name": "First Aid Training",
			"icon": "💉",
			"description": "+1 HP regeneration per second",
			"path": "player_defense",
			"tier": 2,
			"cost": 25,
			"prerequisites": ["tactical_armor"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "player_health_regen",
				"operation": "add",
				"value": 1.0,
				"filter": {"entity_type": ["player"]}
			}],
			"special_effect": ""
		},

		# =================================================================
		# TIER 3 - SPECIALIZATION
		# =================================================================
		{
			"id": "heavy_armor",
			"name": "Heavy Armor",
			"icon": "🏰",
			"description": "+30% max health",
			"path": "player_defense",
			"tier": 3,
			"cost": 50,
			"prerequisites": ["reinforced_plating"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "player_max_health",
				"operation": "multiply",
				"value": 1.30,
				"filter": {"entity_type": ["player"]}
			}],
			"special_effect": ""
		},
		{
			"id": "sprint_training",
			"name": "Sprint Training",
			"icon": "💨",
			"description": "+30% movement speed",
			"path": "player_defense",
			"tier": 3,
			"cost": 50,
			"prerequisites": ["agile_footwork"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "player_speed",
				"operation": "multiply",
				"value": 1.30,
				"filter": {"entity_type": ["player"]}
			}],
			"special_effect": ""
		},
		{
			"id": "regeneration_module",
			"name": "Regeneration Module",
			"icon": "💚",
			"description": "+2 HP regeneration per second",
			"path": "player_defense",
			"tier": 3,
			"cost": 50,
			"prerequisites": ["first_aid_training"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "player_health_regen",
				"operation": "add",
				"value": 2.0,
				"filter": {"entity_type": ["player"]}
			}],
			"special_effect": ""
		},

		# =================================================================
		# TIER 4 - DEEP SPECIALIZATION
		# =================================================================
		{
			"id": "damage_reduction",
			"name": "Damage Reduction",
			"icon": "🔻",
			"description": "Take 15% less damage from all sources",
			"path": "player_defense",
			"tier": 4,
			"cost": 80,
			"prerequisites": ["heavy_armor"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "damage_reduction",
				"operation": "add",
				"value": 0.15,
				"filter": {"entity_type": ["player"]}
			}],
			"special_effect": ""
		},
		{
			"id": "evasion",
			"name": "Evasion",
			"icon": "🌀",
			"description": "10% chance to dodge incoming attacks",
			"path": "player_defense",
			"tier": 4,
			"cost": 80,
			"prerequisites": ["sprint_training"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "unlock_mechanic",
			"modifiers": [],
			"special_effect": "player_evasion"
		},

		# =================================================================
		# TIER 5 - CAPSTONE
		# =================================================================
		{
			"id": "immortal",
			"name": "Immortal",
			"icon": "♾️",
			"description": "+40% max health, +3 HP/s regen, +10% damage reduction",
			"path": "player_defense",
			"tier": 5,
			"cost": 120,
			"prerequisites": ["damage_reduction", "evasion"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [
				{
					"stat": "player_max_health",
					"operation": "multiply",
					"value": 1.40,
					"filter": {"entity_type": ["player"]}
				},
				{
					"stat": "player_health_regen",
					"operation": "add",
					"value": 3.0,
					"filter": {"entity_type": ["player"]}
				},
				{
					"stat": "damage_reduction",
					"operation": "add",
					"value": 0.10,
					"filter": {"entity_type": ["player"]}
				}
			],
			"special_effect": ""
		},
	]
