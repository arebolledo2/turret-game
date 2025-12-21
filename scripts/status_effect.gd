extends RefCounted
class_name StatusEffect

## Represents an active status effect on an enemy.
## Tracks DoT damage, duration, and tick timing.

var damage_type: GameEnums.DamageType
var dot_damage: float
var dot_duration: float
var dot_tick_rate: float
var time_remaining: float
var tick_timer: float
var slow_intensity: float = 0.0  # 0.0 to 1.0 (0.3 = 30% slower = 0.7x speed)

func _init(dtype: GameEnums.DamageType, damage: float, duration: float, tick_rate: float = 1.0, slow_amount: float = 0.0) -> void:
	damage_type = dtype
	dot_damage = damage
	dot_duration = duration
	dot_tick_rate = tick_rate
	time_remaining = duration
	tick_timer = 0.0
	slow_intensity = slow_amount

## Returns true if this effect is stronger than another of the same damage type
func is_stronger_than(other: StatusEffect) -> bool:
	if other == null:
		return true
	# For slow effects, compare slow_intensity instead of dot_damage
	if slow_intensity > 0 and other.slow_intensity > 0:
		return slow_intensity > other.slow_intensity
	return dot_damage > other.dot_damage

## Refresh duration (optionally upgrade damage if new effect is stronger)
func refresh(new_damage: float, new_duration: float, new_slow: float = 0.0) -> void:
	if new_damage > dot_damage:
		dot_damage = new_damage
	if new_slow > slow_intensity:
		slow_intensity = new_slow
	time_remaining = new_duration
	dot_duration = new_duration

## Process tick and return damage dealt this frame (0 if no tick occurred)
func process(delta: float) -> float:
	if time_remaining <= 0:
		return 0.0
	
	time_remaining -= delta
	tick_timer += delta
	
	var tick_interval: float = 1.0 / dot_tick_rate
	if tick_timer >= tick_interval:
		tick_timer -= tick_interval
		return dot_damage
	
	return 0.0

## Check if effect has expired
func is_expired() -> bool:
	return time_remaining <= 0

## Get damage type name for display
func get_type_name() -> String:
	match damage_type:
		GameEnums.DamageType.FIRE:
			return "Burning"
		GameEnums.DamageType.ELECTRIC:
			return "Shocked"
		GameEnums.DamageType.PLASMA:
			return "Irradiated"
		_:
			return "Bleeding"
