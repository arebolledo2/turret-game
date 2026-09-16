extends Node

## Special Effect Service
## Centralizes complex item logic and proximity-based turret effects

func apply_static_effects(turret_type: String, stats: Dictionary) -> void:
	"""Apply effects that depend on global game state (e.g., owned items, total turrets)."""

	# Elemental Conduit: +15% damage per damage type diversity
	if ItemRegistry.has_special_effect("elemental_conduit") and ItemTrackingService.item_counts.get("elemental_conduit", 0) > 0:
		var diversity = ItemTrackingService.get_damage_type_diversity()
		var damage_bonus = diversity * 0.15
		stats["damage"] = stats.get("damage", 0.0) * (1.0 + damage_bonus)

	# Army Doctrine: +3% fire rate per turret beyond 5th (max +30%)
	if ItemRegistry.has_special_effect("army_doctrine") and ItemTrackingService.item_counts.get("army_doctrine", 0) > 0:
		var total_turrets = TurretStatsService.get_total_turret_count()
		var bonus = min(max(0, total_turrets - 5) * 0.03, 0.30)
		stats["fire_rate"] = stats.get("fire_rate", 1.0) * (1.0 + bonus)

	# Elite Forces: +40% damage, +25% range if ≤5 turrets
	if ItemRegistry.has_special_effect("elite_forces") and ItemTrackingService.item_counts.get("elite_forces", 0) > 0:
		if TurretStatsService.get_total_turret_count() <= 5:
			stats["damage"] = stats.get("damage", 0.0) * 1.40
			stats["range"] = stats.get("range", 0.0) * 1.25

	# Focused Investment: Boost most common turret type
	if ItemRegistry.has_special_effect("focused_investment") and ItemTrackingService.item_counts.get("focused_investment", 0) > 0:
		var most_common = TurretStatsService.get_most_common_turret_type()
		if turret_type == most_common and not most_common.is_empty():
			stats["damage"] = stats.get("damage", 0.0) * 1.60
			stats["fire_rate"] = stats.get("fire_rate", 1.0) * 1.20
			stats["range"] = stats.get("range", 0.0) * 1.15
		elif not most_common.is_empty():
			# Penalty for non-dominant types
			stats["damage"] = stats.get("damage", 0.0) * 0.80

	# Diversity Matrix: +8% damage per turret type diversity
	if ItemRegistry.has_special_effect("diversity_matrix") and ItemTrackingService.item_counts.get("diversity_matrix", 0) > 0:
		var diversity = TurretStatsService.get_turret_type_diversity()
		var stacks = ItemTrackingService.item_counts.get("diversity_matrix", 0)
		var damage_bonus = diversity * 0.08 * stacks
		stats["damage"] = stats.get("damage", 0.0) * (1.0 + damage_bonus)

	# Standardized Parts: +5% fire rate per duplicate of same type
	if ItemRegistry.has_special_effect("standardized_parts") and ItemTrackingService.item_counts.get("standardized_parts", 0) > 0:
		var count = TurretStatsService.turret_counts.get(turret_type, 0)
		if count > 1:
			var fire_rate_bonus = (count - 1) * 0.05
			stats["fire_rate"] = stats.get("fire_rate", 1.0) * (1.0 + fire_rate_bonus)

	# Cross-Training: +15% rotation speed for every 2 turret types
	if ItemRegistry.has_special_effect("cross_training") and ItemTrackingService.item_counts.get("cross_training", 0) > 0:
		var diversity = TurretStatsService.get_turret_type_diversity()
		var rotation_bonus = floor(diversity / 2.0) * 0.15
		stats["rotation_speed"] = stats.get("rotation_speed", 180.0) * (1.0 + rotation_bonus)

	# Mono-Type Mastery: +100% damage, +50% fire rate if only one turret type
	if ItemRegistry.has_special_effect("mono_type_mastery") and ItemTrackingService.item_counts.get("mono_type_mastery", 0) > 0:
		if TurretStatsService.get_turret_type_diversity() == 1:
			stats["damage"] = stats.get("damage", 0.0) * 2.0
			stats["fire_rate"] = stats.get("fire_rate", 1.0) * 1.50

	# Synergy Core: +12% damage per turret type, +25% if all 6
	if ItemRegistry.has_special_effect("synergy_core") and ItemTrackingService.item_counts.get("synergy_core", 0) > 0:
		var diversity = TurretStatsService.get_turret_type_diversity()
		var damage_bonus = diversity * 0.12
		if diversity == 6:
			damage_bonus += 0.25 # Completion bonus
		stats["damage"] = stats.get("damage", 0.0) * (1.0 + damage_bonus)


func get_turret_min_distance(item_counts: Dictionary) -> float:
	"""Apply modifications to turret placement rules."""
	# Personal Space increases minimum distance to 200px
	if ItemRegistry.has_special_effect("personal_space") and item_counts.get("personal_space", 0) > 0:
		return GameConstants.PERSONAL_SPACE_MIN_DISTANCE
	return GameConstants.TURRET_MIN_DISTANCE
