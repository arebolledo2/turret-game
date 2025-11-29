extends Control

@onready var shop_panel: PanelContainer = $ShopPanel
@onready var title_label: Label = $ShopPanel/VBoxContainer/Header/TitleLabel
@onready var gold_label: Label = $ShopPanel/VBoxContainer/Header/GoldLabel
@onready var offers_container: HBoxContainer = $ShopPanel/VBoxContainer/OffersContainer
@onready var reroll_button: Button = $ShopPanel/VBoxContainer/RerollContainer/RerollButton
@onready var continue_button: Button = $ShopPanel/VBoxContainer/ButtonContainer/ContinueButton

var shop_manager: Node
var regeneration_pending: bool = false

func _ready() -> void:
	visible = false
	shop_manager = get_node_or_null("/root/Main/ShopManager")

	Events.shop_opened.connect(_on_shop_opened)
	Events.shop_closed.connect(_on_shop_closed)
	Events.shop_offers_generated.connect(_on_offers_generated)
	Events.gold_collected.connect(_on_gold_changed)
	Events.gold_spent.connect(_on_gold_changed)
	Events.shop_purchase_made.connect(_on_purchase_made)
	Events.shop_insufficient_funds.connect(_on_insufficient_funds)

	continue_button.pressed.connect(_on_continue_pressed)
	reroll_button.pressed.connect(_on_reroll_pressed)

func _on_shop_opened(wave_number: int) -> void:
	visible = true
	get_tree().paused = true  # Pause the game when shop opens
	title_label.text = "TURRET SHOP - WAVE %d" % wave_number
	update_gold_display()
	update_reroll_button()

	modulate.a = 0.0
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # Process tween even when paused
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	continue_button.grab_focus()

func _on_shop_closed() -> void:
	# Unpause immediately so game can continue while we fade out
	get_tree().paused = false
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func():
		visible = false
	)

func _on_offers_generated(offers: Array) -> void:
	# First, release focus from any child that might have it
	var focused = get_viewport().gui_get_focus_owner()
	if focused and offers_container.is_ancestor_of(focused):
		focused.release_focus()
	
	# Clear old children
	for child in offers_container.get_children():
		child.queue_free()
	
	# Now create new offer slots
	for i in range(offers.size()):
		var offer = offers[i]
		var slot = create_offer_slot(offer, i)
		offers_container.add_child(slot)
	
	# Restore focus to continue button after a frame to ensure layout is updated
	call_deferred("_restore_focus")

func create_offer_slot(offer: Dictionary, index: int) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 280)
	panel.process_mode = PROCESS_MODE_ALWAYS  # Allow interaction when paused

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	if offer["type"] == "turret":
		var turret_id = offer["turret_id"]
		var turret_config = Globals.TURRET_TYPES[turret_id]
		var turret_stats = Globals.get_turret_stats(turret_id)

		# Icon
		var icon = Label.new()
		icon.text = turret_config["icon"]
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.add_theme_font_size_override("font_size", 48)
		vbox.add_child(icon)

		# Name
		var name_label = Label.new()
		name_label.text = turret_config["name"]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_label)

		# Stats
		var stats_label = Label.new()
		stats_label.text = "Damage: %.0f\nRange: %.0f\nFire Rate: %.1f/s" % [
			turret_stats["damage"],
			turret_stats["range"],
			turret_stats["fire_rate"]
		]
		stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_label.add_theme_font_size_override("font_size", 12)
		vbox.add_child(stats_label)

		# Spacer
		var spacer = Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(spacer)

		# Price
		var price_label = Label.new()
		price_label.text = "%d Gold" % offer["price"]
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_label.add_theme_font_size_override("font_size", 16)
		price_label.add_theme_color_override("font_color", Color.GOLD)
		vbox.add_child(price_label)

		# Purchase button
		var button = Button.new()
		button.process_mode = PROCESS_MODE_ALWAYS  # Allow interaction when paused
		if offer.get("sold", false):
			button.text = "SOLD"
			button.disabled = true
		else:
			button.text = "Purchase"
			button.pressed.connect(func(): _on_purchase_pressed(index))
			if Globals.total_gold < offer["price"]:
				button.disabled = true
		vbox.add_child(button)

	return panel

func _on_purchase_pressed(index: int) -> void:
	if shop_manager:
		shop_manager.purchase_offer(index)

func _restore_focus() -> void:
	if continue_button and is_instance_valid(continue_button):
		continue_button.grab_focus()

func _on_purchase_made(_offer: Dictionary) -> void:
	# Defer regeneration to avoid freeing the button that was just clicked
	_request_regeneration()
	update_reroll_button()

func _request_regeneration() -> void:
	if not regeneration_pending:
		regeneration_pending = true
		call_deferred("_regenerate_offers")

func _regenerate_offers() -> void:
	regeneration_pending = false
	_on_offers_generated(Globals.current_shop_offers)

func _on_reroll_pressed() -> void:
	if shop_manager:
		shop_manager.reroll_shop()
	update_reroll_button()

func update_reroll_button() -> void:
	if shop_manager:
		var cost = shop_manager.get_reroll_cost()
		reroll_button.text = "Reroll (Cost: %d)" % cost
		reroll_button.disabled = not shop_manager.can_afford_reroll()

		if Globals.shop_reroll_count >= Globals.MAX_REROLLS_PER_WAVE:
			reroll_button.text = "Max Rerolls Reached"

func _on_continue_pressed() -> void:
	var game_manager = get_node_or_null("/root/Main/GameManager")
	if game_manager and game_manager.has_method("end_shop_phase"):
		game_manager.end_shop_phase()

func _on_gold_changed(_amount: int, total: int) -> void:
	update_gold_display()
	# Defer regeneration to avoid conflicts with purchase handling
	_request_regeneration()

func update_gold_display() -> void:
	gold_label.text = "Gold: %d" % Globals.total_gold

func _on_insufficient_funds(required: int, current: int) -> void:
	var tween = create_tween()
	tween.tween_property(gold_label, "modulate", Color.RED, 0.1)
	tween.tween_property(gold_label, "modulate", Color.WHITE, 0.1)
