class_name ShopScreen
extends Control

## Opaque shop presentation; transactions and simulation remain owned by ArenaShop/ArenaWorld.
## One screen: offers on top, the squad and owned items below, the build on the right. Focusing an offer
## tints the turrets it helps (green) or hurts (red); a squad card opens the turret details modal. Kept
## quiet on purpose: no borders except focus, one stat style (icon + value), no help text.
var world: ArenaWorld
var offer_buttons: Array[Button] = []
var reroll_button: IconButton
var hero_panel: HeroPanel
var continue_button: IconButton
var offers_grid: GridContainer
var balance: Label
var subtitle: Label
var squad_row: HBoxContainer
var squad_cards: Array[SquadCard] = []
var squad_empty: Label
var vitals: GridContainer
var weapon_badges: AttackFamilyBadges
var weapon_chips: GridContainer
var convoy_text: Label
var detail_title: Label
var detail_text: Label
var impact_text: Label
var installed: HFlowContainer
var status: Label
var details_modal: TurretDetailsModal
var turret_inspector: TurretInspector
var selected: int = -1
var details_key: int = 0
var installed_key: int = 0
var owned_buttons: Array[Button] = []
var prior_disable_3d: bool = false
var suppressing_world: bool = false

const SIDEBAR_WIDTH: float = 400.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color("07171f")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	_build_header(column)
	var content := HBoxContainer.new()
	content.size_flags_vertical = SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 28)
	column.add_child(content)
	_build_main(content)
	_build_sidebar(content)
	status = UiBuilder.label(column, "", 19, UiPalette.MUTED, true)
	details_modal = TurretDetailsModal.new(world)
	add_child(details_modal)
	turret_inspector = details_modal.inspector
	turret_inspector.sold.connect(_on_turret_sold)
	details_modal.closed.connect(_on_details_closed)
	visible = false

## One slim bar: title, wave and balance. The turret growth summary lives in the balance tooltip; each
## squad card shows its own XP gain.
func _build_header(column: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	column.add_child(header)
	UiBuilder.label(header, "SHOP", 40, UiPalette.INK)
	subtitle = UiBuilder.label(header, "", 24, UiPalette.MUTED)
	subtitle.size_flags_vertical = SIZE_SHRINK_CENTER
	subtitle.size_flags_horizontal = SIZE_EXPAND_FILL
	var wallet := HBoxContainer.new()
	wallet.add_theme_constant_override("separation", 8)
	header.add_child(wallet)
	var coin := TextureRect.new()
	coin.texture = UiIcons.get_icon("scrap")
	coin.modulate = UiPalette.SCRAP
	coin.custom_minimum_size = Vector2(30, 30)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.size_flags_vertical = SIZE_SHRINK_CENTER
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallet.add_child(coin)
	balance = UiBuilder.label(wallet, "", 38, UiPalette.SCRAP)
	balance.theme_type_variation = &"Numeral"
	balance.autowrap_mode = TextServer.AUTOWRAP_OFF
	balance.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	balance.mouse_filter = Control.MOUSE_FILTER_PASS

func _section(parent: Node, title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	var label := UiBuilder.label(row, title, 18, UiPalette.MUTED)
	label.size_flags_vertical = SIZE_SHRINK_CENTER
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	return row

## Offers, then the squad strip, then owned items, in one focus-following scroll.
func _build_main(content: HBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	content.add_child(scroll)
	# Focus outlines and impact badges extend beyond control bounds; reserve space inside the scroll clip.
	var focus_margin := MarginContainer.new()
	focus_margin.size_flags_horizontal = SIZE_EXPAND_FILL
	for edge in ["left", "right", "top", "bottom"]:
		focus_margin.add_theme_constant_override("margin_" + edge, 6)
	scroll.add_child(focus_margin)
	var main := VBoxContainer.new()
	main.size_flags_horizontal = SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 14)
	focus_margin.add_child(main)
	var offers_header := _section(main, "OFFERS")
	reroll_button = IconButton.new().setup("reroll", "REROLL")
	reroll_button.custom_minimum_size = Vector2(200, 44)
	_quiet(reroll_button, Color("0b1f28"), UiPalette.INK)
	reroll_button.pressed.connect(_reroll)
	offers_header.add_child(reroll_button)
	offers_grid = GridContainer.new()
	offers_grid.columns = 4
	offers_grid.size_flags_horizontal = SIZE_EXPAND_FILL
	offers_grid.add_theme_constant_override("h_separation", 16)
	offers_grid.add_theme_constant_override("v_separation", 16)
	main.add_child(offers_grid)
	for i in range(GameConstants.SHOP_OFFER_COUNT):
		var card := OfferCard.new()
		card.pressed.connect(_purchase.bind(i))
		card.previewed.connect(_select.bind(i))
		card.lock_requested.connect(_toggle_lock.bind(i))
		var slot := VBoxContainer.new()
		slot.size_flags_horizontal = SIZE_EXPAND_FILL
		offers_grid.add_child(slot)
		slot.add_child(card)
		offer_buttons.append(card)
	_section(main, "SQUAD")
	var squad_scroll := ScrollContainer.new()
	squad_scroll.follow_focus = true
	squad_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	squad_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	main.add_child(squad_scroll)
	var squad_margin := MarginContainer.new()
	# Room for the focus ring.
	for edge in ["left", "right", "top", "bottom"]:
		squad_margin.add_theme_constant_override("margin_" + edge, 4)
	squad_scroll.add_child(squad_margin)
	squad_row = HBoxContainer.new()
	squad_row.add_theme_constant_override("separation", 14)
	squad_margin.add_child(squad_row)
	squad_empty = UiBuilder.label(squad_row, "No turrets deployed yet.", 20, UiPalette.MUTED)
	_section(main, "ITEMS")
	installed = HFlowContainer.new()
	installed.add_theme_constant_override("h_separation", 10)
	installed.add_theme_constant_override("v_separation", 10)
	main.add_child(installed)

## Hero, the build as one aligned list (with the focused offer's before → after), what the focused offer
## does, and Prepare. A fill, no outline.
func _build_sidebar(content: HBoxContainer) -> void:
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = SIDEBAR_WIDTH
	side.add_theme_constant_override("separation", 14)
	content.add_child(side)
	var panel := PanelContainer.new()
	panel.size_flags_vertical = SIZE_EXPAND_FILL
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("0a1c24")
	fill.set_corner_radius_all(14)
	fill.content_margin_left = 22
	fill.content_margin_right = 22
	fill.content_margin_top = 20
	fill.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", fill)
	side.add_child(panel)
	var side_scroll := ScrollContainer.new()
	side_scroll.follow_focus = true
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(side_scroll)
	var sidebar := VBoxContainer.new()
	sidebar.size_flags_horizontal = SIZE_EXPAND_FILL
	sidebar.add_theme_constant_override("separation", 10)
	side_scroll.add_child(sidebar)
	hero_panel = HeroPanel.new()
	sidebar.add_child(hero_panel)
	UiBuilder.label(sidebar, "BUILD", 18, UiPalette.MUTED)
	vitals = _stat_list(sidebar)
	convoy_text = UiBuilder.label(sidebar, "", 19, UiPalette.MUTED, true)
	var weapon_header := HBoxContainer.new()
	weapon_header.add_theme_constant_override("separation", 8)
	sidebar.add_child(weapon_header)
	UiBuilder.label(weapon_header, "HERO WEAPON", 18, UiPalette.MUTED)
	weapon_badges = AttackFamilyBadges.new(false, 20.0)
	weapon_header.add_child(weapon_badges)
	weapon_chips = _stat_list(sidebar)
	# Only an installed item fills the title and text (offers already show theirs on the card).
	detail_title = UiBuilder.label(sidebar, "", 24, UiPalette.INK, true)
	detail_text = UiBuilder.label(sidebar, "", 19, Color("a9c0c6"), true)
	impact_text = UiBuilder.label(sidebar, "", 20, UiPalette.GOOD, true)
	continue_button = IconButton.new().setup("deploy", "PREPARE", true)
	continue_button.custom_minimum_size.y = 60
	_quiet(continue_button, UiPalette.TEAL_HI, UiPalette.PANEL_SOLID)
	continue_button.pressed.connect(_request_deploy)
	side.add_child(continue_button)

## Restyles an IconButton as a plain fill (no outline); focus adds a light ring.
func _quiet(button: IconButton, fill: Color, ink: Color) -> void:
	var clear := Color(0, 0, 0, 0)
	button.add_theme_stylebox_override("normal", ChamferStyle.make(fill, clear, 10.0, 22.0, 8.0))
	button.add_theme_stylebox_override("hover", ChamferStyle.make(fill.lightened(.12), clear, 10.0, 22.0, 8.0))
	button.add_theme_stylebox_override("pressed", ChamferStyle.make(fill.lightened(.2), clear, 10.0, 22.0, 8.0))
	button.add_theme_stylebox_override("disabled", ChamferStyle.make(Color(fill, .4), clear, 10.0, 22.0, 8.0))
	var ring := ChamferStyle.make(clear, Color.WHITE if fill == UiPalette.TEAL_HI else UiPalette.TEAL_HI, 10.0, 22.0, 8.0)
	ring.edge_width = 2.0
	button.add_theme_stylebox_override("focus", ring)
	for slot in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		button.add_theme_color_override(slot, ink)
	button.add_theme_color_override("font_disabled_color", Color(ink, .4))
	button.add_theme_color_override("icon_disabled_color", Color(ink, .4))

func refresh() -> void:
	var active := world.shop.is_open() and not world.dev_menu_open
	var opening := active and not visible
	if opening:
		selected = -1
		details_modal.visible = false
	visible = active
	if active and not suppressing_world:
		prior_disable_3d = get_viewport().disable_3d
		get_viewport().disable_3d = true
		suppressing_world = true
	elif not active:
		_restore_world()
		return
	subtitle.text = "Wave %d" % (GameStateService.current_wave + 1)
	balance.text = "%d" % EconomyService.total_scrap
	balance.tooltip_text = "%d scrap\n%s" % [EconomyService.total_scrap, ShopDetailText.growth_summary(world).replace("   ·   ", "\n")]
	var compact := size.x < 1650
	offers_grid.columns = 2 if compact else 4
	for i in range(offer_buttons.size()):
		var card := offer_buttons[i] as OfferCard
		var exists := i < EconomyService.current_shop_offers.size()
		card.visible = exists and not EconomyService.current_shop_offers[i].sold
		# A bought offer leaves its slot empty so the other cards keep their places.
		(card.get_parent() as Control).visible = exists
		card.set_compact(compact)
		if card.visible:
			var offer := EconomyService.current_shop_offers[i]
			card.setup(offer, float(world.difficulty_config["turret_damage_mult"]), EconomyService.total_scrap >= offer.price)
	var cost := world.shop.reroll_cost()
	reroll_button.set_cost(cost, EconomyService.total_scrap >= cost)
	reroll_button.disabled = not world.shop.can_reroll() or EconomyService.total_scrap < cost
	status.text = world.message
	hero_panel.refresh()
	_refresh_details()
	if details_modal.visible:
		turret_inspector.refresh()
	_refresh_focus()
	if opening:
		selected = -1
		continue_button.grab_focus()

## Opens the details modal on one turret (the first when `turret_id` is 0).
func open_turret_details(turret_id: int = 0) -> void:
	if world.turrets.is_empty():
		return
	details_modal.open(turret_id)

func close_turret_details() -> void:
	details_modal.close()

func _on_details_closed() -> void:
	var id := turret_inspector.selected_id
	for card in squad_cards:
		if card.turret_id == id:
			card.grab_focus()
			return
	continue_button.grab_focus()

func _on_turret_sold() -> void:
	details_key = 0
	refresh()
	if world.turrets.is_empty():
		close_turret_details()

func _input(event: InputEvent) -> void:
	if not visible or not world.shop.is_open():
		return
	if details_modal.visible:
		var back: bool = (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE) \
			or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)
		if back:
			close_turret_details()
			get_viewport().set_input_as_handled()
		return
	var lock_pressed: bool = (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_L) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_X)
	if lock_pressed:
		var focused := offer_buttons.find(get_viewport().gui_get_focus_owner())
		var index := focused if focused >= 0 else selected
		if index >= 0:
			_toggle_lock(index)
			get_viewport().set_input_as_handled()

func _restore_world() -> void:
	if suppressing_world:
		get_viewport().disable_3d = prior_disable_3d
		suppressing_world = false

func _exit_tree() -> void:
	_restore_world()

func _select(index: int) -> void:
	selected = index
	details_key = 0
	_refresh_details()

func _toggle_lock(index: int) -> void:
	if world.shop.toggle_lock(index):
		refresh()

func _purchase(index: int) -> void:
	var had_focus := offer_buttons[index].has_focus()
	if world.shop.purchase(index):
		refresh()
		if had_focus:
			continue_button.grab_focus()
			for offset in range(1, offer_buttons.size() + 1):
				var card := offer_buttons[(index + offset) % offer_buttons.size()]
				if card.visible and not card.disabled:
					card.grab_focus()
					break
	else:
		status.text = world.message

func _reroll() -> void:
	if world.shop.reroll():
		selected = -1
		details_key = 0
	refresh()

func _focused_offer() -> ShopOffer:
	if selected < 0 or selected >= EconomyService.current_shop_offers.size():
		return null
	var offer := EconomyService.current_shop_offers[selected]
	return null if offer.sold else offer

func _refresh_details() -> void:
	if not is_instance_valid(world.player):
		return
	var data := ShopViewData.build_data(world)
	var key := [data, EconomyService.current_shop_offers.map(func(o: ShopOffer) -> Array: return [o.asset_id, o.price, o.sold, o.level, o.form]), selected,
		world.core.health if world.core else -1, world.turrets.map(func(t: TurretActor) -> Array: return [t.turret_id, t.progression.snapshot()])].hash()
	if key == details_key:
		return
	details_key = key
	var offer := _focused_offer()
	var after := ShopViewData.preview(world, offer) if offer else data
	var impacts := ShopViewData.turret_impacts(world, offer, data, after) if offer else {}
	_refresh_squad(data, after, impacts, offer != null)
	_refresh_build(data, after)
	detail_title.text = ""
	detail_text.text = ""
	impact_text.text = ""
	if offer:
		impact_text.text = _impact_summary(offer, impacts)
		impact_text.add_theme_color_override("font_color", UiPalette.MUTED if impacts.is_empty() else UiPalette.GOOD)
	_show_detail_labels()
	_refresh_installed(data["items"])

func _impact_summary(offer: ShopOffer, impacts: Dictionary) -> String:
	var helped := 0
	var hurt := 0
	for id: Variant in impacts:
		if str(id) == "hero":
			continue
		helped += int(impacts[id]["tone"] >= 0)
		hurt += int(impacts[id]["tone"] <= 0)
	var parts := PackedStringArray()
	if helped > 0:
		parts.append("Helps %d %s" % [helped, "turret" if helped == 1 else "turrets"])
	if hurt > 0:
		parts.append("hurts %d" % hurt if helped > 0 else "Hurts %d %s" % [hurt, "turret" if hurt == 1 else "turrets"])
	if impacts.has("hero"):
		var tone := int(impacts["hero"]["tone"])
		parts.append("%s your hero" % ("helps" if tone > 0 else "hurts" if tone < 0 else "changes"))
	if not parts.is_empty():
		return " · ".join(parts) + "."
	if offer.asset_id in ["mono_type_mastery", "army_doctrine", "elite_forces", "elemental_conduit"]:
		return "No active bonus for this build."
	return ""

func _show_detail_labels() -> void:
	for label: Label in [detail_title, detail_text, impact_text]:
		label.visible = not label.text.is_empty()

## Rebuild the squad strip when the roster changes, then refresh every card's numbers and impact.
func _refresh_squad(data: Dictionary, after: Dictionary, impacts: Dictionary, focused: bool) -> void:
	var ids := world.turrets.map(func(t: TurretActor) -> int: return t.turret_id)
	if ids != squad_cards.map(func(c: SquadCard) -> int: return c.turret_id):
		for card in squad_cards:
			squad_row.remove_child(card)
			card.queue_free()
		squad_cards.clear()
		for actor in world.turrets:
			var card := SquadCard.new()
			card.turret_id = actor.turret_id
			card.pressed.connect(open_turret_details.bind(actor.turret_id))
			squad_row.add_child(card)
			squad_cards.append(card)
	squad_empty.visible = squad_cards.is_empty()
	for i in world.turrets.size():
		var actor := world.turrets[i]
		var growth := actor.progression
		var families: Array = ["kinetic", "projectile"] if growth.evolution_form == "stormblade" else TurretRegistry.get_attack_families(actor.turret_type)
		var numbers := _actor_numbers(data, actor)
		var stats: Array = []
		if bool(numbers.get("utility", false)):
			stats.append(["timer", "%.1fs" % float(numbers.get("interval", 0.0))])
		else:
			stats.append(["damage", "%.1f" % float(numbers.get("damage", 0.0))])
			stats.append(["rate", "%.0f°/s" % float(numbers["rotation_rate"]) if float(numbers.get("rotation_rate", 0.0)) > 0.0 else "%.1f" % float(numbers.get("fire_rate", 0.0))])
		var text := ShopDetailText.instance_text(world, data, after, actor)
		squad_cards[i].setup(actor.turret_id, "%s #%d" % [actor.display_name(), actor.turret_id], actor.turret_type,
			growth.evolution_form, growth.level, growth.xp, families, stats, text, _xp_gain(actor.turret_id))
		squad_cards[i].show_impact(impacts.get(actor.turret_id, {}), focused)

## XP this turret received from the salvage settlement that ended the current wave (0 if none).
func _xp_gain(turret_id: int) -> int:
	var ledger := world.salvage.last_settlement
	if ledger.is_empty() or int(ledger.get("wave", -1)) != GameStateService.current_wave:
		return 0
	return int(ledger.get("changes", {}).get(turret_id, {}).get("xp_awarded", 0))

## This turret's current numbers: its own when turret growth is on, otherwise its type's.
func _actor_numbers(data: Dictionary, actor: TurretActor) -> Dictionary:
	for turret: Dictionary in data["turrets"]:
		if turret["id"] != actor.turret_type:
			continue
		for growth: Dictionary in turret.get("instances", []):
			if growth["id"] == actor.turret_id:
				return growth["combat"]
		return turret
	return {}

## Hull, core, movement, pickup, luck and the hero weapon as aligned rows of icon, label and value. While
## an offer is focused a changed value reads "old → new", the new value green or red.
func _refresh_build(data: Dictionary, after: Dictionary) -> void:
	for container: Node in [vitals, weapon_chips]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	_stat_row(vitals, "hull", "Hull", "%d / %d" % [ceili(data["hull"]), ceili(data["max_hull"])],
		"%d / %d" % [ceili(after["hull"]), ceili(after["max_hull"])], _tone(data["max_hull"], after["max_hull"]))
	if world.core:
		var core := "%d / %d" % [ceili(world.core.health), ceili(world.core.max_health)]
		_stat_row(vitals, "core", "Core", core, core, 0)
	_number_row(vitals, "speed", "Move speed", data["speed"], after["speed"], " m/s")
	_number_row(vitals, "pickup", "Pickup", data["pickup"], after["pickup"], " m")
	_stat_row(vitals, "star", "Luck", "%d" % data["luck"], "%d" % after["luck"], _tone(data["luck"], after["luck"]))
	convoy_text.visible = world.convoy_mode
	if world.convoy_mode:
		convoy_text.text = world.shop.convoy_preview_line()
	weapon_badges.show_families(world.run_config.hero.families, "hero")
	var was: Dictionary = data["hero_weapon"]
	var now: Dictionary = after["hero_weapon"]
	_number_row(weapon_chips, "damage", "Damage", float(was["damage"]), float(now["damage"]), "")
	_number_row(weapon_chips, "rate", "Shots/s", float(was["fire_rate"]), float(now["fire_rate"]), "")
	_number_row(weapon_chips, "range", "Reach", float(was["range"]) * WorldGeometry.METRES_PER_PIXEL,
		float(now["range"]) * WorldGeometry.METRES_PER_PIXEL, " m")

func _stat_list(parent: Node) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	return grid

func _number_row(grid: GridContainer, icon: String, title: String, before: float, after: float, unit: String) -> void:
	var format := StatFormat.decimals(before, after) + unit
	_stat_row(grid, icon, title, format % before, format % after, _tone(before, after))

## One build row: icon, label, then the value ("old → new" with the new value toned when it changes).
func _stat_row(grid: GridContainer, icon_name: String, title: String, before: String, after: String, tone: int) -> void:
	var icon := TextureRect.new()
	icon.texture = UiIcons.get_icon(icon_name)
	icon.modulate = StatChip.ICON_NEUTRAL
	icon.custom_minimum_size = Vector2(22, 22)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = SIZE_SHRINK_CENTER
	grid.add_child(icon)
	var name_label := UiBuilder.label(grid, title, 20, UiPalette.MUTED)
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	var value := HBoxContainer.new()
	value.add_theme_constant_override("separation", 6)
	value.alignment = BoxContainer.ALIGNMENT_END
	value.tooltip_text = title
	grid.add_child(value)
	if before != after:
		var old := UiBuilder.label(value, before + " →", 20, Color("6f8d96"))
		old.theme_type_variation = &"Numeral"
	var now := UiBuilder.label(value, after, 20, UiPalette.tone_color(tone, UiPalette.INK) if before != after else UiPalette.INK)
	now.theme_type_variation = &"Numeral"

func _tone(before: float, after: float) -> int:
	return 0 if is_equal_approx(before, after) else (1 if after > before else -1)

func _refresh_installed(items: Array) -> void:
	if items.hash() == installed_key:
		return
	installed_key = items.hash()
	for child in installed.get_children():
		installed.remove_child(child)
		child.queue_free()
	owned_buttons.clear()
	for item: Dictionary in items:
		var definition := ItemRegistry.get_item(item["id"])
		var button := Button.new()
		button.custom_minimum_size = Vector2(72, 72)
		button.icon = ShopArt.item(item["id"])
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.tooltip_text = "%s ×%d\n%s" % [item["name"], item["count"], definition.description]
		for slot: String in ["normal", "hover", "pressed", "focus"]:
			var box := StyleBoxFlat.new()
			box.bg_color = UiPalette.PANEL_HI if slot != "normal" else Color("0b1f28")
			box.border_color = UiPalette.TEAL_HI
			box.set_border_width_all(2 if slot == "focus" else 0)
			box.set_corner_radius_all(10)
			box.set_content_margin_all(6)
			button.add_theme_stylebox_override(slot, box)
		button.focus_entered.connect(_inspect_owned.bind(item["id"]))
		button.pressed.connect(_inspect_owned.bind(item["id"]))
		installed.add_child(button)
		if int(item["count"]) > 1:
			var count := UiBuilder.label(button, "×%d" % item["count"], 18, UiPalette.INK)
			count.theme_type_variation = &"Numeral"
			count.mouse_filter = Control.MOUSE_FILTER_IGNORE
			count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			count.offset_left = -34
			count.offset_top = -26
			count.offset_right = -4
			count.offset_bottom = -2
			count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		owned_buttons.append(button)
	if items.is_empty():
		UiBuilder.label(installed, "No upgrades installed yet.", 20, UiPalette.MUTED)

func _inspect_owned(id: String) -> void:
	selected = -1
	_refresh_details()
	detail_title.text = ItemRegistry.get_item(id).name
	detail_text.text = ItemRegistry.get_item(id).description
	impact_text.text = "Installed ×%d" % ItemTrackingService.item_counts.get(id, 0)
	impact_text.add_theme_color_override("font_color", UiPalette.MUTED)
	_show_detail_labels()

## Controller paths: offers (left/right, up to Reroll) → squad → items → Prepare. Locks are not focus
## stops: X / L locks the focused card. Every row's right end and the bottom of the page lead to Prepare;
## Prepare climbs back the way it came.
func _refresh_focus() -> void:
	var available: Array[Button] = []
	for card in offer_buttons:
		if card.visible and not card.disabled:
			available.append(card)
	# Row 0 stays empty so going up from the squad lands on the nearest offer card.
	var locks: Array[Button] = []
	var squad: Array[Button] = []
	for card in squad_cards:
		squad.append(card)
	var rows: Array = [locks, squad, owned_buttons]
	reroll_button.focus_neighbor_bottom = reroll_button.get_path_to(available[0] if not available.is_empty() else _first_row(rows, 0))
	reroll_button.focus_neighbor_right = reroll_button.get_path_to(continue_button)
	reroll_button.focus_neighbor_left = reroll_button.get_path_to(reroll_button)
	reroll_button.focus_neighbor_top = reroll_button.get_path_to(reroll_button)
	var columns := offers_grid.columns
	for i in available.size():
		var card := available[i]
		var position := offer_buttons.find(card)
		var left: Button = card
		var right: Button = card
		if i > 0 and offer_buttons.find(available[i - 1]) / columns == position / columns: left = available[i - 1]
		if i + 1 < available.size() and offer_buttons.find(available[i + 1]) / columns == position / columns: right = available[i + 1]
		var above := position - columns
		var below := position + columns
		card.focus_neighbor_left = card.get_path_to(left if left != card else reroll_button if not reroll_button.disabled else card)
		card.focus_neighbor_right = card.get_path_to(right if right != card else continue_button)
		card.focus_neighbor_top = card.get_path_to(offer_buttons[above] if above >= 0 and offer_buttons[above] in available else reroll_button)
		card.focus_neighbor_bottom = card.get_path_to(offer_buttons[below] if below < offer_buttons.size() and offer_buttons[below] in available else _nearest_in_rows(card, rows, 1))
	for r in [1, 2]:
		var row: Array[Button] = rows[r]
		for i in row.size():
			var button := row[i]
			button.focus_neighbor_left = button.get_path_to(row[i - 1] if i > 0 else button)
			button.focus_neighbor_right = button.get_path_to(row[i + 1] if i + 1 < row.size() else continue_button)
			button.focus_neighbor_top = button.get_path_to(_nearest_in_rows(button, rows, r - 1, -1))
			button.focus_neighbor_bottom = button.get_path_to(_nearest_in_rows(button, rows, r + 1))
	continue_button.focus_neighbor_top = continue_button.get_path_to(_last_row_end(rows))
	continue_button.focus_neighbor_left = continue_button.focus_neighbor_top
	continue_button.focus_neighbor_bottom = continue_button.get_path_to(continue_button)
	continue_button.focus_neighbor_right = continue_button.get_path_to(continue_button)

## The control nearest `from` horizontally in the first non-empty row from `start` going `step`; Prepare
## below the last row, the nearest offer card (or Reroll) above the first.
func _nearest_in_rows(from: Control, rows: Array, start: int, step: int = 1) -> Button:
	var r := start
	while r >= 0 and r < rows.size():
		var candidates: Array[Button] = rows[r]
		var visible_ones := candidates.filter(func(b: Button) -> bool: return b.is_visible_in_tree() and not b.disabled)
		if not visible_ones.is_empty():
			return _nearest_horizontal(from, visible_ones)
		r += step
	if step < 0:
		var cards := offer_buttons.filter(func(b: Button) -> bool: return b.visible and not b.disabled)
		return _nearest_horizontal(from, cards) if not cards.is_empty() else reroll_button
	return continue_button

func _first_row(rows: Array, start: int) -> Button:
	return _nearest_in_rows(continue_button, rows, start)

func _last_row_end(rows: Array) -> Button:
	for r in range(rows.size() - 1, -1, -1):
		var row: Array[Button] = rows[r]
		var visible_ones := row.filter(func(b: Button) -> bool: return b.is_visible_in_tree() and not b.disabled)
		if not visible_ones.is_empty():
			return visible_ones.back()
	var cards := offer_buttons.filter(func(b: Button) -> bool: return b.visible and not b.disabled)
	return cards.back() if not cards.is_empty() else reroll_button

func _request_deploy() -> void:
	_deploy()

func _deploy() -> void:
	world.begin_next_wave()
	refresh()

func _nearest_horizontal(from: Control, candidates: Array) -> Button:
	var best: Button = continue_button
	var distance := INF
	for candidate: Button in candidates:
		if not candidate.is_visible_in_tree() or candidate.disabled: continue
		var gap := absf(candidate.get_global_rect().get_center().x - from.get_global_rect().get_center().x)
		if gap < distance:
			distance = gap
			best = candidate
	return best
