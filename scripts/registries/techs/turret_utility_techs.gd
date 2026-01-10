class_name TurretUtilityTechs
extends Object

## Turret Utility Tech Path
## Focuses on: AOE, Pierce, Multi-shot, Special Effects

static func get_techs() -> Array:
	return [
		# =================================================================
		# TIER 1 - STARTER
		# =================================================================
		{
			"id": "splash_damage",
			"name": "Splash Damage Module",
			"icon": "💧",
			"description": "Turret projectiles deal AOE damage",
			"path": "turret_utility",
			"tier": 1,
			"cost": 10,
			"prerequisites": [],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "unlock_mechanic",
			"modifiers": [],
			"special_effect": "turret_aoe_damage"
		},

		# =================================================================
		# TIER 2 - BRANCHING OPTIONS
		# =================================================================
		{
			"id": "expanded_blast",
			"name": "Expanded Blast Radius",
			"icon": "🎆",
			"description": "+50% AOE explosion size",
			"path": "turret_utility",
			"tier": 2,
			"cost": 25,
			"prerequisites": ["splash_damage"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "aoe_size",
				"operation": "multiply",
				"value": 1.50,
				"filter": {"entity_type": ["turret"]}
			}],
			"special_effect": ""
		},
		{
			"id": "piercing_projectiles",
			"name": "Piercing Projectiles",
			"icon": "🏹",
			"description": "Projectiles pierce through 1 enemy",
			"path": "turret_utility",
			"tier": 2,
			"cost": 25,
			"prerequisites": ["splash_damage"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "pierce_count",
				"operation": "add",
				"value": 1,
				"filter": {"entity_type": ["turret"]}
			}],
			"special_effect": ""
		},
		{
			"id": "multi_shot",
			"name": "Multi-Shot",
			"icon": "🔀",
			"description": "Fire 1 additional projectile",
			"path": "turret_utility",
			"tier": 2,
			"cost": 25,
			"prerequisites": ["splash_damage"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "projectile_count",
				"operation": "add",
				"value": 1,
				"filter": {"entity_type": ["turret"]}
			}],
			"special_effect": ""
		},

		# =================================================================
		# TIER 3 - SPECIALIZATION
		# =================================================================
		{
			"id": "chain_lightning",
			"name": "Chain Lightning",
			"icon": "⚡",
			"description": "Projectiles chain to 2 nearby enemies",
			"path": "turret_utility",
			"tier": 3,
			"cost": 50,
			"prerequisites": ["expanded_blast"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "unlock_mechanic",
			"modifiers": [],
			"special_effect": "turret_chain_lightning"
		},
		{
			"id": "deep_penetration",
			"name": "Deep Penetration",
			"icon": "➡️",
			"description": "Pierce 2 additional enemies",
			"path": "turret_utility",
			"tier": 3,
			"cost": 50,
			"prerequisites": ["piercing_projectiles"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "pierce_count",
				"operation": "add",
				"value": 2,
				"filter": {"entity_type": ["turret"]}
			}],
			"special_effect": ""
		},
		{
			"id": "volley_fire",
			"name": "Volley Fire",
			"icon": "🎯",
			"description": "Fire 2 additional projectiles",
			"path": "turret_utility",
			"tier": 3,
			"cost": 50,
			"prerequisites": ["multi_shot"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "projectile_count",
				"operation": "add",
				"value": 2,
				"filter": {"entity_type": ["turret"]}
			}],
			"special_effect": ""
		},

		# =================================================================
		# TIER 4 - DEEP SPECIALIZATION
		# =================================================================
		{
			"id": "freezing_rounds",
			"name": "Freezing Rounds",
			"icon": "❄️",
			"description": "20% chance to slow enemies by 50% for 2s",
			"path": "turret_utility",
			"tier": 4,
			"cost": 80,
			"prerequisites": ["chain_lightning"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "unlock_mechanic",
			"modifiers": [],
			"special_effect": "turret_freezing_rounds"
		},
		{
			"id": "shredding_ammunition",
			"name": "Shredding Ammunition",
			"icon": "🗡️",
			"description": "Reduce enemy armor by 10%",
			"path": "turret_utility",
			"tier": 4,
			"cost": 80,
			"prerequisites": ["deep_penetration"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "unlock_mechanic",
			"modifiers": [],
			"special_effect": "turret_armor_shred"
		},

		# =================================================================
		# TIER 5 - CAPSTONE
		# =================================================================
		{
			"id": "orbital_strike",
			"name": "Orbital Strike Protocol",
			"icon": "🛰️",
			"description": "Every 10s, call an orbital strike dealing massive AOE damage",
			"path": "turret_utility",
			"tier": 5,
			"cost": 120,
			"prerequisites": ["freezing_rounds", "shredding_ammunition"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "unlock_mechanic",
			"modifiers": [],
			"special_effect": "turret_orbital_strike"
		},
	]
