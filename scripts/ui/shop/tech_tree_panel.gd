extends VBoxContainer
class_name TechTreePanel

## Tech Tree Panel - displays tech paths and nodes for unlocking during shop phase

const TechNodeButtonScene = preload("res://scenes/ui/components/tech_node_button.tscn")
const _BASE_FONT = preload("res://assets/fonts/NunitoSans-VariableFont.ttf")
static var MAIN_FONT: FontVariation = _create_medium_font()

static func _create_medium_font() -> FontVariation:
	var font_var := FontVariation.new()
	font_var.base_font = _BASE_FONT
	font_var.variation_opentype = {"wght": 500}
	return font_var

# UI References
@onready var research_label: Label = $Header/ResearchLabel
@onready var path_selector: HBoxContainer = $PathSelector
@onready var tech_scroll: ScrollContainer = $TechScroll
@onready var tech_grid: GridContainer = $TechScroll/TechGrid
@onready var detail_panel: PanelContainer = $DetailPanel
@onready var detail_icon: Label = $DetailPanel/DetailVBox/DetailIcon
@onready var detail_name: Label = $DetailPanel/DetailVBox/DetailName
@onready var detail_description: Label = $DetailPanel/DetailVBox/DetailDescription
@onready var detail_cost: Label = $DetailPanel/DetailVBox/DetailCost
@onready var detail_prereqs: Label = $DetailPanel/DetailVBox/DetailPrereqs
@onready var unlock_button: Button = $DetailPanel/DetailVBox/UnlockButton

var current_path: String = "turret_offense"
var selected_tech_id: String = ""
var tech_node_buttons: Array[TechNodeButton] = []


func _ready() -> void:
	# Apply fonts
	if research_label:
		research_label.add_theme_font_override("font", MAIN_FONT)
		research_label.add_theme_font_size_override("font_size", 20)

	# Setup path selector buttons
	_setup_path_selector()

	# Connect to events
	Events.tech_unlocked.connect(_on_tech_unlocked)
	Events.research_points_changed.connect(_on_research_points_changed)

	if unlock_button:
		unlock_button.pressed.connect(_on_unlock_button_pressed)

	# Initial display
	_update_research_label()
	_show_path(current_path)


func _setup_path_selector() -> void:
	if not path_selector:
		return

	var paths = [
		{"id": "turret_offense", "name": "Turret Offense", "icon": "⚔️"},
		{"id": "turret_utility", "name": "Turret Utility", "icon": "🔧"},
		{"id": "turret_unlock", "name": "Turret Unlocks", "icon": "🔓"},
		{"id": "player_combat", "name": "Player Combat", "icon": "🗡️"},
		{"id": "player_defense", "name": "Player Defense", "icon": "🛡️"},
		{"id": "economy", "name": "Economy", "icon": "💰"}
	]

	for path_data in paths:
		var btn = Button.new()
		btn.text = "%s %s" % [path_data["icon"], path_data["name"]]
		btn.custom_minimum_size = Vector2(150, 40)
		btn.add_theme_font_override("font", MAIN_FONT)
		btn.add_theme_font_size_override("font_size", 16)
		var path_id = path_data["id"]
		btn.pressed.connect(func(): _show_path(path_id))
		path_selector.add_child(btn)


func _show_path(path_id: String) -> void:
	current_path = path_id

	# Clear existing nodes
	for child in tech_grid.get_children():
		child.queue_free()
	tech_node_buttons.clear()

	# Get techs for this path
	var techs = TechRegistry.get_techs_by_path(path_id)

	# Create tech node buttons (sorted by tier)
	techs.sort_custom(func(a, b): return a.get("tier", 0) < b.get("tier", 0))

	for tech in techs:
		var node_btn = TechNodeButtonScene.instantiate()
		tech_grid.add_child(node_btn)
		node_btn.setup(tech)
		node_btn.tech_selected.connect(_on_tech_selected)
		node_btn.pressed.connect(_on_tech_selected.bind(tech["id"]))
		tech_node_buttons.append(node_btn)

	# Clear detail panel
	_clear_detail_panel()


func _on_tech_selected(tech_id: String) -> void:
	selected_tech_id = tech_id
	_show_tech_details(tech_id)


func _show_tech_details(tech_id: String) -> void:
	var tech = TechRegistry.get_tech(tech_id)
	if tech.is_empty():
		return

	if detail_icon:
		detail_icon.text = tech.get("icon", "?")

	if detail_name:
		detail_name.text = tech.get("name", "Unknown")

	if detail_description:
		detail_description.text = tech.get("description", "")

	if detail_cost:
		var cost = tech.get("cost", 0)
		var can_afford = TechTreeService.total_research_points >= cost
		detail_cost.text = "Cost: %d Research" % cost
		detail_cost.modulate = Color.GREEN if can_afford else Color.RED

	if detail_prereqs:
		var prerequisites = tech.get("prerequisites", [])
		if prerequisites.is_empty():
			detail_prereqs.text = "Prerequisites: None"
		else:
			var prereq_names = []
			for prereq_id in prerequisites:
				var prereq_tech = TechRegistry.get_tech(prereq_id)
				if not prereq_tech.is_empty():
					var unlocked = TechTreeService.is_tech_unlocked(prereq_id)
					var check = "✅" if unlocked else "❌"
					prereq_names.append("%s %s" % [check, prereq_tech.get("name", prereq_id)])
			detail_prereqs.text = "Prerequisites:\n" + "\n".join(prereq_names)

	# Update purchase button
	if unlock_button:
		var is_unlocked = TechTreeService.is_tech_unlocked(tech_id)
		var can_unlock = TechTreeService.can_unlock_tech(tech_id)

		if is_unlocked:
			unlock_button.text = "Purchased ✅"
			unlock_button.disabled = true
		elif can_unlock:
			unlock_button.text = "Purchase"
			unlock_button.disabled = false
		else:
			unlock_button.text = "Cannot Purchase"
			unlock_button.disabled = true


func _clear_detail_panel() -> void:
	selected_tech_id = ""

	if detail_icon:
		detail_icon.text = ""
	if detail_name:
		detail_name.text = "Select a tech to purchase"
	if detail_description:
		detail_description.text = ""
	if detail_cost:
		detail_cost.text = ""
	if detail_prereqs:
		detail_prereqs.text = ""
	if unlock_button:
		unlock_button.text = "Select to Purchase"
		unlock_button.disabled = true


func _on_unlock_button_pressed() -> void:
	if selected_tech_id.is_empty():
		return

	var success = TechTreeService.unlock_tech(selected_tech_id)
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
