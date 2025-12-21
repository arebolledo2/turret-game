class_name PauseMenuUI
extends ScalableUIPanel

## Handles pause menu display and interactions

const BuildDisplayUIScript = preload("res://scripts/ui/build_display_ui.gd")

const MAIN_FONT = preload("res://addons/gut/fonts/AnonymousPro-Regular.ttf")

var resume_button: Button
var level_label: Label
var wave_label: Label
var stats_grid: GridContainer
var turrets_title: Label
var turret_icons_row: HBoxContainer
var turret_details_panel: PanelContainer
var turret_name_label: Label
var turret_stats_container: HBoxContainer
var items_title: Label
var items_hint: Label
var items_scroll: ScrollContainer
var items_hbox: HBoxContainer
var item_details_panel: PanelContainer
var item_icon_label: Label
var item_name_label: Label
var item_rarity_label: Label
var item_description_label: Label
var _player: Node2D = null
var _selected_turret_type: String = ""
var _selected_item_id: String = ""
var _turret_buttons: Array[Button] = []
var _item_buttons: Array[Button] = []

# Base values at 1080p
const BASE_PANEL_WIDTH: float = 850.0 # Increased for larger fonts
const BASE_PANEL_HEIGHT: float = 650.0 # Increased for larger fonts
const BASE_TITLE_FONT: int = 28
const BASE_LABEL_FONT: int = 18
const BASE_BUTTON_HEIGHT: float = 46.0


func setup(nodes: Dictionary, owner: Node) -> void:
	resume_button = nodes.get("resume_button")
	level_label = nodes.get("level_label")
	wave_label = nodes.get("wave_label")
	stats_grid = nodes.get("stats_grid")
	turrets_title = nodes.get("turrets_title")
	turret_icons_row = nodes.get("turret_icons_row")
	turret_details_panel = nodes.get("turret_details_panel")
	turret_name_label = nodes.get("turret_name_label")
	turret_stats_container = nodes.get("turret_stats_container")
	items_title = nodes.get("items_title")
	items_hint = nodes.get("items_hint")
	items_scroll = nodes.get("items_scroll")
	items_hbox = nodes.get("items_hbox")
	item_details_panel = nodes.get("item_details_panel")
	item_icon_label = nodes.get("item_icon_label")
	item_name_label = nodes.get("item_name_label")
	item_rarity_label = nodes.get("item_rarity_label")
	item_description_label = nodes.get("item_description_label")

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
	if turrets_title:
		turrets_title.add_theme_font_override("font", MAIN_FONT)
		register_font(turrets_title, BASE_TITLE_FONT)
	if items_title:
		items_title.add_theme_font_override("font", MAIN_FONT)
		register_font(items_title, BASE_TITLE_FONT)
	if items_hint:
		items_hint.add_theme_font_override("font", MAIN_FONT)
		register_font(items_hint, BASE_LABEL_FONT)

	if resume_button:
		resume_button.add_theme_font_override("font", MAIN_FONT)


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
		update_turrets_panel()
		update_items_panel()

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
		stats_grid.get_node("SpeedValue").text = "%d" % _player.speed
		stats_grid.get_node("XPValue").text = "%d" % Globals.total_xp
		stats_grid.get_node("KillsValue").text = "%d" % Globals.total_kills

		var minutes := int(Globals.time_survived) / 60
		var seconds := int(Globals.time_survived) % 60
		stats_grid.get_node("TimeValue").text = "%d:%02d" % [minutes, seconds]

		stats_grid.get_node("TurretsValue").text = "%d" % Globals.turrets_spawned
		stats_grid.get_node("LuckValue").text = "%d" % Globals.get_player_luck_display()


func update_turrets_panel() -> void:
	var total_turrets := Globals.get_total_turret_count()
	
	if turrets_title:
		turrets_title.text = "TURRETS (%d)" % total_turrets

	_turret_buttons.clear()

	if turret_icons_row:
		# Clear existing icons (except the "no turrets" label)
		for child in turret_icons_row.get_children():
			if child.name != "NoTurretsLabel":
				child.queue_free()

	var has_turrets := total_turrets > 0

	if turret_icons_row:
		var no_turrets_label = turret_icons_row.get_node_or_null("NoTurretsLabel")
		if no_turrets_label:
			no_turrets_label.visible = not has_turrets

	if turret_details_panel:
		turret_details_panel.visible = has_turrets

	if not has_turrets:
		_selected_turret_type = ""
		return

	# Create icons for each turret type using shared helper
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
		update_turret_details(_selected_turret_type)


func _on_turret_icon_pressed(type: String) -> void:
	_selected_turret_type = type
	update_turret_details(type)


func update_turret_details(type: String) -> void:
	if not turret_stats_container:
		return
	
	var left_stats = turret_stats_container.get_node_or_null("LeftStats")
	var right_stats = turret_stats_container.get_node_or_null("RightStats")
	
	var nodes: Dictionary = {
		"turret_name_label": turret_name_label,
		"damage_label": left_stats.get_node_or_null("DamageLabel") if left_stats else null,
		"range_label": left_stats.get_node_or_null("RangeLabel") if left_stats else null,
		"fire_rate_label": left_stats.get_node_or_null("FireRateLabel") if left_stats else null,
		"rotation_label": right_stats.get_node_or_null("RotationLabel") if right_stats else null,
		"proj_speed_label": right_stats.get_node_or_null("ProjSpeedLabel") if right_stats else null,
		"dps_label": right_stats.get_node_or_null("DPSLabel") if right_stats else null,
	}
	BuildDisplayUIScript.update_turret_details(nodes, type)


func update_items_panel() -> void:
	# Use item_counts for unique items with quantities
	var unique_item_count := Globals.item_counts.size()
	var total_item_count := 0
	for count in Globals.item_counts.values():
		total_item_count += count

	if items_title:
		items_title.text = "ITEMS (%d)" % total_item_count
	if items_hint:
		items_hint.visible = unique_item_count == 0
	if items_scroll:
		items_scroll.visible = unique_item_count > 0
	if item_details_panel:
		item_details_panel.visible = false
		_selected_item_id = ""

	_item_buttons.clear()

	if items_hbox:
		# Clear existing items
		for child in items_hbox.get_children():
			child.queue_free()

		# Add item buttons using shared helper
		for item_id in Globals.item_counts.keys():
			if not ItemRegistry.has_item(item_id):
				continue
			var count: int = Globals.item_counts[item_id]

			var btn: Button = BuildDisplayUIScript.create_item_button(item_id, count)
			if btn:
				var captured_item_id: String = item_id
				btn.pressed.connect(func(): _on_item_selected(captured_item_id))
				btn.focus_entered.connect(func(): _on_item_selected(captured_item_id))

				items_hbox.add_child(btn)
				_item_buttons.append(btn)

	# Set up focus neighbors for controller navigation
	_setup_item_focus_neighbors()


func _setup_item_focus_neighbors() -> void:
	if _item_buttons.is_empty():
		return

	# Set up focus using shared helper with turret buttons as up target
	var up_target: Control = _turret_buttons[_turret_buttons.size() - 1] if not _turret_buttons.is_empty() else null
	BuildDisplayUIScript.setup_focus_neighbors(_item_buttons, up_target, resume_button)
	
	# Additional customization: first item can go left to last turret button
	if not _turret_buttons.is_empty() and not _item_buttons.is_empty():
		_item_buttons[0].focus_neighbor_left = _turret_buttons[_turret_buttons.size() - 1].get_path()
	
	# Last item can go right to resume
	if resume_button and not _item_buttons.is_empty():
		_item_buttons[_item_buttons.size() - 1].focus_neighbor_right = resume_button.get_path()

	# Set turret buttons to navigate down to items
	for i in range(_turret_buttons.size()):
		var turret_btn := _turret_buttons[i]
		if _item_buttons.size() > 0:
			var item_idx := mini(i, _item_buttons.size() - 1)
			turret_btn.focus_neighbor_bottom = _item_buttons[item_idx].get_path()


func _on_item_selected(item_id: String) -> void:
	if not ItemRegistry.has_item(item_id):
		return

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
