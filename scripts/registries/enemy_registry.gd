class_name EnemyRegistry
extends RefCounted

## Registry of all enemy types and helper functions

const TYPES: Dictionary = {
	"basic": {
		"name": "Spider Drone",
		"icon": "🕷️",
		"description": "Spider-like drone with sleek neon design.",
		"base_stats": {
			"health": 8.0,
			"speed": 75.0,
			"contact_damage": 8.0,
			"scrap_value": 1,
			"scale": 0.075, # Smaller scale for sprite clarity
			"mass": 1.0,
		},
	},
	"fast": {
		"name": "Scout Bot",
		"icon": "⚡",
		"description": "Quick but fragile enemy.",
		"base_stats": {
			"health": 4.0,
			"speed": 130.0,
			"contact_damage": 5.0,
			"scrap_value": 1,
			# The Scout Bot source art is 1024px; normalize it to the same
			# roughly 50px gameplay footprint as the standard spider drone.
			"scale": 0.075,
			"mass": 0.6,
		},
	},
	"tank": {
		"name": "Heavy Bot",
		"icon": "🛡️",
		"description": "Slow but very tough enemy.",
		"base_stats": {
			"health": 30.0,
			"speed": 40.0,
			"contact_damage": 13.0,
			"scrap_value": 1,
			# The Heavy Bot source art is also 1024px, so keep its larger body
			# readable without letting the raw source dimensions dominate the arena.
			"scale": 0.1,
			"mass": 3.0,
		},
	},
	"exploder": {
		"name": "Boom Bot",
		"icon": "💥",
		"description": "Explodes on death, damaging nearby enemies and player.",
		"base_stats": {
			"health": 5.0,
			"speed": 90.0,
			"contact_damage": 6.0,
			"scrap_value": 1,
			"scale": 1.3,
			"explosion_radius": 100.0,
			"explosion_damage": 10.0,
			"mass": 0.8,
		},
	},
	"lazy_wanderer": {
		"name": "Lazy Bot",
		"icon": "😴",
		"description": "Wanders aimlessly, never chases the player.",
		"behavior_params": {
			"wander_pause_min": 0.0,
			"wander_pause_max": 0.0,
			"wander_move_min": 2.0,
			"wander_move_max": 4.0,
		},
		"base_stats": {
			"health": 6.0,
			"speed": 40.0,
			"contact_damage": 5.0,
			"scrap_value": 1,
			"scale": 1.4,
			"mass": 1.2,
		},
	},
	"charger": {
		"name": "Charger Bot",
		"icon": "⚡",
		"description": "Wanders lazily until player is close, then charges aggressively.",
		"behavior_params": {
			"wander_pause_min": 1.0,
			"wander_pause_max": 2.0,
			"wander_move_min": 1.5,
			"wander_move_max": 2.5,
			"charge_detect_radius": 200.0,
			"charge_alert_duration": 0.9,
			"charge_speed_multiplier": 3.0,
			"charge_duration": 1.5,
			"charge_cooldown": 2.5,
		},
		"base_stats": {
			"health": 9.0,
			"speed": 60.0,
			"contact_damage": 10.0,
			"scrap_value": 1,
			"scale": 1.5,
			"mass": 1.5,
		},
	},
	"neon_drone": {
		"name": "Neon Drone",
		"icon": "💠",
		"description": "Animated hovering drone with neon synth aesthetics.",
		"base_stats": {
			"health": 10.0,
			"speed": 100.0,
			"contact_damage": 8.0,
			"scrap_value": 1,
			"scale": 0.15,
			"mass": 1.0,
		},
	},
	"lazy_shooter": {
		"name": "Lazy Shooter",
		"icon": "🔫",
		"description": "Wanders aimlessly while taking potshots at distant targets.",
		"behavior_params": {
			"wander_pause_min": 0.0, # No pauses (like lazy_wanderer)
			"wander_pause_max": 0.0,
			"wander_move_min": 2.0,
			"wander_move_max": 4.0,
		},
		"combat_params": {
			"fire_rate": 0.25, # Every 4 seconds
			"projectile_speed": 175.0, # Slow, telegraphed
			"projectile_damage": 8.0, # Moderate damage
			"firing_range": 350.0, # Outranges player (200)
		},
		"base_stats": {
			"health": 8.0,
			"speed": 40.0, # Lazy movement speed
			"contact_damage": 6.0, # Low melee damage
			"scrap_value": 1,
			"scale": 1.3,
			"mass": 1.0,
		},
	},
}


## Get all type IDs
static func get_all_type_ids() -> Array:
	return TYPES.keys() + EnemyEcology.TYPES.keys()


## Get base stats for an enemy type (before wave scaling)
static func get_base_stats(type_id: String) -> Dictionary:
	if EnemyEcology.TYPES.has(type_id):
		var stats: Dictionary = EnemyEcology.TYPES[type_id].duplicate(true)
		stats["scrap_value"] = 0 if type_id in EnemyEcology.SUMMONS else 1
		return stats
	if not TYPES.has(type_id):
		return TYPES["basic"]["base_stats"].duplicate(true)
	return TYPES[type_id]["base_stats"].duplicate(true)


## Get scaled stats for an enemy type at a specific wave
static func get_stats_for_wave(type_id: String, wave: int, difficulty_config: Dictionary) -> Dictionary:
	var base_stats := get_base_stats(type_id)

	# Apply difficulty multipliers
	base_stats["health"] = base_stats["health"] * difficulty_config["enemy_health_mult"]
	base_stats["speed"] = base_stats["speed"] * difficulty_config["enemy_speed_mult"]
	base_stats["contact_damage"] = base_stats["contact_damage"] * difficulty_config["enemy_damage_mult"]

	# Apply wave scaling
	base_stats["health"] = base_stats["health"] * pow(difficulty_config["enemy_hp_scale_per_wave"], wave - 1)
	base_stats["speed"] = base_stats["speed"] * pow(difficulty_config["enemy_speed_scale_per_wave"], wave - 1)

	if EnemyEcology.is_boss(type_id):
		base_stats["health"] = EnemyEcology.boss_health(type_id, difficulty_config)
	return base_stats
