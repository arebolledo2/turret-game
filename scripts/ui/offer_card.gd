class_name OfferCard
extends Button

## Shop offer: illustration beside the name, rarity (or level) with unlabelled attack family badges, the
## effect stats (icon + value, coloured only when they help or hurt), the full effect text (effects are often
## unique, so the words stay) and the price. No border until focused; the lock is an icon in the corner
## (mouse, or X / L on the focused card), and a "Buy" prompt appears on the focused card only.
signal previewed
signal lock_requested
var lock_button: Button
var locked: bool = false
var icon_rect: TextureRect
var name_label: Label
var rarity_label: Label
var desc_label: Label
var cost_label: Label
var cost_icon: TextureRect
var buy_hint: HBoxContainer
var family_badges: AttackFamilyBadges
var chips: HFlowContainer
var shown_key: String = ""
var compact: bool = false
var content_margin: MarginContainer

const MIN_HEIGHT: float = 270.0
const COMPACT_HEIGHT: float = 240.0
const LOCK_SIZE: float = 44.0

func _init() -> void:
	custom_minimum_size = Vector2(220, MIN_HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL
	for slot: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = UiPalette.PANEL_HI if slot in ["hover", "focus", "pressed"] else Color("0b1f28")
		box.border_color = UiPalette.TEAL_HI
		box.set_border_width_all(2 if slot == "focus" else 0)
		box.set_corner_radius_all(12)
		add_theme_stylebox_override(slot, box)
	var margin := MarginContainer.new()
	content_margin = margin
	margin.minimum_size_changed.connect(_refresh_minimum)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 12)
	column.add_child(top)
	icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(72, 72)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(icon_rect)
	var identity := VBoxContainer.new()
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_theme_constant_override("separation", 4)
	top.add_child(identity)
	name_label = _label(identity, 25, UiPalette.INK)
	var meta := HBoxContainer.new()
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.add_theme_constant_override("separation", 8)
	identity.add_child(meta)
	rarity_label = _label(meta, 16, UiPalette.MUTED)
	rarity_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	rarity_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	family_badges = AttackFamilyBadges.new(false, 20.0)
	family_badges.visible = false
	family_badges.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meta.add_child(family_badges)
	# Keeps the name clear of the corner lock.
	var spacer := Control.new()
	spacer.custom_minimum_size.x = LOCK_SIZE - 16.0
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)
	chips = HFlowContainer.new()
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.add_theme_constant_override("h_separation", 16)
	chips.add_theme_constant_override("v_separation", 6)
	column.add_child(chips)
	desc_label = _label(column, 19, Color("a9c0c6"))
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var footer := HBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_theme_constant_override("separation", 6)
	column.add_child(footer)
	cost_icon = TextureRect.new()
	cost_icon.texture = UiIcons.get_icon("scrap")
	cost_icon.custom_minimum_size = Vector2(22, 22)
	cost_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cost_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cost_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cost_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(cost_icon)
	cost_label = _label(footer, 28, UiPalette.SCRAP)
	cost_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	cost_label.theme_type_variation = &"Numeral"
	cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_hint = HBoxContainer.new()
	buy_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buy_hint.add_theme_constant_override("separation", 6)
	buy_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy_hint.visible = false
	footer.add_child(buy_hint)
	var glyph := PanelContainer.new()
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var round_box := StyleBoxFlat.new()
	round_box.bg_color = UiPalette.TEAL_HI
	round_box.set_corner_radius_all(12)
	round_box.content_margin_left = 7
	round_box.content_margin_right = 7
	glyph.add_theme_stylebox_override("panel", round_box)
	buy_hint.add_child(glyph)
	for label: Label in [_label(glyph, 15, UiPalette.PANEL_SOLID), _label(buy_hint, 18, UiPalette.TEAL_HI)]:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.text = "A" if label.get_parent() == glyph else "Buy"
	lock_button = Button.new()
	lock_button.flat = true
	lock_button.focus_mode = Control.FOCUS_NONE
	lock_button.mouse_filter = Control.MOUSE_FILTER_STOP
	lock_button.expand_icon = true
	lock_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_button.add_theme_constant_override("icon_max_width", 20)
	lock_button.custom_minimum_size = Vector2(LOCK_SIZE, LOCK_SIZE)
	lock_button.pressed.connect(func() -> void: lock_requested.emit())
	add_child(lock_button)
	lock_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	lock_button.offset_left = -LOCK_SIZE - 6.0
	lock_button.offset_right = -6.0
	lock_button.offset_top = 6.0
	lock_button.offset_bottom = LOCK_SIZE + 6.0
	for trigger: Signal in [focus_entered, mouse_entered]:
		trigger.connect(func() -> void: previewed.emit())
	focus_entered.connect(func() -> void: buy_hint.visible = true)
	focus_exited.connect(func() -> void: buy_hint.visible = false)

func _label(parent: Node, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _refresh_minimum() -> void:
	custom_minimum_size.y = maxf(COMPACT_HEIGHT if compact else MIN_HEIGHT, content_margin.get_combined_minimum_size().y)

func set_compact(value: bool) -> void:
	if compact == value:
		return
	compact = value
	icon_rect.custom_minimum_size = Vector2(60, 60) if compact else Vector2(72, 72)
	name_label.add_theme_font_size_override("font_size", 22 if compact else 25)
	desc_label.add_theme_font_size_override("font_size", 17 if compact else 19)
	_refresh_minimum()

func setup(offer: ShopOffer, damage_mult: float, affordable: bool) -> void:
	var key := "%s:%s:%d:%s:%s:%s:%s:%d:%s" % [offer.kind, offer.asset_id, offer.price, offer.sold, affordable, damage_mult, offer.locked, offer.level, offer.form]
	if key == shown_key:
		return
	shown_key = key
	locked = offer.locked
	lock_button.icon = UiIcons.get_icon("lock" if offer.locked else "unlock")
	lock_button.disabled = offer.sold
	lock_button.modulate = UiPalette.SCRAP if offer.locked else Color("5d7a83")
	lock_button.tooltip_text = ("Unlock (X / L): restores its current price." if offer.locked
		else "Lock (X / L): keep this offer and price across rerolls and waves.")
	var is_item := offer.kind == "item"
	var rarity := ItemRegistry.get_rarity(offer.asset_id) if is_item else GameEnums.ItemRarity.COMMON
	var accent := ItemRegistry.get_rarity_color(rarity) if is_item else UiPalette.TEAL_HI
	name_label.add_theme_color_override("font_color", UiPalette.INK)
	rarity_label.visible = true
	rarity_label.text = ItemRegistry.get_rarity_name(rarity).to_upper() if is_item \
		else "LEVEL %d%s" % [offer.level, " · EVOLVED" if not offer.form.is_empty() else ""]
	rarity_label.add_theme_color_override("font_color", accent if is_item else UiPalette.MUTED)
	icon_rect.texture = ShopArt.turret(offer.asset_id, offer.form) if offer.kind == "turret" else ShopArt.item(offer.asset_id)
	name_label.text = ArenaShop.offer_name(offer)
	family_badges.show_turret(offer.asset_id if offer.kind == "turret" else "")
	for child in chips.get_children():
		chips.remove_child(child)
		child.queue_free()
	for chip: Dictionary in ShopViewData.offer_chips(offer, damage_mult):
		chips.add_child(StatChip.new().setup(chip["icon"], chip["text"], chip["stat"], chip["tone"]).with_families(chip.get("families", [])))
	chips.visible = chips.get_child_count() > 0
	desc_label.text = ArenaShop.offer_description(offer)
	tooltip_text = name_label.text + (" · " + ItemRegistry.get_rarity_name(rarity) if is_item else "") + "\n" + desc_label.text
	cost_label.text = "INSTALLED" if offer.sold else "%d" % offer.price
	cost_icon.visible = not offer.sold
	cost_icon.modulate = UiPalette.SCRAP if affordable else UiPalette.BAD
	cost_label.add_theme_color_override("font_color", UiPalette.GOOD if offer.sold else UiPalette.SCRAP if affordable else UiPalette.BAD)
	disabled = offer.sold
	focus_mode = Control.FOCUS_NONE if offer.sold else Control.FOCUS_ALL
	modulate = Color(1, 1, 1, .65) if offer.sold else Color.WHITE
