extends Node

## Difficulty Service
## Manages difficulty settings and provides difficulty-based multipliers.
##
## Each tier has two layers. The multipliers (health, damage, count, per-wave HP, hull, turret damage) scale the base
## wave curve. The rules add structure on top and are ignored when the `difficulty_rules` flag is off:
##   elite_chance / elite_health_mult / elite_speed_mult  share of spawns that are elites, and how tough they are
##   core_health_mult / seeker_share / spawn_rate_mult    core mode only: core hit points, share of enemies that
##                                                        ignore the hero, and how fast a wave's enemies arrive
const RULE_DEFAULTS: Dictionary = {
	"elite_start_wave": 1, "elite_chance": 0.0, "elite_health_mult": 1.0, "elite_speed_mult": 1.0,
	"core_health_mult": 1.0, "seeker_share": 0.0, "spawn_rate_mult": 1.0,
}

const DIFFICULTY_CONFIG: Dictionary = {
	GameEnums.Difficulty.EASY: {
		"name": "Easy",
		"description": "Relaxed gameplay for learning",
		"enemy_health_mult": 1.0,
		"enemy_speed_mult": 1.0,
		"enemy_damage_mult": 1.0,
		"enemy_count_mult": 1.8,
		"enemy_hp_scale_per_wave": 1.10,
		"enemy_speed_scale_per_wave": 1.0,
		"player_health_mult": 1.0,
		"turret_damage_mult": 1.0,
	},
	GameEnums.Difficulty.MEDIUM: {
		"name": "Medium",
		"description": "Balanced challenge",
		"enemy_health_mult": 1.25,
		"enemy_speed_mult": 1.0,
		"enemy_damage_mult": 1.2,
		"enemy_count_mult": 2.2,
		"enemy_hp_scale_per_wave": 1.12,
		"enemy_speed_scale_per_wave": 1.0,
		"player_health_mult": 1.0,
		"turret_damage_mult": 1.0,
	},
	GameEnums.Difficulty.HARD: {
		"name": "Hard",
		"description": "For experienced survivors",
		"enemy_health_mult": 1.5,
		"enemy_speed_mult": 1.0,
		"enemy_damage_mult": 1.5,
		"enemy_count_mult": 2.6,
		"enemy_hp_scale_per_wave": 1.15,
		"enemy_speed_scale_per_wave": 1.0,
		"player_health_mult": 0.8,
		"turret_damage_mult": 0.9,
		"elite_start_wave": 4, "elite_chance": 0.10, "elite_health_mult": 2.0, "elite_speed_mult": 1.15,
		"core_health_mult": 0.85, "seeker_share": 0.10, "spawn_rate_mult": 1.15,
	},
	GameEnums.Difficulty.BRUTAL: {
		"name": "Brutal",
		"description": "Elites, core seekers and no mercy",
		"enemy_health_mult": 1.6,
		"enemy_speed_mult": 1.0,
		"enemy_damage_mult": 1.6,
		"enemy_count_mult": 2.8,
		"enemy_hp_scale_per_wave": 1.16,
		"enemy_speed_scale_per_wave": 1.0,
		"player_health_mult": 0.75,
		"turret_damage_mult": 0.9,
		"elite_start_wave": 4, "elite_chance": 0.15, "elite_health_mult": 2.0, "elite_speed_mult": 1.2,
		"core_health_mult": 0.7, "seeker_share": 0.25, "spawn_rate_mult": 1.3,
	},
}

var current_difficulty: GameEnums.Difficulty = GameEnums.Difficulty.MEDIUM


func reset_state() -> void:
	# Keep difficulty setting across runs
	pass


func get_difficulty_config() -> Dictionary:
	return DIFFICULTY_CONFIG[current_difficulty]


func get_difficulty_name() -> String:
	return get_difficulty_config()["name"]


## A tier's rule value, falling back to the neutral default for tiers that do not set it.
static func rule(config: Dictionary, key: String) -> float:
	return float(config.get(key, RULE_DEFAULTS[key]))


## Copy of `config` with every rule neutral (the `difficulty_rules` flag is off).
static func without_rules(config: Dictionary) -> Dictionary:
	var result := config.duplicate()
	for key: String in RULE_DEFAULTS:
		result[key] = RULE_DEFAULTS[key]
	return result


func set_difficulty(difficulty: GameEnums.Difficulty) -> void:
	current_difficulty = difficulty
