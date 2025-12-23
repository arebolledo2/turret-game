class_name HUDMenuManager
extends Node

## Coordinates pause, settings, game-over, and difficulty menus
## Extracted from hud.gd to reduce file size

var pause_menu: Control
var settings_menu: Control
var game_over_screen: Control
var difficulty_screen: Control
var game_mode_screen: Control
var is_paused: bool = false

signal pause_toggled(paused: bool)

func initialize(nodes: Dictionary) -> void:
	pause_menu = nodes.get("pause_menu")
	settings_menu = nodes.get("settings_menu")
	game_over_screen = nodes.get("game_over_screen")
	difficulty_screen = nodes.get("difficulty_screen")
	game_mode_screen = nodes.get("game_mode_screen")

func toggle_pause() -> void:
	if is_paused:
		resume()
	else:
		pause()

func pause() -> void:
	if is_paused:
		return
	
	is_paused = true
	get_tree().paused = true
	if pause_menu:
		pause_menu.visible = true
	
	Events.game_paused.emit()
	pause_toggled.emit(true)

func resume() -> void:
	if not is_paused:
		return
		
	is_paused = false
	get_tree().paused = false
	if pause_menu:
		pause_menu.visible = false
	if settings_menu:
		settings_menu.visible = false
		
	Events.game_resumed.emit()
	pause_toggled.emit(false)

func show_settings() -> void:
	if pause_menu: pause_menu.visible = false
	if settings_menu: settings_menu.visible = true

func hide_settings() -> void:
	if settings_menu: settings_menu.visible = false
	if pause_menu: pause_menu.visible = true

func show_game_over(victory: bool, game_over_handler: Object) -> void:
	if game_over_screen:
		game_over_screen.visible = true
		game_over_handler.show_game_over(victory)

func show_difficulty_select() -> void:
	if difficulty_screen:
		difficulty_screen.visible = true

func show_game_mode_select() -> void:
	if game_mode_screen:
		game_mode_screen.visible = true
