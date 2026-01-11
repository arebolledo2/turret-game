class_name ShopBuildTabsItems
extends Node

## Manages the items tab display in shop/pause menu
## Extracted from shop_screen.gd to reduce file size

const BuildDisplayUIScript = preload("res://scripts/ui/build_display_ui.gd")
const _BASE_FONT = preload("res://assets/fonts/NunitoSans-VariableFont.ttf")
static var MAIN_FONT: FontVariation = _create_medium_font()

static func _create_medium_font() -> FontVariation:
	var font_var := FontVariation.new()
	font_var.base_font = _BASE_FONT
	font_var.variation_opentype = {"wght": 500}
	return font_var

var items_title: Label
var items_hint: Label
var items_scroll: ScrollContainer
var items_hbox: HBoxContainer
var no_items_label: Label
var item_details_panel: PanelContainer
var item_icon_label: Label
var item_name_label: Label
var item_rarity_label: Label
var item_description_label: Label

var _selected_item_id: String = ""
var _item_buttons: Array[Button] = []

func initialize(nodes: Dictionary) -> void:
	items_title = nodes.get("items_title")
	items_hint = nodes.get("items_hint")
	items_scroll = nodes.get("items_scroll")
	items_hbox = nodes.get("items_hbox")
	no_items_label = nodes.get("no_items_label")
	item_details_panel = nodes.get("item_details_panel")
	item_icon_label = nodes.get("item_icon_label")
	item_name_label = nodes.get("item_name_label")
	item_rarity_label = nodes.get("item_rarity_label")
	item_description_label = nodes.get("item_description_label")

func update_display() -> void:
	var unique_item_count := ItemTrackingService.item_counts.size()
	var total_item_count := 0
	for count in ItemTrackingService.item_counts.values():
		total_item_count += count
	
	if items_title:
		items_title.add_theme_font_override("font", MAIN_FONT)
		items_title.text = "ITEMS (%d)" % total_item_count
	
	var has_items := unique_item_count > 0
	
	if items_hint:
		items_hint.visible = has_items
	if no_items_label:
		no_items_label.visible = not has_items
	if items_scroll:
		items_scroll.visible = has_items
	if item_details_panel:
		item_details_panel.visible = false
		_selected_item_id = ""
	
	_item_buttons.clear()
	
	if items_hbox:
		# Clear existing items
		for child in items_hbox.get_children():
			child.queue_free()
		
		# Add item buttons using shared helper
		for item_id in ItemTrackingService.item_counts.keys():
			if not ItemRegistry.has_item(item_id):
				continue
			var count: int = ItemTrackingService.item_counts[item_id]
			
			var btn: Button = BuildDisplayUIScript.create_item_button(item_id, count)
			if btn:
				var captured_item_id: String = item_id
				btn.pressed.connect(func(): _on_item_selected(captured_item_id))
				btn.focus_entered.connect(func(): _on_item_selected(captured_item_id))
				
				items_hbox.add_child(btn)
				_item_buttons.append(btn)

func _on_item_selected(item_id: String) -> void:
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

func get_item_buttons() -> Array[Button]:
	return _item_buttons
