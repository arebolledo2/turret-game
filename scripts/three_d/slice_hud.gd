extends CanvasLayer

var world: SliceWorld
var stats: Label
var status: Label
var hint: Label
var health: ProgressBar
var health_text: Label
var panel: PanelContainer
var title: Label
var description: Label
var turret_button: Button
var damage_button: Button
var repair_button: Button
var continue_button: Button
var restart_button: Button
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
	_label(brand, "PROVING GROUND     /     3D COMBAT TRIAL", 13, Color("54c5c5"))
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
	panel.custom_minimum_size.x = 480
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	title = _label(column, "", 32, Color("d7f2eb"))
	description = _label(column, "", 17, Color("a3bbc6"))
	turret_button = _button(column, "", func() -> void: world.purchase("turret"))
	damage_button = _button(column, "", func() -> void: world.purchase("damage"))
	repair_button = _button(column, "", func() -> void: world.purchase("repair"))
	continue_button = _button(column, "DEPLOY NEXT WAVE", _continue)
	restart_button = _button(column, "START NEW RUN", func() -> void: world.start_run())

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
	for button: Button in [turret_button, damage_button, repair_button]:
		button.visible = in_shop and not world.paused
	continue_button.visible = not ended
	continue_button.text = "RESUME" if world.paused else "DEPLOY NEXT WAVE"
	restart_button.visible = ended
	turret_button.text = "ION TURRET     /     %d scrap" % world.turret_price()
	damage_button.text = "+20%% TURRET DAMAGE     /     %d scrap" % (10 + world.upgrade_count * 5)
	repair_button.text = "REPAIR 10 HULL     /     5 scrap"
	turret_button.disabled = EconomyService.total_scrap < world.turret_price()
	damage_button.disabled = EconomyService.total_scrap < 10 + world.upgrade_count * 5
	repair_button.disabled = EconomyService.total_scrap < 5 or world.player.health >= world.player.max_health
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
