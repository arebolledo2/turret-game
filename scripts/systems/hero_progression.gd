class_name HeroProgression
extends RefCounted

## The hero's run-long growth: XP from collected scrap, levels that raise health, damage and attack speed, and the same
## free evolution milestones as a turret (one upgrade at 5, a choice of two finals at 10). Shares the turret XP curve.
const EVOLUTION_LEVELS: Array[int] = [5, 10]

var level: int = 1
var total_xp: int = 0
var xp: int = 0
var pending_evolutions: Array[int] = []
var evolution_form: String = ""
var evolution_stage: int = 0

static func cost_to_next(current_level: int) -> int:
	return TurretProgression.cost_to_next(current_level)

## Per-level growth plus the bonuses of the form taken so far. Level steps are linear; milestone bursts come every 5 levels.
func stat_multipliers() -> Dictionary:
	var steps := level - 1
	var bursts := floori(float(level) / 5.0)
	var result := {
		"health": 1.0 + GameConstants.HERO_HEALTH_PER_LEVEL * steps + GameConstants.HERO_HEALTH_PER_BURST * bursts,
		"damage": 1.0 + GameConstants.HERO_DAMAGE_PER_LEVEL * steps + GameConstants.HERO_DAMAGE_PER_BURST * bursts,
		"fire_rate": 1.0 + GameConstants.HERO_FIRE_RATE_PER_LEVEL * steps + GameConstants.HERO_FIRE_RATE_PER_BURST * bursts,
		"range": 1.0,
	}
	if evolution_form != "":
		var bonus: Dictionary = HeroForms.row(evolution_form).get("stats", {})
		for key: String in bonus:
			result[key] = float(result[key]) * float(bonus[key])
	return result

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
	return {"xp_awarded": amount, "before": before, "after": snapshot(), "leveled": level > int(before.level)}

## Level 5 offers the single upgrade; level 10 offers the two finals.
func evolution_options() -> Array[String]:
	if pending_evolutions.is_empty() or evolution_stage >= EVOLUTION_LEVELS.size():
		return []
	if pending_evolutions[0] != EVOLUTION_LEVELS[evolution_stage] or level < pending_evolutions[0]:
		return []
	return HeroForms.options(evolution_stage)

func evolve(form: String) -> bool:
	if form not in evolution_options():
		return false
	evolution_form = form
	evolution_stage += 1
	pending_evolutions.pop_front()
	return true

func snapshot() -> Dictionary:
	return {"level": level, "total_xp": total_xp, "xp": xp, "multipliers": stat_multipliers(),
		"next_cost": cost_to_next(level), "pending_evolutions": pending_evolutions.duplicate(),
		"evolution_form": evolution_form, "evolution_stage": evolution_stage}
