class_name EnemyStats
extends RefCounted

## Typed, read-only view of an enemy's per-wave stats (`EnemyRegistry.get_stats_for_wave`).
## Distances and speeds arrive in metres; the registry keeps its pixel-era units.
var values: Dictionary

func _init(resolved: Dictionary = {}) -> void:
	values = resolved

static func for_wave(type_id: String, wave: int, difficulty_config: Dictionary) -> EnemyStats:
	return EnemyStats.new(EnemyRegistry.get_stats_for_wave(type_id, wave, difficulty_config))

var health: float:
	get: return float(values["health"])
var speed_metres: float:
	get: return float(values["speed"]) * WorldGeometry.METRES_PER_PIXEL
var contact_damage: float:
	get: return float(values["contact_damage"])
var mass: float:
	get: return float(values["mass"])
var scrap_value: int:
	get: return int(values["scrap_value"])
var explosion_radius_metres: float:
	get: return float(values.get("explosion_radius", 0.0)) * WorldGeometry.METRES_PER_PIXEL
var explosion_damage: float:
	get: return float(values.get("explosion_damage", 0.0))
