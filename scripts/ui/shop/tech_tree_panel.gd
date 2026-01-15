extends HBoxContainer
class_name TechTreePanel

## Tech Tree Panel - displays all tech categories and nodes for unlocking during shop phase

const TechNodeButtonScene = preload("res://scenes/ui/components/tech_node_button.tscn")

# Category definitions
const CATEGORIES := [
	{"id": "turret_offense", "name": "Turret Offense", "icon": "⚔️"},
	{"id": "turret_utility", "name": "Turret Utility", "icon": "🔧"},
	{"id": "turret_unlock", "name": "Turret Unlocks", "icon": "🔓"},
	{"id": "player_combat", "name": "Player Combat", "icon": "🗡️"},
	{"id": "player_defense", "name": "Player Defense", "icon": "🛡️"},
	{"id": "economy", "name": "Economy", "icon": "💰"}
]

# UI References - Left side
@onready var research_label: Label = $LeftContainer/Header/ResearchLabel
@onready var categories_scroll: ScrollContainer = $LeftContainer/CategoriesScroll
@onready var categories_container: VBoxContainer = $LeftContainer/CategoriesScroll/CategoriesContainer

# UI References - Preview panel (right side)
@onready var preview_panel: PanelContainer = $PreviewPanel
@onready var preview_icon: Label = $PreviewPanel/PreviewVBox/PreviewIcon
@onready var preview_name: Label = $PreviewPanel/PreviewVBox/PreviewName
@onready var preview_description: Label = $PreviewPanel/PreviewVBox/PreviewDescription
@onready var preview_cost: Label = $PreviewPanel/PreviewVBox/PreviewCost
@onready var preview_prereqs: Label = $PreviewPanel/PreviewVBox/PreviewPrereqs
@onready var unlock_button: Button = $PreviewPanel/PreviewVBox/UnlockButton

var selected_tech_id: String = ""
var tech_node_buttons: Array[TechNodeButton] = []


func _ready() -> void:
	# Connect to events
	Events.tech_unlocked.connect(_on_tech_unlocked)
	Events.research_points_changed.connect(_on_research_points_changed)

	if unlock_button:
		unlock_button.pressed.connect(_on_unlock_button_pressed)

	# Build all categories
	_build_all_categories()

	# Initial display
	_update_research_label()


func _build_all_categories() -> void:
	# Clear existing content
	for child in categories_container.get_children():
		child.queue_free()
	tech_node_buttons.clear()

	# Create a section for each category
	for category in CATEGORIES:
		var section := _create_category_section(category)
		categories_container.add_child(section)


func _create_category_section(category: Dictionary) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)

	# Category header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)

	var icon_label := Label.new()
	icon_label.text = category["icon"]
	icon_label.add_theme_font_size_override("font_size", 20)
	header.add_child(icon_label)

	var name_label := Label.new()
	name_label.text = category["name"]
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	header.add_child(name_label)

	section.add_child(header)

	# Tech nodes container (single horizontal row)
	var techs_row := HBoxContainer.new()
	techs_row.add_theme_constant_override("separation", 8)

	# Get and sort techs for this category
	var techs := TechRegistry.get_techs_by_path(category["id"])
	techs.sort_custom(func(a, b): return a.get("tier", 0) < b.get("tier", 0))

	# Create tech node buttons
	for tech in techs:
		var node_btn: TechNodeButton = TechNodeButtonScene.instantiate()
		techs_row.add_child(node_btn)
		node_btn.setup(tech)
		node_btn.tech_focused.connect(_on_tech_focused)
		node_btn.tech_purchase_requested.connect(_on_tech_purchase_requested)
		tech_node_buttons.append(node_btn)

	section.add_child(techs_row)

	# Separator line
	var separator := HSeparator.new()
	separator.add_theme_constant_override("separation", 8)
	section.add_child(separator)

	return section


func _on_tech_focused(tech_id: String) -> void:
	selected_tech_id = tech_id
	_show_tech_details(tech_id)
	_scroll_to_focused_node()


func _on_tech_purchase_requested(tech_id: String) -> void:
	selected_tech_id = tech_id
	_show_tech_details(tech_id)
	_try_purchase_tech(tech_id)


func _try_purchase_tech(tech_id: String) -> void:
	if tech_id.is_empty():
		return

	var success := TechTreeService.unlock_tech(tech_id)
	if success:
		_refresh_all_nodes()
		_show_tech_details(tech_id)
		_update_research_label()


func _show_tech_details(tech_id: String) -> void:
	var tech := TechRegistry.get_tech(tech_id)
	if tech.is_empty():
		return

	if preview_icon:
		preview_icon.text = tech.get("icon", "?")

	if preview_name:
		preview_name.text = tech.get("name", "Unknown")

	if preview_description:
		preview_description.text = tech.get("description", "")

	if preview_cost:
		var cost: int = tech.get("cost", 0)
		var can_afford := TechTreeService.total_research_points >= cost
		preview_cost.text = "Cost: %d Research" % cost
		preview_cost.modulate = Color.GREEN if can_afford else Color.RED

	if preview_prereqs:
		var prerequisites: Array = tech.get("prerequisites", [])
		if prerequisites.is_empty():
			preview_prereqs.text = "Prerequisites: None"
		else:
			var prereq_lines: Array[String] = []
			for prereq_id in prerequisites:
				var prereq_tech := TechRegistry.get_tech(prereq_id)
				if not prereq_tech.is_empty():
					var unlocked := TechTreeService.is_tech_unlocked(prereq_id)
					var check := "✅" if unlocked else "❌"
					prereq_lines.append("%s %s" % [check, prereq_tech.get("name", prereq_id)])
			preview_prereqs.text = "Prerequisites:\n" + "\n".join(prereq_lines)

	# Update purchase button
	if unlock_button:
		var is_unlocked := TechTreeService.is_tech_unlocked(tech_id)
		var can_unlock := TechTreeService.can_unlock_tech(tech_id)

		if is_unlocked:
			unlock_button.text = "Purchased ✅"
			unlock_button.disabled = true
		elif can_unlock:
			unlock_button.text = "Purchase"
			unlock_button.disabled = false
		else:
			unlock_button.text = "Cannot Purchase"
			unlock_button.disabled = true


func _clear_preview_panel() -> void:
	selected_tech_id = ""

	if preview_icon:
		preview_icon.text = ""
	if preview_name:
		preview_name.text = "Select a tech"
	if preview_description:
		preview_description.text = "Click on a tech to view details"
	if preview_cost:
		preview_cost.text = ""
		preview_cost.modulate = Color.WHITE
	if preview_prereqs:
		preview_prereqs.text = ""
	if unlock_button:
		unlock_button.text = "Select to Purchase"
		unlock_button.disabled = true


func _on_unlock_button_pressed() -> void:
	if selected_tech_id.is_empty():
		return

	var success := TechTreeService.unlock_tech(selected_tech_id)
	if success:
		# Refresh UI
		_refresh_all_nodes()
		_show_tech_details(selected_tech_id)
		_update_research_label()


func _on_tech_unlocked(_tech_id: String) -> void:
	_refresh_all_nodes()


func _on_research_points_changed(_total: int) -> void:
	_update_research_label()
	_refresh_all_nodes()
	if not selected_tech_id.is_empty():
		_show_tech_details(selected_tech_id)


func _update_research_label() -> void:
	if research_label:
		research_label.text = "🔬 Research: %d" % TechTreeService.total_research_points


func _refresh_all_nodes() -> void:
	for node_btn in tech_node_buttons:
		if is_instance_valid(node_btn):
			node_btn.refresh()


func _scroll_to_focused_node() -> void:
	# Find the currently focused tech node and scroll it into view
	var focused := get_viewport().gui_get_focus_owner()
	if not focused or not categories_scroll:
		return

	# Get the focused node's position relative to the scroll container's content
	var focused_rect := focused.get_global_rect()
	var scroll_rect := categories_scroll.get_global_rect()

	# Calculate if the focused node is outside the visible area
	var scroll_top := scroll_rect.position.y
	var scroll_bottom := scroll_rect.position.y + scroll_rect.size.y
	var node_top := focused_rect.position.y
	var node_bottom := focused_rect.position.y + focused_rect.size.y

	# Scroll up if node is above visible area
	if node_top < scroll_top:
		var offset := node_top - scroll_top - 20  # 20px padding
		categories_scroll.scroll_vertical += int(offset)
	# Scroll down if node is below visible area
	elif node_bottom > scroll_bottom:
		var offset := node_bottom - scroll_bottom + 20  # 20px padding
		categories_scroll.scroll_vertical += int(offset)


func grab_initial_focus() -> void:
	"""Focus first available element when tab is switched to"""
	# Try to focus unlock button if enabled
	if unlock_button and not unlock_button.disabled:
		unlock_button.grab_focus()
		return

	# Try to focus first available tech node
	for node_btn in tech_node_buttons:
		if is_instance_valid(node_btn) and not node_btn.disabled:
			node_btn.grab_focus()
			return
