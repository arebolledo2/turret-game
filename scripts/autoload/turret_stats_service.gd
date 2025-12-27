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
## Delegates to ModifierService for consistent stat calculation
func get_turret_stats(turret_type: String, difficulty_turret_damage_mult: float) -> Dictionary:
	if not TurretRegistry.TYPES.has(turret_type):
		return {}

	# Build a minimal difficulty config with the damage mult
	var difficulty_config := {"turret_damage_mult": difficulty_turret_damage_mult}
	return _get_modifier_service().get_turret_stats(turret_type, difficulty_config)


## Get turret color
func get_turret_color(turret_type: String) -> Color:
	return TurretRegistry.get_color(turret_type)


## Check if turret has specific attack style
func turret_has_attack_style(turret_type: String, style: GameEnums.AttackStyle) -> bool:
	return TurretRegistry.has_attack_style(turret_type, style)


## Check if turret has specific damage type
func turret_has_damage_type(turret_type: String, dtype: GameEnums.DamageType) -> bool:
	return TurretRegistry.has_damage_type(turret_type, dtype)


## Get turret crit chance with modifiers applied
func get_turret_crit_chance() -> float:
	return _get_modifier_service().apply_modifiers_to_stat(GameConstants.TURRET_BASE_CRIT_CHANCE, "turret_crit_chance")


## Get turret crit multiplier with modifiers applied
func get_turret_crit_multiplier() -> float:
	return _get_modifier_service().apply_modifiers_to_stat(GameConstants.TURRET_BASE_CRIT_MULTIPLIER, "turret_crit_multiplier")


## Roll for critical hit (returns true if crit)
func roll_turret_crit() -> bool:
	return randf() < get_turret_crit_chance()


## Calculate crit damage
func calculate_turret_crit_damage(base_damage: float) -> float:
	return base_damage * get_turret_crit_multiplier()


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

