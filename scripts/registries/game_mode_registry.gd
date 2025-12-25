class_name GameModeRegistry
extends RefCounted

## Definitions for all game modes

const MODES = {
	# Spawn location modes
	GameEnums.GameMode.SENTINEL: {
		"name": "Sentinel",
		"description": "Enemies spawn near the arena edges.",
		"group": "spawn_location"
	},
	GameEnums.GameMode.INVASION: {
		"name": "Invasion",
		"description": "Enemies can spawn anywhere in the arena.",
		"group": "spawn_location",
		"is_default": true
	},
	# Win condition modes
	GameEnums.GameMode.SURVIVAL: {
		"name": "Survival",
		"description": "Classic mode - survive all waves.",
		"group": "win_condition"
	},
	GameEnums.GameMode.TECH_DEFENSE: {
		"name": "Tech Defense",
		"description": "Defend the power core from enemies. If it's destroyed, you lose!",
		"group": "win_condition",
		"is_default": true
	},
	GameEnums.GameMode.TUNNELING_TIMED: {
		"name": "Tunneling (Timed)",
		"description": "Use turrets to breach the exit door before time runs out.",
		"group": "win_condition"
	},
	GameEnums.GameMode.TUNNELING_ALERT: {
		"name": "Tunneling (Alert)",
		"description": "Breach the exit door. Spawn rate escalates until you do!",
		"group": "win_condition"
	},
	# Arena type modes
	GameEnums.GameMode.ARENA_RECTANGULAR: {
		"name": "Classic Arena",
		"description": "Standard rectangular arena.",
		"group": "arena_type"
	},
	GameEnums.GameMode.ARENA_ISOMETRIC: {
		"name": "Isometric Arena",
		"description": "Diamond-shaped isometric arena for AI backgrounds.",
		"group": "arena_type",
		"is_default": true
	},
}

static func get_mode_config(mode: GameEnums.GameMode) -> Dictionary:
	return MODES.get(mode, {})

static func get_modes_in_group(group: String) -> Array:
	var result = []
	for mode_id in MODES:
		if MODES[mode_id].get("group") == group:
			result.append(mode_id)
	return result

static func get_default_mode_for_group(group: String) -> int:
	for mode_id in MODES:
		var config = MODES[mode_id]
		if config.get("group") == group and config.get("is_default", false):
			return mode_id
	return -1
