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
	_apply_special_effects(base_stats, turret_type)

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


## Apply modifiers to a single stat value
func apply_to_stat(base_value: float, stat_name: String) -> float:
	var add_value: float = 0.0
	var mult_values: Array[float] = []

	for modifier in _modifiers:
		if modifier.get("stat", "") != stat_name:
			continue

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
	return apply_to_stat(base_speed, "player_speed")


## Get player max health with modifiers applied
func get_player_max_health(base_health: float) -> float:
	return apply_to_stat(base_health, "player_max_health")


## Get player weapon damage with modifiers applied
func get_player_weapon_damage(base_damage: float) -> float:
	return apply_to_stat(base_damage, "player_weapon_damage")


## Apply special effects from items (dynamic modifiers based on game state)
func _apply_special_effects(stats: Dictionary, turret_type: String) -> void:
	# Elemental Conduit: +15% damage per damage type diversity
	if ItemRegistry.has_special_effect("elemental_conduit") and Globals.item_counts.get("elemental_conduit", 0) > 0:
		var diversity = Globals.get_damage_type_diversity()
		var damage_bonus = diversity * 0.15
		stats["damage"] = stats.get("damage", 0.0) * (1.0 + damage_bonus)

	# Army Doctrine: +3% fire rate per turret beyond 5th (max +30%)
	if ItemRegistry.has_special_effect("army_doctrine") and Globals.item_counts.get("army_doctrine", 0) > 0:
		var total_turrets = Globals.get_total_turret_count()
		var bonus = min(max(0, total_turrets - 5) * 0.03, 0.30)
		stats["fire_rate"] = stats.get("fire_rate", 1.0) * (1.0 + bonus)

	# Elite Forces: +40% damage, +25% range if ≤5 turrets
	if ItemRegistry.has_special_effect("elite_forces") and Globals.item_counts.get("elite_forces", 0) > 0:
		if Globals.get_total_turret_count() <= 5:
			stats["damage"] = stats.get("damage", 0.0) * 1.40
			stats["range"] = stats.get("range", 0.0) * 1.25

	# Focused Investment: Boost most common turret type
	if ItemRegistry.has_special_effect("focused_investment") and Globals.item_counts.get("focused_investment", 0) > 0:
		var most_common = Globals.get_most_common_turret_type()
		if turret_type == most_common and not most_common.is_empty():
			stats["damage"] = stats.get("damage", 0.0) * 1.60
			stats["fire_rate"] = stats.get("fire_rate", 1.0) * 1.20
			stats["range"] = stats.get("range", 0.0) * 1.15
		elif not most_common.is_empty():
			# Penalty for non-dominant types
			stats["damage"] = stats.get("damage", 0.0) * 0.80

	# Diversity Matrix: +8% damage per turret type diversity
	if ItemRegistry.has_special_effect("diversity_matrix") and Globals.item_counts.get("diversity_matrix", 0) > 0:
		var diversity = Globals.get_turret_type_diversity()
		var stacks = Globals.item_counts.get("diversity_matrix", 0)
		var damage_bonus = diversity * 0.08 * stacks
		stats["damage"] = stats.get("damage", 0.0) * (1.0 + damage_bonus)

	# Standardized Parts: +5% fire rate per duplicate of same type
	if ItemRegistry.has_special_effect("standardized_parts") and Globals.item_counts.get("standardized_parts", 0) > 0:
		var count = Globals.turret_counts.get(turret_type, 0)
		if count > 1:
			var fire_rate_bonus = (count - 1) * 0.05
			stats["fire_rate"] = stats.get("fire_rate", 1.0) * (1.0 + fire_rate_bonus)

	# Cross-Training: +15% rotation speed for every 2 turret types
	if ItemRegistry.has_special_effect("cross_training") and Globals.item_counts.get("cross_training", 0) > 0:
		var diversity = Globals.get_turret_type_diversity()
		var rotation_bonus = floor(diversity / 2.0) * 0.15
		stats["rotation_speed"] = stats.get("rotation_speed", 180.0) * (1.0 + rotation_bonus)

	# Mono-Type Mastery: +100% damage, +50% fire rate if only one turret type
	if ItemRegistry.has_special_effect("mono_type_mastery") and Globals.item_counts.get("mono_type_mastery", 0) > 0:
		if Globals.get_turret_type_diversity() == 1:
			stats["damage"] = stats.get("damage", 0.0) * 2.0
			stats["fire_rate"] = stats.get("fire_rate", 1.0) * 1.50

	# Synergy Core: +12% damage per turret type, +25% if all 6
	if ItemRegistry.has_special_effect("synergy_core") and Globals.item_counts.get("synergy_core", 0) > 0:
		var diversity = Globals.get_turret_type_diversity()
		var damage_bonus = diversity * 0.12
		if diversity == 6:
			damage_bonus += 0.25 # Completion bonus
		stats["damage"] = stats.get("damage", 0.0) * (1.0 + damage_bonus)


## Get player luck with modifiers applied
func get_player_luck(base_luck: float) -> float:
	return apply_to_stat(base_luck, "player_luck")


## Get reroll cost multiplier (1.0 = normal)
func get_reroll_cost_multiplier() -> float:
	return apply_to_stat(1.0, "reroll_cost")
