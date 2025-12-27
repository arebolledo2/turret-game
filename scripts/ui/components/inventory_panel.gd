class_name InventoryPanel
extends VBoxContainer

## Reusable component displaying Turrets and Items inventory
## Used in both Shop Screen and Pause Menu
## Always shows owned items/turrets; shows details on selection

signal turret_selected(turret_type: String)
signal item_selected(item_id: String)

const MAIN_FONT = preload("res://assets/fonts/NunitoSans-Regular.ttf")
const BuildDisplayUIScript = preload("res://scripts/ui/build_display_ui.gd")

@onready var turrets_header: HBoxContainer = $TurretsHeader
@onready var turrets_title: Label = $TurretsHeader/TurretsTitle
@onready var turrets_hint: Label = $TurretsHeader/TurretsHint
@onready var turret_icons_row: HBoxContainer = $TurretIconsRow
@onready var turret_details_panel: PanelContainer = $TurretDetailsPanel
@onready var turret_name_label: Label = $TurretDetailsPanel/TurretDetailsVBox/TurretName
@onready var turret_stats_hbox: HBoxContainer = $TurretDetailsPanel/TurretDetailsVBox/StatsHBox
@onready var turret_damage_label: Label = $TurretDetailsPanel/TurretDetailsVBox/StatsHBox/LeftStats/DamageLabel
@onready var turret_range_label: Label = $TurretDetailsPanel/TurretDetailsVBox/StatsHBox/LeftStats/RangeLabel
@onready var turret_fire_rate_label: Label = $TurretDetailsPanel/TurretDetailsVBox/StatsHBox/LeftStats/FireRateLabel
@onready var turret_rotation_label: Label = $TurretDetailsPanel/TurretDetailsVBox/StatsHBox/RightStats/RotationLabel
@onready var turret_proj_speed_label: Label = $TurretDetailsPanel/TurretDetailsVBox/StatsHBox/RightStats/ProjSpeedLabel
@onready var turret_dps_label: Label = $TurretDetailsPanel/TurretDetailsVBox/StatsHBox/RightStats/DPSLabel

@onready var items_header: HBoxContainer = $ItemsHeader
@onready var items_title: Label = $ItemsHeader/ItemsTitle
@onready var items_hint: Label = $ItemsHeader/ItemsHint
@onready var items_scroll: ScrollContainer = $ItemsScrollContainer
@onready var items_hbox: HBoxContainer = $ItemsScrollContainer/ItemsHBox
@onready var item_details_panel: PanelContainer = $ItemDetailsPanel
@onready var item_icon_label: Label = $ItemDetailsPanel/ItemDetailsVBox/ItemHeader/ItemIcon
@onready var item_name_label: Label = $ItemDetailsPanel/ItemDetailsVBox/ItemHeader/ItemName
@onready var item_rarity_label: Label = $ItemDetailsPanel/ItemDetailsVBox/ItemHeader/ItemRarity
@onready var item_description_label: Label = $ItemDetailsPanel/ItemDetailsVBox/ItemDescription

var _selected_turret_type: String = ""
var _selected_item_id: String = ""
var _turret_buttons: Array[Button] = []
var _item_buttons: Array[Button] = []


func _ready() -> void:
	pass


func refresh() -> void:
	_update_turrets()
	_update_items()


func get_turret_buttons() -> Array[Button]:
	return _turret_buttons


func get_item_buttons() -> Array[Button]:
	return _item_buttons


func _update_turrets() -> void:
	var total_turrets := Globals.get_total_turret_count()
	
	if turrets_title:
		turrets_title.add_theme_font_override("font", MAIN_FONT)
		turrets_title.text = "TURRETS (%d)" % total_turrets
	
	_turret_buttons.clear()
	
	# Clear existing icons
	if turret_icons_row:
		for child in turret_icons_row.get_children():
			child.queue_free()
	
	var has_turrets := total_turrets > 0
	
	if turrets_hint:
		turrets_hint.visible = has_turrets
	
	# Always show details panel area (can show "No turrets" message)
	if turret_details_panel:
		turret_details_panel.visible = true
		if not has_turrets:
			turret_name_label.text = "No turrets owned"
			_hide_turret_stats()
	
	if not has_turrets:
		_selected_turret_type = ""
		return
	
	# Create icons for each turret type
	var first_type: String = ""
	for type in TurretRegistry.get_all_type_ids():
		var count: int = Globals.turret_counts.get(type, 0)
		if count > 0:
			if first_type.is_empty():
				first_type = type
			
			var btn: Button = BuildDisplayUIScript.create_turret_button(type, count)
			var captured_type: String = type
			btn.pressed.connect(func(): _on_turret_icon_pressed(captured_type))
			btn.focus_entered.connect(func(): _on_turret_icon_pressed(captured_type))
			
			if turret_icons_row:
				turret_icons_row.add_child(btn)
			_turret_buttons.append(btn)
	
	# Auto-select first turret
	if _selected_turret_type.is_empty() or Globals.turret_counts.get(_selected_turret_type, 0) == 0:
		_selected_turret_type = first_type
	
	if not _selected_turret_type.is_empty():
		_show_turret_details(_selected_turret_type)


func _on_turret_icon_pressed(type: String) -> void:
	_selected_turret_type = type
	_show_turret_details(type)
	turret_selected.emit(type)


func _show_turret_details(type: String) -> void:
	if turret_stats_hbox:
		turret_stats_hbox.visible = true
	
	var nodes: Dictionary = {
		"turret_name_label": turret_name_label,
		"damage_label": turret_damage_label,
		"range_label": turret_range_label,
		"fire_rate_label": turret_fire_rate_label,
		"rotation_label": turret_rotation_label,
		"proj_speed_label": turret_proj_speed_label,
		"dps_label": turret_dps_label,
	}
	BuildDisplayUIScript.update_turret_details(nodes, type)


func _hide_turret_stats() -> void:
	if turret_stats_hbox:
		turret_stats_hbox.visible = false


func _update_items() -> void:
	var total_item_count := 0
	for count in Globals.item_counts.values():
		total_item_count += count
	var unique_item_count := Globals.item_counts.size()
	
	if items_title:
		items_title.add_theme_font_override("font", MAIN_FONT)
		items_title.text = "ITEMS (%d)" % total_item_count
	
	var has_items := unique_item_count > 0
	
	if items_hint:
		items_hint.visible = has_items
	
	# Always visible scroll area
	if items_scroll:
		items_scroll.visible = true
	
	# Details panel shows on selection
	if item_details_panel:
		item_details_panel.visible = false
		_selected_item_id = ""
	
	_item_buttons.clear()
	
	if items_hbox:
		# Clear existing
		for child in items_hbox.get_children():
			child.queue_free()
		
		if not has_items:
			var no_items := Label.new()
			no_items.text = "No items collected"
			no_items.add_theme_font_override("font", MAIN_FONT)
			no_items.add_theme_font_size_override("font_size", 12)
			no_items.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
			items_hbox.add_child(no_items)
			return
		
		# Add item buttons
		for item_id in Globals.item_counts.keys():
			if not ItemRegistry.has_item(item_id):
				continue
			var count: int = Globals.item_counts[item_id]
			
			var btn: Button = BuildDisplayUIScript.create_item_button(item_id, count)
			if btn:
				var captured_item_id: String = item_id
				btn.pressed.connect(func(): _on_item_icon_pressed(captured_item_id))
				btn.focus_entered.connect(func(): _on_item_icon_pressed(captured_item_id))
				
				items_hbox.add_child(btn)
				_item_buttons.append(btn)


func _on_item_icon_pressed(item_id: String) -> void:
	_selected_item_id = item_id
	
	if item_details_panel:
		item_details_panel.visible = true
	
	var nodes: Dictionary = {
		"item_icon_label": item_icon_label,
		"item_name_label": item_name_label,
		"item_rarity_label": item_rarity_label,
		"item_description_label": item_description_label,
	}
	BuildDisplayUIScript.update_item_details(nodes, item_id)
	item_selected.emit(item_id)
