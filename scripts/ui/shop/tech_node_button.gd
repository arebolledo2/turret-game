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
var checkmark_label: Label = null

signal tech_selected(tech_id: String)
signal tech_focused(tech_id: String)
signal tech_purchase_requested(tech_id: String)


func _ready() -> void:
	focus_entered.connect(_on_focus_entered)
	mouse_entered.connect(_on_mouse_entered)
	pressed.connect(_on_pressed)
	_setup_border_style()
	_setup_checkmark()


func _setup_border_style() -> void:
	# Create a visible StyleBoxFlat for the border panel
	if border:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0) # Transparent background
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.border_color = Color(0.3, 0.3, 0.3) # Default gray border
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		border.add_theme_stylebox_override("panel", style)


func _setup_checkmark() -> void:
	# Create checkmark label for purchased state
	checkmark_label = Label.new()
	checkmark_label.text = "✓"
	checkmark_label.add_theme_font_size_override("font_size", 24)
	checkmark_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
	checkmark_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	checkmark_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	checkmark_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	checkmark_label.offset_right = -4
	checkmark_label.offset_bottom = -2
	checkmark_label.visible = false
	add_child(checkmark_label)


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
			modulate = Color(1.0, 1.0, 1.0) # Normal modulate
			if icon_label:
				icon_label.modulate = Color(1.0, 1.0, 1.0)
			if border:
				# Bright green glowing border
				var style: StyleBoxFlat = border.get_theme_stylebox("panel")
				if style:
					style.border_color = Color(0.2, 1.0, 0.2) # Bright green
					style.border_width_left = 4
					style.border_width_right = 4
					style.border_width_top = 4
					style.border_width_bottom = 4
					style.bg_color = Color(0.1, 0.3, 0.1, 0.5) # Subtle green background
			if checkmark_label:
				checkmark_label.visible = true

		State.AFFORDABLE:
			modulate = Color(1.0, 1.0, 0.9) # Slightly warm
			if icon_label:
				icon_label.modulate = Color(1, 1, 1)
			if border:
				var style: StyleBoxFlat = border.get_theme_stylebox("panel")
				if style:
					style.border_color = Color(1.0, 0.9, 0.2) # Yellow border
					style.border_width_left = 3
					style.border_width_right = 3
					style.border_width_top = 3
					style.border_width_bottom = 3
					style.bg_color = Color(0, 0, 0, 0)
			if checkmark_label:
				checkmark_label.visible = false

		State.TOO_EXPENSIVE:
			modulate = Color(0.8, 0.8, 0.6) # Dimmer
			if icon_label:
				icon_label.modulate = Color(0.9, 0.9, 0.9)
			if border:
				var style: StyleBoxFlat = border.get_theme_stylebox("panel")
				if style:
					style.border_color = Color(0.6, 0.5, 0.1) # Dim yellow
					style.border_width_left = 2
					style.border_width_right = 2
					style.border_width_top = 2
					style.border_width_bottom = 2
					style.bg_color = Color(0, 0, 0, 0)
			if checkmark_label:
				checkmark_label.visible = false

		State.LOCKED:
			modulate = Color(0.5, 0.5, 0.5) # Gray
			if icon_label:
				icon_label.modulate = Color(0.7, 0.7, 0.7)
			if border:
				var style: StyleBoxFlat = border.get_theme_stylebox("panel")
				if style:
					style.border_color = Color(0.3, 0.3, 0.3) # Gray
					style.border_width_left = 2
					style.border_width_right = 2
					style.border_width_top = 2
					style.border_width_bottom = 2
					style.bg_color = Color(0, 0, 0, 0)
			if checkmark_label:
				checkmark_label.visible = false


func refresh() -> void:
	_update_state()


func _on_pressed() -> void:
	if not tech_id.is_empty() and can_purchase:
		tech_purchase_requested.emit(tech_id)
