extends Node

## Central runtime feature flag service.
##
## Flags are intentionally named and typed here so systems do not grow their
## own collection of unrelated booleans. The service is the single place to
## override a feature during a run, from tests, or from the dev panel.
##
## Scopes:
##   user        - player preference shown in settings (saved with preferences).
##   dev         - developer tooling, only reachable in dev builds.
##   experiment  - a new system under test; off in release builds and in the
##                 `release` preset, on in `all_experiments`.
##
## `live_safe` flags apply immediately. Other flags requested during a run are
## queued and apply when the next wave begins (see `request_enabled`).

signal flag_changed(flag_id: String, enabled: bool)
signal pending_changed()

const REDUCED_MOTION: String = "reduced_motion"
const DEV_PANEL: String = "dev_panel"
const DEBUG_OVERLAYS: String = "debug_overlays"
const TURRET_PROGRESSION: String = "turret_progression"
const ENTRENCH: String = "entrench"
const PLACEMENT_PREVIEW: String = "placement_preview"
const ITEMS_V2: String = "items_v2"
const ITEMS_V2_HOOKS: String = "items_v2_hooks"
const MODE_PROTECT_CORE: String = "mode_protect_core"
const MODE_CONVOY: String = "mode_convoy"
const TECH_DROPS: String = "tech_drops"
const BUILD_ZONES: String = "build_zones"
const DIFFICULTY_RULES: String = "difficulty_rules"
const TERRAIN_ZONES: String = "terrain_zones"
const DEBUG_ZONES: String = "debug_zones"
const ZONE_READABILITY: String = "zone_readability"
const RANGE_OVERLAY: String = "range_overlay"

const SCOPE_USER: String = "user"
const SCOPE_DEV: String = "dev"
const SCOPE_EXPERIMENT: String = "experiment"

const APPLIED: String = "applied"
const QUEUED: String = "queued"
const REJECTED: String = "rejected"

## Definition fields (all optional except `name`):
##   name, description, default, scope, requires (Array of flag ids),
##   live_safe (bool, default false), phase (roadmap phase that introduced it).
const FLAG_DEFINITIONS: Dictionary = {
	REDUCED_MOTION: {
		"name": "Reduced Motion", "default": false, "scope": SCOPE_USER, "live_safe": true, "phase": 0,
		"description": "Removes bobbing, recoil and hit blinking.",
	},
	DEV_PANEL: {
		"name": "Dev Panel", "default": true, "scope": SCOPE_DEV, "live_safe": true, "phase": 0,
		"description": "Allows the developer panel to open (dev builds only).",
	},
	DEBUG_OVERLAYS: {
		"name": "Debug Overlays", "default": false, "scope": SCOPE_DEV, "live_safe": true, "phase": 0,
		"requires": [DEV_PANEL],
		"description": "Shows live counts (wave, enemies, turrets, projectiles, pending flags) on screen.",
	},
	TURRET_PROGRESSION: {
		"name": "Turret Progression", "default": true, "scope": SCOPE_EXPERIMENT, "live_safe": true, "phase": 1,
		"description": "Leftover scrap becomes turret XP, unlimited stat levels and scarcer turret pricing. Changes apply when you start or restart a run. Evolution forms are not implemented yet.",
	},
	ENTRENCH: {
		"name": "Entrench", "default": true, "scope": SCOPE_EXPERIMENT, "phase": 1,
		"description": "Turrets earn damage and fire rate for every few seconds they stay in place. Picking one up resets its stacks.",
	},
	ITEMS_V2: {
		"name": "Item Pool v2", "default": true, "scope": SCOPE_EXPERIMENT, "phase": 2,
		"description": "Adds the build-direction items (family Doctrines, specialists, tall and wide trades) to the shop pool. Applies from the next shop.",
	},
	ITEMS_V2_HOOKS: {
		"name": "Item Pool v2 Rares", "default": true, "scope": SCOPE_EXPERIMENT, "phase": 2, "requires": [ITEMS_V2],
		"description": "Adds the rare, epic and legendary items, including those with new mechanics (Reactor Overload, Storm Conductor, Last Stand).",
	},
	MODE_PROTECT_CORE: {
		"name": "Protect the Core", "default": true, "scope": SCOPE_EXPERIMENT, "phase": 5,
		"description": "Allows the Protect the Core mode: enemies head for a fixed core and chase the hero only within aggro range. Applies from the next run.",
	},
	MODE_CONVOY: {
		"name": "Convoy", "default": true, "scope": SCOPE_EXPERIMENT, "phase": 5,
		"description": "Allows the Convoy mode: the core drives door to door along a route that changes every round and is previewed in the shop. Applies from the next run.",
	},
	TECH_DROPS: {
		"name": "Tech Drops", "default": true, "scope": SCOPE_EXPERIMENT, "live_safe": true, "phase": 5,
		"description": "Destructible crates appear away from your turrets during a wave. Destroy one for scrap and a chance at a free item; it is lost when the wave ends.",
	},
	BUILD_ZONES: {
		"name": "Build Zones", "default": false, "scope": SCOPE_EXPERIMENT, "live_safe": true, "phase": 5,
		"description": "Glowing build zones appear during a wave. Stand in one to build a turret or an item. Without Turret Progression, leftover scrap is banked and improves next-wave zones; with progression, it becomes turret XP instead.",
	},
	DIFFICULTY_RULES: {
		"name": "Difficulty Rules", "default": true, "scope": SCOPE_EXPERIMENT, "phase": 5,
		"description": "Higher difficulties add elite enemies and, in core mode, core seekers, a weaker core and faster waves. Applies from the next run.",
	},
	TERRAIN_ZONES: {
		"name": "Terrain Zones", "default": false, "scope": SCOPE_EXPERIMENT, "phase": 4,
		"description": "Each run gets a random terrain layout: high ground (turret range), mud (slows enemies and you), no-build ground and power nodes (faster Entrench). Applies from the next run.",
	},
	ZONE_READABILITY: {
		"name": "Zone Readability", "default": true, "scope": SCOPE_EXPERIMENT, "live_safe": true, "phase": 4, "requires": [TERRAIN_ZONES],
		"description": "Patterned zone ground (chevrons, sludge, hazard hatching, charge pulses), distinct colours, bigger props, names that fade in as you approach, a zone line in the hint bar and a legend on pause. Off restores the flat tinted discs. Applies at once.",
	},
	DEBUG_ZONES: {
		"name": "Debug Zones", "default": false, "scope": SCOPE_DEV, "live_safe": true, "phase": 4,
		"requires": [DEV_PANEL],
		"description": "Labels every terrain zone with its type and strength and plants a pole at its centre.",
	},
	RANGE_OVERLAY: {
		"name": "Range Toggle", "default": true, "scope": SCOPE_USER, "live_safe": true, "phase": 4,
		"description": "Y on a controller (Tab on keyboard) toggles a ring showing every turret's range, including high-ground bonuses.",
	},
	PLACEMENT_PREVIEW: {
		"name": "Placement Preview", "default": true, "scope": SCOPE_EXPERIMENT, "live_safe": true, "phase": 1,
		"description": "While carrying a turret, shows a marker where it would be deployed (green clear, red blocked).",
	},
}

## Presets only touch `experiment` flags (plus explicit `overrides`), so choosing one never
## changes player preferences or developer tooling.
const PRESETS: Dictionary = {
	"release": {
		"label": "Release", "experiments": false, "overrides": {},
		"description": "Every experiment off. What a player would get.",
	},
	"all_experiments": {
		"label": "All experiments", "experiments": true, "overrides": {},
		"description": "Every experiment on, for integration testing.",
	},
}

var _definitions: Dictionary = {}
var _flags: Dictionary = {}
var _pending: Dictionary = {}


func _ready() -> void:
	reset_state()


## True for editor/debug builds and for release builds launched with `--dev`.
static func is_dev_build() -> bool:
	return OS.is_debug_build() or "--dev" in OS.get_cmdline_user_args()


func dev_panel_available() -> bool:
	return is_dev_build() and is_enabled(DEV_PANEL)


func reset_state() -> void:
	"""Restore all flags to their declared defaults and drop test-registered flags."""
	_definitions.clear()
	for flag_id in FLAG_DEFINITIONS:
		_definitions[flag_id] = _normalize(FLAG_DEFINITIONS[flag_id])
	_flags.clear()
	_pending.clear()
	for flag_id in _definitions:
		_flags[flag_id] = bool(_definitions[flag_id]["default"])


## Adds a flag at runtime. Used by tests and by systems that declare flags next to their code.
func register_flag(flag_id: String, definition: Dictionary) -> void:
	_definitions[flag_id] = _normalize(definition)
	_flags[flag_id] = bool(_definitions[flag_id]["default"])


func unregister_flag(flag_id: String) -> void:
	_definitions.erase(flag_id)
	_flags.erase(flag_id)
	_pending.erase(flag_id)


static func _normalize(definition: Dictionary) -> Dictionary:
	var result := {
		"name": "", "description": "", "default": false, "scope": SCOPE_USER,
		"requires": [], "live_safe": false, "phase": 0,
	}
	result.merge(definition.duplicate(true), true)
	return result


func is_known_flag(flag_id: String) -> bool:
	return _definitions.has(flag_id)


func is_enabled(flag_id: String, fallback: bool = false) -> bool:
	if not is_known_flag(flag_id):
		return fallback
	return bool(_flags.get(flag_id, _definitions[flag_id]["default"]))


## Applies immediately, regardless of `live_safe`. Used by tests, settings loading and presets
## between runs. Returns false for unknown flags or when a required flag is off.
func set_enabled(flag_id: String, enabled: bool) -> bool:
	if not is_known_flag(flag_id):
		DebugService.warn(DebugService.SYSTEMS, "Unknown feature flag: %s" % flag_id)
		return false
	_pending.erase(flag_id)
	if enabled:
		for required: String in _definitions[flag_id]["requires"]:
			if not is_enabled(required):
				DebugService.warn(DebugService.SYSTEMS, "Flag %s requires %s" % [flag_id, required])
				return false
	_apply(flag_id, enabled)
	if not enabled:
		# Dependents cannot stay on without what they require.
		for other: String in _definitions:
			if is_enabled(other) and flag_id in _definitions[other]["requires"]:
				set_enabled(other, false)
	return true


func toggle(flag_id: String) -> bool:
	return set_enabled(flag_id, not is_enabled(flag_id))


## Run-aware request used by the dev panel: `live_safe` flags apply now, others queue until the
## next wave while a run is active. Returns APPLIED, QUEUED or REJECTED.
func request_enabled(flag_id: String, enabled: bool) -> String:
	if not is_known_flag(flag_id):
		return REJECTED
	if bool(_definitions[flag_id]["live_safe"]) or not _run_active():
		return APPLIED if set_enabled(flag_id, enabled) else REJECTED
	if enabled:
		for required: String in _definitions[flag_id]["requires"]:
			if not is_enabled(required) and not bool(_pending.get(required, false)):
				return REJECTED
	if enabled == is_enabled(flag_id):
		_pending.erase(flag_id)
	else:
		_pending[flag_id] = enabled
	pending_changed.emit()
	return QUEUED


## Value the flag will have once queued changes land.
func get_effective(flag_id: String) -> bool:
	return bool(_pending.get(flag_id, is_enabled(flag_id)))


func has_pending() -> bool:
	return not _pending.is_empty()


func get_pending() -> Dictionary:
	return _pending.duplicate()


## Applies queued changes in definition order. Called when a wave begins.
func apply_pending() -> int:
	if _pending.is_empty():
		return 0
	var queued := _pending.duplicate()
	_pending.clear()
	var applied := 0
	for flag_id: String in _definitions:
		if queued.has(flag_id) and set_enabled(flag_id, bool(queued[flag_id])):
			applied += 1
	pending_changed.emit()
	return applied


func clear_pending() -> void:
	if not _pending.is_empty():
		_pending.clear()
		pending_changed.emit()


func get_preset_ids() -> Array[String]:
	var result: Array[String] = []
	for preset_id: String in PRESETS:
		result.append(preset_id)
	return result


## Sets every experiment flag from the preset (dependencies respected), then its explicit overrides.
## Applies immediately: call between runs, or accept that live systems see the change at once.
func apply_preset(preset_id: String) -> bool:
	if not PRESETS.has(preset_id):
		DebugService.warn(DebugService.SYSTEMS, "Unknown flag preset: %s" % preset_id)
		return false
	var preset: Dictionary = PRESETS[preset_id]
	var experiments_on: bool = bool(preset["experiments"])
	var ordered := get_flag_ids(SCOPE_EXPERIMENT)
	# Turn off first so dependents drop before their requirements, then on in dependency order.
	if not experiments_on:
		for flag_id in ordered:
			set_enabled(flag_id, false)
	else:
		var remaining := ordered.duplicate()
		var guard := remaining.size() + 1
		while not remaining.is_empty() and guard > 0:
			guard -= 1
			for flag_id: String in remaining.duplicate():
				if set_enabled(flag_id, true):
					remaining.erase(flag_id)
	for flag_id: String in preset["overrides"]:
		set_enabled(flag_id, bool(preset["overrides"][flag_id]))
	return true


## Flags can also be named on the command line for tools: `--flags=a,b` enables, `--flags=-a` disables.
func apply_flag_list(spec: String) -> PackedStringArray:
	var failed := PackedStringArray()
	for raw: String in spec.split(",", false):
		var token := raw.strip_edges()
		var enable := not token.begins_with("-")
		var flag_id := token.trim_prefix("-").trim_prefix("+")
		if not set_enabled(flag_id, enable):
			failed.append(token)
	return failed


func get_flag_ids(scope: String = "") -> Array[String]:
	var result: Array[String] = []
	for flag_id: String in _definitions:
		if scope.is_empty() or _definitions[flag_id]["scope"] == scope:
			result.append(flag_id)
	return result


func get_definition(flag_id: String) -> Dictionary:
	return _definitions.get(flag_id, {}).duplicate(true)


func is_live_safe(flag_id: String) -> bool:
	return bool(_definitions.get(flag_id, {}).get("live_safe", false))


func get_all_flags() -> Dictionary:
	return _flags.duplicate(true)


## Compact `{flag_id: bool}` of every non-user flag, for telemetry and logs.
func get_snapshot() -> Dictionary:
	var result := {}
	for flag_id: String in _definitions:
		if _definitions[flag_id]["scope"] != SCOPE_USER:
			result[flag_id] = is_enabled(flag_id)
	return result


func _apply(flag_id: String, enabled: bool) -> void:
	var previous := is_enabled(flag_id)
	_flags[flag_id] = enabled
	if previous != enabled:
		flag_changed.emit(flag_id, enabled)
		Events.feature_flag_changed.emit(flag_id, enabled)


func _run_active() -> bool:
	return GameStateService.is_game_active
