extends Node

## Central runtime feature flag service.
##
## Flags are intentionally named and typed here so systems do not grow their
## own collection of unrelated booleans. The service is the single place to
## override a feature during a run, from tests, or from a future developer
## console/configuration layer.

signal flag_changed(flag_id: String, enabled: bool)

const REDUCED_MOTION: String = "reduced_motion"

const FLAG_DEFINITIONS: Dictionary = {
	REDUCED_MOTION: {"name": "Reduced Motion", "default": false, "scope": "user"},
}

var _flags: Dictionary = {}


func _ready() -> void:
	reset_state()


func reset_state() -> void:
	"""Restore all flags to their declared defaults."""
	_flags.clear()
	for flag_id in FLAG_DEFINITIONS:
		_flags[flag_id] = bool(FLAG_DEFINITIONS[flag_id].get("default", false))


func is_known_flag(flag_id: String) -> bool:
	return FLAG_DEFINITIONS.has(flag_id)


func is_enabled(flag_id: String, fallback: bool = false) -> bool:
	if not is_known_flag(flag_id):
		return fallback
	return bool(_flags.get(flag_id, FLAG_DEFINITIONS[flag_id].get("default", fallback)))


func set_enabled(flag_id: String, enabled: bool) -> bool:
	if not is_known_flag(flag_id):
		DebugService.warn(DebugService.SYSTEMS, "Unknown feature flag: %s" % flag_id)
		return false

	var next_value := bool(enabled)
	var previous_value := is_enabled(flag_id)
	_flags[flag_id] = next_value
	if previous_value != next_value:
		flag_changed.emit(flag_id, next_value)
		Events.feature_flag_changed.emit(flag_id, next_value)
	return true


func toggle(flag_id: String) -> bool:
	return set_enabled(flag_id, not is_enabled(flag_id))


func get_flag_ids(scope: String = "") -> Array[String]:
	var result: Array[String] = []
	for flag_id in FLAG_DEFINITIONS:
		if scope.is_empty() or FLAG_DEFINITIONS[flag_id].get("scope") == scope:
			result.append(flag_id)
	return result


func get_definition(flag_id: String) -> Dictionary:
	return FLAG_DEFINITIONS.get(flag_id, {}).duplicate(true)


func get_all_flags() -> Dictionary:
	return _flags.duplicate(true)
