extends Button
class_name TechNodeButton

## Tech node button component for tech tree UI
## Shows tech icon, name, and state (locked/too expensive/affordable/purchased)

enum State { LOCKED, TOO_EXPENSIVE, AFFORDABLE, PURCHASED }

var tech_id: String = ""
var tech_def: Dictionary = {}
var current_state: State = State.LOCKED

@onready var icon_label: Label = $IconLabel
@onready var border: Panel = $Border

signal tech_selected(tech_id: String)


func setup(tech_data: Dictionary) -> void:
	tech_id = tech_data.get("id", "")
	tech_def = tech_data

	# Set icon
	if icon_label:
		icon_label.text = tech_data.get("icon", "?")

	# Set tooltip (shows name + description)
	tooltip_text = "%s\n%s\nCost: %d Research" % [
		tech_data.get("name", "Unknown"),
		tech_data.get("description", ""),
		tech_data.get("cost", 0)
	]

	_update_state()


func _update_state() -> void:
	if tech_id.is_empty():
		return

	var is_unlocked = TechTreeService.is_tech_unlocked(tech_id)
	var can_unlock = TechTreeService.can_unlock_tech(tech_id)

	# Determine prerequisites status
	var tech = TechRegistry.get_tech(tech_id)
	var prereqs_met = true
	for prereq_id in tech.get("prerequisites", []):
		if not TechTreeService.is_tech_unlocked(prereq_id):
			prereqs_met = false
			break

	var can_afford = TechTreeService.total_research_points >= tech.get("cost", 0)

	# Determine state with 4-way logic
	if is_unlocked:
		current_state = State.PURCHASED
	elif prereqs_met and can_afford:
		current_state = State.AFFORDABLE
	elif prereqs_met and not can_afford:
		current_state = State.TOO_EXPENSIVE
	else:
		current_state = State.LOCKED

	# Apply visual styling based on state
	match current_state:
		State.PURCHASED:
			modulate = Color(0.4, 1.0, 0.4)  # Green
			disabled = true
			if icon_label:
				icon_label.modulate = Color(1, 1, 1)
			if border:
				border.modulate = Color(0.2, 0.8, 0.2)  # Dark green border

		State.AFFORDABLE:
			modulate = Color(1.0, 1.0, 0.4)  # Yellow
			disabled = false
			if icon_label:
				icon_label.modulate = Color(1, 1, 1)
			if border:
				border.modulate = Color(0.8, 0.8, 0.2)  # Solid yellow border

		State.TOO_EXPENSIVE:
			modulate = Color(1.0, 1.0, 0.4)  # Yellow (same color)
			disabled = true  # Can't click
			if icon_label:
				icon_label.modulate = Color(0.9, 0.9, 0.9)
			if border:
				border.modulate = Color(0.6, 0.6, 0.1)  # Dimmer yellow border

		State.LOCKED:
			modulate = Color(0.5, 0.5, 0.5)  # Gray
			disabled = true
			if icon_label:
				icon_label.modulate = Color(0.7, 0.7, 0.7)
			if border:
				border.modulate = Color(0.3, 0.3, 0.3)  # Dark gray border


func refresh() -> void:
	_update_state()


func _on_pressed() -> void:
	if not tech_id.is_empty():
		tech_selected.emit(tech_id)
