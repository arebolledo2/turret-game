class_name ShopBuildTabsPlayer
extends Node

## Manages the player stats tab display in shop/pause menu
## Extracted from shop_screen.gd to reduce file size

const BuildDisplayUIScript = preload("res://scripts/ui/build_display_ui.gd")
const MAIN_FONT = preload("res://assets/fonts/NunitoSans-Regular.ttf")

var player_stats_vbox: VBoxContainer
var _player: Node2D = null

func initialize(vbox: VBoxContainer) -> void:
	player_stats_vbox = vbox
	_player = get_tree().get_first_node_in_group("player")

func update_display() -> void:
	if not player_stats_vbox:
		return

	# Get player reference if not available
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

	# Clear existing stat labels
	for child in player_stats_vbox.get_children():
		child.queue_free()

	# Base player constants (from player.gd defaults)
	const BASE_MAX_HEALTH := 100.0
	const BASE_SPEED := 300.0

	# Get modified values
	var difficulty_config = DifficultyService.get_difficulty_config()
	var modified_max_health := PlayerStatsService.get_player_max_health(difficulty_config["player_health_mult"])
	var modified_speed := PlayerStatsService.get_player_speed()

	# Get current player health
	var health_current := 100
	var health_max := int(modified_max_health)
	if is_instance_valid(_player):
		health_current = int(_player.current_health)

	var luck := PlayerStatsService.get_player_luck_display()
	var xp := GameStateService.total_xp
	var kills := GameStateService.total_kills
	var minutes := int(GameStateService.time_survived) / 60
	var seconds := int(GameStateService.time_survived) % 60

	# Create stat labels
	var health_label := Label.new()
	health_label.text = "❤ Health: %d/%d" % [health_current, health_max]
	if not is_equal_approx(modified_max_health, BASE_MAX_HEALTH):
		health_label.text += " (base: %d)" % int(BASE_MAX_HEALTH)
		health_label.add_theme_color_override("font_color", Color.GREEN)
	health_label.add_theme_font_override("font", MAIN_FONT)
	health_label.add_theme_font_size_override("font_size", 15)
	player_stats_vbox.add_child(health_label)

	# Health Regen (only show if > 0)
	var health_regen := PlayerStatsService.get_player_health_regen()
	if health_regen > 0:
		var regen_label := Label.new()
		regen_label.text = "💚 Regen: +%d" % health_regen
		regen_label.add_theme_color_override("font_color", Color.GREEN)
		regen_label.add_theme_font_override("font", MAIN_FONT)
		regen_label.add_theme_font_size_override("font_size", 15)
		player_stats_vbox.add_child(regen_label)

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
