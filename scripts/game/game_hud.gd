extends CanvasLayer

var world: ArenaWorld
var stats: Label
var status: Label
var hint: Label
var health: ProgressBar
var health_text: Label
var panel: PanelContainer
var title: Label
var description: Label
var offer_buttons: Array[Button] = []
var reroll_button: Button
var repair_button: Button
var actions: HBoxContainer
var build_text: Label
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
	var header := PanelContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 28
	header.offset_right = -28
	header.offset_top = 22
	header.offset_bottom = 105
	header.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(header)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 35)
	header.add_child(row)
	var brand := VBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(brand)
	_label(brand, "T U R R E T   /   S U R V I V O R", 23, Color("cfecea"))
	_label(brand, "SECTOR 01     /     SIX-WAVE SURVIVAL", 13, Color("54c5c5"))
	var vitals := VBoxContainer.new()
	vitals.custom_minimum_size.x = 175
	row.add_child(vitals)
	health_text = _label(vitals, "HULL", 15, Color("cfecea"))
	health = ProgressBar.new()
	health.custom_minimum_size = Vector2(175, 12)
	health.show_percentage = false
	vitals.add_child(health)
	stats = _label(row, "", 18, Color("f4d298"))
	stats.custom_minimum_size.x = 290
	status = Label.new()
	status.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	status.offset_left = -350
	status.offset_right = 350
	status.offset_top = 120
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 24)
	status.add_theme_color_override("font_color", Color("a9ece4"))
	root.add_child(status)
	hint = Label.new()
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_left = 28
	hint.offset_top = -65
	hint.offset_bottom = -20
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color("b3cdd3"))
	root.add_child(hint)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size.x = 1200
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	panel.add_child(columns)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 700
	column.add_theme_constant_override("separation", 8)
	columns.add_child(column)
	title = _label(column, "", 32, Color("d7f2eb"))
	description = _label(column, "", 17, Color("a3bbc6"))
	for index in range(4):
		var button := _button(column, "", _purchase.bind(index))
		button.custom_minimum_size.y = 76
		button.add_theme_font_size_override("font_size", 20)
		offer_buttons.append(button)
	actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	reroll_button = _button(actions, "", func() -> void: world.shop.reroll())
	reroll_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	repair_button = _button(actions, "REPAIR 10 HULL / 5", func() -> void: world.repair())
	repair_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	continue_button = _button(column, "DEPLOY NEXT WAVE", _continue)
	restart_button = _button(column, "START NEW RUN", func() -> void: world.start_run())
	menu_button = _button(column, "MAIN MENU", func() -> void: world.request_menu())
	var build := VBoxContainer.new()
	build.custom_minimum_size.x = 400
	columns.add_child(build)
	_label(build, "YOUR BUILD", 20, Color("54c5c5"))
	_label(build, "Damage · shots/sec · range", 14, Color("a3bbc6"))
	var scroll := ScrollContainer.new()
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.custom_minimum_size = Vector2(400, 200)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	build.add_child(scroll)
	build_text = _label(scroll, "", 20, Color("cfecea"))
	build_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build_text.add_theme_constant_override("line_spacing", 8)
	_label(build, "Max hull upgrades do not repair damage.", 13, Color("a3bbc6"))

func _purchase(index: int) -> void:
	world.shop.purchase(index)

func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.025, .065, .09, .97)
	style.border_color = Color("2b5963")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	return style

func _continue() -> void:
	if world.paused:
		world.toggle_pause()
	else:
		world.begin_next_wave()

func _process(_delta: float) -> void:
	if not is_instance_valid(world.player):
		return
	var phase := GameStateMachine.current_state
	var in_shop := phase == GameStateMachine.GameState.SHOP
	var ended := phase in [GameStateMachine.GameState.GAME_OVER, GameStateMachine.GameState.VICTORY]
	health.max_value = world.player.max_health
	health.value = world.player.health
	health_text.text = "HULL  %d / %d" % [ceili(world.player.health), ceili(world.player.max_health)]
	stats.text = "WAVE %02d / %02d     %02ds\n%d SCRAP     %d KILLS" % [GameStateService.current_wave,
		world.wave_limit, ceili(world.time_left), EconomyService.total_scrap, GameStateService.total_kills]
	status.text = "DEPLOYING WAVE %d  ·  %d" % [GameStateService.current_wave, ceili(world.announcement_left)] if phase == GameStateMachine.GameState.WAVE_ANNOUNCEMENT else ""
	hint.text = "WASD / LEFT STICK  Move     E / A  Carry or place turret     ESC / START  Pause\n" + world.message
	panel.visible = in_shop or ended or world.paused
	for index in range(offer_buttons.size()):
		var button := offer_buttons[index]
		button.visible = in_shop and not world.paused and index < EconomyService.current_shop_offers.size()
		if button.visible:
			var offer: Dictionary = EconomyService.current_shop_offers[index]
			button.text = "%s   /   %s\n%s" % [ArenaShop.offer_name(offer), "INSTALLED" if offer["sold"] else "%d scrap" % offer["price"], ArenaShop.offer_description(offer)]
			button.disabled = offer["sold"] or EconomyService.total_scrap < int(offer["price"])
	actions.visible = in_shop and not world.paused
	continue_button.visible = not ended
	continue_button.text = "RESUME" if world.paused else "DEPLOY NEXT WAVE"
	restart_button.visible = ended
	menu_button.visible = ended or world.paused
	reroll_button.text = "REROLL / %d scrap" % world.shop.reroll_cost()
	reroll_button.disabled = EconomyService.total_scrap < world.shop.reroll_cost()
	repair_button.disabled = EconomyService.total_scrap < 5 or world.player.health >= world.player.max_health
	if panel.visible:
		build_text.text = world.shop.build_summary()
	if world.paused:
		title.text = "SYSTEM PAUSED"
		description.text = "Take a breath. The arena can wait."
	elif in_shop:
		title.text = "REFIT / REDEPLOY"
		description.text = "Wave %d secured. Spend scrap before deploying." % GameStateService.current_wave
	elif ended:
		title.text = "SECTOR SECURED" if phase == GameStateMachine.GameState.VICTORY else "SIGNAL LOST"
		description.text = "%d kills · %d scrap recovered · %ds survived" % [GameStateService.total_kills, GameStateService.total_scrap, int(GameStateService.time_survived)]
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
