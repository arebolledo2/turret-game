extends RefCounted

## Turret Unlock Tech Definitions
## These techs gate availability of turret types in the shop

static func get_techs() -> Array:
	return [
		# Tier 1: All turret unlocks (no prerequisites, independent)

		{
			"id": "turret_unlock_sniper",
			"name": "Sniper Technology",
			"icon": "🎯",
			"description": "Unlocks Sniper Turret for purchase in shop",
			"path": "turret_unlock",
			"tier": 1,
			"cost": 25,
			"prerequisites": [],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "unlock_mechanic",
			"special_effect": "turret_type_sniper",
			"modifiers": []
		},

		{
			"id": "turret_unlock_fire",
			"name": "Incendiary Weapons",
			"icon": "🔥",
			"description": "Unlocks Fire Turret for purchase in shop",
			"path": "turret_unlock",
			"tier": 1,
			"cost": 20,
			"prerequisites": [],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "unlock_mechanic",
			"special_effect": "turret_type_fire",
			"modifiers": []
		},

		{
			"id": "turret_unlock_plasma",
			"name": "Plasma Cannon Research",
			"icon": "💠",
			"description": "Unlocks Plasma Turret for purchase in shop",
			"path": "turret_unlock",
			"tier": 1,
			"cost": 30,
			"prerequisites": [],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "unlock_mechanic",
			"special_effect": "turret_type_plasma",
			"modifiers": []
		},

		{
			"id": "turret_unlock_shock",
			"name": "Shock Field Technology",
			"icon": "💫",
			"description": "Unlocks Shock Turret for purchase in shop",
			"path": "turret_unlock",
			"tier": 1,
			"cost": 25,
			"prerequisites": [],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "unlock_mechanic",
			"special_effect": "turret_type_shock",
			"modifiers": []
		},

		{
			"id": "turret_unlock_tesla",
			"name": "Tesla Coil Research",
			"icon": "⛓️",
			"description": "Unlocks Tesla Turret for purchase in shop",
			"path": "turret_unlock",
			"tier": 1,
			"cost": 35,
			"prerequisites": [],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "unlock_mechanic",
			"special_effect": "turret_type_tesla",
			"modifiers": []
		},

		{
			"id": "turret_unlock_melee",
			"name": "Melee Defense Systems",
			"icon": "⚔️",
			"description": "Unlocks Melee Turret for purchase in shop",
			"path": "turret_unlock",
			"tier": 1,
			"cost": 20,
			"prerequisites": [],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "unlock_mechanic",
			"special_effect": "turret_type_melee",
			"modifiers": []
		},

		{
			"id": "turret_unlock_mine",
			"name": "Proximity Mine Technology",
			"icon": "💣",
			"description": "Unlocks Mine Turret for purchase in shop",
			"path": "turret_unlock",
			"tier": 1,
			"cost": 25,
			"prerequisites": [],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "unlock_mechanic",
			"special_effect": "turret_type_mine",
			"modifiers": []
		}
	]
