class_name ShopBuildTabsEconomy
extends Node

## Manages the economy stats tab display in shop/pause menu
## Extracted from shop_screen.gd to reduce file size

const BuildDisplayUIScript = preload("res://scripts/ui/build_display_ui.gd")
const _BASE_FONT = preload("res://assets/fonts/NunitoSans-VariableFont.ttf")
static var MAIN_FONT: FontVariation = _create_medium_font()

static func _create_medium_font() -> FontVariation:
	var font_var := FontVariation.new()
	font_var.base_font = _BASE_FONT
	font_var.variation_opentype = {"wght": 500}
	return font_var

var economy_stats_vbox: VBoxContainer
var shop_manager: Node

func initialize(vbox: VBoxContainer) -> void:
	economy_stats_vbox = vbox
	shop_manager = get_node_or_null("/root/Main/ShopManager")

func update_display() -> void:
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
	current_gold_label.text = "Scrap: %d" % EconomyService.total_scrap
	current_gold_label.add_theme_font_override("font", MAIN_FONT)
	current_gold_label.add_theme_font_size_override("font_size", 15)
	economy_stats_vbox.add_child(current_gold_label)

	# Scrap Earn Multiplier
	var gold_mult: float = ItemTrackingService.get_scrap_earn_multiplier()
	var gold_mult_stat := BuildDisplayUIScript.format_stat_with_modifier("Scrap Earn", 100.0, gold_mult * 100.0, "%.0f%%", true)
	var gold_mult_label := Label.new()
	gold_mult_label.text = gold_mult_stat["text"]
	gold_mult_label.add_theme_color_override("font_color", gold_mult_stat["color"])
	gold_mult_label.add_theme_font_override("font", MAIN_FONT)
	gold_mult_label.add_theme_font_size_override("font_size", 15)
	economy_stats_vbox.add_child(gold_mult_label)

	# Shop Price Multiplier
	var price_mult: float = ItemTrackingService.get_shop_price_multiplier()
	var price_mult_stat := BuildDisplayUIScript.format_stat_with_modifier("Shop Prices", 100.0, price_mult * 100.0, "%.0f%%", false)
	var price_mult_label := Label.new()
	price_mult_label.text = price_mult_stat["text"]
	price_mult_label.add_theme_color_override("font_color", price_mult_stat["color"])
	price_mult_label.add_theme_font_override("font", MAIN_FONT)
	price_mult_label.add_theme_font_size_override("font_size", 15)
	economy_stats_vbox.add_child(price_mult_label)

	# Turret Penalty
	var penalty: float = TurretStatsService.get_turret_purchase_penalty()
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
	wave_label.text = "Wave: %d" % GameStateService.current_wave
	wave_label.add_theme_font_override("font", MAIN_FONT)
	wave_label.add_theme_font_size_override("font_size", 15)
	economy_stats_vbox.add_child(wave_label)

	# Turrets Owned
	var turrets_owned_label := Label.new()
	turrets_owned_label.text = "Turrets Owned: %d" % TurretStatsService.get_total_turret_count()
	turrets_owned_label.add_theme_font_override("font", MAIN_FONT)
	turrets_owned_label.add_theme_font_size_override("font_size", 15)
	economy_stats_vbox.add_child(turrets_owned_label)

	# Items Collected
	var items_collected_label := Label.new()
	items_collected_label.text = "Items Collected: %d" % ItemTrackingService.collected_items.size()
	items_collected_label.add_theme_font_override("font", MAIN_FONT)
	items_collected_label.add_theme_font_size_override("font_size", 15)
	economy_stats_vbox.add_child(items_collected_label)

	# Turrets Purchased (total)
	var turrets_purchased_label := Label.new()
	turrets_purchased_label.text = "Turrets Purchased: %d" % EconomyService.turrets_purchased
	turrets_purchased_label.add_theme_font_override("font", MAIN_FONT)
	turrets_purchased_label.add_theme_font_size_override("font_size", 15)
	economy_stats_vbox.add_child(turrets_purchased_label)
