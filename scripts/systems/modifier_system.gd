class_name ModifierSystem
extends RefCounted

## Manages active modifiers from items and applies them to stats
##
## Modifier format:
## {
##   "id": String,           # Unique identifier
##   "stat": String,         # Which stat to modify (damage, fire_rate, etc.)
##   "operation": String,    # "add" or "multiply"
##   "value": float,         # The modification value
##   "filter": {             # Optional filters (OR logic within each array)
##     "damage_type": [],    # Array of DamageType enums
##     "attack_style": [],   # Array of AttackStyle enums
##     "turret_type": [],    # Array of turret type IDs
##   }
## }

var _modifiers: Array = []


## Add a modifier (returns the modifier for chaining)
func add_modifier(modifier: Dictionary) -> Dictionary:
	_modifiers.append(modifier)
	return modifier


## Remove a modifier by ID
func remove_modifier(modifier_id: String) -> bool:
	for i in range(_modifiers.size() - 1, -1, -1):
		if _modifiers[i].get("id", "") == modifier_id:
			_modifiers.remove_at(i)
			return true
	return false


## Clear all modifiers
func clear_modifiers() -> void:
	_modifiers.clear()


## Get all active modifiers
func get_all_modifiers() -> Array:
	return _modifiers


## Check if a turret matches a modifier's filter
func _modifier_matches_turret(modifier: Dictionary, turret_type: String) -> bool:
	var turret_def := TurretRegistry.get_type(turret_type)
	var filter: Dictionary = modifier.get("filter", {})

	# Empty filter matches all turrets
	if filter.is_empty():
		return true

	# Check turret_type filter
	if filter.has("turret_type") and not filter["turret_type"].is_empty():
		# "all" is a wildcard that matches any turret type
		if "all" in filter["turret_type"]:
			return true
		if turret_type in filter["turret_type"]:
			return true

	# Check damage_type filter (OR logic)
	if filter.has("damage_type") and not filter["damage_type"].is_empty():
		for dtype in filter["damage_type"]:
			if dtype in turret_def.get("damage_types", []):
				return true

	# Check attack_style filter (OR logic)
	if filter.has("attack_style") and not filter["attack_style"].is_empty():
		for astyle in filter["attack_style"]:
			if astyle in turret_def.get("attack_styles", []):
				return true

	# If filters were specified but none matched
	var has_filters := filter.has("turret_type") or filter.has("damage_type") or filter.has("attack_style")
	return not has_filters


## Get turret stats with all modifiers applied
func get_turret_stats(turret_type: String, difficulty_config: Dictionary) -> Dictionary:
	var base_stats := TurretRegistry.get_base_stats(turret_type)

	# Apply difficulty modifier to damage
	base_stats["damage"] = base_stats["damage"] * difficulty_config["turret_damage_mult"]

	# Apply special effects from items (dynamic modifiers)
	SpecialEffectService.apply_static_effects(turret_type, base_stats)

	# Collect applicable modifiers
	var add_mods: Dictionary = {} # stat -> total add value
	var mult_mods: Dictionary = {} # stat -> array of multipliers

	for modifier in _modifiers:
		if not _modifier_matches_turret(modifier, turret_type):
			continue

		var stat: String = modifier.get("stat", "")
		var operation: String = modifier.get("operation", "add")
		var value: float = modifier.get("value", 0.0)

		if operation == "add":
			add_mods[stat] = add_mods.get(stat, 0.0) + value
		elif operation == "multiply":
			if not mult_mods.has(stat):
				mult_mods[stat] = []
			mult_mods[stat].append(value)

	# Apply modifiers: first add, then multiply
	for stat in add_mods:
		base_stats[stat] = base_stats.get(stat, 0.0) + add_mods[stat]

	for stat in mult_mods:
		var combined_mult: float = 1.0
		for mult in mult_mods[stat]:
			combined_mult *= mult
		base_stats[stat] = base_stats.get(stat, 0.0) * combined_mult

	return base_stats


## Apply modifiers to a single stat value with FILTER VALIDATION
## Now supports entity_type filter for player vs turret distinction
func apply_to_stat(base_value: float, stat_name: String, entity_type: String = "player") -> float:
	var add_value: float = 0.0
	var mult_values: Array[float] = []

	for modifier in _modifiers:
		# Skip if stat name doesn't match
		if modifier.get("stat", "") != stat_name:
			continue

		# Validate filter (similar to _modifier_matches_turret logic)
		var filter: Dictionary = modifier.get("filter", {})
		if not filter.is_empty():
			# Check entity_type filter
			if filter.has("entity_type"):
				var allowed_types: Array = filter.get("entity_type", [])
				# Skip if entity_type is specified but doesn't include our type
				if not allowed_types.is_empty() and entity_type not in allowed_types:
					continue

		# Apply modifier
		var operation = modifier.get("operation", "add")
		var value = modifier.get("value", 0.0)

		if operation == "add":
			add_value += value
		elif operation == "multiply":
			mult_values.append(value)

	# Apply: base + adds, then multiply
	var result = base_value + add_value
	for mult in mult_values:
		result *= mult

	return result


## Get player speed with modifiers applied
func get_player_speed(base_speed: float) -> float:
	return apply_to_stat(base_speed, "player_speed", "player")


## Get player max health with modifiers applied
func get_player_max_health(base_health: float) -> float:
	return apply_to_stat(base_health, "player_max_health", "player")


## Get player weapon damage with modifiers applied
func get_player_weapon_damage(base_damage: float) -> float:
	return apply_to_stat(base_damage, "player_weapon_damage", "player")


## Get player luck with modifiers applied
func get_player_luck(base_luck: float) -> float:
	return apply_to_stat(base_luck, "player_luck", "player")


## Get reroll cost multiplier (1.0 = normal)
func get_reroll_cost_multiplier() -> float:
	return apply_to_stat(1.0, "reroll_cost", "player")
