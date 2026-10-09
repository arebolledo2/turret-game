extends CanvasLayer

var world: ArenaWorld
var hull_bar: VitalBar
var core_bar: VitalBar
var wave_value: Label
var wave_total: Label
var wave_pips: SegmentedBar
var time_label: Label
var scrap_label: Label
var banner: PanelContainer
var banner_label: Label
var hint: Label
var minimap: Minimap
var panel: PanelContainer
var title: Label
var description: Label
var offer_buttons: Array[Button] = []
var reroll_button: IconButton
var repair_button: IconButton
var core_repair_button: IconButton
var zone_legend: Label
var actions: HBoxContainer
var offers_row: HBoxContainer
var balance_row: HBoxContainer
var balance_label: Label
var build_panel: BuildPanel
var build_refresh: float = 0.0
var continue_icon: String = "deploy"
var continue_button: Button
var restart_button: Button
var menu_button: Button
var previous_phase: int = -1
var previous_pause: bool = false

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_corner_clusters(root)
	var indicator := CoreIndicator.new()
	indicator.world = world
	root.add_child(indicator)
	_build_wave_banner(root)
	zone_legend = Label.new()
	zone_legend.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	zone_legend.offset_left = -640
	zone_legend.offset_right = 640
	zone_legend.offset_top = 158
	zone_legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	zone_legend.add_theme_font_size_override("font_size", 15)
	zone_legend.add_theme_color_override("font_color", Color("e2c98f"))
	zone_legend.add_theme_color_override("font_outline_color", Color(0, 0, 0, .85))
	zone_legend.add_theme_constant_override("outline_size", 6)
	zone_legend.visible = false
	root.add_child(zone_legend)
	hint = Label.new()
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_left = 28
	hint.offset_top = -140
	hint.offset_bottom = -40
	hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	hint.add_theme_font_size_override("font_size", 24)
	hint.add_theme_color_override("font_color", UiPalette.INK)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, .85))
	hint.add_theme_constant_override("outline_size", 6)
	root.add_child(hint)
	minimap = Minimap.new()
	minimap.world = world
	root.add_child(minimap)
	_build_panel(root)

## The refit / pause / end panel: offer cards and actions on the left, the build on the right.
func _build_panel(root: Control) -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size.x = 1640
	panel.add_theme_stylebox_override("panel", ChamferStyle.make(Color(.025, .065, .09, .97), UiPalette.LINE, 30.0, 0.0, 0.0))
	center.add_child(panel)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 0)
	panel.add_child(columns)
	var left := _padded(columns, 44, 34, 36, 34)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	left.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	column.add_child(header)
	title = _label(header, "", 46, UiPalette.INK)
	description = _label(header, "", 24, UiPalette.MUTED)
	description.size_flags_vertical = Control.SIZE_SHRINK_END
	var header_gap := Control.new()
	header_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_gap)
	balance_row = HBoxContainer.new()
	balance_row.add_theme_constant_override("separation", 12)
	header.add_child(balance_row)
	balance_row.add_child(_icon("scrap", "scrap", 44))
	balance_label = _numeral(balance_row, 52, UiPalette.SCRAP)
	offers_row = HBoxContainer.new()
	offers_row.add_theme_constant_override("separation", 18)
	column.add_child(offers_row)
	for index in range(4):
		var card := OfferCard.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.pressed.connect(_purchase.bind(index))
		offers_row.add_child(card)
		offer_buttons.append(card)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	column.add_child(footer)
	actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	footer.add_child(actions)
	reroll_button = IconButton.new().setup("reroll", "")
	reroll_button.custom_minimum_size.x = 150
	reroll_button.pressed.connect(func() -> void: world.shop.reroll())
	actions.add_child(reroll_button)
	repair_button = IconButton.new().setup("repair", "+%d" % GameConstants.REPAIR_HEAL_AMOUNT)
	repair_button.custom_minimum_size.x = 210
	repair_button.pressed.connect(func() -> void: world.repair())
	actions.add_child(repair_button)
	core_repair_button = IconButton.new().setup("core", "+%d" % GameConstants.REPAIR_HEAL_AMOUNT)
	core_repair_button.custom_minimum_size.x = 210
	core_repair_button.pressed.connect(func() -> void: world.repair_core())
	actions.add_child(core_repair_button)
	var footer_gap := Control.new()
	footer_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_gap)
	continue_button = IconButton.new().setup("deploy", "DEPLOY", true, 34)
	continue_button.custom_minimum_size.x = 340
	continue_button.pressed.connect(_continue)
	footer.add_child(continue_button)
	restart_button = IconButton.new().setup("reroll", "NEW RUN", true)
	restart_button.custom_minimum_size.x = 300
	restart_button.pressed.connect(func() -> void: world.start_run())
	footer.add_child(restart_button)
	menu_button = IconButton.new().setup("home", "MENU")
	menu_button.custom_minimum_size.x = 200
	menu_button.pressed.connect(func() -> void: world.request_menu())
	footer.add_child(menu_button)
	var divider := ColorRect.new()
	divider.color = UiPalette.LINE
	divider.custom_minimum_size.x = 1
	columns.add_child(divider)
	var right := _padded(columns, 36, 34, 40, 34)
	right.custom_minimum_size.x = 590
	build_panel = BuildPanel.new()
	right.add_child(build_panel)

func _padded(parent: Node, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	parent.add_child(margin)
	return margin

## Three corner clusters: hull (and core) top-left, wave and timer top-centre, scrap top-right.
func _build_corner_clusters(root: Control) -> void:
	var left := VBoxContainer.new()
	left.position = Vector2(48, 40)
	left.custom_minimum_size.x = 540
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_theme_constant_override("separation", 14)
	root.add_child(left)
	hull_bar = VitalBar.new().setup("hull", "hull")
	left.add_child(hull_bar)
	core_bar = VitalBar.new().setup("core", "core")
	core_bar.visible = false
	left.add_child(core_bar)

	var centre := PanelContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.custom_minimum_size = Vector2(560, 96)
	centre.add_theme_stylebox_override("panel", ChamferStyle.make(UiPalette.PANEL, UiPalette.LINE, 10.0, 28.0, 12.0))
	_anchor_top(centre, Control.PRESET_CENTER_TOP, 0.0, Control.GROW_DIRECTION_BOTH)
	root.add_child(centre)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	centre.add_child(row)
	var wave_column := VBoxContainer.new()
	wave_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wave_column.alignment = BoxContainer.ALIGNMENT_CENTER
	wave_column.add_theme_constant_override("separation", 10)
	row.add_child(wave_column)
	var wave_row := HBoxContainer.new()
	wave_row.add_theme_constant_override("separation", 12)
	wave_column.add_child(wave_row)
	wave_row.add_child(_icon("wave", "wave", 36))
	wave_value = _numeral(wave_row, 40, UiPalette.INK)
	wave_total = _numeral(wave_row, 24, UiPalette.MUTED)
	wave_total.size_flags_vertical = Control.SIZE_SHRINK_END
	wave_pips = SegmentedBar.new()
	wave_pips.color = UiPalette.stat_color("wave")
	wave_pips.custom_minimum_size = Vector2(0, 12)
	wave_column.add_child(wave_pips)
	var divider := ColorRect.new()
	divider.color = UiPalette.LINE
	divider.custom_minimum_size = Vector2(1, 56)
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(divider)
	var timer_row := HBoxContainer.new()
	timer_row.add_theme_constant_override("separation", 12)
	timer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(timer_row)
	timer_row.add_child(_icon("timer", "time", 36))
	time_label = _numeral(timer_row, 44, UiPalette.INK)

	var scrap := PanelContainer.new()
	scrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrap.custom_minimum_size = Vector2(0, 96)
	scrap.add_theme_stylebox_override("panel", ChamferStyle.make(UiPalette.PANEL, UiPalette.LINE, 10.0, 24.0, 12.0))
	_anchor_top(scrap, Control.PRESET_TOP_RIGHT, -48.0, Control.GROW_DIRECTION_BEGIN)
	root.add_child(scrap)
	var scrap_row := HBoxContainer.new()
	scrap_row.add_theme_constant_override("separation", 14)
	scrap_row.alignment = BoxContainer.ALIGNMENT_CENTER
	scrap.add_child(scrap_row)
	scrap_row.add_child(_icon("scrap", "scrap", 48))
	scrap_label = _numeral(scrap_row, 50, UiPalette.SCRAP)

## Quick "WAVE 04" flash while a wave is being announced (no countdown digit).
func _build_wave_banner(root: Control) -> void:
	banner = PanelContainer.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.visible = false
	banner.add_theme_stylebox_override("panel", ChamferStyle.make(UiPalette.PANEL, UiPalette.TEAL_HI, 16.0, 56.0, 20.0))
	_anchor_top(banner, Control.PRESET_CENTER_TOP, 0.0, Control.GROW_DIRECTION_BOTH)
	banner.offset_top = 300
	banner.offset_bottom = 300
	root.add_child(banner)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	banner.add_child(row)
	row.add_child(_icon("deploy", "wave", 84))
	banner_label = _numeral(row, 84, UiPalette.INK)

## Pins a control to the top edge at its minimum size, growing away from the anchor.
func _anchor_top(control: Control, preset: int, edge_offset: float, grow: int) -> void:
	control.set_anchors_preset(preset)
	control.offset_left = edge_offset
	control.offset_right = edge_offset
	control.offset_top = 40
	control.offset_bottom = 40
	control.grow_horizontal = grow as Control.GrowDirection

func _icon(icon_name: String, stat: String, size: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = UiIcons.get_icon(icon_name)
	rect.modulate = UiPalette.stat_color(stat)
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func _numeral(parent: Node, size: int, color: Color) -> Label:
	var label := _label(parent, "", size, color)
	label.theme_type_variation = &"Numeral"
	return label

func _purchase(index: int) -> void:
	world.shop.purchase(index)

func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _continue() -> void:
	if world.paused:
		world.toggle_pause()
	else:
		world.begin_next_wave()

## One line about the turret within reach (or carried) so the Entrench bonus is readable.
func _entrench_readout() -> String:
	if not FeatureFlagService.is_enabled(FeatureFlagService.ENTRENCH) or not is_instance_valid(world.player):
		return ""
	var best: TurretActor = null
	var best_distance := TurretPlacement.PICKUP_RANGE
	for turret in world.turrets:
		var distance := turret.position.distance_to(world.player.position)
		if distance < best_distance and not turret.carried:
			best_distance = distance
			best = turret
	if not best:
		return ""
	var stacks := best.entrench_stacks_cached
	return "
ENTRENCH %d / %d  +%d%% damage  +%d%% fire rate" % [stacks, best.entrench_max(),
		roundi(best.entrench_damage_bonus() * 100.0), roundi(best.entrench_fire_rate_bonus() * 100.0)]

## One line about the ground under the hero while zones are readable ("MUD  Mud · slows you and enemies 45%").
func _zone_readout() -> String:
	if not world.terrain or not world.terrain.readable or not is_instance_valid(world.player):
		return ""
	var text := world.terrain.describe_at(world.player.position)
	return "
GROUND  %s" % text if not text.is_empty() else ""

## Terrain legend: shown while a wave is being announced and on the pause screen.
func _zone_legend_text(phase: int) -> String:
	if not world.terrain or not world.terrain.readable:
		return ""
	if phase == GameStateMachine.GameState.WAVE_ANNOUNCEMENT or world.paused:
		return world.terrain.legend()
	return ""

func _process(delta: float) -> void:
	if not is_instance_valid(world.player):
		return
	var phase := GameStateMachine.current_state
	var in_shop := phase == GameStateMachine.GameState.SHOP
	var ended := phase in [GameStateMachine.GameState.GAME_OVER, GameStateMachine.GameState.VICTORY]
	hull_bar.set_values(world.player.health, world.player.max_health)
	core_bar.visible = world.core != null
	if world.core:
		core_bar.set_values(world.core.health, world.core.max_health)
	var wave := GameStateService.current_wave
	var in_wave := phase in [GameStateMachine.GameState.WAVE_ANNOUNCEMENT, GameStateMachine.GameState.COMBAT]
	wave_value.text = "%02d" % wave
	wave_total.text = "/%02d" % world.wave_limit
	wave_pips.set_state(maxi(wave - 1, 0) if in_wave else wave, world.wave_limit, false, wave - 1 if in_wave else -1)
	var seconds := ceili(world.waves.time_left)
	time_label.text = "%d:%02d" % [floori(seconds / 60.0), seconds % 60]
	scrap_label.text = str(EconomyService.total_scrap)
	banner.visible = phase == GameStateMachine.GameState.WAVE_ANNOUNCEMENT
	if banner.visible:
		banner_label.text = "WAVE %02d" % wave
	hint.text = (world.message + _entrench_readout() + _zone_readout()).strip_edges()
	var legend_text := _zone_legend_text(phase)
	zone_legend.text = legend_text
	zone_legend.visible = not legend_text.is_empty() and not world.dev_menu_open
	panel.visible = (in_shop or ended or world.paused) and not world.dev_menu_open
	minimap.suppressed = panel.visible
	var shop_open := in_shop and not world.paused
	var damage_mult := float(world.difficulty_config["turret_damage_mult"])
	var hovered := -1
	var focused := -1
	for index in range(offer_buttons.size()):
		var card := offer_buttons[index] as OfferCard
		card.visible = shop_open and index < EconomyService.current_shop_offers.size()
		if card.visible:
			var offer := EconomyService.current_shop_offers[index]
			card.setup(offer, damage_mult, EconomyService.total_scrap >= offer.price)
			if card.is_hovered():
				hovered = index
			if card.has_focus():
				focused = index
	balance_row.visible = shop_open
	balance_label.text = str(EconomyService.total_scrap)
	actions.visible = shop_open
	continue_button.visible = not ended
	var continue_target := "play" if world.paused else "deploy"
	if continue_target != continue_icon:
		continue_icon = continue_target
		continue_button.icon = UiIcons.get_icon(continue_target)
		continue_button.text = "RESUME" if world.paused else "DEPLOY"
	restart_button.visible = ended
	menu_button.visible = ended or world.paused
	var reroll_cost := world.shop.reroll_cost()
	reroll_button.set_cost(reroll_cost, EconomyService.total_scrap >= reroll_cost)
	reroll_button.disabled = EconomyService.total_scrap < reroll_cost
	repair_button.set_cost(GameConstants.REPAIR_COST, EconomyService.total_scrap >= GameConstants.REPAIR_COST)
	repair_button.disabled = EconomyService.total_scrap < GameConstants.REPAIR_COST or world.player.health >= world.player.max_health
	core_repair_button.visible = world.core != null
	if world.core:
		core_repair_button.set_cost(GameConstants.REPAIR_COST, EconomyService.total_scrap >= GameConstants.REPAIR_COST)
		core_repair_button.disabled = EconomyService.total_scrap < GameConstants.REPAIR_COST or world.core.health >= world.core.max_health
	if panel.visible:
		build_refresh -= delta
		if build_refresh <= 0.0 or phase != previous_phase or world.paused != previous_pause:
			build_refresh = .1
			var previewed := hovered if hovered >= 0 else focused
			var preview: Dictionary = {}
			if shop_open and previewed >= 0 and not EconomyService.current_shop_offers[previewed].sold:
				preview = ShopViewData.preview(world, EconomyService.current_shop_offers[previewed])
			build_panel.set_data(ShopViewData.build_data(world), preview)
	if world.paused:
		title.text = "PAUSED"
		description.text = ""
	elif in_shop:
		title.text = "REFIT"
		description.text = ""
	elif ended:
		title.text = "SECTOR SECURED" if phase == GameStateMachine.GameState.VICTORY else "SIGNAL LOST"
		description.text = "%s%d kills · %d scrap recovered · %ds survived" % ["%s · " % world.defeat_reason if world.defeat_reason != "" else "",
			GameStateService.total_kills, GameStateService.lifetime_scrap, int(GameStateService.time_survived)]
	if phase != previous_phase or world.paused != previous_pause:
		if ended:
			restart_button.grab_focus()
		elif panel.visible:
			continue_button.grab_focus()
		else:
			var focus := get_viewport().gui_get_focus_owner()
			if focus:
				focus.release_focus()
	previous_phase = phase
	previous_pause = world.paused
