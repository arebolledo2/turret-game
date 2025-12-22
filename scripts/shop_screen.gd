extends Control

## Shop screen orchestrator - delegates to specialized panels
## REFACTORED: Reduced from 734 to ~200 lines by extracting panels

const BuildDisplayUIScript = preload("res://scripts/ui/build_display_ui.gd")
const MAIN_FONT = preload("res://addons/gut/fonts/AnonymousPro-Regular.ttf")

# Preload component scripts to ensure they are found
const ShopOffersPanelScript = preload("res://scripts/ui/shop/shop_offers_panel.gd")
const ShopBuildTabsPlayerScript = preload("res://scripts/ui/shop/shop_build_tabs/player_tab.gd")
const ShopBuildTabsEconomyScript = preload("res://scripts/ui/shop/shop_build_tabs/economy_tab.gd")
const ShopBuildTabsTurretsScript = preload("res://scripts/ui/shop/shop_build_tabs/turrets_tab.gd")
const ShopBuildTabsItemsScript = preload("res://scripts/ui/shop/shop_build_tabs/items_tab.gd")

# UI References
@onready var shop_panel: PanelContainer = $ShopPanel
@onready var title_label: Label = $ShopPanel/VBoxContainer/Header/TitleLabel
@onready var gold_label: Label = $ShopPanel/VBoxContainer/Header/GoldLabel
@onready var offers_container: HBoxContainer = $ShopPanel/VBoxContainer/OffersContainer
@onready var reroll_button: Button = $ShopPanel/VBoxContainer/RerollContainer/RerollButton
@onready var continue_button: Button = $ShopPanel/VBoxContainer/ButtonContainer/ContinueButton

# Build tab containers
@onready var build_tabs: TabContainer = $ShopPanel/VBoxContainer/PlayerBuildSection/PlayerBuildVBox/BuildTabs
@onready var player_stats_vbox: VBoxContainer = $ShopPanel/VBoxContainer/PlayerBuildSection/PlayerBuildVBox/BuildTabs/Player/PlayerStatsVBox
@onready var economy_stats_vbox: VBoxContainer = $ShopPanel/VBoxContainer/PlayerBuildSection/PlayerBuildVBox/BuildTabs/Economy/EconomyStatsVBox

# Turrets tab nodes
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

# Items tab nodes
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

# Panel handlers (delegate complex logic to these)
var offers_panel
var player_tab
var economy_tab
var turrets_tab
var items_tab

var shop_manager: Node
var regeneration_pending: bool = false


func _ready() -> void:
	visible = false
	shop_manager = Globals.shop_manager

	# Initialize panel handlers
	offers_panel = ShopOffersPanelScript.new()
	add_child(offers_panel)
	offers_panel.initialize(offers_container, reroll_button)
	
	player_tab = ShopBuildTabsPlayerScript.new()
	add_child(player_tab)
	player_tab.initialize(player_stats_vbox)
	
	economy_tab = ShopBuildTabsEconomyScript.new()
	add_child(economy_tab)
	economy_tab.initialize(economy_stats_vbox)
	
	turrets_tab = ShopBuildTabsTurretsScript.new()
	add_child(turrets_tab)
	turrets_tab.initialize({
		"turrets_title": turrets_title,
		"turrets_hint": turrets_hint,
		"turret_icons_row": turret_icons_row,
		"turret_details_panel": turret_details_panel,
		"turret_name_label": turret_name_label,
		"turret_damage_label": turret_damage_label,
		"turret_range_label": turret_range_label,
		"turret_fire_rate_label": turret_fire_rate_label,
		"turret_rotation_label": turret_rotation_label,
		"turret_proj_speed_label": turret_proj_speed_label,
		"turret_dps_label": turret_dps_label,
	})
	
	items_tab = ShopBuildTabsItemsScript.new()
	add_child(items_tab)
	items_tab.initialize({
		"items_title": items_title,
		"items_hint": items_hint,
		"items_scroll": items_scroll,
		"items_hbox": items_hbox,
		"no_items_label": no_items_label,
		"item_details_panel": item_details_panel,
		"item_icon_label": item_icon_label,
		"item_name_label": item_name_label,
		"item_rarity_label": item_rarity_label,
		"item_description_label": item_description_label,
	})

	# Connect events
	Events.shop_opened.connect(_on_shop_opened)
	Events.shop_closed.connect(_on_shop_closed)
	Events.gold_collected.connect(_on_gold_changed)
	Events.gold_spent.connect(_on_gold_changed)
	Events.shop_purchase_made.connect(_on_purchase_made)
	Events.shop_insufficient_funds.connect(_on_insufficient_funds)

	# Connect panel signals
	offers_panel.purchase_requested.connect(_on_purchase_pressed)
	offers_panel.reroll_requested.connect(_on_reroll_pressed)
	
	continue_button.pressed.connect(_on_continue_pressed)


func _on_shop_opened(wave_number: int) -> void:
	visible = true
	get_tree().paused = true
	
	# Apply fonts to header elements
	title_label.add_theme_font_override("font", MAIN_FONT)
	title_label.add_theme_font_size_override("font_size", 32)
	gold_label.add_theme_font_override("font", MAIN_FONT)
	gold_label.add_theme_font_size_override("font_size", 24)
	continue_button.add_theme_font_override("font", MAIN_FONT)
	
	title_label.text = "TURRET SHOP - WAVE %d" % wave_number
	update_gold_display()
	offers_panel.update_reroll_button()
	update_player_build()

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
	update_player_build()

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
	var game_manager = Globals.game_manager
	if game_manager and game_manager.has_method("end_shop_phase"):
		game_manager.end_shop_phase()

func _on_gold_changed(_amount: int, _total: int) -> void:
	update_gold_display()
	_request_regeneration()

func update_gold_display() -> void:
	gold_label.text = "Gold: %d" % Globals.total_gold

func _on_insufficient_funds(_required: int, _current: int) -> void:
	var tween = create_tween()
	tween.tween_property(gold_label, "modulate", Color.RED, 0.1)
	tween.tween_property(gold_label, "modulate", Color.WHITE, 0.1)

func update_player_build() -> void:
	player_tab.update_display()
	economy_tab.update_display()
	turrets_tab.update_display()
	items_tab.update_display()
	_setup_build_focus_neighbors()

func _setup_build_focus_neighbors() -> void:
	var turret_buttons = turrets_tab.get_turret_buttons()
	var item_buttons = items_tab.get_item_buttons()
	var offer_buttons = offers_panel.get_offer_buttons()

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
	
	# Connect continue button back to offers
	if continue_button and not offer_buttons.is_empty():
		continue_button.focus_neighbor_top = reroll_button.get_path()
		if reroll_button:
			reroll_button.focus_neighbor_bottom = continue_button.get_path()
