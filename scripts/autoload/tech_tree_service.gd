extends Node

## TechTreeService manages research points and tech tree unlocks.
##
## This service tracks:
## - Total research points accumulated across waves
## - Which techs have been unlocked
## - How many times repeatable techs have been unlocked
##
## Research points are gained by converting uncollected scrap at wave end.
## During the shop phase, players can spend research points to unlock techs.

# State tracking
var total_research_points: int = 0
var unlocked_tech_ids: Array[String] = []
var tech_unlock_counts: Dictionary = {}  # tech_id -> unlock_count for repeatable techs


func _ready() -> void:
	reset_state()


## Reset all tech tree state (called on game start)
func reset_state() -> void:
	total_research_points = 0
	unlocked_tech_ids.clear()
	tech_unlock_counts.clear()
	DebugService.log(DebugService.SYSTEMS, "Tech tree state reset")


## Add research points (typically from scrap conversion at wave end)
func add_research_points(amount: int) -> void:
	if amount <= 0:
		return

	total_research_points += amount
	Events.research_points_changed.emit(total_research_points)
	DebugService.log(DebugService.SYSTEMS, "Added ", amount, " research points (total: ", total_research_points, ")")


## Check if a tech can be unlocked
## Returns false if:
## - Tech doesn't exist
## - Already unlocked (non-repeatable)
## - Max unlock count reached
## - Prerequisites not met
## - Not enough research points
func can_unlock_tech(tech_id: String) -> bool:
	# Will be implemented in Phase 3 when TechRegistry exists
	# For now, just check basic affordability
	var tech_def = _get_tech_definition(tech_id)
	if not tech_def:
		return false

	# Check if already unlocked (non-repeatable)
	if is_tech_unlocked(tech_id) and not tech_def.get("repeatable", false):
		return false

	# Check max unlocks cap
	var max_unlocks: int = tech_def.get("max_unlocks", 0)
	if max_unlocks > 0:
		var current_count: int = get_tech_unlock_count(tech_id)
		if current_count >= max_unlocks:
			return false

	# Check all prerequisites unlocked
	var prerequisites: Array = tech_def.get("prerequisites", [])
	for prereq_id in prerequisites:
		if not is_tech_unlocked(prereq_id):
			return false

	# Check affordability
	var cost: int = tech_def.get("cost", 0)
	return total_research_points >= cost


## Unlock a tech and apply its effects
## Returns true if successful, false otherwise
func unlock_tech(tech_id: String) -> bool:
	if not can_unlock_tech(tech_id):
		Events.tech_unlock_failed.emit(tech_id, "Cannot unlock tech")
		return false

	var tech_def = _get_tech_definition(tech_id)
	if not tech_def:
		Events.tech_unlock_failed.emit(tech_id, "Tech definition not found")
		return false

	var cost: int = tech_def.get("cost", 0)

	# Deduct points
	total_research_points -= cost

	# Track unlock
	if tech_id not in unlocked_tech_ids:
		unlocked_tech_ids.append(tech_id)

	var current_count: int = tech_unlock_counts.get(tech_id, 0)
	tech_unlock_counts[tech_id] = current_count + 1

	# Apply effects
	_apply_tech_effects(tech_id, tech_def)

	# Emit signals
	Events.tech_unlocked.emit(tech_id)
	Events.research_points_changed.emit(total_research_points)

	DebugService.log(DebugService.SYSTEMS, "Unlocked tech '", tech_id, "' for ", cost, " research (remaining: ", total_research_points, ")")

	return true


## Check if a tech is unlocked
func is_tech_unlocked(tech_id: String) -> bool:
	return tech_id in unlocked_tech_ids


## Get the number of times a tech has been unlocked (for repeatable techs)
func get_tech_unlock_count(tech_id: String) -> int:
	return tech_unlock_counts.get(tech_id, 0)


## Get tech definition from registry
func _get_tech_definition(tech_id: String) -> Dictionary:
	return TechRegistry.get_tech(tech_id)


## Apply tech effects based on effect type
func _apply_tech_effects(tech_id: String, tech_def: Dictionary) -> void:
	var effect_type: String = tech_def.get("effect_type", "modifier")
	var unlock_count: int = tech_unlock_counts[tech_id]

	match effect_type:
		"modifier":
			# Add modifiers to ModifierService
			var modifiers: Array = tech_def.get("modifiers", [])
			for modifier in modifiers:
				var mod_id: String = "tech_%s_%d" % [tech_id, unlock_count]
				var full_modifier: Dictionary = modifier.duplicate(true)
				full_modifier["id"] = mod_id
				full_modifier["source"] = "tech"
				full_modifier["source_id"] = tech_id
				ModifierService.add_modifier(full_modifier)

			# Notify that modifiers changed
			Events.modifiers_changed.emit()
			DebugService.log(DebugService.SYSTEMS, "Applied ", modifiers.size(), " modifier(s) from tech '", tech_id, "'")

		"unlock_mechanic":
			# Set flags for special mechanics (queried by game systems)
			var special_effect: String = tech_def.get("special_effect", "")
			if special_effect:
				DebugService.log(DebugService.SYSTEMS, "Unlocked mechanic '", special_effect, "' from tech '", tech_id, "'")
			# Specific mechanics will be queried via helper methods

		"shop_improvement":
			# Shop improvements are queried by shop system when generating offers/prices
			DebugService.log(DebugService.SYSTEMS, "Unlocked shop improvement from tech '", tech_id, "'")

		_:
			push_warning("Unknown tech effect type: %s" % effect_type)


## Helper method to check if a specific mechanic is unlocked
func has_mechanic_unlocked(mechanic_id: String) -> bool:
	for tech_id in unlocked_tech_ids:
		var tech_def = _get_tech_definition(tech_id)
		if tech_def.get("effect_type") == "unlock_mechanic":
			if tech_def.get("special_effect") == mechanic_id:
				return true
	return false


## Get all modifiers from unlocked techs that affect shop mechanics
## Returns Dictionary with aggregated values:
## - "price_mult": float (multiply all values together, default 1.0)
## - "offer_count_bonus": int (sum all additive bonuses, default 0)
func get_shop_modifiers() -> Dictionary:
	var price_mult := 1.0
	var offer_count_bonus := 0

	for tech_id in unlocked_tech_ids:
		var tech_def = _get_tech_definition(tech_id)
		var modifiers: Array = tech_def.get("modifiers", [])

		for modifier in modifiers:
			var stat: String = modifier.get("stat", "")
			var operation: String = modifier.get("operation", "")
			var value = modifier.get("value", 0)

			# Shop price multiplier
			if stat == "shop_price_mult" and operation == "multiply":
				price_mult *= value

			# Shop offer count bonus
			elif stat == "shop_offer_count" and operation == "add":
				offer_count_bonus += int(value)

	return {
		"price_mult": price_mult,
		"offer_count_bonus": offer_count_bonus
	}
