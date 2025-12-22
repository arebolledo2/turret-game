class_name BuildDisplayUI
extends RefCounted

## Shared UI rendering facade for player build display
## REFACTORED: Logic moved to TurretDisplayUI, ItemDisplayUI, and UIHelpers

# Facade methods for TurretDisplayUI
static func create_turret_button(turret_type: String, count: int) -> Button:
	return TurretDisplayUI.create_turret_button(turret_type, count)

static func style_turret_button(btn: Button, turret_type: String) -> void:
	TurretDisplayUI.style_turret_button(btn, turret_type)

static func update_turret_details(nodes: Dictionary, turret_type: String) -> void:
	TurretDisplayUI.update_turret_details(nodes, turret_type)

static func calculate_effective_dps(turret_type: String, stats: Dictionary) -> Dictionary:
	return TurretDisplayUI.calculate_effective_dps(turret_type, stats)

# Facade methods for ItemDisplayUI
static func create_item_button(item_id: String, count: int) -> Button:
	return ItemDisplayUI.create_item_button(item_id, count)

static func style_item_button(btn: Button, item_id: String) -> void:
	ItemDisplayUI.style_item_button(btn, item_id)

static func update_item_details(nodes: Dictionary, item_id: String) -> void:
	ItemDisplayUI.update_item_details(nodes, item_id)

# Facade methods for UIHelpers
static func setup_focus_neighbors(buttons: Array[Button], up_target: Control, down_target: Control) -> void:
	UIHelpers.setup_focus_neighbors(buttons, up_target, down_target)

static func format_stat_with_modifier(stat_name: String, base_val: float, mod_val: float, fmt: String = "%.1f", higher_better: bool = true) -> Dictionary:
	return UIHelpers.format_stat_with_modifier(stat_name, base_val, mod_val, fmt, higher_better)

static func format_percentage(value: float) -> String:
	return UIHelpers.format_percentage(value)

# Legacy helper
static func get_base_turret_stats(turret_type: String) -> Dictionary:
	return TurretRegistry.get_base_stats(turret_type)
