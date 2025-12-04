class_name PauseMenuUI
extends RefCounted

## Handles pause menu display and interactions

var container: Control
var resume_button: Button
var level_label: Label
var wave_label: Label
var stats_grid: GridContainer
var turrets_title: Label
var turret_icons_row: HBoxContainer
var turret_details_panel: PanelContainer
var turret_name_label: Label
var turret_stats_container: HBoxContainer
var items_title: Label
var items_hint: Label
var items_scroll: ScrollContainer
var items_hbox: HBoxContainer
var _owner: Node
var _player: Node2D = null


func setup(nodes: Dictionary, owner: Node) -> void:
	container = nodes.get("container")
	resume_button = nodes.get("resume_button")
	level_label = nodes.get("level_label")
	wave_label = nodes.get("wave_label")
	stats_grid = nodes.get("stats_grid")
	turrets_title = nodes.get("turrets_title")
	turret_icons_row = nodes.get("turret_icons_row")
	turret_details_panel = nodes.get("turret_details_panel")
	turret_name_label = nodes.get("turret_name_label")
	turret_stats_container = nodes.get("turret_stats_container")
	items_title = nodes.get("items_title")
	items_hint = nodes.get("items_hint")
	items_scroll = nodes.get("items_scroll")
	items_hbox = nodes.get("items_hbox")
	_owner = owner


func set_player(player: Node2D) -> void:
	_player = player


func show() -> void:
	if container:
		update_stats()
		update_turrets_panel()
		update_items_panel()

		container.modulate.a = 0.0
		container.visible = true
		var tween = _owner.create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(container, "modulate:a", 1.0, 0.15)
		if resume_button:
			resume_button.grab_focus()


func hide() -> void:
	if container:
		container.visible = false


func update_stats() -> void:
	if level_label:
		level_label.text = "Level: %d" % Globals.player_level
	if wave_label:
		wave_label.text = "Wave: %d/%d" % [Globals.current_wave, Globals.MAX_WAVES]

	if _player and stats_grid:
		stats_grid.get_node("HealthValue").text = "%d/%d" % [_player.current_health, _player.max_health]
		stats_grid.get_node("SpeedValue").text = "%d" % _player.speed
		stats_grid.get_node("XPValue").text = "%d" % Globals.total_xp
		stats_grid.get_node("KillsValue").text = "%d" % Globals.total_kills

		var minutes := int(Globals.time_survived) / 60
		var seconds := int(Globals.time_survived) % 60
		stats_grid.get_node("TimeValue").text = "%d:%02d" % [minutes, seconds]

		stats_grid.get_node("TurretsValue").text = "%d" % Globals.turrets_spawned


func update_turrets_panel() -> void:
	if turrets_title:
		turrets_title.text = "TURRETS (%d)" % Globals.get_total_turret_count()

	if turret_icons_row:
		# Clear existing icons (except the "no turrets" label)
		for child in turret_icons_row.get_children():
			if child.name != "NoTurretsLabel":
				child.queue_free()

	var has_turrets := Globals.get_total_turret_count() > 0

	if turret_icons_row:
		var no_turrets_label = turret_icons_row.get_node_or_null("NoTurretsLabel")
		if no_turrets_label:
			no_turrets_label.visible = not has_turrets

	if turret_details_panel:
		turret_details_panel.visible = has_turrets

	if not has_turrets:
		return

	# Create icons for each turret type that we have
	for type in Globals.TURRET_TYPES.keys():
		var count: int = Globals.turret_counts.get(type, 0)
		if count > 0:
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(48, 48)
			btn.text = Globals.TURRET_TYPES[type]["icon"]
			btn.tooltip_text = Globals.TURRET_TYPES[type]["name"]
			btn.pressed.connect(func(): _on_turret_icon_pressed(type))

			var badge := Label.new()
			badge.text = str(count)
			badge.add_theme_font_size_override("font_size", 10)
			badge.position = Vector2(30, 30)
			btn.add_child(badge)

			if turret_icons_row:
				turret_icons_row.add_child(btn)

			# Auto-select if nothing selected or this is the currently selected type
			if Globals.selected_turret_type == "" or Globals.selected_turret_type == type:
				_on_turret_icon_pressed(type)


func _on_turret_icon_pressed(type: String) -> void:
	Globals.selected_turret_type = type
	update_turret_details(type)


func update_turret_details(type: String) -> void:
	var config: Dictionary = Globals.TURRET_TYPES[type]
	var stats: Dictionary = Globals.get_turret_stats(type)
	var count: int = Globals.turret_counts.get(type, 0)

	if turret_name_label:
		turret_name_label.text = "%s %s (x%d)" % [config["icon"], config["name"], count]

	if turret_stats_container:
		var left_stats = turret_stats_container.get_node_or_null("LeftStats")
		if left_stats:
			left_stats.get_node("DamageLabel").text = "• Damage: %.1f" % stats["damage"]
			left_stats.get_node("RangeLabel").text = "• Range: %d" % stats["range"]
			left_stats.get_node("FireRateLabel").text = "• Fire Rate: %.1f/s" % stats["fire_rate"]

		var right_stats = turret_stats_container.get_node_or_null("RightStats")
		if right_stats:
			right_stats.get_node("RotationLabel").text = "• Rotation: %d°/s" % stats["rotation_speed"]
			right_stats.get_node("ProjSpeedLabel").text = "• Proj Speed: %d" % stats.get("projectile_speed", 0)

			var dps: float = stats["damage"] * stats["fire_rate"]
			right_stats.get_node("DPSLabel").text = "• DPS: %.1f" % dps


func update_items_panel() -> void:
	var item_count := Globals.collected_items.size()

	if items_title:
		items_title.text = "ITEMS (%d)" % item_count
	if items_hint:
		items_hint.visible = item_count == 0
	if items_scroll:
		items_scroll.visible = item_count > 0

	if items_hbox:
		# Clear existing items
		for child in items_hbox.get_children():
			child.queue_free()

		# Add item slots
		for item_id in Globals.collected_items:
			if not Globals.ITEMS.has(item_id):
				continue
			var item_data = Globals.ITEMS[item_id]
			var slot := ColorRect.new()
			slot.custom_minimum_size = Vector2(40, 40)
			slot.color = Globals.RARITY_COLORS.get(item_data.get("rarity", 0), Color.WHITE)
			slot.tooltip_text = "%s\n%s" % [item_data.get("name", "Unknown Item"), item_data.get("description", "")]
			items_hbox.add_child(slot)
