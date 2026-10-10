class_name ModifierSystem
extends RefCounted

## Manages active modifiers from items and applies them to stats
## Uses Path of Exile-style modifier stacking:
##   - "add": Flat value added to base (stacks additively)
##   - "increase": Percentage modifier (all sources sum, then multiply base)
##   - "more": Multiplicative modifier (each source multiplies independently)
##   - "multiply": Alias for "more" used by the tech registry
##
## Formula: final = (base + flat_total) × (1 + increase_total) × more1 × more2 × ...
##
## Example:
##   Base 10, +5 flat, +50% increase, +50% increase, 1.2 more, 1.3 more
##   = (10 + 5) × (1 + 0.5 + 0.5) × 1.2 × 1.3
##   = 15 × 2.0 × 1.2 × 1.3 = 46.8
##
## Modifier format:
## {
##   "id": String,           # Unique identifier
##   "stat": String,         # Which stat to modify (damage, fire_rate, etc.)
##   "operation": String,    # "add", "increase", "more", or "multiply"
##   "value": float,         # The modification value
##   "filter": {             # Optional filters (OR logic within each array)
##     "damage_type": [],    # Array of DamageType enums
##     "attack_style": [],   # Array of AttackStyle enums
##     "turret_type": [],    # Array of turret type IDs
##   }
## }

var _modifiers: Array[StatModifier] = []


## Add a modifier (returns the modifier for chaining)
func add_modifier(modifier: Dictionary) -> Dictionary:
	_modifiers.append(StatModifier.new(modifier))
	return modifier.duplicate(true)


## Remove a modifier by ID
func remove_modifier(modifier_id: String) -> bool:
	for i in range(_modifiers.size() - 1, -1, -1):
		if _modifiers[i].id == modifier_id:
			_modifiers.remove_at(i)
			return true
	return false


## Clear all modifiers
func clear_modifiers() -> void:
	_modifiers.clear()


## Get all active modifiers
func get_all_modifiers() -> Array:
	var snapshot: Array = []
	for modifier in _modifiers:
		snapshot.append(modifier.to_dictionary())
	return snapshot


## Check if a turret matches a modifier's filter
func _modifier_matches_turret(modifier: StatModifier, turret_type: String) -> bool:
	var turret_def := TurretRegistry.get_type(turret_type)
	var filter: Dictionary = modifier.filter

	for capability: String in filter.get("requires", []):
		if not TurretRegistry.has_capability(turret_type, capability):
			return false
	if filter.has("attack_family"):
		for family: String in filter["attack_family"]:
			if family in TurretRegistry.get_attack_families(turret_type):
				return true
		return false

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

	# Check family filter (OR logic): ion, plasma, electric, melee
	if filter.has("family") and not filter["family"].is_empty():
		if TurretRegistry.get_family(turret_type) in filter["family"]:
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
	var has_filters := filter.has("turret_type") or filter.has("damage_type") or filter.has("attack_style") or filter.has("family")
	return not has_filters


## Get turret stats with all modifiers applied
## Uses PoE formula: (base + flat) × (1 + increases) × more1 × more2 × ...
func get_turret_stats(turret_type: String, difficulty_config: Dictionary, static_effects: Callable = Callable()) -> Dictionary:
	var base_stats := TurretRegistry.get_base_stats(turret_type)
	base_stats["area_size"] = 1.0
	base_stats["attack_speed"] = 1.0

	# Apply difficulty modifier to damage
	base_stats["damage"] = base_stats["damage"] * difficulty_config["turret_damage_mult"]

	# Apply special effects from items (dynamic modifiers)
	if static_effects.is_valid():
		static_effects.call(turret_type, base_stats)

	# Collect applicable modifiers by type
	var flat_mods: Dictionary = {}      # stat -> total flat value
	var increase_mods: Dictionary = {}  # stat -> total increase % (summed)
	var more_mods: Dictionary = {}      # stat -> array of more multipliers

	for modifier in _modifiers:
		if not _modifier_matches_turret(modifier, turret_type):
			continue

		var stat: String = modifier.stat
		var operation: String = modifier.operation
		var value: float = modifier.value

		match operation:
			"add":
				flat_mods[stat] = flat_mods.get(stat, 0.0) + value
			"increase":
				increase_mods[stat] = increase_mods.get(stat, 0.0) + value
			"more":
				if not more_mods.has(stat):
					more_mods[stat] = []
				more_mods[stat].append(value)

	# Apply PoE formula: (base + flat) × (1 + increases) × more1 × more2 × ...
	# Get all stats that have any modifier
	var all_stats: Dictionary = {}
	for stat in flat_mods:
		all_stats[stat] = true
	for stat in increase_mods:
		all_stats[stat] = true
	for stat in more_mods:
		all_stats[stat] = true

	for stat in all_stats:
		var base_value: float = base_stats.get(stat, 0.0)

		# Step 1: Add flat modifiers
		base_value += flat_mods.get(stat, 0.0)

		# Step 2: Apply summed increases as single multiplier
		var increase_total: float = increase_mods.get(stat, 0.0)
		base_value *= (1.0 + increase_total)

		# Step 3: Apply each "more" multiplier independently
		if more_mods.has(stat):
			for more_mult in more_mods[stat]:
				base_value *= more_mult

		base_stats[stat] = base_value

	var cadence := maxf(.05, float(base_stats["attack_speed"]))
	for key: String in ["fire_rate", "rotation_rate"]:
		if base_stats.has(key):
			base_stats[key] *= cadence
	return base_stats


## Apply modifiers to a single stat value with FILTER VALIDATION
## Uses PoE formula: (base + flat) × (1 + increases) × more1 × more2 × ...
## Supports entity_type filter for player vs turret distinction
func apply_to_stat(base_value: float, stat_name: String, entity_type: String = "player") -> float:
	var flat_value: float = 0.0
	var increase_value: float = 0.0
	var more_values: Array[float] = []

	for modifier in _modifiers:
		# Skip if stat name doesn't match
		if modifier.stat != stat_name:
			continue

		# Validate filter (similar to _modifier_matches_turret logic)
		var filter: Dictionary = modifier.filter
		if not filter.is_empty():
			# Check entity_type filter
			if filter.has("entity_type"):
				var allowed_types: Array = filter.get("entity_type", [])
				# Skip if entity_type is specified but doesn't include our type
				if not allowed_types.is_empty() and entity_type not in allowed_types:
					continue

		# Collect modifier by operation type
		var operation: String = modifier.operation
		var value: float = modifier.value

		match operation:
			"add":
				flat_value += value
			"increase":
				increase_value += value
			"more":
				more_values.append(value)

	# Apply PoE formula: (base + flat) × (1 + increases) × more1 × more2 × ...
	var result: float = base_value + flat_value
	result *= (1.0 + increase_value)
	for more_mult in more_values:
		result *= more_mult

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
