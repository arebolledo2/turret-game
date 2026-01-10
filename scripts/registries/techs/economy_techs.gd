class_name EconomyTechs
extends Object

## Economy Tech Path
## Focuses on: Scrap Gain, Shop Improvements, Research Conversion

static func get_techs() -> Array:
	return [
		# =================================================================
		# TIER 1 - STARTER
		# =================================================================
		{
			"id": "scrap_collector",
			"name": "Scrap Collector",
			"icon": "💰",
			"description": "+15% scrap earned from all sources",
			"path": "economy",
			"tier": 1,
			"cost": 10,
			"prerequisites": [],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "scrap_earn_mult",
				"operation": "multiply",
				"value": 1.15,
				"filter": {}
			}],
			"special_effect": ""
		},

		# =================================================================
		# TIER 2 - BRANCHING OPTIONS
		# =================================================================
		{
			"id": "efficient_looting",
			"name": "Efficient Looting",
			"icon": "🔍",
			"description": "+20% scrap earned from all sources",
			"path": "economy",
			"tier": 2,
			"cost": 25,
			"prerequisites": ["scrap_collector"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "scrap_earn_mult",
				"operation": "multiply",
				"value": 1.20,
				"filter": {}
			}],
			"special_effect": ""
		},
		{
			"id": "shop_discount",
			"name": "Shop Discount",
			"icon": "🏷️",
			"description": "10% reduction on all shop prices",
			"path": "economy",
			"tier": 2,
			"cost": 25,
			"prerequisites": ["scrap_collector"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "shop_price_mult",
				"operation": "multiply",
				"value": 0.90,
				"filter": {}
			}],
			"special_effect": ""
		},
		{
			"id": "research_focus",
			"name": "Research Focus",
			"icon": "🔬",
			"description": "+20% scrap-to-research conversion rate",
			"path": "economy",
			"tier": 2,
			"cost": 25,
			"prerequisites": ["scrap_collector"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "research_conversion_mult",
				"operation": "multiply",
				"value": 1.20,
				"filter": {}
			}],
			"special_effect": ""
		},

		# =================================================================
		# TIER 3 - SPECIALIZATION
		# =================================================================
		{
			"id": "scrap_magnet",
			"name": "Scrap Magnet",
			"icon": "🧲",
			"description": "+30% scrap earned from all sources",
			"path": "economy",
			"tier": 3,
			"cost": 50,
			"prerequisites": ["efficient_looting"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "scrap_earn_mult",
				"operation": "multiply",
				"value": 1.30,
				"filter": {}
			}],
			"special_effect": ""
		},
		{
			"id": "bargain_hunter",
			"name": "Bargain Hunter",
			"icon": "🛒",
			"description": "+1 shop offer per wave",
			"path": "economy",
			"tier": 3,
			"cost": 50,
			"prerequisites": ["shop_discount"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "shop_offer_count",
				"operation": "add",
				"value": 1,
				"filter": {}
			}],
			"special_effect": ""
		},
		{
			"id": "academic",
			"name": "Academic",
			"icon": "📚",
			"description": "+50% scrap-to-research conversion rate",
			"path": "economy",
			"tier": 3,
			"cost": 50,
			"prerequisites": ["research_focus"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [{
				"stat": "research_conversion_mult",
				"operation": "multiply",
				"value": 1.50,
				"filter": {}
			}],
			"special_effect": ""
		},

		# =================================================================
		# TIER 4 - DEEP SPECIALIZATION
		# =================================================================
		{
			"id": "shop_lock",
			"name": "Offer Preservation",
			"icon": "🔒",
			"description": "Unlock ability to lock shop offers (prevents reroll)",
			"path": "economy",
			"tier": 4,
			"cost": 80,
			"prerequisites": ["bargain_hunter"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "unlock_mechanic",
			"modifiers": [],
			"special_effect": "unlock_shop_lock"
		},
		{
			"id": "compound_interest",
			"name": "Compound Interest",
			"icon": "📈",
			"description": "Gain 5% of total scrap as bonus each wave",
			"path": "economy",
			"tier": 4,
			"cost": 80,
			"prerequisites": ["scrap_magnet"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "unlock_mechanic",
			"modifiers": [],
			"special_effect": "scrap_interest"
		},

		# =================================================================
		# TIER 5 - CAPSTONE
		# =================================================================
		{
			"id": "economic_supremacy",
			"name": "Economic Supremacy",
			"icon": "👑",
			"description": "+40% scrap gain, +20% shop discount, +2 shop offers",
			"path": "economy",
			"tier": 5,
			"cost": 120,
			"prerequisites": ["shop_lock", "compound_interest"],
			"repeatable": false,
			"max_unlocks": 1,
			"effect_type": "modifier",
			"modifiers": [
				{
					"stat": "scrap_earn_mult",
					"operation": "multiply",
					"value": 1.40,
					"filter": {}
				},
				{
					"stat": "shop_price_mult",
					"operation": "multiply",
					"value": 0.80,
					"filter": {}
				},
				{
					"stat": "shop_offer_count",
					"operation": "add",
					"value": 2,
					"filter": {}
				}
			],
			"special_effect": ""
		},
	]
