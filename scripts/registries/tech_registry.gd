class_name TechRegistry
extends Object

## TechRegistry - Central registry for all tech tree definitions
##
## Tech Definition Structure:
## {
##     "id": String,              # Unique identifier
##     "name": String,            # Display name
##     "icon": String,            # Emoji icon
##     "description": String,     # Effect description
##     "path": String,            # turret_offense, turret_utility, player_combat, player_defense, economy
##     "tier": int,               # 1-5 (visual tier)
##     "cost": int,               # Research point cost
##     "prerequisites": Array,    # Tech IDs required
##     "repeatable": bool,        # Can unlock multiple times
##     "max_unlocks": int,        # 0 = infinite
##     "effect_type": String,     # modifier, unlock_mechanic, shop_improvement
##     "modifiers": Array,        # For stat modifiers
##     "special_effect": String   # For special mechanics
## }

# Tech path constants
const PATH_TURRET_OFFENSE := "turret_offense"
const PATH_TURRET_UTILITY := "turret_utility"
const PATH_PLAYER_COMBAT := "player_combat"
const PATH_PLAYER_DEFENSE := "player_defense"
const PATH_ECONOMY := "economy"

# Cached tech definitions
static var _all_techs: Dictionary = {}
static var _techs_by_path: Dictionary = {}
static var _initialized := false


## Initialize the registry (called on first access)
static func _ensure_initialized() -> void:
	if _initialized:
		return

	_initialized = true
	_all_techs.clear()
	_techs_by_path.clear()

	# Load techs from all path files
	var turret_offense_techs = preload("res://scripts/registries/techs/turret_offense_techs.gd")
	var turret_utility_techs = preload("res://scripts/registries/techs/turret_utility_techs.gd")
	var player_combat_techs = preload("res://scripts/registries/techs/player_combat_techs.gd")
	var player_defense_techs = preload("res://scripts/registries/techs/player_defense_techs.gd")
	var economy_techs = preload("res://scripts/registries/techs/economy_techs.gd")

	# Register techs from each path
	_register_path_techs(turret_offense_techs.get_techs())
	_register_path_techs(turret_utility_techs.get_techs())
	_register_path_techs(player_combat_techs.get_techs())
	_register_path_techs(player_defense_techs.get_techs())
	_register_path_techs(economy_techs.get_techs())

	DebugService.log(DebugService.SYSTEMS, "TechRegistry initialized with ", _all_techs.size(), " techs across ", _techs_by_path.size(), " paths")


## Register techs from a path file
static func _register_path_techs(techs: Array) -> void:
	for tech in techs:
		var tech_id: String = tech.get("id", "")
		var path: String = tech.get("path", "")

		if tech_id.is_empty():
			push_warning("Tech missing ID: %s" % tech)
			continue

		if tech_id in _all_techs:
			push_warning("Duplicate tech ID: %s" % tech_id)
			continue

		# Store tech
		_all_techs[tech_id] = tech

		# Index by path
		if not path.is_empty():
			if path not in _techs_by_path:
				_techs_by_path[path] = []
			_techs_by_path[path].append(tech)


## Get a tech definition by ID
static func get_tech(tech_id: String) -> Dictionary:
	_ensure_initialized()
	return _all_techs.get(tech_id, {})


## Get all techs for a specific path
static func get_techs_by_path(path: String) -> Array:
	_ensure_initialized()
	return _techs_by_path.get(path, [])


## Get all tech IDs
static func get_all_tech_ids() -> Array:
	_ensure_initialized()
	return _all_techs.keys()


## Get all techs
static func get_all_techs() -> Dictionary:
	_ensure_initialized()
	return _all_techs.duplicate()


## Get all available paths
static func get_all_paths() -> Array:
	_ensure_initialized()
	return _techs_by_path.keys()


## Check if a tech exists
static func has_tech(tech_id: String) -> bool:
	_ensure_initialized()
	return tech_id in _all_techs
