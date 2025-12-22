class_name ShopOffersPanel
extends Node

## Manages shop offer display and purchase interactions
## Extracted from shop_screen.gd to reduce file size

const MAIN_FONT = preload("res://addons/gut/fonts/AnonymousPro-Regular.ttf")

var offers_container: HBoxContainer
var reroll_button: Button
var shop_manager: Node
var _offer_buttons: Array[Button] = []

signal purchase_requested(index: int)
signal reroll_requested()
signal focus_restored()

func initialize(offers_cont: HBoxContainer, reroll_btn: Button) -> void:
	offers_container = offers_cont
	reroll_button = reroll_btn
	shop_manager = Globals.shop_manager
	
	if reroll_button:
		reroll_button.pressed.connect(_on_reroll_pressed)
		reroll_button.add_theme_font_override("font", MAIN_FONT)
	
	Events.shop_offers_generated.connect(_on_offers_generated)

func _on_offers_generated(offers: Array) -> void:
	# Release focus from current offer if present
	var focused = get_viewport().gui_get_focus_owner()
	if focused and offers_container.is_ancestor_of(focused):
		focused.release_focus()

	# Clear old children and offer buttons array
	for child in offers_container.get_children():
		child.queue_free()
	_offer_buttons.clear()

	# Create new offer slots
	for i in range(offers.size()):
		var offer = offers[i]
		var slot = create_offer_slot(offer, i)
		offers_container.add_child(slot)

	# Set up focus neighbors after a frame
	call_deferred("_setup_offer_focus_neighbors")
	call_deferred("_restore_focus")

func create_offer_slot(offer: Dictionary, index: int) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 300)
	panel.process_mode = Control.PROCESS_MODE_ALWAYS

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	if offer["type"] == "turret":
		_create_turret_offer_ui(offer, vbox)
	elif offer["type"] == "item":
		_create_item_offer_ui(offer, vbox)

	# Price label (common for both types)
	var price_label = Label.new()
	price_label.text = "%d Gold" % offer["price"]
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_override("font", MAIN_FONT)
	price_label.add_theme_font_size_override("font_size", 20)
	price_label.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(price_label)

	# Purchase button (common for both types)
	var button = Button.new()
	button.add_theme_font_override("font", MAIN_FONT)
	button.process_mode = Control.PROCESS_MODE_ALWAYS
	if offer.get("sold", false):
		button.text = "SOLD"
		button.disabled = true
	else:
		button.text = "Purchase"
		button.pressed.connect(func(): purchase_requested.emit(index))
		if Globals.total_gold < offer["price"]:
			button.disabled = true
	vbox.add_child(button)

	_offer_buttons.append(button)
	return panel

func _create_turret_offer_ui(offer: Dictionary, container: VBoxContainer) -> void:
	var turret_id = offer["turret_id"]
	var turret_config = TurretRegistry.get_type(turret_id)
	var turret_stats = Globals.get_turret_stats(turret_id)

	# Icon
	var icon = Label.new()
	icon.text = turret_config["icon"]
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_override("font", MAIN_FONT)
	icon.add_theme_font_size_override("font_size", 56)
	container.add_child(icon)

	# Name
	var name_label = Label.new()
	name_label.text = turret_config["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", MAIN_FONT)
	name_label.add_theme_font_size_override("font_size", 20)
	container.add_child(name_label)

	# Stats
	var stats_label = Label.new()
	stats_label.text = "Damage: %.0f\nRange: %.0f\nFire Rate: %.1f/s" % [
		turret_stats["damage"],
		turret_stats["range"],
		turret_stats["fire_rate"]
	]
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_override("font", MAIN_FONT)
	stats_label.add_theme_font_size_override("font_size", 14)
	container.add_child(stats_label)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(spacer)

func _create_item_offer_ui(offer: Dictionary, container: VBoxContainer) -> void:
	var item_id = offer["item_id"]
	var item_data = ItemRegistry.get_item_dict(item_id)

	# Icon
	var icon_label = Label.new()
	icon_label.text = item_data["icon"]
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_override("font", MAIN_FONT)
	icon_label.add_theme_font_size_override("font_size", 56)
	container.add_child(icon_label)

	# Name with rarity color
	var name_label = Label.new()
	name_label.text = item_data["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", MAIN_FONT)
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", ItemRegistry.get_rarity_color(item_data["rarity"]))
	container.add_child(name_label)

	# Description (only if it has unique effects)
	if ItemRegistry.should_show_description(item_id):
		var desc_label = Label.new()
		desc_label.text = item_data["description"]
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_label.add_theme_font_override("font", MAIN_FONT)
		desc_label.add_theme_font_size_override("font_size", 14)
		container.add_child(desc_label)

	# Modifiers display
	for modifier in item_data["modifiers"]:
		var mod_label = Label.new()
		mod_label.text = _format_modifier(modifier)
		mod_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mod_label.add_theme_font_override("font", MAIN_FONT)
		mod_label.add_theme_font_size_override("font_size", 13)
		
		var is_benefit = (modifier["operation"] == "multiply" and modifier["value"] > 1.0) or \
						  (modifier["operation"] == "add" and modifier["value"] > 0.0)
		mod_label.add_theme_color_override("font_color", Color.GREEN if is_benefit else Color.RED)
		container.add_child(mod_label)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(spacer)

func _format_modifier(modifier: Dictionary) -> String:
	var stat = modifier["stat"]
	var operation = modifier["operation"]
	var value = modifier["value"]

	var stat_name = stat.replace("_", " ").capitalize()
	var sign_str = "+"
	var display_value = 0.0
	var tag = ""

	# Check for filters and create a tag
	if modifier.has("filter"):
		var filter: Dictionary = modifier["filter"]
		if filter.has("turret_type"):
			var types: Array = filter["turret_type"]
			if not "all" in types:
				tag = " [%s]" % ", ".join(types).capitalize()
		elif filter.has("damage_type"):
			var d_types: Array = filter["damage_type"]
			var names = []
			for dt in d_types:
				names.append(GameEnums.DamageType.keys()[dt].capitalize())
			tag = " [%s]" % ", ".join(names)
		elif filter.has("attack_style"):
			var a_styles: Array = filter["attack_style"]
			var names = []
			for as_idx in a_styles:
				names.append(GameEnums.AttackStyle.keys()[as_idx].capitalize())
			tag = " [%s]" % ", ".join(names)

	if operation == "multiply":
		display_value = (value - 1.0) * 100.0
		sign_str = "+" if display_value > 0 else ""
		return "%s%.1f%% %s%s" % [sign_str, display_value, stat_name, tag]
	elif operation == "add":
		# Stats stored as decimals (0.0-1.0 range) that represent percentages
		var percentage_stats = ["player_luck", "turret_penalty_reduction"]

		if stat in percentage_stats:
			# Convert decimal to percentage (0.10 -> 10%)
			display_value = value * 100.0
			sign_str = "+" if display_value > 0 else ""
			return "%s%.0f%% %s%s" % [sign_str, display_value, stat_name, tag]
		else:
			# Absolute value stats (damage, health, range, etc.)
			display_value = value
			sign_str = "+" if value > 0 else ""
			return "%s%.0f %s%s" % [sign_str, display_value, stat_name, tag]

	return ""

func _setup_offer_focus_neighbors() -> void:
	for i in range(_offer_buttons.size()):
		var btn := _offer_buttons[i]
		if not is_instance_valid(btn):
			continue

		# Left neighbor
		if i > 0 and is_instance_valid(_offer_buttons[i - 1]):
			btn.focus_neighbor_left = _offer_buttons[i - 1].get_path()

		# Right neighbor
		if i < _offer_buttons.size() - 1 and is_instance_valid(_offer_buttons[i + 1]):
			btn.focus_neighbor_right = _offer_buttons[i + 1].get_path()

		# Down neighbor -> reroll button
		if reroll_button and is_instance_valid(reroll_button):
			btn.focus_neighbor_bottom = reroll_button.get_path()

	# Set up reroll button navigation
	if reroll_button and is_instance_valid(reroll_button):
		if not _offer_buttons.is_empty() and is_instance_valid(_offer_buttons[0]):
			reroll_button.focus_neighbor_top = _offer_buttons[0].get_path()

func _restore_focus() -> void:
	# Try to focus first non-sold offer button
	for btn in _offer_buttons:
		if is_instance_valid(btn) and not btn.disabled:
			btn.grab_focus()
			focus_restored.emit()
			return

	# If no purchasable offers, focus reroll if available
	if reroll_button and not reroll_button.disabled:
		reroll_button.grab_focus()
		focus_restored.emit()
		return

func _on_reroll_pressed() -> void:
	reroll_requested.emit()

func update_reroll_button() -> void:
	if shop_manager and reroll_button:
		var cost = shop_manager.get_reroll_cost()
		reroll_button.text = "Reroll (Cost: %d)" % cost
		reroll_button.disabled = not shop_manager.can_afford_reroll()

func regenerate_offers() -> void:
	_on_offers_generated(Globals.current_shop_offers)

func get_offer_buttons() -> Array[Button]:
	return _offer_buttons
