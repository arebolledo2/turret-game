class_name TurretStatsService
extends Node

## Turret Stats Service
## Manages turret counts, types, and stat calculations with modifiers

# Turret tracking
var turret_counts: Dictionary = {}
var selected_turret_type: String = ""

# Modifier system reference (injected)
var _modifier_service: ModifierService = null

func _get_modifier_service() -> ModifierService:
	if _modifier_service == null:
		_modifier_service = get_node("/root/ModifierService")
	return _modifier_service


func reset_state() -> void:
	turret_counts.clear()
	selected_turret_type = ""


## Get turret stats with all modifiers applied
func get_turret_stats(turret_type: String, difficulty_turret_damage_mult: float) -> Dictionary:
	if not TurretRegistry.TYPES.has(turret_type):
		return {}

	var base_stats: Dictionary = TurretRegistry.get_base_stats(turret_type)
	base_stats["damage"] = base_stats["damage"] * difficulty_turret_damage_mult

	var add_mods: Dictionary = {}
	var mult_mods: Dictionary = {}

	for modifier in _get_modifier_service().active_modifiers:
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

	for stat in add_mods:
		base_stats[stat] = base_stats.get(stat, 0.0) + add_mods[stat]

	for stat in mult_mods:
		var combined_mult: float = 1.0
		for mult in mult_mods[stat]:
			combined_mult *= mult
		base_stats[stat] = base_stats.get(stat, 0.0) * combined_mult

	return base_stats


func _modifier_matches_turret(modifier: Dictionary, turret_type: String) -> bool:
	if not TurretRegistry.TYPES.has(turret_type):
		return false

	var turret_def: Dictionary = TurretRegistry.get_type(turret_type)
	var filter: Dictionary = modifier.get("filter", {})

	if filter.is_empty():
		return true

	if filter.has("turret_type") and not filter["turret_type"].is_empty():
		if turret_type in filter["turret_type"]:
			return true

	if filter.has("damage_type") and not filter["damage_type"].is_empty():
		for dtype in filter["damage_type"]:
			if dtype in turret_def.get("damage_types", []):
				return true

	if filter.has("attack_style") and not filter["attack_style"].is_empty():
		for astyle in filter["attack_style"]:
			if astyle in turret_def.get("attack_styles", []):
				return true

	var has_filters := filter.has("turret_type") or filter.has("damage_type") or filter.has("attack_style")
	return not has_filters


## Get turret color
func get_turret_color(turret_type: String) -> Color:
	return TurretRegistry.get_color(turret_type)


## Check if turret has specific attack style
func turret_has_attack_style(turret_type: String, style: GameEnums.AttackStyle) -> bool:
	return TurretRegistry.has_attack_style(turret_type, style)


## Check if turret has specific damage type
func turret_has_damage_type(turret_type: String, dtype: GameEnums.DamageType) -> bool:
	return TurretRegistry.has_damage_type(turret_type, dtype)


## Get total number of turrets owned
func get_total_turret_count() -> int:
	var total := 0
	for count in turret_counts.values():
		total += count
	return total


## Get number of different turret types owned (e.g., 3 if you own Normal, Fire, and Sniper)
func get_turret_type_diversity() -> int:
	var count := 0
	for type_count in turret_counts.values():
		if type_count > 0:
			count += 1
	return count


## Get number of different damage types represented in owned turrets
func get_damage_type_diversity() -> int:
	var damage_types_seen: Array = []
	for turret_type in turret_counts.keys():
		if turret_counts[turret_type] > 0:
			var turret_def = TurretRegistry.get_type(turret_type)
			var dtypes = turret_def.get("damage_types", [])
			for dtype in dtypes:
				if dtype not in damage_types_seen:
					damage_types_seen.append(dtype)
	return damage_types_seen.size()


## Get the most common turret type (returns empty string if no turrets)
func get_most_common_turret_type() -> String:
	var max_count := 0
	var most_common := ""
	for turret_type in turret_counts.keys():
		if turret_counts[turret_type] > max_count:
			max_count = turret_counts[turret_type]
			most_common = turret_type
	return most_common


## Get turret minimum distance (modified by Personal Space item)
func get_turret_min_distance(item_counts: Dictionary) -> float:
	# Personal Space increases minimum distance to 200px
	if ItemRegistry.has_special_effect("personal_space") and item_counts.get("personal_space", 0) > 0:
		return 200.0
	return GameConstants.TURRET_MIN_DISTANCE


## Get turret purchase penalty (base 0.25, can be reduced/increased by items)
func get_turret_purchase_penalty() -> float:
	var penalty = GameConstants.TURRET_PURCHASE_PENALTY
	# Apply reductions (e.g., Compact Design, Mass Production)
	penalty = _get_modifier_service().apply_modifiers_to_stat(penalty, "turret_penalty_reduction")
	# Apply increases (e.g., Elite Forces, Diversity Matrix)
	penalty = _get_modifier_service().apply_modifiers_to_stat(penalty, "turret_penalty_increase")
	return penalty

