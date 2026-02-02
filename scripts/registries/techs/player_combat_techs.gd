class_name PlayerCombatTechs
extends Object

## Player Combat Tech Path
## Focuses on: Player Damage, Crit Chance, Crit Damage, Attack Speed

static func get_techs() -> Array:
	return [
		# =================================================================
		# TIER 1 - STARTER
		# =================================================================
		{
			"id": "combat_training",
			"name": "Combat Training",
			"icon": "🗡️",
			"description": "+15% player damage",
			"path": "player_combat",
			"tier": 1,
			"cost": 10,
			"prerequisites": [],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "player_weapon_damage",
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
			"id": "weapon_mastery",
			"name": "Weapon Mastery",
			"icon": "⚔️",
			"description": "+20% player damage",
			"path": "player_combat",
			"tier": 2,
			"cost": 25,
			"prerequisites": ["combat_training"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "player_weapon_damage",
				"operation": "multiply",
				"value": 1.20,
				"filter": {"entity_type": ["player"]}
			}],
			"special_effect": ""
		},
		{
			"id": "critical_training",
			"name": "Critical Training",
			"icon": "💢",
			"description": "+10% player critical hit chance",
			"path": "player_combat",
			"tier": 2,
			"cost": 25,
			"prerequisites": ["combat_training"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "player_crit_chance",
				"operation": "add",
				"value": 0.10,
				"filter": {"entity_type": ["player"]}
			}],
			"special_effect": ""
		},
		{
			"id": "swift_strikes",
			"name": "Swift Strikes",
			"icon": "⚡",
			"description": "+20% player attack speed",
			"path": "player_combat",
			"tier": 2,
			"cost": 25,
			"prerequisites": ["combat_training"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "player_fire_rate",
				"operation": "multiply",
				"value": 1.20,
				"filter": {"entity_type": ["player"]}
			}],
			"special_effect": ""
		},

		# =================================================================
		# TIER 3 - SPECIALIZATION
		# =================================================================
		{
			"id": "lethal_force",
			"name": "Lethal Force",
			"icon": "🔪",
			"description": "+30% player damage",
			"path": "player_combat",
			"tier": 3,
			"cost": 50,
			"prerequisites": ["weapon_mastery"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "player_weapon_damage",
				"operation": "multiply",
				"value": 1.30,
				"filter": {"entity_type": ["player"]}
			}],
			"special_effect": ""
		},
		{
			"id": "deadly_precision",
			"name": "Deadly Precision",
			"icon": "🎯",
			"description": "+15% player critical hit chance",
			"path": "player_combat",
			"tier": 3,
			"cost": 50,
			"prerequisites": ["critical_training"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "player_crit_chance",
				"operation": "add",
				"value": 0.15,
				"filter": {"entity_type": ["player"]}
			}],
			"special_effect": ""
		},
		{
			"id": "berserker_rage",
			"name": "Berserker Rage",
			"icon": "🔥",
			"description": "+30% player attack speed",
			"path": "player_combat",
			"tier": 3,
			"cost": 50,
			"prerequisites": ["swift_strikes"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "player_fire_rate",
				"operation": "multiply",
				"value": 1.30,
				"filter": {"entity_type": ["player"]}
			}],
			"special_effect": ""
		},

		# =================================================================
		# TIER 4 - DEEP SPECIALIZATION
		# =================================================================
		{
			"id": "executioner",
			"name": "Executioner",
			"icon": "🪓",
			"description": "+50% player critical damage multiplier",
			"path": "player_combat",
			"tier": 4,
			"cost": 80,
			"prerequisites": ["deadly_precision"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "player_crit_multiplier",
				"operation": "multiply",
				"value": 1.50,
				"filter": {"entity_type": ["player"]}
			}],
			"special_effect": ""
		},

		# =================================================================
		# TIER 5 - CAPSTONE
		# =================================================================
		{
			"id": "war_god",
			"name": "War God",
			"icon": "👑",
			"description": "+30% damage, +20% crit chance, +20% attack speed",
			"path": "player_combat",
			"tier": 5,
			"cost": 120,
			"prerequisites": ["executioner", "berserker_rage"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [
				{
					"stat": "player_weapon_damage",
					"operation": "multiply",
					"value": 1.30,
					"filter": {"entity_type": ["player"]}
				},
				{
					"stat": "player_crit_chance",
					"operation": "add",
					"value": 0.20,
					"filter": {"entity_type": ["player"]}
				},
				{
					"stat": "player_fire_rate",
					"operation": "multiply",
					"value": 1.20,
					"filter": {"entity_type": ["player"]}
				}
			],
			"special_effect": ""
		},
	]
