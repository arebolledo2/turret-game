class_name ShopScreen
extends Control

## Opaque shop presentation; transactions and simulation remain owned by ArenaShop/ArenaWorld.
var world: ArenaWorld
var active_tab: int = 0
var tabs: Array[Button] = []
var offers_content: HBoxContainer
var turret_inspector: TurretInspector
var offer_buttons: Array[Button] = []
var reroll_button: IconButton
var repair_button: IconButton
var core_repair_button: IconButton
var evolution_reminder: EvolutionReminder
var continue_button: IconButton
var offers_grid: GridContainer
var balance: Label
var subtitle: Label
var growth_summary: Label
var vital_text: Label
var turret_text: RichTextLabel
var detail_title: Label
var detail_text: Label
var impact_text: Label
var installed: VBoxContainer
var status: Label
var selected: int = -1
var details_key: int = 0
var installed_key: int = 0
var owned_buttons: Array[Button] = []
var prior_disable_3d: bool = false
var suppressing_world: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color("07171f")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 56)
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(heading)
	_label(heading, "SHOP", 48)
	subtitle = _label(heading, "", 23, UiPalette.MUTED)
	balance = _label(header, "", 42, UiPalette.SCRAP)
	balance.autowrap_mode = TextServer.AUTOWRAP_OFF
	balance.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	growth_summary = _label(column, "", 24, UiPalette.GOOD)
	column.add_child(HSeparator.new())
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 16)
	column.add_child(tab_row)
	for tab_name in ["OFFERS", "TURRETS"]:
		var tab := Button.new()
		tab.text = tab_name
		tab.toggle_mode = true
		tab.custom_minimum_size = Vector2(220, 52)
		tab.add_theme_font_size_override("font_size", 25)
		tab.pressed.connect(switch_tab.bind(tabs.size()))
		tab_row.add_child(tab)
		tabs.append(tab)
	var tab_hint := _label(tab_row, "Tabs: Q / E or LB / RB  ·  Details: right stick / mouse wheel", 21, UiPalette.MUTED)
	tab_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	tab_hint.size_flags_horizontal = SIZE_EXPAND_FILL
	tab_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var content := HBoxContainer.new()
	offers_content = content
	content.size_flags_vertical = SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 32)
	column.add_child(content)
	var offers_scroll := ScrollContainer.new()
	offers_scroll.follow_focus = true
	offers_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	offers_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	content.add_child(offers_scroll)
	offers_grid = GridContainer.new()
	offers_grid.columns = 4
	offers_grid.size_flags_horizontal = SIZE_EXPAND_FILL
	offers_grid.size_flags_vertical = SIZE_EXPAND_FILL
	offers_grid.add_theme_constant_override("h_separation", 18)
	offers_grid.add_theme_constant_override("v_separation", 18)
	offers_scroll.add_child(offers_grid)
	for i in range(4):
		var card := OfferCard.new()
		card.pressed.connect(_purchase.bind(i))
		card.previewed.connect(_select.bind(i))
		card.lock_requested.connect(_toggle_lock.bind(i))
		offers_grid.add_child(card)
		offer_buttons.append(card)
	var side_scroll := ScrollContainer.new()
	side_scroll.follow_focus = true
	side_scroll.custom_minimum_size.x = 410
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(side_scroll)
	var sidebar := VBoxContainer.new()
	sidebar.size_flags_horizontal = SIZE_EXPAND_FILL
	sidebar.add_theme_constant_override("separation", 16)
	side_scroll.add_child(sidebar)
	_label(sidebar, "Your build", 30)
	vital_text = _label(sidebar, "", 23, UiPalette.MUTED)
	turret_text = RichTextLabel.new()
	turret_text.bbcode_enabled = true
	turret_text.fit_content = true
	turret_text.scroll_active = false
	turret_text.add_theme_font_size_override("normal_font_size", 23)
	sidebar.add_child(turret_text)
	sidebar.add_child(HSeparator.new())
	detail_title = _label(sidebar, "Choose an offer", 30)
	detail_text = _label(sidebar, "See what it adds to your build.", 23, Color("b9cdd0"))
	impact_text = _label(sidebar, "", 23, UiPalette.GOOD)
	sidebar.add_child(HSeparator.new())
	_label(sidebar, "Installed upgrades", 26)
	installed = VBoxContainer.new()
	sidebar.add_child(installed)
	turret_inspector = TurretInspector.new()
	turret_inspector.world = world
	turret_inspector.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(turret_inspector)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 18)
	column.add_child(footer)
	reroll_button = IconButton.new().setup("reroll", "REROLL")
	reroll_button.custom_minimum_size.x = 265
	reroll_button.pressed.connect(_reroll)
	footer.add_child(reroll_button)
	repair_button = IconButton.new().setup("repair", "+10 HULL")
	repair_button.custom_minimum_size.x = 285
	repair_button.pressed.connect(func() -> void: world.repair(); refresh())
	footer.add_child(repair_button)
	core_repair_button = IconButton.new().setup("core", "+10 CORE")
	core_repair_button.custom_minimum_size.x = 285
	core_repair_button.pressed.connect(func() -> void: world.repair_core(); refresh())
	footer.add_child(core_repair_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	footer.add_child(spacer)
	continue_button = IconButton.new().setup("deploy", "PREPARE", true)
	continue_button.custom_minimum_size.x = 310
	continue_button.pressed.connect(_request_deploy)
	footer.add_child(continue_button)
	turret_inspector.navigation_exit = continue_button
	evolution_reminder = EvolutionReminder.new()
	add_child(evolution_reminder)
	evolution_reminder.review_requested.connect(_review_ready_turret)
	evolution_reminder.deploy_requested.connect(_deploy)
	evolution_reminder.canceled.connect(func() -> void: continue_button.grab_focus.call_deferred())
	status = _label(column, "", 20, UiPalette.MUTED)
	visible = false

func _label(parent: Node, text: String, font_size: int, color: Color = UiPalette.INK) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func refresh() -> void:
	var active := world.shop.is_open() and not world.dev_menu_open
	var opening := active and not visible
	if opening:
		selected = -1
	visible = active
	if active and not suppressing_world:
		prior_disable_3d = get_viewport().disable_3d
		get_viewport().disable_3d = true
		suppressing_world = true
	elif not active:
		_restore_world()
		return
	subtitle.text = "Wave %d secured · Prepare for wave %d" % [GameStateService.current_wave, GameStateService.current_wave + 1]
	balance.text = "%d SCRAP" % EconomyService.total_scrap
	growth_summary.text = _growth_summary()
	var compact := size.x < 1650
	offers_grid.columns = 2 if compact else 4
	continue_button.custom_minimum_size.x = 250 if compact else 310
	for i in range(offer_buttons.size()):
		var card := offer_buttons[i] as OfferCard
		card.visible = i < EconomyService.current_shop_offers.size()
		card.set_compact(compact)
		if card.visible:
			var offer := EconomyService.current_shop_offers[i]
			card.setup(offer, float(world.difficulty_config["turret_damage_mult"]), EconomyService.total_scrap >= offer.price)
	var cost := world.shop.reroll_cost()
	reroll_button.set_cost(cost, EconomyService.total_scrap >= cost)
	reroll_button.disabled = not world.shop.can_reroll() or EconomyService.total_scrap < cost
	for button: IconButton in [repair_button, core_repair_button]:
		button.set_cost(GameConstants.REPAIR_COST, EconomyService.total_scrap >= GameConstants.REPAIR_COST)
	repair_button.disabled = EconomyService.total_scrap < GameConstants.REPAIR_COST or world.player.health >= world.player.max_health
	core_repair_button.visible = world.core != null
	core_repair_button.disabled = not world.core or EconomyService.total_scrap < GameConstants.REPAIR_COST or world.core.health >= world.core.max_health
	status.text = world.message
	offers_content.visible = active_tab == 0
	turret_inspector.visible = active_tab == 1
	reroll_button.visible = active_tab == 0
	var ready_turrets := 0
	for turret in world.turrets:
		if not turret.available_evolutions().is_empty():
			ready_turrets += 1
	tabs[1].text = "TURRETS" if ready_turrets == 0 else "TURRETS - %d READY" % ready_turrets
	for i in tabs.size():
		tabs[i].set_pressed_no_signal(i == active_tab)
	if active_tab == 1:
		turret_inspector.refresh()
	_refresh_details()
	_refresh_focus()
	if opening:
		selected = -1
		continue_button.grab_focus()

func switch_tab(index: int) -> void:
	active_tab = clampi(index, 0, 1)
	refresh()
	tabs[active_tab].grab_focus()

func _input(event: InputEvent) -> void:
	if not visible or not world.shop.is_open() or turret_inspector.evolution_preview.visible or evolution_reminder.visible:
		return
	var lock_pressed: bool = (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_L) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_X)
	if lock_pressed and active_tab == 0:
		var focused := offer_buttons.find(get_viewport().gui_get_focus_owner())
		var index := focused if focused >= 0 else selected
		if index >= 0:
			_toggle_lock(index)
			get_viewport().set_input_as_handled()
		return
	var direction := 0
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_Q:
			direction = -1
		elif event.physical_keycode == KEY_E:
			direction = 1
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			direction = -1
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			direction = 1
	if direction != 0:
		switch_tab(posmod(active_tab + direction, 2))
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
			for card in offer_buttons:
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

func _refresh_details() -> void:
	if not is_instance_valid(world.player):
		return
	var data := ShopViewData.build_data(world)
	var key := [data, EconomyService.current_shop_offers.map(func(o: ShopOffer) -> Array: return [o.asset_id, o.price, o.sold]), selected,
		world.core.health if world.core else -1].hash()
	if key == details_key:
		return
	details_key = key
	vital_text.text = "Hull %d / %d" % [ceili(data["hull"]), ceili(data["max_hull"])]
	if world.core:
		vital_text.text += "   Core %d / %d" % [ceili(world.core.health), ceili(world.core.max_health)]
	var after := data
	if selected >= 0 and selected < EconomyService.current_shop_offers.size():
		var offer := EconomyService.current_shop_offers[selected]
		detail_title.text = ArenaShop.offer_name(offer)
		detail_text.text = ArenaShop.offer_description(offer)
		if not offer.sold:
			after = ShopViewData.preview(world, offer)
			var affected := ShopViewData.affected_turrets(world, offer)
			if after.hero_weapon != data.hero_weapon:
				affected.push_front("Hero weapon")
			if not affected.is_empty():
				impact_text.text = "Affects: " + ", ".join(affected)
			elif offer.asset_id in ["mono_type_mastery", "army_doctrine", "elite_forces", "elemental_conduit"]:
				impact_text.text = "No active bonus for this build."
			else:
				impact_text.text = "No matching turret owned" if _needs_turret(offer) else "Upgrades your support systems."
		else:
			impact_text.text = "Installed."
	else:
		detail_title.text = "Choose an offer"
		detail_text.text = "Inspect its benefits and the changes to your build."
		impact_text.text = ""
	if after["max_hull"] != data["max_hull"]:
		vital_text.text += "\nMax hull %.0f → %.0f" % [data["max_hull"], after["max_hull"]]
	vital_text.text += "\nMove %.2f m/s · Pickup %.2f m" % [after["speed"], after["pickup"]]
	if world.convoy_mode:
		vital_text.text += "\n" + world.shop.convoy_preview_line()
	var lines := PackedStringArray()
	lines.append("[b]Hero weapon · %s[/b]\n%s damage · %s shots/s\n%s m reach" % [
		", ".join(world.run_config.hero.families).capitalize(),
		_number(data.hero_weapon, after.hero_weapon, "damage", ""),
		_number(data.hero_weapon, after.hero_weapon, "fire_rate", ""),
		"%.2f" % (float(after.hero_weapon.range) * WorldGeometry.METRES_PER_PIXEL)])
	for turret: Dictionary in after["turrets"]:
		var was: Dictionary = {}
		for old: Dictionary in data["turrets"]:
			if old["id"] == turret["id"]:
				was = old
		var instances: Array = turret.get("instances", [])
		if instances.is_empty():
			lines.append("[b]%s ×%d[/b]\n%s" % [turret["name"], turret["count"], _turret_numbers(was, turret)])
			continue
		for growth: Dictionary in instances:
			var current: Dictionary = growth["combat"]
			var previous: Dictionary = {}
			var previous_gun: Dictionary = {}
			for old_growth: Dictionary in was.get("instances", []):
				if old_growth["id"] == growth["id"]:
					previous = old_growth["combat"]
					previous_gun = old_growth.get("gun", {})
			var caption := "[b]%s #%d · Lv %d[/b]" % [growth["name"], growth["id"], growth["level"]]
			caption += "\nXP %d / %d toward Lv %d" % [growth["xp"], growth["next_cost"], int(growth["level"]) + 1]
			var change: Dictionary = world.salvage.last_settlement.get("changes", {}).get(growth["id"], {})
			if not change.is_empty() and int(world.salvage.last_settlement.get("wave", -1)) == GameStateService.current_wave:
				caption += "\n[color=#8be0c9]+%d XP this wave" % change["xp_awarded"]
				if change["after"]["level"] > change["before"]["level"]:
					caption += " · Lv %d → %d" % [change["before"]["level"], change["after"]["level"]]
				caption += "[/color]"
			lines.append(caption + "\n" + _turret_numbers(previous, current))
			if growth.has("gun"):
				lines.append("[b]Gun · Projectile[/b]\n" + _turret_numbers(previous_gun, growth["gun"]))
		if int(turret["count"]) > instances.size():
			lines.append("[b]%s · New Lv 1 turret[/b]\n%s" % [turret["name"], _turret_numbers({}, turret)])
	turret_text.text = "\n\n".join(lines)
	_refresh_installed(data["items"])

func _growth_summary() -> String:
	if not world.session.state.turret_progression_enabled:
		return "Turret growth is OFF for this run."
	var ledger := world.salvage.last_settlement
	if ledger.is_empty() or int(ledger.get("wave", -1)) != GameStateService.current_wave:
		return "Turret growth is ON · Scrap left on the floor becomes XP at wave end."
	if int(ledger["raw_scrap"]) == 0:
		return "Turret growth · +0 XP — no scrap was left on the floor."
	if int(ledger["xp_awarded"]) == 0:
		return "Turret growth · No turrets to receive XP; salvage returned %d scrap." % ledger["fallback_cash"]
	var levels := 0
	for change: Dictionary in ledger["changes"].values():
		levels += int(change["after"]["level"]) - int(change["before"]["level"])
	return "Turret growth · +%d XP from leftover scrap · %d %s gained" % [
		ledger["xp_awarded"], levels, "level" if levels == 1 else "levels"]

func _turret_numbers(was: Dictionary, turret: Dictionary) -> String:
	var cadence_key := "rotation_rate" if turret["rotation_rate"] > 0 else "fire_rate"
	var cadence_unit := "°/s sweep" if cadence_key == "rotation_rate" else " shots/s"
	if cadence_key == "fire_rate" and int(turret.get("burst_size", 1)) > 1:
		cadence_unit = " bursts/s (%d shots)" % int(turret["burst_size"])
	var numbers := _number(was, turret, "damage", " damage") + " · " + _number(was, turret, cadence_key, cadence_unit)
	numbers += "\n" + _number(was, turret, "range", " m reach")
	if turret["area"] > 0:
		numbers += " · " + _number(was, turret, "area", " m area")
	for spec: Array in [["pierce", " pierce"], ["projectile_speed", " m/s projectile"], ["chain_count", " chain jumps"],
		["chain_decay", "% chain damage retained"], ["slow", "% slow strength"], ["slow_duration", " s slow"],
		["rehit_delay", " s rehit"], ["knockback", " m knockback"]]:
		if not was.is_empty() and not is_equal_approx(float(was["stats"][spec[0]]), float(turret["stats"][spec[0]])):
			numbers += "\n" + _number(was["stats"], turret["stats"], spec[0], spec[1], spec[0] == "rehit_delay")
	return numbers

## Explicit before/after numbers; colour reinforces the direction without carrying meaning alone.
func _number(before: Dictionary, after: Dictionary, key: String, unit: String, lower_is_better: bool = false) -> String:
	var value := float(after.get(key, 0))
	var old := float(before.get(key, value))
	var format := "%.1f" if key == "damage" else "%.2f"
	if is_equal_approx(old, value):
		return (format % value) + unit
	var better := value < old if lower_is_better else value > old
	return "[color=#%s]%s → %s%s[/color]" % ["8be0c9" if better else "ff9b8c", format % old, format % value, unit]

func _needs_turret(offer: ShopOffer) -> bool:
	if offer.kind == "turret":
		return true
	for modifier: Dictionary in ItemRegistry.get_modifiers(offer.asset_id):
		if modifier.get("filter", {}).has("attack_family"):
			return true
	return offer.asset_id in ["reactor_overload", "storm_conductor", "mono_type_mastery", "elemental_conduit"]

func _refresh_installed(items: Array) -> void:
	if items.hash() == installed_key:
		return
	installed_key = items.hash()
	for child in installed.get_children():
		installed.remove_child(child)
		child.queue_free()
	owned_buttons.clear()
	for item: Dictionary in items:
		var button := Button.new()
		button.text = "%s ×%d" % [item["name"], item["count"]]
		button.icon = ShopArt.item(item["id"])
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 44)
		button.add_theme_font_size_override("font_size", 22)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = ItemRegistry.get_item(item["id"]).description
		button.focus_entered.connect(_inspect_owned.bind(item["id"]))
		button.pressed.connect(_inspect_owned.bind(item["id"]))
		installed.add_child(button)
		owned_buttons.append(button)
	if items.is_empty():
		_label(installed, "No upgrades installed yet.", 22, UiPalette.MUTED)

func _inspect_owned(id: String) -> void:
	selected = -1
	_refresh_details()
	detail_title.text = ItemRegistry.get_item(id).name
	detail_text.text = ItemRegistry.get_item(id).description
	impact_text.text = "Installed ×%d" % ItemTrackingService.item_counts.get(id, 0)

func _refresh_focus() -> void:
	var row: Array[Button] = [reroll_button, repair_button, core_repair_button, continue_button]
	for i in range(row.size()):
		for direction: int in [-1, 1]:
			var target := row[i]
			var j := i + direction
			while j >= 0 and j < row.size():
				if row[j].visible and not row[j].disabled:
					target = row[j]
					break
				j += direction
			row[i].set_focus_neighbor(SIDE_LEFT if direction < 0 else SIDE_RIGHT, row[i].get_path_to(target))
	tabs[0].focus_neighbor_right = tabs[0].get_path_to(tabs[1])
	tabs[1].focus_neighbor_left = tabs[1].get_path_to(tabs[0])
	if active_tab == 1:
		var roster := turret_inspector.buttons
		for tab in tabs:
			tab.focus_neighbor_bottom = tab.get_path_to(roster[0] if not roster.is_empty() else continue_button)
		for i in roster.size():
			roster[i].focus_neighbor_top = roster[i].get_path_to(roster[i - 1] if i > 0 else tabs[1])
			roster[i].focus_neighbor_bottom = roster[i].get_path_to(roster[i + 1] if i + 1 < roster.size() else continue_button)
		turret_inspector.refresh_navigation()
		for button in row:
			button.focus_neighbor_top = button.get_path_to(roster[-1] if not roster.is_empty() else tabs[1])
		return
	var available: Array[Button] = []
	for card in offer_buttons:
		if card.visible and not card.disabled:
			available.append(card)
	for tab in tabs:
		tab.focus_neighbor_bottom = tab.get_path_to(available[0] if not available.is_empty() else continue_button)
	for button in row:
		button.focus_neighbor_top = button.get_path_to((available[-1] as OfferCard).lock_button if not available.is_empty() else owned_buttons[0] if not owned_buttons.is_empty() else button)
	for i in range(available.size()):
		var card := available[i]
		card.focus_neighbor_left = card.get_path_to(available[maxi(0, i - 1)])
		card.focus_neighbor_right = card.get_path_to(available[i + 1] if i + 1 < available.size() else owned_buttons[0] if not owned_buttons.is_empty() else card)
		var position := offer_buttons.find(card)
		var below := position + offers_grid.columns
		var above := position - offers_grid.columns
		var lock := (card as OfferCard).lock_button
		card.focus_neighbor_bottom = card.get_path_to(lock)
		card.focus_neighbor_top = card.get_path_to((offer_buttons[above] as OfferCard).lock_button if above >= 0 and offer_buttons[above] in available else tabs[0])
		lock.focus_neighbor_top = lock.get_path_to(card)
		lock.focus_neighbor_bottom = lock.get_path_to(offer_buttons[below] if below < offer_buttons.size() and offer_buttons[below] in available else continue_button)
		lock.focus_neighbor_left = lock.get_path_to((available[maxi(0, i - 1)] as OfferCard).lock_button)
		lock.focus_neighbor_right = lock.get_path_to((available[mini(available.size() - 1, i + 1)] as OfferCard).lock_button)
	for i in range(owned_buttons.size()):
		var button := owned_buttons[i]
		button.focus_neighbor_left = button.get_path_to(available[-1] if not available.is_empty() else continue_button)
		button.focus_neighbor_top = button.get_path_to(owned_buttons[maxi(0, i - 1)])
		button.focus_neighbor_bottom = button.get_path_to(owned_buttons[i + 1] if i + 1 < owned_buttons.size() else continue_button)

func _request_deploy() -> void:
	var count := 0
	for turret in world.turrets:
		if not turret.available_evolutions().is_empty():
			count += 1
	if count > 0:
		evolution_reminder.show_ready(count)
	else:
		_deploy()

func _deploy() -> void:
	world.begin_next_wave()
	refresh()

func _review_ready_turret() -> void:
	switch_tab(1)
	for i in range(world.turrets.size()):
		var turret: TurretActor = world.turrets[i]
		if not turret.available_evolutions().is_empty():
			turret_inspector.select(turret.turret_id)
			turret_inspector.buttons[i].grab_focus.call_deferred()
			return
