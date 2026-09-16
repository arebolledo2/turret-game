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
var vsync_check: CheckButton
var motion_check: CheckButton

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
	var style := StyleBoxFlat.new()
	style.bg_color = Color("102832")
	style.border_color = Color("358d95")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 48
	style.content_margin_right = 48
	style.content_margin_top = 36
	style.content_margin_bottom = 36
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	panel.add_child(column)
	_label(column, "TURRET / SURVIVOR", 44, Color("d7f2eb"))
	_label(column, "Build your defenses. Survive the swarm.", 23, Color("71d3d3"))
	home = VBoxContainer.new()
	home.add_theme_constant_override("separation", 18)
	column.add_child(home)
	_label(home, "Six waves · Easy difficulty · Three turret types", 22)
	_label(home, "Move     WASD / arrows / left stick\nCarry or place turret     E / controller A\nPause     Esc / controller Start\nAuto-fire targets nearby enemies.", 22)
	play_button = _button(home, "PLAY", start_game)
	settings_button = _button(home, "SETTINGS", show_settings)
	_button(home, "QUIT", func() -> void: get_tree().quit())
	options = VBoxContainer.new()
	options.add_theme_constant_override("separation", 18)
	column.add_child(options)
	_label(options, "SETTINGS", 28)
	fullscreen_check = _check(options, "Fullscreen", func(value: bool) -> void: SettingsService.set_fullscreen(value))
	vsync_check = _check(options, "VSync", func(value: bool) -> void: SettingsService.set_vsync(value))
	motion_check = _check(options, "Reduced motion", func(value: bool) -> void: SettingsService.set_reduced_motion(value))
	_label(options, "Reduced motion removes bobbing, recoil and hit blinking.\nAttack warnings and effect ranges remain visible.", 20)
	back_button = _button(options, "BACK", show_home)

func _label(parent: Node, text: String, size: int, color: Color = Color("c8dddf")) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 58
	button.add_theme_font_size_override("font_size", 23)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _check(parent: Node, text: String, action: Callable) -> CheckButton:
	var button := CheckButton.new()
	button.text = text
	button.custom_minimum_size.y = 54
	button.add_theme_font_size_override("font_size", 23)
	button.toggled.connect(action)
	parent.add_child(button)
	return button

func show_home() -> void:
	menu.visible = true
	home.visible = true
	options.visible = false
	play_button.grab_focus()

func show_settings() -> void:
	home.visible = false
	options.visible = true
	fullscreen_check.set_pressed_no_signal(SettingsService.fullscreen)
	vsync_check.set_pressed_no_signal(SettingsService.vsync)
	motion_check.set_pressed_no_signal(FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION))
	fullscreen_check.grab_focus()

func start_game() -> void:
	if is_instance_valid(arena):
		return
	menu.visible = false
	arena = preload("res://scenes/game/arena.tscn").instantiate()
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
