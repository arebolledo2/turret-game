class_name GameModeRegistry
extends RefCounted

## Definitions for all game modes

const MODES = {
	GameEnums.GameMode.SENTINEL: {
		"name": "Sentinel",
		"description": "Enemies spawn near the arena edges.",
		"group": "spawn_location",
		"is_default": true
	},
	GameEnums.GameMode.INVASION: {
		"name": "Invasion",
		"description": "Enemies can spawn anywhere in the arena.",
		"group": "spawn_location"
	}
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
