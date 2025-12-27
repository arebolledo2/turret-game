class_name EnemyRegistry
extends RefCounted

## Registry of all enemy types and helper functions

const TYPES: Dictionary = {
	"basic": {
		"name": "Spider Drone",
		"icon": "🕷️",
		"description": "Animated spider-like drone with sleek neon design.",
		"behaviors": [GameEnums.EnemyBehavior.CHASE],
		"scene_path": "res://scenes/enemy_spider_drone.tscn",
		"base_stats": {
			"health": 8.0,
			"speed": 75.0,
			"contact_damage": 8.0,
			"xp_value": 10,
			"scale": 1.0, # Using 1.0 scale to match normalized scene
			"mass": 1.0,
		},
		"spawn_weight": 100,
		"min_wave": 1,
		"spawn_count": 3,
	},
	"fast": {
		"name": "Scout Bot",
		"icon": "⚡",
		"description": "Quick but fragile enemy.",
		"behaviors": [GameEnums.EnemyBehavior.CHASE, GameEnums.EnemyBehavior.SWARM],
		"sprite_folder": "res://assets/sprites/enemy_tiny",
		"color_tint": Color(0.6, 0.9, 1.0),
		"base_stats": {
			"health": 4.0,
			"speed": 130.0,
			"contact_damage": 5.0,
			"xp_value": 8,
			"scale": 1.2,
			"mass": 0.6,
		},
		"hurtbox": {
			"type": "circle",
			"size": Vector2(14, 14),
		},
		"spawn_weight": 60,
		"min_wave": 2,
		"spawn_count": 5,
	},
	"tank": {
		"name": "Heavy Bot",
		"icon": "🛡️",
		"description": "Slow but very tough enemy.",
		"behaviors": [GameEnums.EnemyBehavior.CHASE, GameEnums.EnemyBehavior.TANK],
		"sprite_folder": "res://assets/sprites/enemy_tiny",
		"color_tint": Color(0.8, 0.5, 0.3),
		"base_stats": {
			"health": 30.0,
			"speed": 40.0,
			"contact_damage": 13.0,
			"xp_value": 25,
			"scale": 2.0,
			"mass": 3.0,
		},
		"hurtbox": {
			"type": "rectangle",
			"size": Vector2(40, 50),
		},
		"spawn_weight": 20,
		"min_wave": 3,
	},
	"exploder": {
		"name": "Boom Bot",
		"icon": "💥",
		"description": "Explodes on death, damaging nearby enemies and player.",
		"behaviors": [GameEnums.EnemyBehavior.CHASE, GameEnums.EnemyBehavior.EXPLOSIVE],
		"sprite_folder": "res://assets/sprites/enemy_tiny",
		"color_tint": Color(1.0, 0.4, 0.2),
		"base_stats": {
			"health": 5.0,
			"speed": 90.0,
			"contact_damage": 6.0,
			"xp_value": 15,
			"scale": 1.3,
			"explosion_radius": 100.0,
			"explosion_damage": 10.0,
			"mass": 0.8,
		},
		"hurtbox": {
			"type": "circle",
			"size": Vector2(16, 16),
		},
		"spawn_weight": 0,  # Disabled
		"min_wave": 4,
		"spawn_count": 3,
	},
	"lazy_wanderer": {
		"name": "Lazy Bot",
		"icon": "😴",
		"description": "Wanders aimlessly, never chases the player.",
		"behaviors": [GameEnums.EnemyBehavior.WANDER],
		"sprite_folder": "res://assets/sprites/enemy_tiny",
		"color_tint": Color(0.7, 0.7, 0.9),
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
			"xp_value": 8,
			"scale": 1.4,
			"mass": 1.2,
		},
		"hurtbox": {
			"type": "circle",
			"size": Vector2(17, 17),
		},
		"spawn_weight": 80,
		"min_wave": 2,
		"spawn_count": 2,
	},
	"charger": {
		"name": "Charger Bot",
		"icon": "⚡",
		"description": "Wanders lazily until player is close, then charges aggressively.",
		"behaviors": [GameEnums.EnemyBehavior.CHARGE],
		"sprite_folder": "res://assets/sprites/enemy_tiny",
		"color_tint": Color(1.0, 0.8, 0.3),
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
			"xp_value": 15,
			"scale": 1.5,
			"mass": 1.5,
		},
		"hurtbox": {
			"type": "circle",
			"size": Vector2(18, 18),
		},
		"spawn_weight": 30,
		"min_wave": 3,
		"spawn_count": 1,
	},
	"neon_drone": {
		"name": "Neon Drone",
		"icon": "💠",
		"description": "Animated hovering drone with neon synth aesthetics.",
		"behaviors": [GameEnums.EnemyBehavior.CHASE],
		"scene_path": "res://scenes/enemy_animated.tscn",
		"base_stats": {
			"health": 10.0,
			"speed": 100.0,
			"contact_damage": 8.0,
			"xp_value": 12,
			"scale": 0.15,
			"mass": 1.0,
		},
		"hurtbox": {
			"type": "circle",
			"size": Vector2(24, 24),
		},
		"spawn_weight": 40,
		"min_wave": 2,
		"spawn_count": 2,
	},
	"lazy_shooter": {
		"name": "Lazy Shooter",
		"icon": "🔫",
		"description": "Wanders aimlessly while taking potshots at distant targets.",
		"behaviors": [GameEnums.EnemyBehavior.WANDER],
		"sprite_folder": "res://assets/sprites/enemy_tiny",
		"color_tint": Color(0.9, 0.7, 0.5),  # Orange/tan
		"behavior_params": {
			"wander_pause_min": 0.0,  # No pauses (like lazy_wanderer)
			"wander_pause_max": 0.0,
			"wander_move_min": 2.0,
			"wander_move_max": 4.0,
		},
		"combat_params": {
			"fire_rate": 0.25,          # Every 4 seconds
			"projectile_speed": 175.0,  # Slow, telegraphed
			"projectile_damage": 8.0,   # Moderate damage
			"firing_range": 350.0,      # Outranges player (200)
		},
		"base_stats": {
			"health": 8.0,
			"speed": 40.0,              # Lazy movement speed
			"contact_damage": 6.0,      # Low melee damage
			"xp_value": 12,             # Slightly more than basic
			"scale": 1.3,
			"mass": 1.0,
		},
		"hurtbox": {
			"type": "circle",
			"size": Vector2(16, 16),
		},
		"spawn_weight": 50,             # Moderate spawn rate
		"min_wave": 3,                  # Appears wave 3+
		"spawn_count": 2,               # Spawn in pairs
	},
}


## Get the definition for an enemy type
static func get_type(type_id: String) -> Dictionary:
	return TYPES.get(type_id, TYPES["basic"])


## Get all type IDs
static func get_all_type_ids() -> Array:
	return TYPES.keys()


## Get base stats for an enemy type (before wave scaling)
static func get_base_stats(type_id: String) -> Dictionary:
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

	return base_stats


## Get available enemy types for a given wave (respects min_wave)
static func get_available_types(wave: int) -> Array:
	var available: Array = []
	for type_id in TYPES:
		if TYPES[type_id].get("min_wave", 1) <= wave:
			available.append(type_id)
	return available


## Select a random enemy type based on spawn weights
static func select_random_type(wave: int) -> String:
	var available := get_available_types(wave)
	if available.is_empty():
		return "basic"

	# Calculate total weight
	var total_weight: float = 0.0
	for type_id in available:
		total_weight += TYPES[type_id].get("spawn_weight", 100)

	# Random selection based on weight
	var roll := randf() * total_weight
	var cumulative: float = 0.0

	for type_id in available:
		cumulative += TYPES[type_id].get("spawn_weight", 100)
		if roll <= cumulative:
			return type_id

	return available[-1]


## Check if enemy type has a specific behavior
static func has_behavior(type_id: String, behavior: GameEnums.EnemyBehavior) -> bool:
	if not TYPES.has(type_id):
		return false
	return behavior in TYPES[type_id].get("behaviors", [])


## Get spawn count for an enemy type
static func get_spawn_count(type_id: String) -> int:
	if not TYPES.has(type_id):
		return 1
	return TYPES[type_id].get("spawn_count", 1)


## Get color tint for an enemy type
static func get_color(type_id: String) -> Color:
	if not TYPES.has(type_id):
		return Color.WHITE
	return TYPES[type_id].get("color_tint", Color.WHITE)


## Get sprite folder path for an enemy type
static func get_sprite_folder(type_id: String) -> String:
	if not TYPES.has(type_id):
		return "res://assets/sprites/enemy_tiny"
	return TYPES[type_id].get("sprite_folder", "res://assets/sprites/enemy_tiny")
