extends Control

## Shop screen orchestrator - uses StatsPanel and InventoryPanel components

const BuildDisplayUIScript = preload("res://scripts/ui/build_display_ui.gd")

# Preload shop offers panel script
const ShopOffersPanelScript = preload("res://scripts/ui/shop/shop_offers_panel.gd")

# UI References
@onready var title_label: Label = $MainContainer/ContentVBox/Header/TitleLabel
@onready var scrap_label: Label = $MainContainer/ContentVBox/Header/ScrapLabel
@onready var offers_container: HBoxContainer = $MainContainer/ContentVBox/MainHBox/LeftPanel/OffersContainer
@onready var tech_tree_panel: VBoxContainer = $MainContainer/ContentVBox/MainHBox/LeftPanel/TechTreePanel
@onready var reroll_button: Button = $MainContainer/ContentVBox/MainHBox/LeftPanel/RerollContainer/RerollButton
@onready var tech_tree_button: Button = $MainContainer/ContentVBox/MainHBox/LeftPanel/RerollContainer/TechTreeButton
@onready var continue_button: Button = $MainContainer/ContentVBox/MainHBox/LeftPanel/RerollContainer/ContinueButton

# Component references
@onready var stats_panel: VBoxContainer = $MainContainer/ContentVBox/MainHBox/RightPanel/StatsPanel
@onready var inventory_panel: VBoxContainer = $MainContainer/ContentVBox/BottomPanel/InventoryPanel

# Panel handler for shop offers
var offers_panel
var shop_manager: Node
var regeneration_pending: bool = false
var showing_tech_tree: bool = false


func _ready() -> void:
	visible = false
	shop_manager = get_node_or_null("/root/Main/ShopManager")

	# Initialize offers panel handler
	offers_panel = ShopOffersPanelScript.new()
	add_child(offers_panel)
	offers_panel.initialize(offers_container, reroll_button)

	# Connect events
	Events.shop_opened.connect(_on_shop_opened)
	Events.shop_closed.connect(_on_shop_closed)
	Events.scrap_collected.connect(_on_scrap_changed)
	Events.scrap_spent.connect(_on_scrap_changed)
	Events.shop_purchase_made.connect(_on_purchase_made)
	Events.shop_insufficient_funds.connect(_on_insufficient_funds)

	# Connect panel signals
	offers_panel.purchase_requested.connect(_on_purchase_pressed)
	offers_panel.reroll_requested.connect(_on_reroll_pressed)
	offers_panel.focus_restored.connect(_setup_focus_neighbors)

	continue_button.pressed.connect(_on_continue_pressed)
	tech_tree_button.pressed.connect(_on_tech_tree_button_pressed)


func _unhandled_input(_event: InputEvent) -> void:
	if not visible:
		return
	# Can add tab navigation for stats/inventory if needed later


func _on_shop_opened(wave_number: int) -> void:
	visible = true
	get_tree().paused = true
	
	# Apply fonts to header elements
	if title_label:
		title_label.add_theme_font_size_override("font_size", 42)
		title_label.add_theme_color_override("font_outline_color", Color.BLACK)
		title_label.add_theme_constant_override("outline_size", 6)

	if scrap_label:
		scrap_label.add_theme_font_size_override("font_size", 32)
		scrap_label.add_theme_color_override("font_outline_color", Color.BLACK)
		scrap_label.add_theme_constant_override("outline_size", 4)

	if reroll_button:
		reroll_button.add_theme_font_size_override("font_size", 28)
		reroll_button.add_theme_constant_override("outline_size", 6)
		reroll_button.add_theme_color_override("font_outline_color", Color.BLACK)

	if continue_button:
		continue_button.add_theme_font_size_override("font_size", 32)
		continue_button.add_theme_constant_override("outline_size", 6)
		continue_button.add_theme_color_override("font_outline_color", Color.BLACK)
	
	title_label.text = "TURRET SHOP - WAVE %d" % wave_number
	update_scrap_display()
	offers_panel.update_reroll_button()
	_update_panels()

	# Fade in animation
	modulate.a = 0.0
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	continue_button.grab_focus()


func _on_shop_closed() -> void:
	get_tree().paused = false
	
	# Fade out animation
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): visible = false)


func _on_purchase_pressed(index: int) -> void:
	if shop_manager:
		shop_manager.purchase_offer(index)


func _on_purchase_made(_offer: Dictionary) -> void:
	_request_regeneration()
	offers_panel.update_reroll_button()
	_update_panels()


func _request_regeneration() -> void:
	if not regeneration_pending:
		regeneration_pending = true
		call_deferred("_regenerate_offers")


func _regenerate_offers() -> void:
	regeneration_pending = false
	offers_panel.regenerate_offers()


func _on_reroll_pressed() -> void:
	if shop_manager:
		shop_manager.reroll_shop()
	offers_panel.update_reroll_button()


func _on_continue_pressed() -> void:
	var game_manager = get_node_or_null("/root/Main/GameManager")
	if game_manager and game_manager.has_method("end_shop_phase"):
		game_manager.end_shop_phase()


func _on_tech_tree_button_pressed() -> void:
	showing_tech_tree = not showing_tech_tree

	if showing_tech_tree:
		# Show tech tree, hide offers
		offers_container.visible = false
		tech_tree_panel.visible = true
		reroll_button.visible = false
		tech_tree_button.text = "🛒 Shop"
	else:
		# Show offers, hide tech tree
		offers_container.visible = true
		tech_tree_panel.visible = false
		reroll_button.visible = true
		tech_tree_button.text = "🔬 Tech Tree"


func _on_scrap_changed(_amount: int, _total: int) -> void:
	update_scrap_display()
	_request_regeneration()


func update_scrap_display() -> void:
	scrap_label.text = "💰 %d" % EconomyService.total_scrap


func _on_insufficient_funds(_required: int, _current: int) -> void:
	var tween = create_tween()
	tween.tween_property(scrap_label, "modulate", Color.RED, 0.1)
	tween.tween_property(scrap_label, "modulate", Color.WHITE, 0.1)


func _update_panels() -> void:
	if stats_panel and stats_panel.has_method("refresh"):
		stats_panel.refresh()
	if inventory_panel and inventory_panel.has_method("refresh"):
		inventory_panel.refresh()
	_setup_focus_neighbors()


func _setup_focus_neighbors() -> void:
	var turret_buttons = inventory_panel.get_turret_buttons() if inventory_panel else []
	var item_buttons = inventory_panel.get_item_buttons() if inventory_panel else []

	# Connect reroll and continue buttons (horizontal navigation)
	if reroll_button and continue_button:
		reroll_button.focus_neighbor_right = continue_button.get_path()
		continue_button.focus_neighbor_left = reroll_button.get_path()

		# Connect to offers above (Biased Navigation)
		var offer_buttons_bottom = offers_panel.get_bottom_row_buttons()
		if not offer_buttons_bottom.is_empty():
			# Reroll (left side) favors: 2nd item -> 1st -> 3rd -> 4th
			var reroll_search_order = [1, 0, 2, 3]
			var reroll_target = null
			for idx in reroll_search_order:
				if idx < offer_buttons_bottom.size() and is_instance_valid(offer_buttons_bottom[idx]):
					var btn = offer_buttons_bottom[idx]
					if not btn.disabled:
						reroll_target = btn
						break
			if reroll_target:
				reroll_button.focus_neighbor_top = reroll_target.get_path()

			# Continue (right side) favors: 3rd item -> 4th -> 2nd -> 1st
			var continue_search_order = [2, 3, 1, 0]
			var continue_target = null
			for idx in continue_search_order:
				if idx < offer_buttons_bottom.size() and is_instance_valid(offer_buttons_bottom[idx]):
					var btn = offer_buttons_bottom[idx]
					if not btn.disabled:
						continue_target = btn
						break
			if continue_target:
				continue_button.focus_neighbor_top = continue_target.get_path()

		# Connect down to turrets or items
		var down_target: Control = null
		if not turret_buttons.is_empty():
			down_target = turret_buttons[0]
		elif not item_buttons.is_empty():
			down_target = item_buttons[0]
		
		if down_target:
			reroll_button.focus_neighbor_bottom = down_target.get_path()
			continue_button.focus_neighbor_bottom = down_target.get_path()

	# Set up turret button focus
	if not turret_buttons.is_empty():
		var down_target: Control = item_buttons[0] if not item_buttons.is_empty() else continue_button
		BuildDisplayUIScript.setup_focus_neighbors(turret_buttons, reroll_button, down_target)
	
	# Set up item button focus
	if not item_buttons.is_empty():
		var up_target: Control = turret_buttons[turret_buttons.size() - 1] if not turret_buttons.is_empty() else reroll_button
		BuildDisplayUIScript.setup_focus_neighbors(item_buttons, up_target, continue_button)
		
		# Connect turret buttons down to items
		for i in range(turret_buttons.size()):
			if item_buttons.size() > 0:
				var item_idx := mini(i, item_buttons.size() - 1)
				turret_buttons[i].focus_neighbor_bottom = item_buttons[item_idx].get_path()
