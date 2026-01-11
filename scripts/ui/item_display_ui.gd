class_name ItemDisplayUI
extends RefCounted

## Item-specific UI rendering helpers

const ITEM_BUTTON_SIZE := Vector2(60, 60)
const ICON_FONT_SIZE := 28
const BADGE_FONT_SIZE := 12
const _BASE_FONT = preload("res://assets/fonts/NunitoSans-VariableFont.ttf")
static var MAIN_FONT: FontVariation = _create_medium_font()

static func _create_medium_font() -> FontVariation:
	var font_var := FontVariation.new()
	font_var.base_font = _BASE_FONT
	font_var.variation_opentype = {"wght": 500}
	return font_var

## Creates a 60x60 button with emoji icon, rarity border, and count badge for item display
static func create_item_button(item_id: String, count: int) -> Button:
	if not ItemRegistry.has_item(item_id):
		return null

	var item_data: Dictionary = ItemRegistry.get_item_dict(item_id)
	
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
	icon_label.add_theme_font_override("font", MAIN_FONT)
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
		badge.add_theme_font_override("font", MAIN_FONT)
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

	var item_data: Dictionary = ItemRegistry.get_item_dict(item_id)
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
static func update_item_details(nodes: Dictionary, item_id: String) -> void:
	if not ItemRegistry.has_item(item_id):
		return

	var item_data: Dictionary = ItemRegistry.get_item_dict(item_id)
	var count: int = ItemTrackingService.item_counts.get(item_id, 1)
	
	if nodes.has("item_icon_label") and nodes["item_icon_label"]:
		nodes["item_icon_label"].add_theme_font_override("font", MAIN_FONT)
		nodes["item_icon_label"].text = item_data.get("icon", "?")
	
	if nodes.has("item_name_label") and nodes["item_name_label"]:
		nodes["item_name_label"].add_theme_font_override("font", MAIN_FONT)
		if count > 1:
			nodes["item_name_label"].text = "%s (x%d)" % [item_data.get("name", "Unknown Item"), count]
		else:
			nodes["item_name_label"].text = item_data.get("name", "Unknown Item")
	
	if nodes.has("item_rarity_label") and nodes["item_rarity_label"]:
		nodes["item_rarity_label"].add_theme_font_override("font", MAIN_FONT)
		var rarity = item_data.get("rarity", GameEnums.ItemRarity.COMMON)
		nodes["item_rarity_label"].text = ItemRegistry.RARITY_NAMES.get(rarity, "Common")
		nodes["item_rarity_label"].add_theme_color_override("font_color", ItemRegistry.get_rarity_color(rarity))
	
	if nodes.has("item_description_label") and nodes["item_description_label"]:
		nodes["item_description_label"].add_theme_font_override("font", MAIN_FONT)
		if ItemRegistry.should_show_description(item_id):
			nodes["item_description_label"].text = item_data.get("description", "")
			nodes["item_description_label"].visible = true
		else:
			nodes["item_description_label"].text = ""
			nodes["item_description_label"].visible = false
