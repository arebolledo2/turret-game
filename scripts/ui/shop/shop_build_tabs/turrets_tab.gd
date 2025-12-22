class_name ShopBuildTabsTurrets
extends Node

## Manages the turrets tab display in shop/pause menu
## Extracted from shop_screen.gd to reduce file size

const BuildDisplayUIScript = preload("res://scripts/ui/build_display_ui.gd")
const MAIN_FONT = preload("res://addons/gut/fonts/AnonymousPro-Regular.ttf")

var turrets_title: Label
var turrets_hint: Label
var turret_icons_row: HBoxContainer
var turret_details_panel: PanelContainer
var turret_name_label: Label
var turret_damage_label: Label
var turret_range_label: Label
var turret_fire_rate_label: Label
var turret_rotation_label: Label
var turret_proj_speed_label: Label
var turret_dps_label: Label

var _selected_turret_type: String = ""
var _turret_buttons: Array[Button] = []

func initialize(nodes: Dictionary) -> void:
	turrets_title = nodes.get("turrets_title")
	turrets_hint = nodes.get("turrets_hint")
	turret_icons_row = nodes.get("turret_icons_row")
	turret_details_panel = nodes.get("turret_details_panel")
	turret_name_label = nodes.get("turret_name_label")
	turret_damage_label = nodes.get("turret_damage_label")
	turret_range_label = nodes.get("turret_range_label")
	turret_fire_rate_label = nodes.get("turret_fire_rate_label")
	turret_rotation_label = nodes.get("turret_rotation_label")
	turret_proj_speed_label = nodes.get("turret_proj_speed_label")
	turret_dps_label = nodes.get("turret_dps_label")

func update_display() -> void:
	var total_turrets := Globals.get_total_turret_count()
	
	if turrets_title:
		turrets_title.add_theme_font_override("font", MAIN_FONT)
		turrets_title.text = "TURRETS (%d)" % total_turrets
	
	_turret_buttons.clear()
	
	# Clear existing icons (except the "no turrets" label)
	if turret_icons_row:
		for child in turret_icons_row.get_children():
			if child.name != "NoTurretsLabel":
				child.queue_free()
	
	var has_turrets := total_turrets > 0
	
	if turret_icons_row:
		var no_turrets_label = turret_icons_row.get_node_or_null("NoTurretsLabel")
		if no_turrets_label:
			no_turrets_label.visible = not has_turrets
	
	if turrets_hint:
		turrets_hint.visible = has_turrets
	
	if turret_details_panel:
		turret_details_panel.visible = has_turrets
	
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
	
	# Auto-select first turret if nothing selected
	if _selected_turret_type.is_empty() or Globals.turret_counts.get(_selected_turret_type, 0) == 0:
		_selected_turret_type = first_type
	
	if not _selected_turret_type.is_empty():
		_update_turret_details(_selected_turret_type)

func _on_turret_icon_pressed(type: String) -> void:
	_selected_turret_type = type
	_update_turret_details(type)

func _update_turret_details(type: String) -> void:
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

func get_turret_buttons() -> Array[Button]:
	return _turret_buttons
