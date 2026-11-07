class_name AttackFamilyBadges
extends HFlowContainer

## Uses the same overlapping families as item eligibility, not legacy turret categories. Each family is a
## coloured shape badge (UiIcons.family_badge); `labelled` adds the family name beside it.
var shown_type: String = ""
var labelled: bool = true
var badge_size: float = 26.0

func _init(show_labels: bool = true, size: float = 26.0) -> void:
	labelled = show_labels
	badge_size = size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("h_separation", 10 if labelled else 4)
	add_theme_constant_override("v_separation", 6)

func show_turret(type_id: String) -> void:
	show_families(TurretRegistry.get_attack_families(type_id) if not type_id.is_empty() else [], type_id)

func show_families(families: Array, identity: String = "") -> void:
	var ordered := UiIcons.sort_families(families)
	var key := identity + ":" + ",".join(ordered)
	if key == shown_type:
		return
	shown_type = key
	for child in get_children():
		remove_child(child)
		child.queue_free()
	visible = not ordered.is_empty()
	# Unlabelled badges sit inside rows; reserve their width so a flow container never stacks them.
	if not labelled:
		custom_minimum_size.x = ordered.size() * (badge_size + 4.0)
	for family in ordered:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 6)
		row.tooltip_text = UiIcons.family_name(family)
		add_child(row)
		var badge := TextureRect.new()
		badge.texture = UiIcons.family_badge(family)
		badge.custom_minimum_size = Vector2(badge_size, badge_size)
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(badge)
		if labelled:
			var label := UiBuilder.label(row, UiIcons.family_name(family), 20, UiPalette.INK)
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
