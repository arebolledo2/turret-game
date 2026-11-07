class_name SquadCard
extends Button

## One deployed turret in the shop's squad strip: portrait, name, attack family badges, level (and this
## wave's XP gain), XP and its main numbers. While an offer is focused, `show_impact` tints the card green
## (helped), red (hurt) or amber (mixed), draws a bar along its bottom edge and lists the change in that
## colour; cards the offer leaves alone dim. No border except the focus ring. Pressing it opens the details.
const WIDTH: float = 212.0
const HEIGHT: float = 172.0
const BAR_HEIGHT: float = 4.0

var turret_id: int = 0
var portrait: TextureRect
var name_label: Label
var level_label: Label
var gain_label: Label
var family_badges: AttackFamilyBadges
var xp_bar: TurretXpBar
var stats_row: HBoxContainer
## The focused offer's change, inline under the stats (arrow, then icon + value per change).
var impact_badge: HBoxContainer
var impact_bar: ColorRect
## The before/after text for the focused offer; part of the tooltip.
var report: String = ""
var summary: String = ""

func _init() -> void:
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
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
	portrait.custom_minimum_size = Vector2(60, 60)
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
	family_badges = AttackFamilyBadges.new(false, 18.0)
	level_row.add_child(family_badges)
	level_label = UiBuilder.label(level_row, "", 19, UiPalette.MUTED)
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gain_label = UiBuilder.label(level_row, "", 18, UiPalette.TEAL_HI)
	gain_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gain_label.visible = false
	xp_bar = TurretXpBar.new()
	xp_bar.custom_minimum_size.y = 6
	column.add_child(xp_bar)
	stats_row = HBoxContainer.new()
	stats_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_row.add_theme_constant_override("separation", 12)
	column.add_child(stats_row)
	impact_badge = HBoxContainer.new()
	impact_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	impact_badge.add_theme_constant_override("separation", 10)
	impact_badge.visible = false
	column.add_child(impact_badge)
	impact_bar = ColorRect.new()
	impact_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	impact_bar.visible = false
	add_child(impact_bar)
	impact_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	impact_bar.offset_top = -BAR_HEIGHT
	show_impact({}, false)

## `stats`: [[icon, text], ...] for the main numbers; `gain`: XP awarded this wave (0 hides it).
func setup(id: int, title: String, type_id: String, form: String, level: int, xp: int, families: Array,
		stats: Array, details: String, gain: int = 0) -> void:
	turret_id = id
	portrait.texture = ShopArt.turret(type_id, form)
	name_label.text = title
	level_label.text = "Lv %d" % level
	gain_label.visible = gain > 0
	gain_label.text = "+%d XP" % gain
	family_badges.show_families(families, "%d:%s" % [id, form])
	xp_bar.show_progress(level, xp)
	for child in stats_row.get_children():
		stats_row.remove_child(child)
		child.queue_free()
	for stat: Array in stats:
		var chip := StatChip.new().setup(stat[0], stat[1], "", 0, Color("c3d5da"))
		chip.label.add_theme_font_size_override("font_size", 18)
		stats_row.add_child(chip)
	summary = details
	_refresh_tooltip()

## impact: one ShopViewData.turret_impacts entry, or {} when the focused offer leaves this turret alone.
## `focused` is whether any offer is focused at all (untouched cards dim only then).
func show_impact(impact: Dictionary, focused: bool) -> void:
	var tone := int(impact.get("tone", 0))
	var color := UiPalette.SCRAP
	if not impact.is_empty():
		color = UiPalette.GOOD if tone > 0 else UiPalette.BAD if tone < 0 else UiPalette.SCRAP
	for slot: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var lit := slot in ["hover", "pressed", "focus"]
		var box := StyleBoxFlat.new()
		box.bg_color = UiPalette.PANEL_HI if lit else Color("0b1f28")
		if not impact.is_empty():
			box.bg_color = box.bg_color.lerp(color, .12)
		box.border_color = UiPalette.TEAL_HI
		box.set_border_width_all(2 if slot == "focus" else 0)
		box.set_corner_radius_all(12)
		add_theme_stylebox_override(slot, box)
	modulate = Color(1, 1, 1, .45) if focused and impact.is_empty() else Color.WHITE
	impact_bar.visible = not impact.is_empty()
	impact_bar.color = color
	for child in impact_badge.get_children():
		impact_badge.remove_child(child)
		child.queue_free()
	impact_badge.visible = not impact.is_empty()
	if impact.is_empty():
		_refresh_tooltip()
		return
	var arrow := "arrow_up" if tone > 0 else "arrow_down" if tone < 0 else "deploy"
	var changes: Array = impact.get("changes", [])
	if changes.is_empty():
		impact_badge.add_child(StatChip.new().setup(str(impact.get("icon", "check")), "", "", tone))
	for change: Dictionary in changes.slice(0, 2):
		var chip := StatChip.new().setup(change["icon"], change["text"], "", int(change.get("tone", tone)))
		chip.label.add_theme_font_size_override("font_size", 18)
		impact_badge.add_child(chip)
	var lead := StatChip.new().setup(arrow, "", "", tone)
	impact_badge.add_child(lead)
	impact_badge.move_child(lead, 0)
	if tone == 0:
		lead.icon_rect.modulate = color
	_refresh_tooltip()

func set_report(text: String) -> void:
	report = text
	_refresh_tooltip()

func _refresh_tooltip() -> void:
	tooltip_text = summary + ("\n\n" + report if not report.is_empty() else "")
