class_name RunTelemetry
extends RefCounted

## Per-wave counters used to compare balance and behaviour across flag sets and builds.
## Pure data: the arena records into it, tools print `to_dict()`. It never affects gameplay.
const SPEND_CATEGORIES: Array[String] = ["turret", "item", "reroll", "repair"]

var waves: Array[Dictionary] = []
var flags: Dictionary = {}
var _current: Dictionary = {}

func begin_run() -> void:
	waves.clear()
	_current = {}
	flags = FeatureFlagService.get_snapshot()

func begin_wave(wave: int) -> void:
	_current = {"wave": wave, "kills": 0, "turret_moves": 0, "scrap_earned": 0,
		"scrap_spent": {}, "kills_by_turret": {}, "hull_lost": 0.0}
	for category in SPEND_CATEGORIES:
		_current["scrap_spent"][category] = 0
	waves.append(_current)

func _ensure_wave() -> void:
	if _current.is_empty():
		begin_wave(0)

## `turret_label` is "<id>:<type>"; empty means the kill had no turret source (player gun, blast).
func record_kill(turret_label: String = "") -> void:
	_ensure_wave()
	_current["kills"] = int(_current["kills"]) + 1
	if not turret_label.is_empty():
		var by_turret: Dictionary = _current["kills_by_turret"]
		by_turret[turret_label] = int(by_turret.get(turret_label, 0)) + 1

func record_turret_move() -> void:
	_ensure_wave()
	_current["turret_moves"] = int(_current["turret_moves"]) + 1

func record_scrap_earned(amount: int) -> void:
	_ensure_wave()
	_current["scrap_earned"] = int(_current["scrap_earned"]) + amount

func record_spend(category: String, amount: int) -> void:
	_ensure_wave()
	var spent: Dictionary = _current["scrap_spent"]
	spent[category] = int(spent.get(category, 0)) + amount

func record_hull_lost(amount: float) -> void:
	_ensure_wave()
	_current["hull_lost"] = float(_current["hull_lost"]) + amount

func total(field: String) -> int:
	var sum := 0
	for entry in waves:
		sum += int(entry.get(field, 0))
	return sum

func total_spent(category: String) -> int:
	var sum := 0
	for entry in waves:
		sum += int(entry["scrap_spent"].get(category, 0))
	return sum

func to_dict() -> Dictionary:
	return {"flags": flags, "waves": waves.duplicate(true),
		"totals": {"kills": total("kills"), "turret_moves": total("turret_moves"), "scrap_earned": total("scrap_earned"),
			"scrap_spent": {"turret": total_spent("turret"), "item": total_spent("item"),
				"reroll": total_spent("reroll"), "repair": total_spent("repair")}}}
