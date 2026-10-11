class_name ItemsV3
extends RefCounted

## Reviewed shop catalog. IDs stay stable for owned items and presets; eligibility uses attack families.
const ROWS: Array = [
	{
		"description": "Pickup radius +20%.",
		"id": "scrap_magnet",
		"max_stacks": 0,
		"modifiers": [
			{
				"stat": "pickup_radius",
				"operation": "increase",
				"value": 0.2,
				"filter": {}
			}
		],
		"name": "Scrap Magnet",
		"rarity": 0,
		"special_effect": ""
	},
	{
		"description": "Max hull +4.",
		"id": "reinforced_hull",
		"max_stacks": 0,
		"modifiers": [
			{
				"stat": "player_max_health",
				"operation": "add",
				"value": 4,
				"filter": {}
			}
		],
		"name": "Reinforced Hull",
		"rarity": 0,
		"special_effect": ""
	},
	{
		"description": "Attack speed +7% for all weapons.",
		"id": "quick_loader",
		"max_stacks": 0,
		"modifiers": [
			{
				"stat": "attack_speed",
				"operation": "increase",
				"value": 0.07,
				"filter": {}
			}
		],
		"name": "Quick Loader",
		"rarity": 0,
		"special_effect": ""
	},
	{
		"description": "Projectile damage +10% and projectile speed +15%.",
		"id": "dense_rounds",
		"max_stacks": 0,
		"modifiers": [
			{
				"stat": "damage",
				"operation": "increase",
				"value": 0.1,
				"filter": {
					"attack_family": [
						"projectile"
					]
				}
			},
			{
				"stat": "projectile_speed",
				"operation": "increase",
				"value": 0.15,
				"filter": {
					"attack_family": [
						"projectile"
					]
				}
			}
		],
		"name": "Dense Rounds",
		"rarity": 1,
		"special_effect": ""
	},
	{
		"description": "Reroll costs -10%.",
		"id": "budget_capacitor",
		"max_stacks": 0,
		"modifiers": [
			{
				"stat": "reroll_cost",
				"operation": "increase",
				"value": -0.1,
				"filter": {}
			}
		],
		"name": "Budget Capacitor",
		"rarity": 0,
		"special_effect": ""
	},
	{
		"description": "Turret purchase scaling -4 percentage points.",
		"id": "compact_design",
		"max_stacks": 3,
		"modifiers": [
			{
				"stat": "turret_penalty_reduction",
				"operation": "add",
				"value": -0.04,
				"filter": {}
			}
		],
		"name": "Compact Design",
		"rarity": 0,
		"special_effect": ""
	},
	{
		"description": "All turret reach +15%.",
		"id": "extended_barrel",
		"max_stacks": 0,
		"modifiers": [
			{
				"stat": "range",
				"operation": "increase",
				"value": 0.15,
				"filter": {}
			}
		],
		"name": "Extended Barrel",
		"rarity": 1,
		"special_effect": ""
	},
	{
		"description": "Attack speed +15% for all weapons.",
		"id": "rapid_coolant",
		"max_stacks": 0,
		"modifiers": [
			{
				"stat": "attack_speed",
				"operation": "increase",
				"value": 0.15,
				"filter": {}
			}
		],
		"name": "Rapid Coolant",
		"rarity": 1,
		"special_effect": ""
	},
	{
		"description": "Max hull +5. Move speed -3%.",
		"id": "heavy_plating",
		"max_stacks": 0,
		"modifiers": [
			{
				"stat": "player_max_health",
				"operation": "add",
				"value": 5,
				"filter": {}
			},
			{
				"stat": "player_speed",
				"operation": "increase",
				"value": -0.03,
				"filter": {}
			}
		],
		"name": "Heavy Plating",
		"rarity": 1,
		"special_effect": ""
	},
	{
		"description": "Turret purchase scaling -10 percentage points.",
		"id": "mass_production",
		"max_stacks": 2,
		"modifiers": [
			{
				"stat": "turret_penalty_reduction",
				"operation": "add",
				"value": -0.1,
				"filter": {}
			}
		],
		"name": "Mass Production",
		"rarity": 1,
		"special_effect": ""
	},
	{
		"description": "Projectile damage +10%.",
		"id": "polished_barrels",
		"max_stacks": 0,
		"modifiers": [
			{
				"stat": "damage",
				"operation": "increase",
				"value": 0.1,
				"filter": {
					"attack_family": [
						"projectile"
					]
				}
			}
		],
		"name": "Polished Barrels",
		"rarity": 0,
		"special_effect": ""
	},
	{
		"description": "Area radius +9%. Existing area knockback +8%.",
		"id": "blast_charges",
		"max_stacks": 0,
		"modifiers": [
			{
				"stat": "area_size",
				"operation": "increase",
				"value": 0.09,
				"filter": {
					"attack_family": [
						"aoe"
					]
				}
			},
			{
				"stat": "knockback_force",
				"operation": "increase",
				"value": 0.08,
				"filter": {
					"attack_family": [
						"aoe"
					],
					"requires": [
						"knockback"
					]
				}
			}
		],
		"name": "Blast Charges",
		"rarity": 0,
		"special_effect": ""
	},
	{
		"description": "Instant damage +8%.",
		"id": "capacitor_bank",
		"max_stacks": 0,
		"modifiers": [
			{
				"stat": "damage",
				"operation": "increase",
				"value": 0.08,
				"filter": {
					"attack_family": [
						"instant"
					]
				}
			}
		],
		"name": "Capacitor Bank",
		"rarity": 0,
		"special_effect": ""
	},
	{
		"description": "Kinetic damage +12%.",
		"id": "weighted_bat",
		"max_stacks": 0,
		"modifiers": [
			{
				"stat": "damage",
				"operation": "increase",
				"value": 0.12,
				"filter": {
					"attack_family": [
						"kinetic"
					]
				}
			}
		],
		"name": "Counterweight",
		"rarity": 0,
		"special_effect": ""
	},
	{
		"description": "Entrench stacks arrive 15% faster.",
		"id": "concrete_footings",
		"max_stacks": 3,
		"modifiers": [
			{
				"stat": "entrench_stack_seconds",
				"operation": "increase",
				"value": -0.15,
				"filter": {}
			}
		],
		"name": "Concrete Footings",
		"rarity": 0,
		"special_effect": ""
	},
	{
		"description": "Existing Instant slows: +10 percentage points strength and +0.2s duration.",
		"id": "static_grounding",
		"max_stacks": 0,
		"modifiers": [
			{
				"stat": "slow_intensity",
				"operation": "add",
				"value": 0.1,
				"filter": {
					"attack_family": [
						"instant"
					],
					"requires": [
						"slow"
					]
				}
			},
			{
				"stat": "slow_duration",
				"operation": "add",
				"value": 0.2,
				"filter": {
					"attack_family": [
						"instant"
					],
					"requires": [
						"slow"
					]
				}
			}
		],
		"name": "Static Grounding",
		"rarity": 0,
		"special_effect": ""
	},
	{
		"description": "Instant attack speed +10%.",
		"id": "faulty_wiring",
		"max_stacks": 0,
		"modifiers": [
			{
				"stat": "attack_speed",
				"operation": "increase",
				"value": 0.1,
				"filter": {
					"attack_family": [
						"instant"
					]
				}
			}
		],
		"name": "Pulse Regulator",
		"rarity": 0,
		"special_effect": ""
	},
	{
		"description": "Projectile damage +20%.",
		"id": "ion_doctrine",
		"max_stacks": 2,
		"modifiers": [
			{
				"stat": "damage",
				"operation": "increase",
				"value": 0.2,
				"filter": {
					"attack_family": [
						"projectile"
					]
				}
			}
		],
		"name": "Projectile Doctrine",
		"rarity": 1,
		"special_effect": ""
	},
	{
		"description": "Area damage +20%.",
		"id": "plasma_doctrine",
		"max_stacks": 2,
		"modifiers": [
			{
				"stat": "damage",
				"operation": "increase",
				"value": 0.2,
				"filter": {
					"attack_family": [
						"aoe"
					]
				}
			}
		],
		"name": "Area Doctrine",
		"rarity": 1,
		"special_effect": ""
	},
	{
		"description": "Instant damage +20%.",
		"id": "voltage_doctrine",
		"max_stacks": 2,
		"modifiers": [
			{
				"stat": "damage",
				"operation": "increase",
				"value": 0.2,
				"filter": {
					"attack_family": [
						"instant"
					]
				}
			}
		],
		"name": "Instant Doctrine",
		"rarity": 1,
		"special_effect": ""
	},
	{
		"description": "Kinetic damage +20%.",
		"id": "bat_doctrine",
		"max_stacks": 2,
		"modifiers": [
			{
				"stat": "damage",
				"operation": "increase",
				"value": 0.2,
				"filter": {
					"attack_family": [
						"kinetic"
					]
				}
			}
		],
		"name": "Kinetic Doctrine",
		"rarity": 1,
		"special_effect": ""
	},
	{
		"description": "Direct projectiles pass through 1 extra enemy. Explosive shots do not pierce.",
		"id": "piercing_rounds",
		"max_stacks": 2,
		"modifiers": [
			{
				"stat": "pierce",
				"operation": "add",
				"value": 1,
				"filter": {
					"attack_family": [
						"projectile"
					],
					"requires": [
						"direct_projectile"
					]
				}
			}
		],
		"name": "Piercing Rounds",
		"rarity": 1,
		"special_effect": ""
	},
	{
		"description": "Area radius +20%.",
		"id": "cluster_warheads",
		"max_stacks": 2,
		"modifiers": [
			{
				"stat": "area_size",
				"operation": "increase",
				"value": 0.2,
				"filter": {
					"attack_family": [
						"aoe"
					]
				}
			}
		],
		"name": "Cluster Warheads",
		"rarity": 1,
		"special_effect": ""
	},
	{
		"description": "Instant chains gain 1 jump; existing Instant slows are 25% stronger.",
		"id": "superconductors",
		"max_stacks": 2,
		"modifiers": [
			{
				"stat": "chain_count",
				"operation": "add",
				"value": 1,
				"filter": {
					"attack_family": [
						"instant"
					],
					"requires": [
						"chain"
					]
				}
			},
			{
				"stat": "slow_intensity",
				"operation": "increase",
				"value": 0.25,
				"filter": {
					"attack_family": [
						"instant"
					],
					"requires": [
						"slow"
					]
				}
			}
		],
		"name": "Superconductors",
		"rarity": 1,
		"special_effect": ""
	},
	{
		"description": "Kinetic knockback +40% and reach +20%.",
		"id": "spiked_bat",
		"max_stacks": 2,
		"modifiers": [
			{
				"stat": "knockback_force",
				"operation": "increase",
				"value": 0.4,
				"filter": {
					"attack_family": [
						"kinetic"
					]
				}
			},
			{
				"stat": "range",
				"operation": "increase",
				"value": 0.2,
				"filter": {
					"attack_family": [
						"kinetic"
					]
				}
			}
		],
		"name": "Impact Head",
		"rarity": 1,
		"special_effect": ""
	},
	{
		"description": "Entrench stack limit +2 and bonus per stack +50%. Carry speed -10%.",
		"id": "hardpoint",
		"max_stacks": 2,
		"modifiers": [
			{
				"stat": "entrench_max_stacks",
				"operation": "add",
				"value": 2,
				"filter": {}
			},
			{
				"stat": "entrench_bonus",
				"operation": "increase",
				"value": 0.5,
				"filter": {}
			},
			{
				"stat": "carry_speed",
				"operation": "increase",
				"value": -0.1,
				"filter": {}
			}
		],
		"name": "Hardpoint",
		"rarity": 1,
		"special_effect": ""
	},
	{
		"description": "Core movement speed +15%.",
		"id": "tracked_chassis",
		"max_stacks": 3,
		"modifiers": [
			{
				"stat": "core_move_speed",
				"operation": "increase",
				"value": 0.15,
				"filter": {}
			}
		],
		"name": "Tracked Chassis",
		"rarity": 0,
		"special_effect": ""
	},
	{
		"description": "Core movement speed +30%.",
		"id": "overdrive_engine",
		"max_stacks": 2,
		"modifiers": [
			{
				"stat": "core_move_speed",
				"operation": "increase",
				"value": 0.3,
				"filter": {}
			}
		],
		"name": "Overdrive Engine",
		"rarity": 1,
		"special_effect": ""
	},
	{
		"description": "Core movement speed -20%: longer rounds, more enemies. Kill scrap +15%.",
		"id": "heavy_hauler",
		"max_stacks": 2,
		"modifiers": [
			{
				"stat": "core_move_speed",
				"operation": "increase",
				"value": -0.2,
				"filter": {}
			},
			{
				"stat": "scrap_earn_mult",
				"operation": "increase",
				"value": 0.15,
				"filter": {}
			}
		],
		"name": "Heavy Hauler",
		"rarity": 1,
		"special_effect": ""
	},
	{
		"description": "Instant chains gain 2 jumps and retain 15 percentage points more damage per jump.",
		"id": "arc_rod",
		"max_stacks": 2,
		"modifiers": [
			{
				"stat": "chain_count",
				"operation": "add",
				"value": 2,
				"filter": {
					"attack_family": [
						"instant"
					],
					"requires": [
						"chain"
					]
				}
			},
			{
				"stat": "chain_decay",
				"operation": "add",
				"value": 0.15,
				"filter": {
					"attack_family": [
						"instant"
					],
					"requires": [
						"chain"
					]
				}
			}
		],
		"name": "Arc Rod",
		"rarity": 2,
		"special_effect": ""
	},
	{
		"description": "Area radius +40%. Existing area knockback +50%.",
		"id": "plasma_capacitor",
		"max_stacks": 2,
		"modifiers": [
			{
				"stat": "area_size",
				"operation": "increase",
				"value": 0.4,
				"filter": {
					"attack_family": [
						"aoe"
					]
				}
			},
			{
				"stat": "knockback_force",
				"operation": "increase",
				"value": 0.5,
				"filter": {
					"attack_family": [
						"aoe"
					],
					"requires": [
						"knockback"
					]
				}
			}
		],
		"name": "Blast Amplifier",
		"rarity": 2,
		"special_effect": ""
	},
	{
		"description": "Kinetic attacks can hit the same enemy twice as often.",
		"id": "killzone_bat",
		"max_stacks": 2,
		"modifiers": [
			{
				"stat": "rehit_delay",
				"operation": "increase",
				"value": -0.5,
				"filter": {
					"attack_family": [
						"kinetic"
					]
				}
			}
		],
		"name": "Return Spring",
		"rarity": 2,
		"special_effect": ""
	},
	{
		"description": "Instant reach +30% and damage +10%.",
		"id": "overwatch_optics",
		"max_stacks": 2,
		"modifiers": [
			{
				"stat": "range",
				"operation": "increase",
				"value": 0.3,
				"filter": {
					"attack_family": [
						"instant"
					]
				}
			},
			{
				"stat": "damage",
				"operation": "increase",
				"value": 0.1,
				"filter": {
					"attack_family": [
						"instant"
					]
				}
			}
		],
		"name": "Overwatch Optics",
		"rarity": 2,
		"special_effect": ""
	},
	{
		"description": "Attack speed +3% per turret beyond the third, up to +30%.",
		"id": "army_doctrine",
		"max_stacks": 1,
		"modifiers": [],
		"name": "Army Doctrine",
		"rarity": 2,
		"special_effect": "army_doctrine"
	},
	{
		"description": "With 5 or fewer turrets: damage +40%, reach +25%. Turret purchase scaling +8 percentage points.",
		"id": "elite_forces",
		"max_stacks": 1,
		"modifiers": [
			{
				"stat": "turret_penalty_increase",
				"operation": "add",
				"value": 0.08,
				"filter": {}
			}
		],
		"name": "Elite Forces",
		"rarity": 2,
		"special_effect": "elite_forces"
	},
	{
		"description": "Below 30% hull: attack speed +40%. Max hull -10%.",
		"id": "last_stand",
		"max_stacks": 1,
		"modifiers": [
			{
				"stat": "last_stand_fire_rate",
				"operation": "add",
				"value": 0.4,
				"filter": {}
			},
			{
				"stat": "player_max_health",
				"operation": "increase",
				"value": -0.1,
				"filter": {}
			}
		],
		"name": "Last Stand",
		"rarity": 2,
		"special_effect": ""
	},
	{
		"description": "Enemies per wave -15%, kill scrap +25%. Shop prices +10%.",
		"id": "quality_over_quantity",
		"max_stacks": 1,
		"modifiers": [
			{
				"stat": "enemy_count_mult",
				"operation": "increase",
				"value": -0.15,
				"filter": {}
			},
			{
				"stat": "scrap_earn_mult",
				"operation": "increase",
				"value": 0.25,
				"filter": {}
			},
			{
				"stat": "shop_price_mult",
				"operation": "increase",
				"value": 0.1,
				"filter": {}
			}
		],
		"name": "Quality Over Quantity",
		"rarity": 3,
		"special_effect": ""
	},
	{
		"description": "All weapon damage +40%. Max hull -25%.",
		"id": "glass_cannon_core",
		"max_stacks": 1,
		"modifiers": [
			{
				"stat": "damage",
				"operation": "increase",
				"value": 0.4,
				"filter": {}
			},
			{
				"stat": "player_max_health",
				"operation": "increase",
				"value": -0.25,
				"filter": {}
			}
		],
		"name": "Glass Cannon Core",
		"rarity": 3,
		"special_effect": ""
	},
	{
		"description": "When every owned turret shares an attack family: damage +50%, attack speed +25%.",
		"id": "mono_type_mastery",
		"max_stacks": 1,
		"modifiers": [],
		"name": "Focused Arsenal",
		"rarity": 3,
		"special_effect": "mono_type_mastery"
	},
	{
		"description": "Area kills detonate for 40% of the killing damage at 60% of its area radius. Chains up to 3 deep.",
		"id": "reactor_overload",
		"max_stacks": 1,
		"modifiers": [
			{
				"stat": "reactor_overload",
				"operation": "add",
				"value": 1,
				"filter": {}
			}
		],
		"name": "Reactor Overload",
		"rarity": 3,
		"special_effect": ""
	},
	{
		"description": "Instant turrets within 4 m of another Instant turret deal +35% damage.",
		"id": "storm_conductor",
		"max_stacks": 1,
		"modifiers": [
			{
				"stat": "storm_link_damage",
				"operation": "add",
				"value": 0.35,
				"filter": {}
			}
		],
		"name": "Resonance Link",
		"rarity": 3,
		"special_effect": ""
	},
	{
		"description": "Damage +12% per attack family represented by a separate owned turret, up to +48%.",
		"id": "elemental_conduit",
		"max_stacks": 1,
		"modifiers": [],
		"name": "Combined Arms",
		"rarity": 4,
		"special_effect": "elemental_conduit"
	},
	{
		"description": "Kinetic sweep speed +100%, reach +50%; hits slow 25% for 0.5s.",
		"id": "whirlwind_frame",
		"max_stacks": 1,
		"modifiers": [
			{
				"stat": "rotation_rate",
				"operation": "increase",
				"value": 1,
				"filter": {
					"attack_family": [
						"kinetic"
					]
				}
			},
			{
				"stat": "range",
				"operation": "increase",
				"value": 0.5,
				"filter": {
					"attack_family": [
						"kinetic"
					]
				}
			},
			{
				"stat": "slow_intensity",
				"operation": "add",
				"value": 0.25,
				"filter": {
					"attack_family": [
						"kinetic"
					]
				}
			},
			{
				"stat": "slow_duration",
				"operation": "add",
				"value": 0.5,
				"filter": {
					"attack_family": [
						"kinetic"
					]
				}
			}
		],
		"name": "Whirlwind Frame",
		"rarity": 4,
		"special_effect": ""
	},
	{
	  "id": "opening_salvo",
	  "name": "Opening Salvo",
	  "rarity": 1,
	  "description": "Projectile hits against full-health enemies deal +25% damage.",
	  "max_stacks": 1,
	  "modifiers": [],
	  "special_effect": "opening_salvo"
	},
	{
	  "id": "return_address",
	  "name": "Return Address",
	  "rarity": 2,
	  "description": "Projectile shots that miss every enemy return once to their firing position for 50% damage.",
	  "max_stacks": 1,
	  "modifiers": [],
	  "special_effect": "return_address"
	},
	{
	  "id": "slipstream_fletching",
	  "name": "Slipstream Fletching",
	  "rarity": 1,
	  "description": "Projectile hits gain +20% damage after travelling 2 m.",
	  "max_stacks": 1,
	  "modifiers": [],
	  "special_effect": "slipstream_fletching"
	},
	{
	  "id": "cinder_reserve",
	  "name": "Cinder Reserve",
	  "rarity": 2,
	  "description": "Kills transfer up to 1 second of remaining burn to the nearest unburned enemy within 1.5 m. Transferred burns cannot transfer again.",
	  "max_stacks": 1,
	  "modifiers": [],
	  "special_effect": "cinder_reserve"
	},
	{
	  "id": "arc_insurance",
	  "name": "Arc Insurance",
	  "rarity": 2,
	  "description": "Unused chain jumps add +8% damage each to the final hit, up to +24%. Requires a chain attack.",
	  "max_stacks": 1,
	  "modifiers": [],
	  "special_effect": "arc_insurance"
	},
	{
	  "id": "follow_through",
	  "name": "Follow-Through",
	  "rarity": 3,
	  "description": "Hit 3 distinct enemies in one kinetic swing or rolling shot: +10% weapon attack speed for 2 seconds. Up to 5 active stacks; triggering refreshes duration.",
	  "max_stacks": 1,
	  "modifiers": [],
	  "special_effect": "follow_through"
	},
	{
	  "id": "counterweight",
	  "name": "Counterweight",
	  "rarity": 2,
	  "description": "Kinetic hits deal +20% damage against enemies with knockback resistance (mass above 1).",
	  "max_stacks": 1,
	  "modifiers": [],
	  "special_effect": "counterweight"
	},
	{
	  "id": "victory_lap",
	  "name": "Victory Lap",
	  "rarity": 3,
	  "description": "Kinetic kills grant that weapon +10% reach for 2 seconds. Up to 5 active stacks; kills refresh duration.",
	  "max_stacks": 1,
	  "modifiers": [],
	  "special_effect": "victory_lap"
	},
	{
	  "id": "rescue_beacon",
	  "name": "Rescue Beacon",
	  "rarity": 2,
	  "description": "Taking hull damage grants you and turrets within 3 m +15% attack speed for 2 seconds. Cooldown: 8 seconds.",
	  "max_stacks": 1,
	  "modifiers": [],
	  "special_effect": "rescue_beacon"
	},
	{
	  "id": "reserve_battery",
	  "name": "Reserve Battery",
	  "rarity": 3,
	  "description": "Once per wave, fully heal the core when a surviving hit leaves it below 30% health. Core modes only.",
	  "max_stacks": 1,
	  "modifiers": [],
	  "special_effect": "reserve_battery"
	},
	{
	  "id": "close_partnership",
	  "name": "Close Partnership",
	  "rarity": 1,
	  "description": "You and every deployed turret within 1.5 m gain +8% damage. Multiple nearby turrets do not multiply the hero bonus.",
	  "max_stacks": 1,
	  "modifiers": [],
	  "special_effect": "close_partnership"
	}
]

static func get_all() -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in ROWS:
		var item := Item.new()
		item.item_id = row["id"]
		item.name = row["name"]
		item.description = row["description"]
		item.rarity = int(row["rarity"]) as GameEnums.ItemRarity
		item.max_stacks = int(row["max_stacks"])
		item.special_effect = row["special_effect"]
		item.modifiers.assign(row["modifiers"].duplicate(true))
		result[item.item_id] = item
	return result
