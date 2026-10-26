class_name TurretStats
extends RefCounted

## Typed, read-only view of a turret's resolved stat dictionary (registry base stats after modifiers).
## The modifier pipeline addresses stats by name, so it keeps working on the dictionary; game code reads through
## this view so each default is declared once and distances arrive in metres instead of registry pixels.
const DEFAULT_RANGE: float = 240.0
const DEFAULT_FIRE_RATE: float = 1.2
const DEFAULT_ROTATION_RATE: float = 360.0
const DEFAULT_REHIT_DELAY: float = .5
const MIN_FIRE_RATE: float = .01
const MAX_SLOW_INTENSITY: float = .9

var values: Dictionary

func _init(resolved: Dictionary = {}) -> void:
	values = resolved

var damage: float:
	get: return maxf(float(values.get("damage", 0.0)), 0.0)
var fire_rate: float:
	get: return float(values.get("fire_rate", DEFAULT_FIRE_RATE))
## Seconds between shots; never divides by zero for a stalled fire rate.
var cooldown_seconds: float:
	get: return 1.0 / maxf(fire_rate, MIN_FIRE_RATE)
var range_metres: float:
	get: return _metres("range", DEFAULT_RANGE)
var aoe_radius_metres: float:
	get: return maxf(_metres("aoe_radius", 0.0), 0.0) * area_size
var area_size: float:
	get: return maxf(.1, float(values.get("area_size", 1.0)))
var projectile_speed_metres: float:
	get: return maxf(_metres("projectile_speed", 0.0), 0.0)
var knockback_metres: float:
	get: return maxf(_metres("knockback_force", 0.0), 0.0)
var chain_range_metres: float:
	get: return _metres("chain_range", 0.0)
var chain_count: int:
	get: return int(values.get("chain_count", 0))
var chain_decay: float:
	get: return float(values.get("chain_decay", 1.0))
var pierce: int:
	get: return maxi(int(values.get("pierce", 0)), 0)
var slow_intensity: float:
	get: return clampf(float(values.get("slow_intensity", 0.0)), 0.0, MAX_SLOW_INTENSITY)
var slow_duration: float:
	get: return maxf(float(values.get("slow_duration", 0.0)), 0.0)
## Seconds a hit staggers an enemy (Quake); 0 for turrets that do not.
var stagger_seconds: float:
	get: return maxf(float(values.get("stagger", 0.0)), 0.0)
## Melee bat spin speed in degrees per second.
var rotation_rate: float:
	get: return float(values.get("rotation_rate", DEFAULT_ROTATION_RATE))
var rehit_delay: float:
	get: return maxf(.05, float(values.get("rehit_delay", DEFAULT_REHIT_DELAY)))

func _metres(key: String, fallback_pixels: float) -> float:
	return float(values.get(key, fallback_pixels)) * WorldGeometry.METRES_PER_PIXEL
