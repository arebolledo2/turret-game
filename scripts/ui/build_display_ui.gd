class_name BuildDisplayUI
extends RefCounted

## Shared UI rendering helpers for player build display (turrets, items, stats)
## Used by both PauseMenuUI and ShopScreen

const TURRET_BUTTON_SIZE := Vector2(48, 48)
const ITEM_BUTTON_SIZE := Vector2(50, 50)
const ICON_FONT_SIZE := 24
const BADGE_FONT_SIZE := 10


## Creates a 48x48 button with icon and count badge for turret display
static func create_turret_button(turret_type: String, count: int) -> Button:
	var turret_config: Dictionary = TurretRegistry.get_type(turret_type)
	
	var btn := Button.new()
	btn.custom_minimum_size = TURRET_BUTTON_SIZE
	btn.text = turret_config.get("icon", "?")
	btn.tooltip_text = turret_config.get("name", "Unknown Turret")
	btn.focus_mode = Control.FOCUS_ALL
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	
	style_turret_button(btn, turret_type)
	
	# Add count badge
	if count > 0:
		var badge := Label.new()
		badge.text = str(count)
		badge.add_theme_font_size_override("font_size", BADGE_FONT_SIZE)
		badge.add_theme_color_override("font_color", Color.WHITE)
		badge.add_theme_color_override("font_outline_color", Color.BLACK)
		badge.add_theme_constant_override("outline_size", 2)
		badge.position = Vector2(30, 30)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(badge)
	
	return btn


## Applies styling to turret button
static func style_turret_button(btn: Button, turret_type: String) -> void:
	var turret_color := TurretRegistry.get_color(turret_type)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 1.0)
	style.border_color = turret_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)
	
	var style_hover := style.duplicate()
	style_hover.bg_color = Color(0.25, 0.25, 0.25, 1.0)
	btn.add_theme_stylebox_override("hover", style_hover)
	
	var style_focus := style.duplicate()
	style_focus.border_color = Color.WHITE
	style_focus.set_border_width_all(3)
	btn.add_theme_stylebox_override("focus", style_focus)


## Updates a turret details panel with stats for the given turret type
## nodes dictionary should contain: turret_name_label, damage_label, range_label, 
## fire_rate_label, rotation_label, proj_speed_label, dps_label
static func update_turret_details(nodes: Dictionary, turret_type: String) -> void:
	var config: Dictionary = TurretRegistry.get_type(turret_type)
	var stats: Dictionary = Globals.get_turret_stats(turret_type)
	var count: int = Globals.turret_counts.get(turret_type, 0)
	
	if nodes.has("turret_name_label") and nodes["turret_name_label"]:
		nodes["turret_name_label"].text = "%s %s (x%d)" % [config.get("icon", "?"), config.get("name", "Unknown"), count]
	
	if nodes.has("damage_label") and nodes["damage_label"]:
		nodes["damage_label"].text = "• Damage: %.1f" % stats.get("damage", 0)
	
	if nodes.has("range_label") and nodes["range_label"]:
		nodes["range_label"].text = "• Range: %d" % stats.get("range", 0)
	
	if nodes.has("fire_rate_label") and nodes["fire_rate_label"]:
		nodes["fire_rate_label"].text = "• Fire Rate: %.1f/s" % stats.get("fire_rate", 0)
	
	if nodes.has("rotation_label") and nodes["rotation_label"]:
		nodes["rotation_label"].text = "• Rotation: %d°/s" % stats.get("rotation_speed", 0)
	
	if nodes.has("proj_speed_label") and nodes["proj_speed_label"]:
		nodes["proj_speed_label"].text = "• Proj Speed: %d" % stats.get("projectile_speed", 0)
	
	if nodes.has("dps_label") and nodes["dps_label"]:
		var dps: float = stats.get("damage", 0) * stats.get("fire_rate", 0)
		nodes["dps_label"].text = "• DPS: %.1f" % dps


## Creates a 50x50 button with emoji icon, rarity border, and count badge for item display
static func create_item_button(item_id: String, count: int) -> Button:
	if not ItemRegistry.has_item(item_id):
		return null
	
	var item_data: Dictionary = ItemRegistry.get_item(item_id)
	
	var btn := Button.new()
	btn.custom_minimum_size = ITEM_BUTTON_SIZE
	btn.focus_mode = Control.FOCUS_ALL
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	
	style_item_button(btn, item_id)
	
	# Create container for icon and badge
	var container_node := Control.new()
	container_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	container_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(container_node)
	
	# Add emoji icon label
	var icon_label := Label.new()
	icon_label.text = item_data.get("icon", "?")
	icon_label.add_theme_font_size_override("font_size", ICON_FONT_SIZE)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container_node.add_child(icon_label)
	
	# Add quantity badge if count > 1
	if count > 1:
		var badge := Label.new()
		badge.text = "x%d" % count
		badge.add_theme_font_size_override("font_size", BADGE_FONT_SIZE)
		badge.add_theme_color_override("font_color", Color.WHITE)
		badge.add_theme_color_override("font_outline_color", Color.BLACK)
		badge.add_theme_constant_override("outline_size", 2)
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -20
		badge.offset_right = -2
		badge.offset_top = 2
		badge.offset_bottom = 14
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container_node.add_child(badge)
	
	btn.tooltip_text = "%s\n%s" % [item_data.get("name", "Unknown Item"), item_data.get("description", "")]
	
	return btn


## Applies rarity-colored border styling to item button
static func style_item_button(btn: Button, item_id: String) -> void:
	if not ItemRegistry.has_item(item_id):
		return
	
	var item_data: Dictionary = ItemRegistry.get_item(item_id)
	var rarity_color := ItemRegistry.get_rarity_color(item_data.get("rarity", 0))
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 1.0)
	style.border_color = rarity_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)
	
	var style_hover := style.duplicate()
	style_hover.bg_color = Color(0.25, 0.25, 0.25, 1.0)
	btn.add_theme_stylebox_override("hover", style_hover)
	
	var style_focus := style.duplicate()
	style_focus.border_color = Color.WHITE
	style_focus.set_border_width_all(3)
	btn.add_theme_stylebox_override("focus", style_focus)


## Updates an item details panel with info for the given item
## nodes dictionary should contain: item_icon_label, item_name_label, 
## item_rarity_label, item_description_label
static func update_item_details(nodes: Dictionary, item_id: String) -> void:
	if not ItemRegistry.has_item(item_id):
		return
	
	var item_data: Dictionary = ItemRegistry.get_item(item_id)
	var count: int = Globals.item_counts.get(item_id, 1)
	
	if nodes.has("item_icon_label") and nodes["item_icon_label"]:
		nodes["item_icon_label"].text = item_data.get("icon", "?")
	
	if nodes.has("item_name_label") and nodes["item_name_label"]:
		if count > 1:
			nodes["item_name_label"].text = "%s (x%d)" % [item_data.get("name", "Unknown Item"), count]
		else:
			nodes["item_name_label"].text = item_data.get("name", "Unknown Item")
	
	if nodes.has("item_rarity_label") and nodes["item_rarity_label"]:
		var rarity = item_data.get("rarity", GameEnums.ItemRarity.COMMON)
		nodes["item_rarity_label"].text = ItemRegistry.RARITY_NAMES.get(rarity, "Common")
		nodes["item_rarity_label"].add_theme_color_override("font_color", ItemRegistry.get_rarity_color(rarity))
	
	if nodes.has("item_description_label") and nodes["item_description_label"]:
		nodes["item_description_label"].text = item_data.get("description", "")


## Sets up focus neighbors for a row of buttons
## Connects left/right within the row, and up/down to specified targets
static func setup_focus_neighbors(buttons: Array[Button], up_target: Control, down_target: Control) -> void:
	if buttons.is_empty():
		return
	
	for i in range(buttons.size()):
		var btn := buttons[i]
		
		# Left neighbor
		if i > 0:
			btn.focus_neighbor_left = buttons[i - 1].get_path()
		
		# Right neighbor
		if i < buttons.size() - 1:
			btn.focus_neighbor_right = buttons[i + 1].get_path()
		
		# Up neighbor
		if up_target and is_instance_valid(up_target):
			btn.focus_neighbor_top = up_target.get_path()
		
		# Down neighbor
		if down_target and is_instance_valid(down_target):
			btn.focus_neighbor_bottom = down_target.get_path()
