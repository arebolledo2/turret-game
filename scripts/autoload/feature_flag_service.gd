extends Node

## Central runtime feature flag service.
##
## Flags are intentionally named and typed here so systems do not grow their
## own collection of unrelated booleans. The service is the single place to
## override a feature during a run, from tests, or from a future developer
## console/configuration layer.

signal flag_changed(flag_id: String, enabled: bool)

# Presentation and player settings
const SHOW_DAMAGE_NUMBERS: String = "show_damage_numbers"
const PLAYER_AUTO_ATTACK: String = "player_auto_attack"
const SHOW_TURRET_RANGES: String = "show_turret_ranges"
const ISOMETRIC_DEBUG: String = "isometric_debug"
const REDUCED_MOTION: String = "reduced_motion"

# System gates
const ENEMY_SPAWNING: String = "enemy_spawning"
const TECH_DROPS: String = "tech_drops"
const SHOP: String = "shop"
const ASSET_STUDIO: String = "asset_studio"
const TUNNEL_ALERT_ESCALATION: String = "tunneling_alert_escalation"

# Game-mode gates. These make registry entries switchable without editing UI
# code or removing the mode definition itself.
const MODE_SENTINEL: String = "mode_sentinel"
const MODE_INVASION: String = "mode_invasion"
const MODE_SURVIVAL: String = "mode_survival"
const MODE_TECH_DEFENSE: String = "mode_tech_defense"
const MODE_TUNNELING_TIMED: String = "mode_tunneling_timed"
const MODE_TUNNELING_ALERT: String = "mode_tunneling_alert"
const MODE_ESCORT: String = "mode_escort"
const MODE_ARENA_RECTANGULAR: String = "mode_arena_rectangular"
const MODE_ARENA_ISOMETRIC: String = "mode_arena_isometric"

const FLAG_DEFINITIONS: Dictionary = {
	SHOW_DAMAGE_NUMBERS: {"name": "Damage Numbers", "default": true, "scope": "user"},
	PLAYER_AUTO_ATTACK: {"name": "Player Auto Attack", "default": true, "scope": "user"},
	SHOW_TURRET_RANGES: {"name": "Turret Ranges", "default": false, "scope": "user"},
	ISOMETRIC_DEBUG: {"name": "Isometric Debug", "default": false, "scope": "debug"},
	REDUCED_MOTION: {"name": "Reduced Motion", "default": false, "scope": "user"},
	ENEMY_SPAWNING: {"name": "Enemy Spawning", "default": true, "scope": "system"},
	TECH_DROPS: {"name": "Tech Drops", "default": true, "scope": "system"},
	SHOP: {"name": "Shop", "default": true, "scope": "system"},
	ASSET_STUDIO: {"name": "Asset Studio", "default": true, "scope": "system"},
	TUNNEL_ALERT_ESCALATION: {"name": "Tunneling Alert Escalation", "default": true, "scope": "system"},
	MODE_SENTINEL: {"name": "Sentinel Mode", "default": true, "scope": "mode"},
	MODE_INVASION: {"name": "Invasion Mode", "default": true, "scope": "mode"},
	MODE_SURVIVAL: {"name": "Survival Mode", "default": true, "scope": "mode"},
	MODE_TECH_DEFENSE: {"name": "Tech Defense Mode", "default": true, "scope": "mode"},
	MODE_TUNNELING_TIMED: {"name": "Tunneling Timed Mode", "default": true, "scope": "mode"},
	MODE_TUNNELING_ALERT: {"name": "Tunneling Alert Mode", "default": true, "scope": "mode"},
	MODE_ESCORT: {"name": "Escort Mode", "default": true, "scope": "mode"},
	MODE_ARENA_RECTANGULAR: {"name": "Classic Arena", "default": true, "scope": "mode"},
	MODE_ARENA_ISOMETRIC: {"name": "Isometric Arena", "default": true, "scope": "mode"},
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

	# Mode availability is a run-boundary decision. Changing it after entity
	# setup would leave the active run with stale objectives or spawn rules.
	if FLAG_DEFINITIONS[flag_id].get("scope") == "mode" and GameStateService.is_game_active:
		DebugService.warn(DebugService.SYSTEMS, "Cannot change mode feature flags during an active run: %s" % flag_id)
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
