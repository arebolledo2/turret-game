extends Button
class_name TechNodeButton

## Tech node button component for tech tree UI
## Shows tech icon, name, and state (locked/too expensive/affordable/purchased)

enum State {LOCKED, TOO_EXPENSIVE, AFFORDABLE, PURCHASED}

var tech_id: String = ""
var tech_def: Dictionary = {}
var current_state: State = State.LOCKED
var can_purchase: bool = false # Track if purchase is allowed (keeps buttons focusable for gamepad navigation)

@onready var icon_label: Label = $IconLabel
@onready var border: Panel = $Border

signal tech_selected(tech_id: String)
signal tech_focused(tech_id: String)
signal tech_purchase_requested(tech_id: String)


func _ready() -> void:
	focus_entered.connect(_on_focus_entered)
	mouse_entered.connect(_on_mouse_entered)
	pressed.connect(_on_pressed)


func _on_focus_entered() -> void:
	if not tech_id.is_empty():
		tech_focused.emit(tech_id)


func _on_mouse_entered() -> void:
	if not tech_id.is_empty():
		tech_focused.emit(tech_id)


func setup(tech_data: Dictionary) -> void:
	tech_id = tech_data.get("id", "")
	tech_def = tech_data

	# Set tooltip (shows name + description)
	tooltip_text = "%s\n%s\nCost: %d Research" % [
		tech_data.get("name", "Unknown"),
		tech_data.get("description", ""),
		tech_data.get("cost", 0)
	]

	# Defer icon and state update until node is ready
	if is_node_ready():
		_apply_icon()
		_update_state()
	else:
		ready.connect(_on_setup_ready, CONNECT_ONE_SHOT)


func _on_setup_ready() -> void:
	_apply_icon()
	_update_state()


func _apply_icon() -> void:
	if icon_label and not tech_def.is_empty():
		icon_label.text = tech_def.get("icon", "?")


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
	# All states keep disabled = false for gamepad focus navigation
	# Purchase is controlled by can_purchase flag checked in _on_pressed()
	can_purchase = (current_state == State.AFFORDABLE)

	# Apply visual styling based on state
	match current_state:
		State.PURCHASED:
			modulate = Color(0.4, 1.0, 0.4) # Green
			if icon_label:
				icon_label.modulate = Color(1, 1, 1)
			if border:
				border.modulate = Color(0.2, 0.8, 0.2) # Dark green border

		State.AFFORDABLE:
			modulate = Color(1.0, 1.0, 0.4) # Yellow
			if icon_label:
				icon_label.modulate = Color(1, 1, 1)
			if border:
				border.modulate = Color(0.8, 0.8, 0.2) # Solid yellow border

		State.TOO_EXPENSIVE:
			modulate = Color(1.0, 1.0, 0.4) # Yellow (same color)
			if icon_label:
				icon_label.modulate = Color(0.9, 0.9, 0.9)
			if border:
				border.modulate = Color(0.6, 0.6, 0.1) # Dimmer yellow border

		State.LOCKED:
			modulate = Color(0.5, 0.5, 0.5) # Gray
			if icon_label:
				icon_label.modulate = Color(0.7, 0.7, 0.7)
			if border:
				border.modulate = Color(0.3, 0.3, 0.3) # Dark gray border


func refresh() -> void:
	_update_state()


func _on_pressed() -> void:
	if not tech_id.is_empty() and can_purchase:
		tech_purchase_requested.emit(tech_id)
