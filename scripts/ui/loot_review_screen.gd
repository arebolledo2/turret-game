extends RefCounted

## Loot Review Screen
## Shows found items one at a time for player to keep or discard

var container: Control
var panel: PanelContainer
var title_label: Label
var item_name_label: Label
var item_description_label: Label
var item_rarity_label: Label
var counter_label: Label
var keep_button: Button
var discard_button: Button
var parent_node: Node

var pending_items: Array = []
var current_index: int = 0
var shop_manager: Node = null


func setup(refs: Dictionary, parent: Node) -> void:
	parent_node = parent
	container = refs.get("container")
	panel = refs.get("panel")
	title_label = refs.get("title_label")
	item_name_label = refs.get("item_name_label")
	item_description_label = refs.get("item_description_label")
	item_rarity_label = refs.get("item_rarity_label")
	counter_label = refs.get("counter_label")
	keep_button = refs.get("keep_button")
	discard_button = refs.get("discard_button")
	shop_manager = refs.get("shop_manager")

	if container:
		container.visible = false

	if keep_button:
		keep_button.pressed.connect(_on_keep_pressed)

	if discard_button:
		discard_button.pressed.connect(_on_discard_pressed)


func show_review(item_ids: Array) -> void:
	"""Start reviewing found items."""
	pending_items = item_ids.duplicate()
	current_index = 0

	if pending_items.is_empty():
		_finish_review()
		return

	if container:
		container.visible = true

	_show_current_item()


func _show_current_item() -> void:
	"""Display the current item in the queue."""
	if current_index >= pending_items.size():
		_finish_review()
		return

	var item_id: String = pending_items[current_index]
	var item = ItemRegistry.get_item(item_id)

	if not item:
		_advance_queue()
		return

	# Update labels
	if item_name_label:
		item_name_label.text = item.name
		var rarity_color := ItemRegistry.get_rarity_color(item.rarity)
		item_name_label.add_theme_color_override("font_color", rarity_color)

	if item_description_label:
		item_description_label.text = item.description

	if item_rarity_label:
		var rarity_name := ItemRegistry.get_rarity_name(item.rarity)
		item_rarity_label.text = rarity_name
		var rarity_color := ItemRegistry.get_rarity_color(item.rarity)
		item_rarity_label.add_theme_color_override("font_color", rarity_color)

	if counter_label:
		counter_label.text = "Item %d of %d" % [current_index + 1, pending_items.size()]


func _on_keep_pressed() -> void:
	"""Player chose to keep the item."""
	if current_index < pending_items.size():
		var item_id: String = pending_items[current_index]

		# Apply item using shop_manager's logic
		if shop_manager and shop_manager.has_method("apply_item"):
			shop_manager.apply_item(item_id)

		Events.loot_item_accepted.emit(item_id)

	_advance_queue()


func _on_discard_pressed() -> void:
	"""Player chose to discard the item."""
	if current_index < pending_items.size():
		var item_id: String = pending_items[current_index]
		Events.loot_item_discarded.emit(item_id)

	_advance_queue()


func _advance_queue() -> void:
	"""Move to next item or finish."""
	current_index += 1
	_show_current_item()


func _finish_review() -> void:
	"""All items reviewed, proceed to shop."""
	if container:
		container.visible = false

	pending_items.clear()
	current_index = 0
	Events.loot_review_completed.emit()
