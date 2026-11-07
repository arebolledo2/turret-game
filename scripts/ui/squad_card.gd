class_name SquadCard
extends Button

## One deployed turret in the shop's squad strip: portrait, name, attack family badges, level, XP and its
## main numbers. While an offer is focused, `show_impact` outlines the card green (helped), red (hurt) or
## amber (mixed) with a badge naming the change, and dims cards the offer leaves alone. Pressing it opens
## the turret details.
const WIDTH: float = 212.0
const HEIGHT: float = 150.0

var turret_id: int = 0
var portrait: TextureRect
var name_label: Label
var level_label: Label
var family_badges: AttackFamilyBadges
var xp_bar: TurretXpBar
var stats_row: HBoxContainer
var impact_badge: PanelContainer
var impact_row: HBoxContainer
## The before/after text for the focused offer; part of the tooltip.
var report: String = ""
var summary: String = ""

func _init() -> void:
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	focus_mode = Control.FOCUS_ALL
	clip_contents = false
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 10)
	column.add_child(top)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(68, 68)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(portrait)
	var identity := VBoxContainer.new()
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_theme_constant_override("separation", 4)
	top.add_child(identity)
	name_label = UiBuilder.label(identity, "", 22, UiPalette.INK)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.clip_text = true
	var level_row := HBoxContainer.new()
	level_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_row.add_theme_constant_override("separation", 6)
	identity.add_child(level_row)
	family_badges = AttackFamilyBadges.new(false, 20.0)
	level_row.add_child(family_badges)
	level_label = UiBuilder.label(level_row, "", 19, UiPalette.MUTED)
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_bar = TurretXpBar.new()
	xp_bar.custom_minimum_size.y = 8
	column.add_child(xp_bar)
	stats_row = HBoxContainer.new()
	stats_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_row.add_theme_constant_override("separation", 6)
	column.add_child(stats_row)
	impact_badge = PanelContainer.new()
	impact_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	impact_badge.visible = false
	add_child(impact_badge)
	impact_row = HBoxContainer.new()
	impact_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	impact_row.add_theme_constant_override("separation", 4)
	impact_badge.add_child(impact_row)
	show_impact({}, false)

## `stats`: [[icon, text], ...] for the main numbers.
func setup(id: int, title: String, type_id: String, form: String, level: int, xp: int, families: Array,
		stats: Array, details: String) -> void:
	turret_id = id
	portrait.texture = ShopArt.turret(type_id, form)
	name_label.text = title
	level_label.text = "Lv %d" % level
	family_badges.show_families(families, "%d:%s" % [id, form])
	xp_bar.show_progress(level, xp)
	for child in stats_row.get_children():
		stats_row.remove_child(child)
		child.queue_free()
	for stat: Array in stats:
		var chip := StatChip.new().setup(stat[0], stat[1], "")
		chip.label.add_theme_font_size_override("font_size", 17)
		stats_row.add_child(chip)
	summary = details
	_refresh_tooltip()

## impact: one ShopViewData.turret_impacts entry, or {} when the focused offer leaves this turret alone.
## `focused` is whether any offer is focused at all (untouched cards dim only then).
func show_impact(impact: Dictionary, focused: bool) -> void:
	var tone := int(impact.get("tone", 0))
	var edge := UiPalette.LINE
	if not impact.is_empty():
		edge = UiPalette.GOOD if tone > 0 else UiPalette.BAD if tone < 0 else UiPalette.SCRAP
	for slot: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var lit := slot in ["hover", "pressed", "focus"]
		var box := StyleBoxFlat.new()
		box.bg_color = UiPalette.PANEL_HI if lit else UiPalette.PANEL_SOLID
		if not impact.is_empty():
			box.bg_color = box.bg_color.lerp(edge, .12)
		box.border_color = UiPalette.TEAL_HI if slot == "focus" else edge
		box.set_border_width_all(3 if slot == "focus" or not impact.is_empty() else 1)
		box.set_corner_radius_all(12)
		add_theme_stylebox_override(slot, box)
	modulate = Color(1, 1, 1, .5) if focused and impact.is_empty() else Color.WHITE
	for child in impact_row.get_children():
		impact_row.remove_child(child)
		child.queue_free()
	impact_badge.visible = not impact.is_empty()
	if impact.is_empty():
		_refresh_tooltip()
		return
	impact_badge.add_theme_stylebox_override("panel", ChamferStyle.make(edge, edge, 4.0, 8.0, 2.0))
	var arrow := "arrow_up" if tone > 0 else "arrow_down" if tone < 0 else "deploy"
	_badge_icon(arrow, 14.0)
	var changes: Array = impact.get("changes", [])
	if changes.is_empty():
		_badge_icon(str(impact.get("icon", "check")), 16.0)
	for change: Dictionary in changes.slice(0, 2):
		_badge_icon(change["icon"], 16.0)
		var text := UiBuilder.label(impact_row, change["text"], 17, UiPalette.PANEL_SOLID)
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.theme_type_variation = &"Numeral"
	impact_badge.reset_size()
	impact_badge.position = Vector2(WIDTH - impact_badge.get_combined_minimum_size().x - 10.0, -12.0)
	_refresh_tooltip()

func _badge_icon(icon_name: String, icon_size: float) -> void:
	var icon := TextureRect.new()
	icon.texture = UiIcons.get_icon(icon_name)
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.modulate = UiPalette.PANEL_SOLID
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	impact_row.add_child(icon)

func set_report(text: String) -> void:
	report = text
	_refresh_tooltip()

func _refresh_tooltip() -> void:
	tooltip_text = summary + ("\n\n" + report if not report.is_empty() else "")
