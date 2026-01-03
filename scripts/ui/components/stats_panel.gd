class_name StatsPanel
extends VBoxContainer

## Reusable component displaying Player and Economy stats
## Used in both Shop Screen and Pause Menu

const MAIN_FONT = preload("res://assets/fonts/NunitoSans-Regular.ttf")
const BuildDisplayUIScript = preload("res://scripts/ui/build_display_ui.gd")

# Base player constants (from player.gd defaults)
const BASE_MAX_HEALTH := 100.0
const BASE_SPEED := 300.0

var _player: Node2D = null
var shop_manager: Node = null

@onready var player_section: VBoxContainer = $PlayerSection
@onready var economy_section: VBoxContainer = $EconomySection


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	shop_manager = get_node_or_null("/root/Main/ShopManager")


func refresh() -> void:
	_update_player_stats()
	_update_economy_stats()


func _update_player_stats() -> void:
	if not player_section:
		return

	# Get player reference if not available
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

	# Clear existing labels
	for child in player_section.get_children():
		child.queue_free()

	# Section header
	var header := _create_label("🎮 PLAYER STATS", 24, Color(0.5, 0.8, 1.0))
	player_section.add_child(header)

	# Get modified values
	var difficulty_config = DifficultyService.get_difficulty_config()
	var modified_max_health := PlayerStatsService.get_player_max_health(difficulty_config["player_health_mult"])
	var modified_speed := PlayerStatsService.get_player_speed()

	# Health
	var health_current := 100
	var health_max := int(modified_max_health)
	if is_instance_valid(_player):
		health_current = int(_player.current_health)

	var health_label := _create_label("❤ Health: %d/%d" % [health_current, health_max], 18)
	if not is_equal_approx(modified_max_health, BASE_MAX_HEALTH):
		var diff := modified_max_health - BASE_MAX_HEALTH
		health_label.text += " (+%d)" % int(diff)
		health_label.add_theme_color_override("font_color", Color.GREEN)
	player_section.add_child(health_label)

	# Health Regen (only show if > 0)
	var health_regen := PlayerStatsService.get_player_health_regen()
	if health_regen > 0:
		player_section.add_child(_create_label("💚 Regen: +%d" % health_regen, 18, Color.GREEN))

	# Speed
	var speed_stat := BuildDisplayUIScript.format_stat_with_modifier("⚡ Speed", BASE_SPEED, modified_speed, "%.0f", true)
	var speed_label := _create_label(speed_stat["text"], 18, speed_stat["color"])
	player_section.add_child(speed_label)

	# Luck
	var luck := PlayerStatsService.get_player_luck_display()
	player_section.add_child(_create_label("🍀 Luck: %d" % luck, 18))

	# Crit Chance
	var base_crit_chance := GameConstants.PLAYER_BASE_CRIT_CHANCE * 100.0
	var modified_crit_chance := PlayerStatsService.get_player_crit_chance() * 100.0
	var crit_chance_stat := BuildDisplayUIScript.format_stat_with_modifier("💥 Crit Chance", base_crit_chance, modified_crit_chance, "%.1f%%", true)
	var crit_chance_label := _create_label(crit_chance_stat["text"], 18, crit_chance_stat["color"])
	player_section.add_child(crit_chance_label)

	# Crit Multiplier
	var base_crit_mult := GameConstants.PLAYER_BASE_CRIT_MULTIPLIER
	var modified_crit_mult := PlayerStatsService.get_player_crit_multiplier()
	var crit_mult_stat := BuildDisplayUIScript.format_stat_with_modifier("⚡ Crit Damage", base_crit_mult, modified_crit_mult, "%.1fx", true)
	var crit_mult_label := _create_label(crit_mult_stat["text"], 18, crit_mult_stat["color"])
	player_section.add_child(crit_mult_label)

	# XP
	player_section.add_child(_create_label("✨ XP: %d" % GameStateService.total_xp, 18))

	# Kills
	player_section.add_child(_create_label("💀 Kills: %d" % GameStateService.total_kills, 18))

	# Time
	var minutes := int(GameStateService.time_survived) / 60
	var seconds := int(GameStateService.time_survived) % 60
	player_section.add_child(_create_label("⏱ Time: %d:%02d" % [minutes, seconds], 18))


func _update_economy_stats() -> void:
	if not economy_section:
		return

	# Clear existing
	for child in economy_section.get_children():
		child.queue_free()

	# Section header
	economy_section.add_child(_create_label("💰 ECONOMY", 24, Color(1, 0.84, 0, 1)))

	# Current Gold
	economy_section.add_child(_create_label("Gold: %d" % EconomyService.total_gold, 18))

	# Gold Earn Multiplier
	var gold_mult := ItemTrackingService.get_gold_earn_multiplier()
	var gold_stat := BuildDisplayUIScript.format_stat_with_modifier("Earn Rate", 100.0, gold_mult * 100.0, "%.0f%%", true)
	economy_section.add_child(_create_label(gold_stat["text"], 18, gold_stat["color"]))

	# Shop Prices
	var price_mult := ItemTrackingService.get_shop_price_multiplier()
	var price_stat := BuildDisplayUIScript.format_stat_with_modifier("Shop Prices", 100.0, price_mult * 100.0, "%.0f%%", false)
	economy_section.add_child(_create_label(price_stat["text"], 18, price_stat["color"]))

	# Reroll Cost
	var reroll_cost: int = shop_manager.get_reroll_cost() if shop_manager else 0
	economy_section.add_child(_create_label("Reroll: %dg" % reroll_cost, 18))

	# Separator
	economy_section.add_child(HSeparator.new())

	# Progress header
	economy_section.add_child(_create_label("📊 PROGRESS", 24, Color(0.7, 0.7, 1, 1)))

	# Wave
	economy_section.add_child(_create_label("Wave: %d" % GameStateService.current_wave, 18))

	# Turrets Owned
	economy_section.add_child(_create_label("Turrets: %d" % TurretStatsService.get_total_turret_count(), 18))

	# Items Collected
	economy_section.add_child(_create_label("Items: %d" % ItemTrackingService.collected_items.size(), 18))


func _create_label(text: String, font_size: int, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", MAIN_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	if color != Color.WHITE:
		label.add_theme_color_override("font_color", color)
	
	# Add outline for better readability
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	
	# Set texture filter to linear to ensure fonts are anti-aliased
	# This overrides the global project setting of "Nearest" which is used for pixel art
	label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	
	return label
