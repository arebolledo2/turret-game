extends Node

## Special Effect Service
## Centralizes complex item logic and proximity-based turret effects

func apply_static_effects(turret_type: String, stats: Dictionary) -> void:
	"""Apply effects that depend on global game state (e.g., owned items, total turrets)."""

	# Combined Arms: +12% damage per distinct assigned attack family (max +48%)
	if ItemRegistry.has_special_effect("elemental_conduit") and ItemTrackingService.item_counts.get("elemental_conduit", 0) > 0:
		var diversity: int = TurretStatsService.get_family_diversity()
		var damage_bonus: float = diversity * 0.12
		stats["damage"] = stats.get("damage", 0.0) * (1.0 + damage_bonus)

	# Army Doctrine: +3% attack speed per attacking turret beyond the 3rd (max +30%); no-attack turrets do not count
	if ItemRegistry.has_special_effect("army_doctrine") and ItemTrackingService.item_counts.get("army_doctrine", 0) > 0:
		var total_turrets: int = TurretStatsService.get_attack_turret_count()
		var bonus: float = min(max(0, total_turrets - 3) * 0.03, 0.30)
		stats["attack_speed"] = stats.get("attack_speed", 1.0) * (1.0 + bonus)

	# Elite Forces: +40% damage, +25% range if ≤5 turrets
	if ItemRegistry.has_special_effect("elite_forces") and ItemTrackingService.item_counts.get("elite_forces", 0) > 0:
		if TurretStatsService.get_total_turret_count() <= 5:
			stats["damage"] = stats.get("damage", 0.0) * 1.40
			stats["range"] = stats.get("range", 0.0) * 1.25

	# Focused Arsenal: +50% damage, +25% attack speed if all attacking turrets share an attack family (no-attack turrets are ignored)
	if ItemRegistry.has_special_effect("mono_type_mastery") and ItemTrackingService.item_counts.get("mono_type_mastery", 0) > 0:
		if not TurretStatsService.shared_attack_families().is_empty():
			stats["damage"] = stats.get("damage", 0.0) * 1.5
			stats["attack_speed"] = stats.get("attack_speed", 1.0) * 1.25


func get_turret_min_distance(_item_counts: Dictionary) -> float:
	"""Apply modifications to turret placement rules."""
	return GameConstants.TURRET_MIN_DISTANCE
