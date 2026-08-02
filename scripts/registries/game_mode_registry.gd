class_name GameModeRegistry
extends RefCounted

## Definitions for all game modes

const MODES = {
	# Spawn location modes
	GameEnums.GameMode.SENTINEL: {
		"name": "Sentinel",
		"description": "Enemies spawn near the arena edges.",
		"group": "spawn_location",
		"feature_flag": FeatureFlagService.MODE_SENTINEL,
		"is_default": true
	},
	GameEnums.GameMode.INVASION: {
		"name": "Invasion",
		"description": "Enemies can spawn anywhere in the arena.",
		"group": "spawn_location",
		"feature_flag": FeatureFlagService.MODE_INVASION
	},
	# Win condition modes
	GameEnums.GameMode.SURVIVAL: {
		"name": "Survival",
		"description": "Classic mode - survive all waves.",
		"group": "win_condition",
		"feature_flag": FeatureFlagService.MODE_SURVIVAL
	},
	GameEnums.GameMode.TECH_DEFENSE: {
		"name": "Tech Defense",
		"description": "Defend the power core from enemies. If it's destroyed, you lose!",
		"group": "win_condition",
		"feature_flag": FeatureFlagService.MODE_TECH_DEFENSE,
		"is_default": true
	},
	GameEnums.GameMode.TUNNELING_TIMED: {
		"name": "Tunneling (Timed)",
		"description": "Use turrets to breach the exit door before time runs out.",
		"group": "win_condition",
		"feature_flag": FeatureFlagService.MODE_TUNNELING_TIMED
	},
	GameEnums.GameMode.TUNNELING_ALERT: {
		"name": "Tunneling (Alert)",
		"description": "Breach the exit door. Spawn rate escalates until you do!",
		"group": "win_condition",
		"feature_flag": FeatureFlagService.MODE_TUNNELING_ALERT
	},
	GameEnums.GameMode.ESCORT: {
		"name": "Escort",
		"description": "Defend the target as it travels across the arena. Stay close to keep it moving!",
		"group": "win_condition",
		"feature_flag": FeatureFlagService.MODE_ESCORT
	},
	# Arena type modes
	GameEnums.GameMode.ARENA_RECTANGULAR: {
		"name": "Classic Arena",
		"description": "Standard rectangular arena.",
		"group": "arena_type",
		"feature_flag": FeatureFlagService.MODE_ARENA_RECTANGULAR
	},
	GameEnums.GameMode.ARENA_ISOMETRIC: {
		"name": "Isometric Arena",
		"description": "Diamond-shaped isometric arena for AI backgrounds.",
		"group": "arena_type",
		"feature_flag": FeatureFlagService.MODE_ARENA_ISOMETRIC,
		"is_default": true
	},
}

static func get_mode_config(mode: GameEnums.GameMode) -> Dictionary:
	return MODES.get(mode, {})

static func is_mode_enabled(mode_id: GameEnums.GameMode) -> bool:
	var config: Dictionary = get_mode_config(mode_id)
	if config.is_empty() or not bool(config.get("enabled", true)):
		return false

	var feature_flag := str(config.get("feature_flag", ""))
	return feature_flag.is_empty() or FeatureFlagService.is_enabled(feature_flag, true)

static func get_modes_in_group(group: String, include_disabled: bool = false) -> Array:
	var result = []
	for mode_id in MODES:
		if MODES[mode_id].get("group") == group and (include_disabled or is_mode_enabled(mode_id)):
			result.append(mode_id)
	return result

static func get_default_mode_for_group(group: String) -> int:
	var first_enabled := -1
	for mode_id in MODES:
		var config = MODES[mode_id]
		if config.get("group") != group or not is_mode_enabled(mode_id):
			continue
		if first_enabled == -1:
			first_enabled = mode_id
		if config.get("is_default", false):
			return mode_id
	return first_enabled
