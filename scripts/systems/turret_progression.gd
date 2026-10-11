class_name TurretProgression
extends RefCounted

## Persistent identity-owned growth. Forms will consume pending milestones in Phase 2.
const EVOLUTION_LEVELS: Array[int] = [5, 10, 15]
const DAMAGE_PER_LEVEL: float = .03

var level: int = 1
var total_xp: int = 0
var xp: int = 0
var pending_evolutions: Array[int] = []

static func cost_to_next(current_level: int) -> int:
	var step := maxi(0, current_level - 1)
	# Integer tenths avoid floating-point ceil errors at exact thresholds.
	return 14 + 2 * step + ceili(3.0 * step * step / 10.0)

func damage_multiplier() -> float:
	var ordinary := level - 1
	for milestone in EVOLUTION_LEVELS:
		if level >= milestone:
			ordinary -= 1
	return 1.0 + DAMAGE_PER_LEVEL * ordinary

func award(amount: int) -> Dictionary:
	var before := snapshot()
	amount = maxi(0, amount)
	total_xp += amount
	xp += amount
	while xp >= cost_to_next(level):
		xp -= cost_to_next(level)
		level += 1
		if level in EVOLUTION_LEVELS:
			pending_evolutions.append(level)
	return {"xp_awarded": amount, "before": before, "after": snapshot()}

func snapshot() -> Dictionary:
	return {"level": level, "total_xp": total_xp, "xp": xp,
		"next_cost": cost_to_next(level), "damage_multiplier": damage_multiplier(),
		"pending_evolutions": pending_evolutions.duplicate()}
