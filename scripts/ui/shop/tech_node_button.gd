extends Button
class_name TechNodeButton

## Tech node button component for tech tree UI
## Shows tech icon, name, and state (locked/available/unlocked)

enum State { LOCKED, AVAILABLE, UNLOCKED }

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

	# Determine state
	if TechTreeService.is_tech_unlocked(tech_id):
		current_state = State.UNLOCKED
	elif TechTreeService.can_unlock_tech(tech_id):
		current_state = State.AVAILABLE
	else:
		current_state = State.LOCKED

	# Apply visual styling based on state
	match current_state:
		State.UNLOCKED:
			modulate = Color(0.4, 1.0, 0.4)  # Green
			disabled = true
			if icon_label:
				icon_label.modulate = Color(1, 1, 1)

		State.AVAILABLE:
			modulate = Color(1.0, 1.0, 0.4)  # Yellow
			disabled = false
			if icon_label:
				icon_label.modulate = Color(1, 1, 1)

		State.LOCKED:
			modulate = Color(0.5, 0.5, 0.5)  # Gray
			disabled = true
			if icon_label:
				icon_label.modulate = Color(0.7, 0.7, 0.7)


func refresh() -> void:
	_update_state()


func _on_pressed() -> void:
	if not tech_id.is_empty():
		tech_selected.emit(tech_id)
