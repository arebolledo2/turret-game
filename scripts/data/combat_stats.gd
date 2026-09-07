class_name CombatStats
extends RefCounted

## Typed frequently-used combat values; optional attack-specific data stays in the snapshot.
var damage: float
var fire_rate: float
var attack_range: float
var targeting: String
var _has_damage: bool
var _source: Dictionary

func _init(data: Dictionary) -> void:
	_source = data.duplicate(true)
	_has_damage = data.has("damage")
	damage = float(data.get("damage", 15.0))
	fire_rate = float(data.get("fire_rate", 2.0))
	attack_range = float(data.get("range", 250.0))
	targeting = str(data.get("targeting", "nearest"))

func damage_or(fallback: float) -> float:
	return damage if _has_damage else fallback

func to_dictionary() -> Dictionary:
	return _source.duplicate(true)
