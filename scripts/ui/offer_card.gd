class_name OfferCard
extends Button

## Shop illustration, name, readable effect and price. Categories are intentionally not displayed.
signal previewed
signal lock_requested
var lock_button: Button
var icon_rect: TextureRect
var name_label: Label
var desc_label: Label
var cost_label: Label
var family_badges: AttackFamilyBadges
var shown_key: String = ""
var compact: bool = false
var content_margin: MarginContainer

func _init() -> void:
	custom_minimum_size = Vector2(220, 430)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL
	for slot: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("102b36") if slot in ["hover", "focus", "pressed"] else Color("0c212c")
		box.border_color = UiPalette.TEAL_HI if slot in ["hover", "focus", "pressed"] else Color("36505b")
		box.set_border_width_all(2 if slot == "focus" else 1)
		box.set_corner_radius_all(18)
		add_theme_stylebox_override(slot, box)
	var margin := MarginContainer.new()
	content_margin = margin
	margin.minimum_size_changed.connect(_refresh_minimum)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size.y = 150
	icon_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(icon_rect)
	name_label = _label(column, 30, UiPalette.INK)
	name_label.custom_minimum_size.y = 48
	family_badges = AttackFamilyBadges.new()
	family_badges.visible = false
	column.add_child(family_badges)
	desc_label = _label(column, 23, Color("bfd9d5"))
	desc_label.custom_minimum_size.y = 80
	cost_label = _label(column, 34, UiPalette.SCRAP)
	cost_label.theme_type_variation = &"Numeral"
	lock_button = Button.new()
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
	custom_minimum_size.y = maxf(315 if compact else 430, content_margin.get_combined_minimum_size().y)

func set_compact(value: bool) -> void:
	if compact == value:
		return
	compact = value
	custom_minimum_size.y = 315 if compact else 430
	icon_rect.custom_minimum_size.y = 95 if compact else 150
	name_label.custom_minimum_size.y = 38 if compact else 48
	name_label.add_theme_font_size_override("font_size", 26 if compact else 30)
	desc_label.custom_minimum_size.y = 70 if compact else 80
	desc_label.add_theme_font_size_override("font_size", 20 if compact else 23)
	_refresh_minimum()

func setup(offer: ShopOffer, damage_mult: float, affordable: bool) -> void:
	var key := "%s:%s:%d:%s:%s:%s:%s" % [offer.kind, offer.asset_id, offer.price, offer.sold, affordable, damage_mult, offer.locked]
	if key == shown_key:
		return
	shown_key = key
	lock_button.text = "UNLOCK" if offer.locked else "LOCK"
	lock_button.disabled = offer.sold
	lock_button.focus_mode = Control.FOCUS_NONE if offer.sold else Control.FOCUS_ALL
	lock_button.modulate = UiPalette.SCRAP if offer.locked else UiPalette.INK
	lock_button.tooltip_text = "Keep this offer and price across rerolls and waves. Unlocking restores its current price."
	var rarity := int(ItemRegistry.get_rarity(offer.asset_id)) if offer.kind == "item" else 0
	var accents: Array[Color] = [Color("36505b"), Color("657c5a"), Color("587992"), Color("84618c"), Color("ac8950")]
	(get_theme_stylebox("normal") as StyleBoxFlat).border_color = accents[clampi(rarity, 0, 4)]
	icon_rect.texture = ShopArt.turret(offer.asset_id) if offer.kind == "turret" else ShopArt.item(offer.asset_id)
	name_label.text = ArenaShop.offer_name(offer)
	family_badges.show_turret(offer.asset_id if offer.kind == "turret" else "")
	desc_label.text = ArenaShop.offer_description(offer)
	tooltip_text = name_label.text + "\n" + desc_label.text
	cost_label.text = "INSTALLED" if offer.sold else "%d scrap" % offer.price
	cost_label.add_theme_color_override("font_color", UiPalette.GOOD if offer.sold else UiPalette.SCRAP if affordable else UiPalette.BAD)
	disabled = offer.sold
	focus_mode = Control.FOCUS_NONE if offer.sold else Control.FOCUS_ALL
	modulate = Color(1, 1, 1, .65) if offer.sold else Color.WHITE
