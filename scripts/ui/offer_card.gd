class_name OfferCard
extends Button

## One shop offer as a card: kind tag, big icon, name, stat chips, cost. It is a Button (so focus,
## controller navigation and `pressed` work as before); `previewed` fires on focus or hover so the HUD
## can show what buying it does. The description only shows on the focused card, or always for
## special-effect items that have no chips.
signal previewed

var kind_label: Label
var icon_rect: TextureRect
var name_label: Label
var chips_box: HFlowContainer
var desc_label: Label
var cost_icon: TextureRect
var cost_label: Label
var shown_key: String = ""
var always_describe: bool = false

func _init() -> void:
	custom_minimum_size = Vector2(240, 450)
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	_apply_styles()
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	kind_label = _label(column, 15, UiPalette.MUTED)
	var tile := PanelContainer.new()
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile.custom_minimum_size = Vector2(104, 104)
	tile.add_theme_stylebox_override("panel", ChamferStyle.make(Color("0f2a33"), UiPalette.LINE, 16.0, 10.0, 10.0))
	column.add_child(tile)
	icon_rect = TextureRect.new()
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(icon_rect)
	name_label = _label(column, 27, UiPalette.INK)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size.y = 62
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chips_box = HFlowContainer.new()
	chips_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips_box.alignment = FlowContainer.ALIGNMENT_CENTER
	chips_box.add_theme_constant_override("h_separation", 8)
	chips_box.add_theme_constant_override("v_separation", 8)
	chips_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chips_box.custom_minimum_size.y = 76
	column.add_child(chips_box)
	desc_label = _label(column, 19, Color("a9c9cf"))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size.y = 56
	desc_label.max_lines_visible = 2 # a long description must not push the cost row down
	var cost_row := HBoxContainer.new()
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.add_theme_constant_override("separation", 8)
	column.add_child(cost_row)
	cost_icon = TextureRect.new()
	cost_icon.custom_minimum_size = Vector2(30, 30)
	cost_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cost_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cost_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_row.add_child(cost_icon)
	cost_label = _label(cost_row, 34, UiPalette.SCRAP)
	cost_label.theme_type_variation = &"Numeral"
	for signal_ref: Signal in [focus_entered, mouse_entered]:
		signal_ref.connect(_on_previewed)
	for signal_ref: Signal in [focus_exited, mouse_exited]:
		signal_ref.connect(_refresh_description)

func _label(parent: Node, size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _apply_styles() -> void:
	var fill := Color(.035, .086, .118, .97)
	add_theme_stylebox_override("normal", ChamferStyle.make(fill, UiPalette.LINE, 18.0, 0.0, 0.0))
	add_theme_stylebox_override("hover", ChamferStyle.make(UiPalette.PANEL_HI, UiPalette.TEAL, 18.0, 0.0, 0.0))
	add_theme_stylebox_override("pressed", ChamferStyle.make(UiPalette.PANEL_HI, UiPalette.TEAL_HI, 18.0, 0.0, 0.0))
	add_theme_stylebox_override("focus", ChamferStyle.make(UiPalette.PANEL_HI, UiPalette.TEAL_HI, 18.0, 0.0, 0.0))
	add_theme_stylebox_override("disabled", ChamferStyle.make(Color(fill, .6), Color(UiPalette.LINE, .5), 18.0, 0.0, 0.0))

func _on_previewed() -> void:
	_refresh_description()
	previewed.emit()

func _refresh_description() -> void:
	desc_label.modulate.a = 1.0 if (always_describe or has_focus() or is_hovered()) else 0.0

## Fills the card; cheap to call every frame (does nothing unless the offer or affordability changed).
func setup(offer: ShopOffer, damage_mult: float, affordable: bool) -> void:
	var key := "%s:%s:%d:%s:%s" % [offer.kind, offer.asset_id, offer.price, offer.sold, affordable]
	if key == shown_key:
		return
	shown_key = key
	var is_turret := offer.kind == "turret"
	icon_rect.texture = UiIcons.turret(offer.asset_id) if is_turret else UiIcons.item(offer.asset_id)
	icon_rect.modulate = UiPalette.TEAL_HI if is_turret else UiPalette.stat_color("slow")
	kind_label.text = "TURRET" if is_turret else ItemRegistry.get_tag(offer.asset_id)
	name_label.text = ArenaShop.offer_name(offer)
	for child in chips_box.get_children():
		chips_box.remove_child(child)
		child.queue_free()
	var chips := ShopViewData.offer_chips(offer, damage_mult)
	for chip in chips:
		chips_box.add_child(StatChip.new().setup(chip["icon"], chip["text"], chip["stat"], chip["tone"]))
	always_describe = chips.is_empty()
	desc_label.text = ArenaShop.offer_description(offer)
	cost_icon.texture = UiIcons.get_icon("check" if offer.sold else "scrap")
	cost_label.visible = not offer.sold
	cost_label.text = str(offer.price)
	var tint := UiPalette.GOOD if offer.sold else (UiPalette.SCRAP if affordable else UiPalette.BAD)
	cost_icon.modulate = tint
	cost_label.add_theme_color_override("font_color", tint)
	disabled = offer.sold
	# A bought offer vanishes but keeps its slot so the other cards don't shift.
	modulate = Color.TRANSPARENT if offer.sold else (Color.WHITE if affordable else Color(1, 1, 1, .62))
	focus_mode = Control.FOCUS_NONE if offer.sold else Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_IGNORE if offer.sold else Control.MOUSE_FILTER_STOP
	_refresh_description()
