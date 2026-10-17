class_name GameApp
extends Node

var arena: ArenaWorld
var menu: CanvasLayer
var play_button: Button
var settings_button: Button
var back_button: Button
var home: VBoxContainer
var options: VBoxContainer
var fullscreen_check: CheckButton
var window_size_option: OptionButton
var vsync_check: CheckButton
var marker_option: OptionButton
var motion_check: CheckButton
var volume_slider: HSlider
var volume_label: Label
var home_summary: Label
var summary_chips: HBoxContainer
var difficulty_option: OptionButton
var mode_option: OptionButton
## Chosen for the next Play; tools and the dev panel may replace it.
var run_config: RunConfig = RunConfig.new()

func _init() -> void:
	# Apply defaults at construction so tools can still supply a config before _ready.
	run_config.difficulty = SettingsService.run_difficulty
	run_config.mode = SettingsService.run_mode

func _ready() -> void:
	_build_menu()
	show_home()

func _build_menu() -> void:
	menu = CanvasLayer.new()
	add_child(menu)
	var background := ColorRect.new()
	background.color = Color("08151e")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 820
	panel.add_theme_stylebox_override("panel", ChamferStyle.make(Color(.025, .065, .09, .97), UiPalette.LINE, 30.0, 52.0, 40.0))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	panel.add_child(column)
	var wordmark := _label(column, "TURRET / SURVIVOR", 76, UiPalette.INK)
	wordmark.theme_type_variation = &"Header1"
	wordmark.add_theme_font_size_override("font_size", 76)
	_label(column, "Build your defenses. Survive the swarm.", 26, UiPalette.TEAL_HI)
	home = VBoxContainer.new()
	home.add_theme_constant_override("separation", 18)
	column.add_child(home)
	home_summary = _label(home, "", 22) # text mirror of the chips, kept for screen readers and tests
	home_summary.visible = false
	summary_chips = HBoxContainer.new()
	summary_chips.add_theme_constant_override("separation", 10)
	home.add_child(summary_chips)
	difficulty_option = _option(home, "Difficulty", func(index: int) -> void:
		run_config.difficulty = difficulty_option.get_item_id(index) as GameEnums.Difficulty
		SettingsService.set_run_difficulty(run_config.difficulty)
		_update_summary())
	for difficulty: int in DifficultyService.DIFFICULTY_CONFIG:
		difficulty_option.add_item("Difficulty  %s  -  %s" % [DifficultyService.DIFFICULTY_CONFIG[difficulty]["name"], DifficultyService.DIFFICULTY_CONFIG[difficulty]["description"]], difficulty)
	mode_option = _option(home, "Mode", func(index: int) -> void:
		run_config.mode = RunConfig.MODES[index]
		SettingsService.set_run_mode(run_config.mode)
		_update_summary())
	mode_option.add_item("Mode  Survive  -  last all the waves")
	mode_option.add_item("Mode  Protect the core  -  keep the reactor alive")
	mode_option.add_item("Mode  Convoy  -  escort the core door to door")
	play_button = _button(home, "PLAY", start_game, "play", true)
	settings_button = _button(home, "SETTINGS", show_settings, "settings")
	_button(home, "QUIT", func() -> void: get_tree().quit(), "power")
	options = VBoxContainer.new()
	options.add_theme_constant_override("separation", 18)
	column.add_child(options)
	var settings_title := _label(options, "SETTINGS", 40, UiPalette.INK)
	settings_title.theme_type_variation = &"Header2"
	fullscreen_check = _check(options, "Fullscreen", "fullscreen", func(value: bool) -> void: SettingsService.set_fullscreen(value))
	window_size_option = OptionButton.new()
	window_size_option.custom_minimum_size.y = 54
	window_size_option.add_theme_font_size_override("font_size", 23)
	window_size_option.icon = UiIcons.get_icon("monitor")
	_style_control(window_size_option)
	window_size_option.accessibility_name = "Window size; you can also drag the window edges"
	for preset in SettingsService.WINDOW_SIZE_PRESETS:
		window_size_option.add_item("Window  %d x %d" % [preset.x, preset.y])
	window_size_option.item_selected.connect(func(index: int) -> void:
		if index < SettingsService.WINDOW_SIZE_PRESETS.size():
			SettingsService.set_window_size(SettingsService.WINDOW_SIZE_PRESETS[index]))
	options.add_child(window_size_option)
	vsync_check = _check(options, "VSync", "signal", func(value: bool) -> void: SettingsService.set_vsync(value))
	marker_option = _option(options, "Ground markers", func(index: int) -> void: SettingsService.set_ground_markers(index))
	for label in ["Off", "Contextual", "All"]:
		marker_option.add_item("Ground markers  -  " + label)
	marker_option.tooltip_text = "Optional ground markers. Build zones and attack warnings stay visible."
	motion_check = _check(options, "Reduced motion", "motion", func(value: bool) -> void: SettingsService.set_reduced_motion(value))
	_label(options, "Reduced motion removes bobbing, recoil and hit blinking, and simplifies salvage animations.\nAttack warnings and effect ranges remain visible.", 20)
	var volume_row := HBoxContainer.new()
	volume_row.add_theme_constant_override("separation", 12)
	options.add_child(volume_row)
	var volume_icon := TextureRect.new()
	volume_icon.texture = UiIcons.get_icon("volume")
	volume_icon.modulate = UiPalette.stat_color("slow")
	volume_icon.custom_minimum_size = Vector2(32, 32)
	volume_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	volume_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	volume_row.add_child(volume_icon)
	volume_label = Label.new()
	volume_label.theme_type_variation = &"Numeral"
	volume_label.add_theme_font_size_override("font_size", 24)
	volume_row.add_child(volume_label)
	volume_slider = HSlider.new()
	volume_slider.min_value = 0
	volume_slider.max_value = 100
	volume_slider.step = 5
	volume_slider.custom_minimum_size.y = 32
	volume_slider.accessibility_name = "Sound effects volume; zero mutes"
	options.add_child(volume_slider)
	volume_slider.value_changed.connect(func(value: float) -> void:
		SettingsService.set_sfx_volume(value / 100.0)
		_update_volume_label())
	back_button = _button(options, "BACK", show_home, "back")

func _label(parent: Node, text: String, size: int, color: Color = UiPalette.INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable, icon_name: String = "", primary: bool = false) -> Button:
	var button := IconButton.new().setup(icon_name, text, primary, 30)
	button.custom_minimum_size.y = 62
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _option(parent: Node, accessibility: String, action: Callable) -> OptionButton:
	var button := OptionButton.new()
	button.custom_minimum_size.y = 54
	button.add_theme_font_size_override("font_size", 21)
	button.accessibility_name = accessibility
	button.item_selected.connect(action)
	_style_control(button)
	parent.add_child(button)
	return button

## Chamfered look for option buttons and checks, matching IconButton.
func _style_control(control: Button) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var edge := UiPalette.TEAL_HI if state in ["pressed", "focus"] else (UiPalette.TEAL if state == "hover" else UiPalette.LINE)
		var fill := Color(0, 0, 0, 0) if state == "focus" else (UiPalette.PANEL_HI if state != "normal" else UiPalette.PANEL)
		if state == "pressed" and control is CheckButton:
			continue # "pressed" means checked here; the switch shows that, the frame must not
		control.add_theme_stylebox_override(state, ChamferStyle.make(fill, edge, 10.0, 20.0, 8.0))
	if control is CheckButton:
		control.add_theme_stylebox_override("pressed", control.get_theme_stylebox("normal"))
		control.add_theme_stylebox_override("hover_pressed", control.get_theme_stylebox("hover"))

func _rebuild_chips(mode_name: String) -> void:
	for child in summary_chips.get_children():
		summary_chips.remove_child(child)
		child.queue_free()
	summary_chips.add_child(StatChip.new().setup("wave", "%d waves" % run_config.wave_limit, "wave"))
	summary_chips.add_child(StatChip.new().setup("hull", run_config.difficulty_name(), "hull"))
	summary_chips.add_child(StatChip.new().setup("sector", mode_name, "core"))

func _update_summary() -> void:
	var mode_name := "Survive"
	match run_config.mode:
		RunConfig.MODE_CORE: mode_name = "Protect the core"
		RunConfig.MODE_CONVOY: mode_name = "Convoy"
	_rebuild_chips(mode_name)
	home_summary.text = "%d waves · %s difficulty · %s" % [run_config.wave_limit, run_config.difficulty_name(), mode_name]

func _check(parent: Node, text: String, icon_name: String, action: Callable) -> CheckButton:
	var button := CheckButton.new()
	button.text = text
	button.icon = UiIcons.get_icon(icon_name)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 30)
	button.add_theme_constant_override("h_separation", 14)
	_style_control(button)
	button.custom_minimum_size.y = 54
	button.add_theme_font_size_override("font_size", 23)
	button.toggled.connect(action)
	parent.add_child(button)
	return button

func show_home() -> void:
	menu.visible = true
	# Core mode needs its experiment flag; without it the selector is hidden and the run is Survive.
	var core_allowed := FeatureFlagService.is_enabled(FeatureFlagService.MODE_PROTECT_CORE)
	var convoy_allowed := FeatureFlagService.is_enabled(FeatureFlagService.MODE_CONVOY)
	mode_option.visible = core_allowed or convoy_allowed
	mode_option.set_item_disabled(RunConfig.MODES.find(RunConfig.MODE_CORE), not core_allowed)
	mode_option.set_item_disabled(RunConfig.MODES.find(RunConfig.MODE_CONVOY), not convoy_allowed)
	if (run_config.mode == RunConfig.MODE_CORE and not core_allowed) or (run_config.mode == RunConfig.MODE_CONVOY and not convoy_allowed):
		run_config.mode = RunConfig.MODE_SURVIVE
	difficulty_option.select(difficulty_option.get_item_index(run_config.difficulty))
	mode_option.select(RunConfig.MODES.find(run_config.mode))
	_update_summary()
	home.visible = true
	options.visible = false
	play_button.grab_focus()

func show_settings() -> void:
	home.visible = false
	options.visible = true
	fullscreen_check.set_pressed_no_signal(SettingsService.fullscreen)
	vsync_check.set_pressed_no_signal(SettingsService.vsync)
	# Default/custom window dimensions are valid even when they are not a preset.
	while window_size_option.item_count > SettingsService.WINDOW_SIZE_PRESETS.size():
		window_size_option.remove_item(window_size_option.item_count - 1)
	var actual_size := get_window().size if SettingsService.window_size == Vector2i.ZERO else SettingsService.window_size
	var preset_index := SettingsService.WINDOW_SIZE_PRESETS.find(actual_size)
	if preset_index < 0:
		window_size_option.add_item("Window  %d x %d (custom)" % [actual_size.x, actual_size.y])
		preset_index = window_size_option.item_count - 1
	window_size_option.select(preset_index)
	marker_option.select(SettingsService.ground_markers)
	motion_check.set_pressed_no_signal(FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION))
	volume_slider.set_value_no_signal(SettingsService.sfx_volume * 100.0)
	_update_volume_label()
	fullscreen_check.grab_focus()

func _update_volume_label() -> void:
	volume_label.text = "SOUND EFFECTS  %d%%%s" % [roundi(SettingsService.sfx_volume * 100), " / MUTED" if SettingsService.sfx_volume <= 0 else ""]

func start_game() -> void:
	if is_instance_valid(arena):
		return
	menu.visible = false
	arena = preload("res://scenes/game/arena.tscn").instantiate()
	arena.run_config = run_config
	arena.menu_requested.connect(return_to_menu)
	add_child(arena)

func return_to_menu() -> void:
	if is_instance_valid(arena):
		# Detach services synchronously before another Play can create a new run.
		remove_child(arena)
		arena.queue_free()
		arena = null
	GameStateService.is_game_active = false
	GameStateMachine.force_transition(GameStateMachine.GameState.IDLE)
	show_home()

func _input(event: InputEvent) -> void:
	var back: bool = event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)
	if menu.visible and options.visible and back:
		show_home()
		get_viewport().set_input_as_handled()
