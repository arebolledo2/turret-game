extends Control

const BuildDisplayUIScript = preload("res://scripts/ui/build_display_ui.gd")

const MAIN_FONT = preload("res://addons/gut/fonts/AnonymousPro-Regular.ttf")

@onready var shop_panel: PanelContainer = $ShopPanel
@onready var title_label: Label = $ShopPanel/VBoxContainer/Header/TitleLabel
@onready var gold_label: Label = $ShopPanel/VBoxContainer/Header/GoldLabel
@onready var offers_container: HBoxContainer = $ShopPanel/VBoxContainer/OffersContainer
@onready var reroll_button: Button = $ShopPanel/VBoxContainer/RerollContainer/RerollButton
@onready var continue_button: Button = $ShopPanel/VBoxContainer/ButtonContainer/ContinueButton

# Build tabs
@onready var build_tabs: TabContainer = $ShopPanel/VBoxContainer/PlayerBuildSection/PlayerBuildVBox/BuildTabs
@onready var player_stats_vbox: VBoxContainer = $ShopPanel/VBoxContainer/PlayerBuildSection/PlayerBuildVBox/BuildTabs/Player/PlayerStatsVBox
@onready var economy_stats_vbox: VBoxContainer = $ShopPanel/VBoxContainer/PlayerBuildSection/PlayerBuildVBox/BuildTabs/Economy/EconomyStatsVBox

# Turrets tab
@onready var turrets_title: Label = $ShopPanel/VBoxContainer/PlayerBuildSection/PlayerBuildVBox/BuildTabs/Turrets/TurretsSection/TurretsHeader/TurretsTitle
@onready var turrets_hint: Label = $ShopPanel/VBoxContainer/PlayerBuildSection/PlayerBuildVBox/BuildTabs/Turrets/TurretsSection/TurretsHeader/TurretsHint
@onready var turret_icons_row: HBoxContainer = $ShopPanel/VBoxContainer/PlayerBuildSection/PlayerBuildVBox/BuildTabs/Turrets/TurretsSection/TurretIconsRow
@onready var turret_details_panel: PanelContainer = $ShopPanel/VBoxContainer/PlayerBuildSection/PlayerBuildVBox/BuildTabs/Turrets/TurretsSection/TurretDetailsPanel
@onready var turret_name_label: Label = $ShopPanel/VBoxContainer/PlayerBuildSection/PlayerBuildVBox/BuildTabs/Turrets/TurretsSection/TurretDetailsPanel/TurretDetailsVBox/TurretName
@onready var turret_damage_label: Label = $ShopPanel/VBoxContainer/PlayerBuildSection/PlayerBuildVBox/BuildTabs/Turrets/TurretsSection/TurretDetailsPanel/TurretDetailsVBox/StatsHBox/LeftStats/DamageLabel
@onready var turret_range_label: Label = $ShopPanel/VBoxContainer/PlayerBuildSection/PlayerBuildVBox/BuildTabs/Turrets/TurretsSection/TurretDetailsPanel/TurretDetailsVBox/StatsHBox/LeftStats/RangeLabel
@onready var turret_fire_rate_label: Label = $ShopPanel/VBoxContainer/PlayerBuildSection/PlayerBuildVBox/BuildTabs/Turrets/TurretsSection/TurretDetailsPanel/TurretDetailsVBox/StatsHBox/LeftStats/FireRateLabel
@onready var turret_rotation_label: Label = $ShopPanel/VBoxContainer/PlayerBuildSection/PlayerBuildVBox/BuildTabs/Turrets/TurretsSection/TurretDetailsPanel/TurretDetailsVBox/StatsHBox/RightStats/RotationLabel
@onready var turret_proj_speed_label: Label = $ShopPanel/VBoxContainer/PlayerBuildSection/PlayerBuildVBox/BuildTabs/Turrets/TurretsSection/TurretDetailsPanel/TurretDetailsVBox/StatsHBox/RightStats/ProjSpeedLabel
@onready var turret_dps_label: Label = $ShopPanel/VBoxContainer/PlayerBuildSection/PlayerBuildVBox/BuildTabs/Turrets/TurretsSection/TurretDetailsPanel/TurretDetailsVBox/StatsHBox/RightStats/DPSLabel

# Items tab
@onready var items_title: Label = $ShopPanel/VBoxContainer/PlayerBuildSection/PlayerBuildVBox/BuildTabs/Items/ItemsSection/ItemsHeader/ItemsTitle
@onready var items_hint: Label = $ShopPanel/VBoxContainer/PlayerBuildSection/PlayerBuildVBox/BuildTabs/Items/ItemsSection/ItemsHeader/ItemsHint
@onready var items_scroll: ScrollContainer = $ShopPanel/VBoxContainer/PlayerBuildSection/PlayerBuildVBox/BuildTabs/Items/ItemsSection/ItemsScrollContainer
@onready var items_hbox: HBoxContainer = $ShopPanel/VBoxContainer/PlayerBuildSection/PlayerBuildVBox/BuildTabs/Items/ItemsSection/ItemsScrollContainer/ItemsHBox
@onready var no_items_label: Label = $ShopPanel/VBoxContainer/PlayerBuildSection/PlayerBuildVBox/BuildTabs/Items/ItemsSection/NoItemsLabel
@onready var item_details_panel: PanelContainer = $ShopPanel/VBoxContainer/PlayerBuildSection/PlayerBuildVBox/BuildTabs/Items/ItemsSection/ItemDetailsPanel
@onready var item_icon_label: Label = $ShopPanel/VBoxContainer/PlayerBuildSection/PlayerBuildVBox/BuildTabs/Items/ItemsSection/ItemDetailsPanel/ItemDetailsVBox/ItemHeader/ItemIcon
@onready var item_name_label: Label = $ShopPanel/VBoxContainer/PlayerBuildSection/PlayerBuildVBox/BuildTabs/Items/ItemsSection/ItemDetailsPanel/ItemDetailsVBox/ItemHeader/ItemName
@onready var item_rarity_label: Label = $ShopPanel/VBoxContainer/PlayerBuildSection/PlayerBuildVBox/BuildTabs/Items/ItemsSection/ItemDetailsPanel/ItemDetailsVBox/ItemHeader/ItemRarity
@onready var item_description_label: Label = $ShopPanel/VBoxContainer/PlayerBuildSection/PlayerBuildVBox/BuildTabs/Items/ItemsSection/ItemDetailsPanel/ItemDetailsVBox/ItemDescription

var shop_manager: Node
var regeneration_pending: bool = false
var _player: Node2D = null
var _selected_turret_type: String = ""
var _selected_item_id: String = ""
var _turret_buttons: Array[Button] = []
var _item_buttons: Array[Button] = []
var _offer_buttons: Array[Button] = []

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

	# Get player reference
	_player = get_tree().get_first_node_in_group("player")

func _on_shop_opened(wave_number: int) -> void:
	visible = true
	get_tree().paused = true  # Pause the game when shop opens
	
	title_label.add_theme_font_override("font", MAIN_FONT)
	title_label.add_theme_font_size_override("font_size", 32)
	gold_label.add_theme_font_override("font", MAIN_FONT)
	gold_label.add_theme_font_size_override("font_size", 24)
	reroll_button.add_theme_font_override("font", MAIN_FONT)
	continue_button.add_theme_font_override("font", MAIN_FONT)
	
	title_label.text = "TURRET SHOP - WAVE %d" % wave_number
	update_gold_display()
	update_reroll_button()
	update_player_build()

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

	# Clear old children and offer buttons array
	for child in offers_container.get_children():
		child.queue_free()
	_offer_buttons.clear()

	# Now create new offer slots
	for i in range(offers.size()):
		var offer = offers[i]
		var slot = create_offer_slot(offer, i)
		offers_container.add_child(slot)

	# Set up focus neighbors for offer buttons after a frame (to ensure nodes are ready)
	call_deferred("_setup_offer_focus_neighbors")

	# Restore focus after layout is updated
	call_deferred("_restore_focus")

func create_offer_slot(offer: Dictionary, index: int) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 300)
	panel.process_mode = PROCESS_MODE_ALWAYS  # Allow interaction when paused

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	if offer["type"] == "turret":
		var turret_id = offer["turret_id"]
		var turret_config = TurretRegistry.get_type(turret_id)
		var turret_stats = Globals.get_turret_stats(turret_id)

		# Icon
		var icon = Label.new()
		icon.text = turret_config["icon"]
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.add_theme_font_override("font", MAIN_FONT)
		icon.add_theme_font_size_override("font_size", 56)
		vbox.add_child(icon)

		# Name
		var name_label = Label.new()
		name_label.text = turret_config["name"]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_override("font", MAIN_FONT)
		name_label.add_theme_font_size_override("font_size", 20)
		vbox.add_child(name_label)

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
		vbox.add_child(stats_label)

		# Spacer
		var spacer = Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(spacer)
	elif offer["type"] == "item":
		create_item_ui(offer, vbox)

	# Price (common for both turrets and items)
	var price_label = Label.new()
	price_label.text = "%d Gold" % offer["price"]
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_override("font", MAIN_FONT)
	price_label.add_theme_font_size_override("font_size", 20)
	price_label.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(price_label)

	# Purchase button (common for both turrets and items)
	var button = Button.new()
	button.add_theme_font_override("font", MAIN_FONT)
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

	# Track the button for focus navigation
	_offer_buttons.append(button)

	return panel

func create_item_ui(offer: Dictionary, container: VBoxContainer) -> void:
	var item_id = offer["item_id"]
	var item_data = ItemRegistry.get_item(item_id)

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
		mod_label.text = format_modifier(modifier)
		mod_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mod_label.add_theme_font_override("font", MAIN_FONT)
		mod_label.add_theme_font_size_override("font_size", 13)
		# Green for benefits (value > 1.0 for multiply), red for drawbacks
		var is_benefit = (modifier["operation"] == "multiply" and modifier["value"] > 1.0) or \
						  (modifier["operation"] == "add" and modifier["value"] > 0.0)
		mod_label.add_theme_color_override("font_color", Color.GREEN if is_benefit else Color.RED)
		container.add_child(mod_label)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(spacer)

func format_modifier(modifier: Dictionary) -> String:
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
		display_value = (value - 1.0) * 100.0  # Convert to percentage
		sign_str = "+" if display_value > 0 else ""
		return "%s%.1f%% %s%s" % [sign_str, display_value, stat_name, tag]
	elif operation == "add":
		display_value = value
		sign_str = "+" if value > 0 else ""
		return "%s%.0f %s%s" % [sign_str, display_value, stat_name, tag]  # Absolute value (no %)

	return ""

func _on_purchase_pressed(index: int) -> void:
	if shop_manager:
		shop_manager.purchase_offer(index)

func _setup_offer_focus_neighbors() -> void:
	# Set up left/right navigation between offer buttons
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
		# Up -> first offer button (or stay if none)
		if not _offer_buttons.is_empty() and is_instance_valid(_offer_buttons[0]):
			reroll_button.focus_neighbor_top = _offer_buttons[0].get_path()
		# Down -> continue button
		if continue_button and is_instance_valid(continue_button):
			reroll_button.focus_neighbor_bottom = continue_button.get_path()

	# Set up continue button navigation
	if continue_button and is_instance_valid(continue_button):
		# Up -> reroll button
		if reroll_button and is_instance_valid(reroll_button):
			continue_button.focus_neighbor_top = reroll_button.get_path()

func _restore_focus() -> void:
	# Try to focus first non-sold offer button
	for btn in _offer_buttons:
		if is_instance_valid(btn) and not btn.disabled:
			btn.grab_focus()
			return

	# If no purchasable offers, focus reroll if available
	if reroll_button and not reroll_button.disabled:
		reroll_button.grab_focus()
		return

	# Fallback to continue button
	if continue_button and is_instance_valid(continue_button):
		continue_button.grab_focus()

func _on_purchase_made(_offer: Dictionary) -> void:
	# Defer regeneration to avoid freeing the button that was just clicked
	_request_regeneration()
	update_reroll_button()
	# Update player build display to show new stats/turrets/items
	update_player_build()

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


func update_player_build() -> void:
	# Get player reference if not available
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

	_update_player_tab()
	_update_economy_tab()
	_update_turrets_tab()
	_update_items_tab()
	_setup_build_focus_neighbors()


func _update_player_tab() -> void:
	if not player_stats_vbox:
		return

	# Clear existing stat labels
	for child in player_stats_vbox.get_children():
		child.queue_free()

	# Base player constants (from player.gd defaults)
	const BASE_MAX_HEALTH := 100.0
	const BASE_SPEED := 300.0

	# Get modified values
	var modified_max_health := Globals.get_player_max_health()
	var modified_speed := Globals.get_player_speed()

	# Get current player health
	var health_current := 100
	var health_max := int(modified_max_health)
	if is_instance_valid(_player):
		health_current = int(_player.current_health)

	var luck := Globals.get_player_luck_display()
	var xp := Globals.total_xp
	var kills := Globals.total_kills
	var minutes := int(Globals.time_survived) / 60
	var seconds := int(Globals.time_survived) % 60

	# Create stat labels
	var health_label := Label.new()
	health_label.text = "❤ Health: %d/%d" % [health_current, health_max]
	if not is_equal_approx(modified_max_health, BASE_MAX_HEALTH):
		health_label.text += " (base: %d)" % int(BASE_MAX_HEALTH)
		health_label.add_theme_color_override("font_color", Color.GREEN)
	health_label.add_theme_font_override("font", MAIN_FONT)
	health_label.add_theme_font_size_override("font_size", 15)
	player_stats_vbox.add_child(health_label)

	# Speed stat with base/modified
	var speed_stat := BuildDisplayUIScript.format_stat_with_modifier("⚡ Speed", BASE_SPEED, modified_speed, "%.0f", true)
	var speed_label := Label.new()
	speed_label.text = speed_stat["text"]
	speed_label.add_theme_color_override("font_color", speed_stat["color"])
	speed_label.add_theme_font_override("font", MAIN_FONT)
	speed_label.add_theme_font_size_override("font_size", 15)
	player_stats_vbox.add_child(speed_label)

	# Luck
	var luck_label := Label.new()
	luck_label.text = "🍀 Luck: %d" % luck
	luck_label.add_theme_font_override("font", MAIN_FONT)
	luck_label.add_theme_font_size_override("font_size", 15)
	player_stats_vbox.add_child(luck_label)

	# XP
	var xp_label := Label.new()
	xp_label.text = "✨ XP: %d" % xp
	xp_label.add_theme_font_override("font", MAIN_FONT)
	xp_label.add_theme_font_size_override("font_size", 15)
	player_stats_vbox.add_child(xp_label)

	# Kills
	var kills_label := Label.new()
	kills_label.text = "💀 Kills: %d" % kills
	kills_label.add_theme_font_override("font", MAIN_FONT)
	kills_label.add_theme_font_size_override("font_size", 15)
	player_stats_vbox.add_child(kills_label)

	# Time
	var time_label := Label.new()
	time_label.text = "⏱ Time: %d:%02d" % [minutes, seconds]
	time_label.add_theme_font_override("font", MAIN_FONT)
	time_label.add_theme_font_size_override("font_size", 15)
	player_stats_vbox.add_child(time_label)


func _update_economy_tab() -> void:
	if not economy_stats_vbox:
		return

	# Clear existing labels
	for child in economy_stats_vbox.get_children():
		child.queue_free()

	# Economy section header
	var economy_header := Label.new()
	economy_header.text = "💰 ECONOMY STATS"
	economy_header.add_theme_font_override("font", MAIN_FONT)
	economy_header.add_theme_font_size_override("font_size", 18)
	economy_header.add_theme_color_override("font_color", Color(1, 0.84, 0, 1))
	economy_stats_vbox.add_child(economy_header)

	# Current Gold
	var current_gold_label := Label.new()
	current_gold_label.text = "Gold: %d" % Globals.total_gold
	current_gold_label.add_theme_font_override("font", MAIN_FONT)
	current_gold_label.add_theme_font_size_override("font_size", 15)
	economy_stats_vbox.add_child(current_gold_label)

	# Gold Earn Multiplier
	var gold_mult := Globals.get_gold_earn_multiplier()
	var gold_mult_stat := BuildDisplayUIScript.format_stat_with_modifier("Gold Earn", 100.0, gold_mult * 100.0, "%.0f%%", true)
	var gold_mult_label := Label.new()
	gold_mult_label.text = gold_mult_stat["text"]
	gold_mult_label.add_theme_color_override("font_color", gold_mult_stat["color"])
	gold_mult_label.add_theme_font_override("font", MAIN_FONT)
	gold_mult_label.add_theme_font_size_override("font_size", 15)
	economy_stats_vbox.add_child(gold_mult_label)

	# Shop Price Multiplier
	var price_mult := Globals.get_shop_price_multiplier()
	var price_mult_stat := BuildDisplayUIScript.format_stat_with_modifier("Shop Prices", 100.0, price_mult * 100.0, "%.0f%%", false)
	var price_mult_label := Label.new()
	price_mult_label.text = price_mult_stat["text"]
	price_mult_label.add_theme_color_override("font_color", price_mult_stat["color"])
	price_mult_label.add_theme_font_override("font", MAIN_FONT)
	price_mult_label.add_theme_font_size_override("font_size", 15)
	economy_stats_vbox.add_child(price_mult_label)

	# Turret Penalty
	var penalty := Globals.get_turret_purchase_penalty()
	var penalty_stat := BuildDisplayUIScript.format_stat_with_modifier("Turret Penalty", 25.0, penalty * 100.0, "%.0f%% per turret", false)
	var penalty_label := Label.new()
	penalty_label.text = penalty_stat["text"]
	penalty_label.add_theme_color_override("font_color", penalty_stat["color"])
	penalty_label.add_theme_font_override("font", MAIN_FONT)
	penalty_label.add_theme_font_size_override("font_size", 15)
	economy_stats_vbox.add_child(penalty_label)

	# Reroll Cost
	var reroll_cost: int = shop_manager.get_reroll_cost() if shop_manager else 0
	var reroll_cost_label := Label.new()
	reroll_cost_label.text = "Reroll Cost: %dg" % reroll_cost
	reroll_cost_label.add_theme_font_override("font", MAIN_FONT)
	reroll_cost_label.add_theme_font_size_override("font_size", 15)
	economy_stats_vbox.add_child(reroll_cost_label)

	# Separator
	var sep := HSeparator.new()
	economy_stats_vbox.add_child(sep)

	# Progress section header
	var progress_header := Label.new()
	progress_header.text = "📊 GAME PROGRESS"
	progress_header.add_theme_font_override("font", MAIN_FONT)
	progress_header.add_theme_font_size_override("font_size", 18)
	progress_header.add_theme_color_override("font_color", Color(0.7, 0.7, 1, 1))
	economy_stats_vbox.add_child(progress_header)

	# Wave
	var wave_label := Label.new()
	wave_label.text = "Wave: %d" % Globals.current_wave
	wave_label.add_theme_font_override("font", MAIN_FONT)
	wave_label.add_theme_font_size_override("font_size", 15)
	economy_stats_vbox.add_child(wave_label)

	# Turrets Owned
	var turrets_owned_label := Label.new()
	turrets_owned_label.text = "Turrets Owned: %d" % Globals.get_total_turret_count()
	turrets_owned_label.add_theme_font_override("font", MAIN_FONT)
	turrets_owned_label.add_theme_font_size_override("font_size", 15)
	economy_stats_vbox.add_child(turrets_owned_label)

	# Items Collected
	var items_collected_label := Label.new()
	items_collected_label.text = "Items Collected: %d" % Globals.collected_items.size()
	items_collected_label.add_theme_font_override("font", MAIN_FONT)
	items_collected_label.add_theme_font_size_override("font_size", 15)
	economy_stats_vbox.add_child(items_collected_label)

	# Turrets Purchased (total)
	var turrets_purchased_label := Label.new()
	turrets_purchased_label.text = "Turrets Purchased: %d" % Globals.turrets_purchased
	turrets_purchased_label.add_theme_font_override("font", MAIN_FONT)
	turrets_purchased_label.add_theme_font_size_override("font_size", 15)
	economy_stats_vbox.add_child(turrets_purchased_label)


func _update_turrets_tab() -> void:
	var total_turrets := Globals.get_total_turret_count()
	
	if turrets_title:
		turrets_title.add_theme_font_override("font", MAIN_FONT)
		turrets_title.text = "TURRETS (%d)" % total_turrets
	
	_turret_buttons.clear()
	
	# Clear existing icons (except the "no turrets" label)
	if turret_icons_row:
		for child in turret_icons_row.get_children():
			if child.name != "NoTurretsLabel":
				child.queue_free()
	
	var has_turrets := total_turrets > 0
	
	if turret_icons_row:
		var no_turrets_label = turret_icons_row.get_node_or_null("NoTurretsLabel")
		if no_turrets_label:
			no_turrets_label.visible = not has_turrets
	
	if turrets_hint:
		turrets_hint.visible = has_turrets
	
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
		_update_turret_details(_selected_turret_type)


func _on_turret_icon_pressed(type: String) -> void:
	_selected_turret_type = type
	_update_turret_details(type)


func _update_turret_details(type: String) -> void:
	var nodes: Dictionary = {
		"turret_name_label": turret_name_label,
		"damage_label": turret_damage_label,
		"range_label": turret_range_label,
		"fire_rate_label": turret_fire_rate_label,
		"rotation_label": turret_rotation_label,
		"proj_speed_label": turret_proj_speed_label,
		"dps_label": turret_dps_label,
	}
	BuildDisplayUIScript.update_turret_details(nodes, type)


func _update_items_tab() -> void:
	var unique_item_count := Globals.item_counts.size()
	var total_item_count := 0
	for count in Globals.item_counts.values():
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


func _setup_build_focus_neighbors() -> void:
	# Set up turret button focus
	if not _turret_buttons.is_empty():
		var down_target: Control = _item_buttons[0] if not _item_buttons.is_empty() else continue_button
		BuildDisplayUIScript.setup_focus_neighbors(_turret_buttons, reroll_button, down_target)
	
	# Set up item button focus
	if not _item_buttons.is_empty():
		var up_target: Control = _turret_buttons[_turret_buttons.size() - 1] if not _turret_buttons.is_empty() else reroll_button
		BuildDisplayUIScript.setup_focus_neighbors(_item_buttons, up_target, continue_button)
		
		# Connect turret buttons down to items
		for i in range(_turret_buttons.size()):
			if _item_buttons.size() > 0:
				var item_idx := mini(i, _item_buttons.size() - 1)
				_turret_buttons[i].focus_neighbor_bottom = _item_buttons[item_idx].get_path()
