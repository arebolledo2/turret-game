class_name OfferCard
extends Button

## Shop offer: illustration beside the name, rarity (or level) and attack family badges, effect chips that
## sum up the numbers, the full effect text (effects are often unique, so the words stay) and the price.
signal previewed
signal lock_requested
var lock_button: Button
var icon_rect: TextureRect
var name_label: Label
var rarity_label: Label
var desc_label: Label
var cost_label: Label
var family_badges: AttackFamilyBadges
var chips: HFlowContainer
var shown_key: String = ""
var compact: bool = false
var content_margin: MarginContainer

const MIN_HEIGHT: float = 300.0
const COMPACT_HEIGHT: float = 260.0

func _init() -> void:
	custom_minimum_size = Vector2(220, MIN_HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL
	for slot: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("102b36") if slot in ["hover", "focus", "pressed"] else Color("0c212c")
		box.border_color = UiPalette.TEAL_HI if slot in ["hover", "focus", "pressed"] else Color("36505b")
		box.set_border_width_all(3 if slot == "focus" else 1)
		box.set_corner_radius_all(14)
		add_theme_stylebox_override(slot, box)
	var margin := MarginContainer.new()
	content_margin = margin
	margin.minimum_size_changed.connect(_refresh_minimum)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 12)
	column.add_child(top)
	icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(88, 88)
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
	rarity_label = _label(identity, 16, UiPalette.MUTED)
	rarity_label.visible = false
	family_badges = AttackFamilyBadges.new(true, 22.0)
	family_badges.visible = false
	identity.add_child(family_badges)
	chips = HFlowContainer.new()
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	column.add_child(chips)
	desc_label = _label(column, 19, Color("bfd9d5"))
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cost_label = _label(column, 28, UiPalette.SCRAP)
	cost_label.theme_type_variation = &"Numeral"
	lock_button = Button.new()
	ChamferStyle.style_button(lock_button)
	lock_button.focus_mode = Control.FOCUS_ALL
	lock_button.mouse_filter = Control.MOUSE_FILTER_STOP
	lock_button.custom_minimum_size.y = 36
	lock_button.add_theme_font_size_override("font_size", 20)
	lock_button.pressed.connect(func() -> void: lock_requested.emit())
	lock_button.focus_entered.connect(func() -> void: previewed.emit())
	column.add_child(lock_button)
	for trigger: Signal in [focus_entered, mouse_entered]:
		trigger.connect(func() -> void: previewed.emit())

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
	icon_rect.custom_minimum_size = Vector2(64, 64) if compact else Vector2(88, 88)
	name_label.add_theme_font_size_override("font_size", 22 if compact else 25)
	desc_label.add_theme_font_size_override("font_size", 17 if compact else 19)
	_refresh_minimum()

func setup(offer: ShopOffer, damage_mult: float, affordable: bool) -> void:
	var key := "%s:%s:%d:%s:%s:%s:%s:%d:%s" % [offer.kind, offer.asset_id, offer.price, offer.sold, affordable, damage_mult, offer.locked, offer.level, offer.form]
	if key == shown_key:
		return
	shown_key = key
	lock_button.text = "UNLOCK" if offer.locked else "LOCK"
	lock_button.disabled = offer.sold
	lock_button.focus_mode = Control.FOCUS_NONE if offer.sold else Control.FOCUS_ALL
	lock_button.modulate = UiPalette.SCRAP if offer.locked else UiPalette.INK
	lock_button.tooltip_text = "Keep this offer and price across rerolls and waves. Unlocking restores its current price."
	var is_item := offer.kind == "item"
	var rarity := ItemRegistry.get_rarity(offer.asset_id) if is_item else GameEnums.ItemRarity.COMMON
	var accent := ItemRegistry.get_rarity_color(rarity) if is_item else UiPalette.TEAL_HI
	(get_theme_stylebox("normal") as StyleBoxFlat).border_color = Color(accent, .65)
	name_label.add_theme_color_override("font_color", accent if is_item else UiPalette.INK)
	rarity_label.visible = true
	rarity_label.text = ItemRegistry.get_rarity_name(rarity).to_upper() if is_item \
		else "LEVEL %d%s" % [offer.level, " · EVOLVED" if not offer.form.is_empty() else ""]
	rarity_label.add_theme_color_override("font_color", accent)
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
	cost_label.text = "INSTALLED" if offer.sold else "%d scrap" % offer.price
	cost_label.add_theme_color_override("font_color", UiPalette.GOOD if offer.sold else UiPalette.SCRAP if affordable else UiPalette.BAD)
	disabled = offer.sold
	focus_mode = Control.FOCUS_NONE if offer.sold else Control.FOCUS_ALL
	modulate = Color(1, 1, 1, .65) if offer.sold else Color.WHITE
