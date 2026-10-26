class_name TurretProgression
extends RefCounted

## Persistent identity-owned growth with ordered, free evolution milestones.
const EVOLUTION_LEVELS: Array[int] = [5, 10]

var level: int = 1
var total_xp: int = 0
var xp: int = 0
var pending_evolutions: Array[int] = []
var evolution_form: String = ""
var evolution_stage: int = 0

static func cost_to_next(current_level: int) -> int:
	var step := maxi(0, current_level - 1)
	# Integer tenths avoid floating-point ceil errors at exact thresholds.
	return 20 + 4 * step + ceili(3.0 * step * step / 10.0)

## Five-level blocks: damage, speed, reach, then a milestone burst; next block starts with damage.
func stat_multipliers() -> Dictionary:
	var bursts := floori(float(level) / 5.0)
	return {
		"damage": 1.0 + .05 * (floori(float(level + 3) / 5.0) + floori(float(level - 1) / 5.0)) + .05 * bursts,
		"speed": 1.0 + .06 * floori(float(level + 2) / 5.0) + .04 * bursts,
		"range": 1.0 + .10 * floori(float(level + 1) / 5.0) + .03 * bursts,
	}

func damage_multiplier() -> float:
	return float(stat_multipliers().damage)

func apply_stats(stats: Dictionary) -> void:
	var multipliers := stat_multipliers()
	for key: String in ["damage", "range", "fire_rate", "rotation_rate"]:
		if stats.has(key):
			stats[key] = float(stats[key]) * float(multipliers["speed" if key in ["fire_rate", "rotation_rate"] else key])

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

## Level 5 offers the base turret's single upgrade; level 10 offers its two finals.
func evolution_options(base_type: String) -> Array[String]:
	if pending_evolutions.is_empty() or evolution_stage >= EVOLUTION_LEVELS.size():
		return []
	if pending_evolutions[0] != EVOLUTION_LEVELS[evolution_stage] or level < pending_evolutions[0]:
		return []
	return TurretEvolution.options(base_type, evolution_stage)

func evolve(base_type: String, form: String) -> bool:
	if form not in evolution_options(base_type):
		return false
	evolution_form = form
	evolution_stage += 1
	pending_evolutions.pop_front()
	return true

func snapshot() -> Dictionary:
	return {"level": level, "total_xp": total_xp, "xp": xp,
		"multipliers": stat_multipliers(), "next_cost": cost_to_next(level), "damage_multiplier": damage_multiplier(),
		"pending_evolutions": pending_evolutions.duplicate(),
		"evolution_form": evolution_form, "evolution_stage": evolution_stage}
