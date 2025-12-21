class_name BuildDisplayUI
extends RefCounted

## Shared UI rendering helpers for player build display (turrets, items, stats)
## Used by both PauseMenuUI and ShopScreen

const TURRET_BUTTON_SIZE := Vector2(56, 56)
const ITEM_BUTTON_SIZE := Vector2(60, 60)
const ICON_FONT_SIZE := 28
const BADGE_FONT_SIZE := 12

const MAIN_FONT = preload("res://addons/gut/fonts/AnonymousPro-Regular.ttf")


## Creates a 56x56 button with icon and count badge for turret display
static func create_turret_button(turret_type: String, count: int) -> Button:
	var turret_config: Dictionary = TurretRegistry.get_type(turret_type)
	
	var btn := Button.new()
	btn.custom_minimum_size = TURRET_BUTTON_SIZE
	btn.add_theme_font_override("font", MAIN_FONT)
	btn.add_theme_font_size_override("font_size", ICON_FONT_SIZE)
	btn.text = turret_config.get("icon", "?")
	btn.tooltip_text = turret_config.get("name", "Unknown Turret")
	btn.focus_mode = Control.FOCUS_ALL
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	
	style_turret_button(btn, turret_type)
	
	# Add count badge
	if count > 0:
		var badge := Label.new()
		badge.text = str(count)
		badge.add_theme_font_override("font", MAIN_FONT)
		badge.add_theme_font_size_override("font_size", BADGE_FONT_SIZE)
		badge.add_theme_color_override("font_color", Color.WHITE)
		badge.add_theme_color_override("font_outline_color", Color.BLACK)
		badge.add_theme_constant_override("outline_size", 2)
		badge.position = Vector2(30, 30)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(badge)
	
	return btn


## Applies styling to turret button
static func style_turret_button(btn: Button, turret_type: String) -> void:
	var turret_color := TurretRegistry.get_color(turret_type)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 1.0)
	style.border_color = turret_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)
	
	var style_hover := style.duplicate()
	style_hover.bg_color = Color(0.25, 0.25, 0.25, 1.0)
	btn.add_theme_stylebox_override("hover", style_hover)
	
	var style_focus := style.duplicate()
	style_focus.border_color = Color.WHITE
	style_focus.set_border_width_all(3)
	btn.add_theme_stylebox_override("focus", style_focus)


## Updates a turret details panel with stats for the given turret type
## Shows base vs modified stats and calculates effective DPS
## nodes dictionary should contain: turret_name_label, damage_label, range_label,
## fire_rate_label, rotation_label, proj_speed_label, dps_label
static func update_turret_details(nodes: Dictionary, turret_type: String) -> void:
	var config: Dictionary = TurretRegistry.get_type(turret_type)
	var base_stats: Dictionary = TurretRegistry.get_base_stats(turret_type)
	var modified_stats: Dictionary = Globals.get_turret_stats(turret_type)
	var count: int = Globals.turret_counts.get(turret_type, 0)

	if nodes.has("turret_name_label") and nodes["turret_name_label"]:
		nodes["turret_name_label"].add_theme_font_override("font", MAIN_FONT)
		nodes["turret_name_label"].text = "%s %s (x%d)" % [config.get("icon", "?"), config.get("name", "Unknown"), count]

	# Damage with base/modified
	if nodes.has("damage_label") and nodes["damage_label"]:
		nodes["damage_label"].add_theme_font_override("font", MAIN_FONT)
		var base_damage := float(base_stats.get("damage", 0))
		var mod_damage := float(modified_stats.get("damage", 0))
		var damage_stat := format_stat_with_modifier("Damage", base_damage, mod_damage, "%.1f", true)
		nodes["damage_label"].text = "• " + damage_stat["text"]
		nodes["damage_label"].add_theme_color_override("font_color", damage_stat["color"])

	# Range with base/modified
	if nodes.has("range_label") and nodes["range_label"]:
		nodes["range_label"].add_theme_font_override("font", MAIN_FONT)
		var base_range := float(base_stats.get("range", 0))
		var mod_range := float(modified_stats.get("range", 0))
		var range_stat := format_stat_with_modifier("Range", base_range, mod_range, "%.0f", true)
		nodes["range_label"].text = "• " + range_stat["text"]
		nodes["range_label"].add_theme_color_override("font_color", range_stat["color"])

	# Fire Rate with base/modified
	if nodes.has("fire_rate_label") and nodes["fire_rate_label"]:
		nodes["fire_rate_label"].add_theme_font_override("font", MAIN_FONT)
		var base_fire_rate := float(base_stats.get("fire_rate", 0))
		var mod_fire_rate := float(modified_stats.get("fire_rate", 0))
		var fire_rate_stat := format_stat_with_modifier("Fire Rate", base_fire_rate, mod_fire_rate, "%.1f/s", true)
		nodes["fire_rate_label"].text = "• " + fire_rate_stat["text"]
		nodes["fire_rate_label"].add_theme_color_override("font_color", fire_rate_stat["color"])

	# Rotation Speed with base/modified
	if nodes.has("rotation_label") and nodes["rotation_label"]:
		nodes["rotation_label"].add_theme_font_override("font", MAIN_FONT)
		var base_rotation := float(base_stats.get("rotation_speed", 0))
		var mod_rotation := float(modified_stats.get("rotation_speed", 0))
		var rotation_stat := format_stat_with_modifier("Rotation", base_rotation, mod_rotation, "%.0f°/s", true)
		nodes["rotation_label"].text = "• " + rotation_stat["text"]
		nodes["rotation_label"].add_theme_color_override("font_color", rotation_stat["color"])

	# Projectile Speed with base/modified
	if nodes.has("proj_speed_label") and nodes["proj_speed_label"]:
		nodes["proj_speed_label"].add_theme_font_override("font", MAIN_FONT)
		var base_proj_speed := float(base_stats.get("projectile_speed", 0))
		var mod_proj_speed := float(modified_stats.get("projectile_speed", 0))
		var proj_speed_stat := format_stat_with_modifier("Proj Speed", base_proj_speed, mod_proj_speed, "%.0f", true)
		nodes["proj_speed_label"].text = "• " + proj_speed_stat["text"]
		nodes["proj_speed_label"].add_theme_color_override("font_color", proj_speed_stat["color"])

	# DPS with effective calculation
	if nodes.has("dps_label") and nodes["dps_label"]:
		nodes["dps_label"].add_theme_font_override("font", MAIN_FONT)
		var dps_calc := calculate_effective_dps(turret_type, modified_stats)
		var base_dps: float = float(dps_calc["base_dps"])
		var effective_dps: float = float(dps_calc["effective_dps"])

		if is_equal_approx(base_dps, effective_dps):
			nodes["dps_label"].text = "• DPS: %.1f" % base_dps
		else:
			nodes["dps_label"].text = "• DPS: %.1f (eff: %.1f)" % [base_dps, effective_dps]
		nodes["dps_label"].add_theme_color_override("font_color", Color(1, 0.84, 0, 1))


## Creates a 60x60 button with emoji icon, rarity border, and count badge for item display
static func create_item_button(item_id: String, count: int) -> Button:
	if not ItemRegistry.has_item(item_id):
		return null
	
	var item_data: Dictionary = ItemRegistry.get_item(item_id)
	
	var btn := Button.new()
	btn.custom_minimum_size = ITEM_BUTTON_SIZE
	btn.focus_mode = Control.FOCUS_ALL
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	
	style_item_button(btn, item_id)
	
	# Create container for icon and badge
	var container_node := Control.new()
	container_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	container_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(container_node)
	
	# Add emoji icon label
	var icon_label := Label.new()
	icon_label.text = item_data.get("icon", "?")
	icon_label.add_theme_font_override("font", MAIN_FONT)
	icon_label.add_theme_font_size_override("font_size", ICON_FONT_SIZE)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container_node.add_child(icon_label)
	
	# Add quantity badge if count > 1
	if count > 1:
		var badge := Label.new()
		badge.text = "x%d" % count
		badge.add_theme_font_override("font", MAIN_FONT)
		badge.add_theme_font_size_override("font_size", BADGE_FONT_SIZE)
		badge.add_theme_color_override("font_color", Color.WHITE)
		badge.add_theme_color_override("font_outline_color", Color.BLACK)
		badge.add_theme_constant_override("outline_size", 2)
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -20
		badge.offset_right = -2
		badge.offset_top = 2
		badge.offset_bottom = 14
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container_node.add_child(badge)
	
	btn.tooltip_text = "%s\n%s" % [item_data.get("name", "Unknown Item"), item_data.get("description", "")]
	
	return btn


## Applies rarity-colored border styling to item button
static func style_item_button(btn: Button, item_id: String) -> void:
	if not ItemRegistry.has_item(item_id):
		return
	
	var item_data: Dictionary = ItemRegistry.get_item(item_id)
	var rarity_color := ItemRegistry.get_rarity_color(item_data.get("rarity", 0))
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 1.0)
	style.border_color = rarity_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)
	
	var style_hover := style.duplicate()
	style_hover.bg_color = Color(0.25, 0.25, 0.25, 1.0)
	btn.add_theme_stylebox_override("hover", style_hover)
	
	var style_focus := style.duplicate()
	style_focus.border_color = Color.WHITE
	style_focus.set_border_width_all(3)
	btn.add_theme_stylebox_override("focus", style_focus)


## Updates an item details panel with info for the given item
## nodes dictionary should contain: item_icon_label, item_name_label, 
## item_rarity_label, item_description_label
static func update_item_details(nodes: Dictionary, item_id: String) -> void:
	if not ItemRegistry.has_item(item_id):
		return
	
	var item_data: Dictionary = ItemRegistry.get_item(item_id)
	var count: int = Globals.item_counts.get(item_id, 1)
	
	if nodes.has("item_icon_label") and nodes["item_icon_label"]:
		nodes["item_icon_label"].add_theme_font_override("font", MAIN_FONT)
		nodes["item_icon_label"].text = item_data.get("icon", "?")
	
	if nodes.has("item_name_label") and nodes["item_name_label"]:
		nodes["item_name_label"].add_theme_font_override("font", MAIN_FONT)
		if count > 1:
			nodes["item_name_label"].text = "%s (x%d)" % [item_data.get("name", "Unknown Item"), count]
		else:
			nodes["item_name_label"].text = item_data.get("name", "Unknown Item")
	
	if nodes.has("item_rarity_label") and nodes["item_rarity_label"]:
		nodes["item_rarity_label"].add_theme_font_override("font", MAIN_FONT)
		var rarity = item_data.get("rarity", GameEnums.ItemRarity.COMMON)
		nodes["item_rarity_label"].text = ItemRegistry.RARITY_NAMES.get(rarity, "Common")
		nodes["item_rarity_label"].add_theme_color_override("font_color", ItemRegistry.get_rarity_color(rarity))
	
	if nodes.has("item_description_label") and nodes["item_description_label"]:
		nodes["item_description_label"].add_theme_font_override("font", MAIN_FONT)
		if ItemRegistry.should_show_description(item_id):
			nodes["item_description_label"].text = item_data.get("description", "")
			nodes["item_description_label"].visible = true
		else:
			nodes["item_description_label"].text = ""
			nodes["item_description_label"].visible = false


## Sets up focus neighbors for a row of buttons
## Connects left/right within the row, and up/down to specified targets
static func setup_focus_neighbors(buttons: Array[Button], up_target: Control, down_target: Control) -> void:
	if buttons.is_empty():
		return

	for i in range(buttons.size()):
		var btn := buttons[i]

		# Left neighbor
		if i > 0:
			btn.focus_neighbor_left = buttons[i - 1].get_path()

		# Right neighbor
		if i < buttons.size() - 1:
			btn.focus_neighbor_right = buttons[i + 1].get_path()

		# Up neighbor
		if up_target and is_instance_valid(up_target):
			btn.focus_neighbor_top = up_target.get_path()

		# Down neighbor
		if down_target and is_instance_valid(down_target):
			btn.focus_neighbor_bottom = down_target.get_path()


## Format a stat with base and modified values
## Returns Dictionary with text and color for display
static func format_stat_with_modifier(
	stat_name: String,
	base_value: float,
	modified_value: float,
	format_string: String = "%.1f",
	is_higher_better: bool = true
) -> Dictionary:
	var has_change := not is_equal_approx(base_value, modified_value)
	var text: String
	var color := Color.WHITE

	if has_change:
		text = "%s: %s (%s)" % [
			stat_name,
			format_string % base_value,
			format_string % modified_value
		]
		var is_improved := (modified_value > base_value) == is_higher_better
		color = Color.GREEN if is_improved else Color.RED
	else:
		text = "%s: %s" % [stat_name, format_string % base_value]

	return {"text": text, "color": color}


## Calculate effective DPS for a turret type including special effects
## Returns Dictionary with base_dps, effective_dps, and breakdown
static func calculate_effective_dps(turret_type: String, stats: Dictionary) -> Dictionary:
	var base_dps: float = float(stats.get("damage", 0.0)) * float(stats.get("fire_rate", 0.0))
	var effective_dps: float = base_dps
	var breakdown: Array[String] = []

	match turret_type:
		"normal", "sniper":
			# Simple: damage × fire_rate
			effective_dps = base_dps
			breakdown.append("Base DPS: %.1f" % base_dps)

		"fire":
			# Fire: (damage × fire_rate) + (dot_damage × fire_rate × dot_duration / dot_tick_rate)
			var dot_dps := 0.0
			if stats.has("dot_damage") and stats.has("dot_duration") and stats.has("dot_tick_rate"):
				var dot_damage: float = float(stats["dot_damage"])
				var dot_duration: float = float(stats["dot_duration"])
				var dot_tick_rate: float = float(stats["dot_tick_rate"])
				if dot_tick_rate > 0:
					var ticks_per_dot: float = dot_duration / dot_tick_rate
					dot_dps = dot_damage * ticks_per_dot * float(stats.get("fire_rate", 0.0))

			effective_dps = base_dps + dot_dps
			breakdown.append("Direct DPS: %.1f" % base_dps)
			breakdown.append("DoT DPS: %.1f" % dot_dps)
			breakdown.append("Total DPS: %.1f" % effective_dps)

		"tesla":
			# Tesla: damage × fire_rate × (1 + decay + decay² + ... decay^chain_count)
			var chain_count := int(stats.get("chain_count", 0))
			var decay: float = float(stats.get("chain_decay", 0.7))
			var chain_mult := 1.0
			var decay_power: float = decay
			for i in range(chain_count):
				chain_mult += decay_power
				decay_power *= decay

			effective_dps = base_dps * chain_mult
			breakdown.append("Base DPS: %.1f" % base_dps)
			breakdown.append("Chain Mult: %.2fx" % chain_mult)
			breakdown.append("Effective DPS: %.1f" % effective_dps)

		"plasma":
			# Plasma: Base DPS only (AoE depends on enemy density)
			effective_dps = base_dps
			var aoe: float = float(stats.get("aoe_radius", 0.0))
			breakdown.append("Single-target DPS: %.1f" % base_dps)
			breakdown.append("AoE Radius: %.0fpx (multi-target)" % aoe)

		"shock":
			# Shock: Base DPS only (pulse AoE, not single target)
			effective_dps = base_dps
			var range_val: float = float(stats.get("range", 0.0))
			breakdown.append("Pulse DPS: %.1f" % base_dps)
			breakdown.append("AoE Range: %.0fpx" % range_val)

	return {
		"base_dps": base_dps,
		"effective_dps": effective_dps,
		"breakdown": breakdown
	}


## Format a float as a percentage string
static func format_percentage(value: float) -> String:
	return "%.0f%%" % (value * 100.0)


## Get base turret stats without modifiers
static func get_base_turret_stats(turret_type: String) -> Dictionary:
	return TurretRegistry.get_base_stats(turret_type)
