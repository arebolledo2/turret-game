class_name PauseMenuUI
extends ScalableUIPanel

## Handles pause menu display and interactions
## REFACTORED: Now uses InventoryPanel component for turrets/items

const MAIN_FONT = preload("res://addons/gut/fonts/AnonymousPro-Regular.ttf")

var resume_button: Button
var level_label: Label
var wave_label: Label
var stats_grid: GridContainer
var _player: Node2D = null

# Inventory panel instance (created dynamically)
var _inventory_panel: VBoxContainer = null
var _inventory_section: VBoxContainer = null

# Base values at 1080p
const BASE_PANEL_WIDTH: float = 850.0
const BASE_PANEL_HEIGHT: float = 650.0
const BASE_TITLE_FONT: int = 28
const BASE_LABEL_FONT: int = 18
const BASE_BUTTON_HEIGHT: float = 46.0


func setup(nodes: Dictionary, owner: Node) -> void:
	resume_button = nodes.get("resume_button")
	level_label = nodes.get("level_label")
	wave_label = nodes.get("wave_label")
	stats_grid = nodes.get("stats_grid")
	
	# Get reference to inventory section for adding InventoryPanel
	_inventory_section = nodes.get("inventory_section")

	# Set base size
	base_panel_size = Vector2(BASE_PANEL_WIDTH, BASE_PANEL_HEIGHT)

	# Call parent setup
	super.setup(nodes, owner)

	# Register fonts
	if level_label:
		level_label.add_theme_font_override("font", MAIN_FONT)
		register_font(level_label, BASE_LABEL_FONT)
	if wave_label:
		wave_label.add_theme_font_override("font", MAIN_FONT)
		register_font(wave_label, BASE_LABEL_FONT)
	if resume_button:
		resume_button.add_theme_font_override("font", MAIN_FONT)
	
	# Create and add InventoryPanel
	_create_inventory_panel()


func _create_inventory_panel() -> void:
	if not _inventory_section:
		return
	
	# Load and instantiate the InventoryPanel scene
	var inventory_scene = preload("res://scenes/ui/components/inventory_panel.tscn")
	_inventory_panel = inventory_scene.instantiate()
	
	# Clear existing children in inventory section
	for child in _inventory_section.get_children():
		child.queue_free()
	
	# Add the inventory panel
	_inventory_section.add_child(_inventory_panel)


func _scale_fonts(scale: float) -> void:
	# Apply registered font scales
	apply_font_scales(scale)

	# Scale buttons
	if resume_button:
		resume_button.custom_minimum_size.y = UIScaler.scale(BASE_BUTTON_HEIGHT)


func set_player(player: Node2D) -> void:
	_player = player


func show() -> void:
	if container:
		update_stats()
		_refresh_inventory()

		container.modulate.a = 0.0
		container.visible = true
		var tween = _owner.create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(container, "modulate:a", 1.0, 0.15)
		if resume_button:
			resume_button.grab_focus()


func hide() -> void:
	if container:
		container.visible = false


func update_stats() -> void:
	if level_label:
		level_label.text = "Level: %d" % Globals.player_level
	if wave_label:
		wave_label.text = "Wave: %d/%d" % [Globals.current_wave, Globals.MAX_WAVES]

	if _player and stats_grid:
		for child in stats_grid.get_children():
			if child is Label:
				child.add_theme_font_override("font", MAIN_FONT)
				child.add_theme_font_size_override("font_size", UIScaler.scale(BASE_LABEL_FONT))
		
		if stats_grid.has_node("HealthValue"):
			stats_grid.get_node("HealthValue").text = "%d/%d" % [_player.current_health, _player.max_health]
		if stats_grid.has_node("SpeedValue"):
			stats_grid.get_node("SpeedValue").text = "%d" % Globals.get_player_speed()
		if stats_grid.has_node("XPValue"):
			stats_grid.get_node("XPValue").text = "%d" % Globals.total_xp
		if stats_grid.has_node("KillsValue"):
			stats_grid.get_node("KillsValue").text = "%d" % Globals.total_kills

		var minutes := int(Globals.time_survived) / 60
		var seconds := int(Globals.time_survived) % 60
		if stats_grid.has_node("TimeValue"):
			stats_grid.get_node("TimeValue").text = "%d:%02d" % [minutes, seconds]

		if stats_grid.has_node("TurretsValue"):
			stats_grid.get_node("TurretsValue").text = "%d" % Globals.get_total_turret_count()
		if stats_grid.has_node("LuckValue"):
			stats_grid.get_node("LuckValue").text = "%d" % Globals.get_player_luck_display()


func _refresh_inventory() -> void:
	if _inventory_panel and _inventory_panel.has_method("refresh"):
		_inventory_panel.refresh()


# Legacy API methods for backward compatibility
func update_turrets_panel() -> void:
	_refresh_inventory()


func update_items_panel() -> void:
	_refresh_inventory()


func update_turret_details(_type: String) -> void:
	# Handled internally by InventoryPanel now
	pass
