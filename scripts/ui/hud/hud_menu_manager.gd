class_name HUDMenuManager
extends Node

## Coordinates pause, settings, game-over, and difficulty menus
## Extracted from hud.gd to reduce file size

var pause_menu: Control
var settings_menu: Control
var asset_studio: Control
var game_over_screen: Control
var difficulty_screen: Control
var game_mode_screen: Control

var pause_controller: Object
var settings_controller: Object
var asset_studio_controller: Object
var difficulty_controller: Object
var game_mode_controller: Object

var is_paused: bool = false

signal pause_toggled(paused: bool)


func initialize(nodes: Dictionary) -> void:
	pause_menu = nodes.get("pause_menu")
	settings_menu = nodes.get("settings_menu")
	asset_studio = nodes.get("asset_studio")
	game_over_screen = nodes.get("game_over_screen")
	difficulty_screen = nodes.get("difficulty_screen")
	game_mode_screen = nodes.get("game_mode_screen")
	
	pause_controller = nodes.get("pause_controller")
	settings_controller = nodes.get("settings_controller")
	asset_studio_controller = nodes.get("asset_studio_controller")
	difficulty_controller = nodes.get("difficulty_controller")
	game_mode_controller = nodes.get("game_mode_controller")

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
	
	if pause_controller and pause_controller.has_method("show"):
		pause_controller.show()
	elif pause_menu:
		pause_menu.visible = true
	
	Events.game_paused.emit()
	pause_toggled.emit(true)

func resume() -> void:
	if not is_paused:
		return
		
	is_paused = false
	get_tree().paused = false
	
	if pause_controller and pause_controller.has_method("hide"):
		pause_controller.hide()
	elif pause_menu:
		pause_menu.visible = false
		
	if settings_controller and settings_controller.has_method("hide"):
		settings_controller.hide()
	elif settings_menu:
		settings_menu.visible = false

	if asset_studio_controller and asset_studio_controller.has_method("hide"):
		asset_studio_controller.hide()
	elif asset_studio:
		asset_studio.visible = false
		
	Events.game_resumed.emit()
	pause_toggled.emit(false)

func show_settings() -> void:
	if pause_controller and pause_controller.has_method("hide"):
		pause_controller.hide()
	elif pause_menu:
		pause_menu.visible = false
		
	if settings_controller and settings_controller.has_method("show"):
		settings_controller.show()
	elif settings_menu:
		settings_menu.visible = true

func hide_settings() -> void:
	if settings_controller and settings_controller.has_method("hide"):
		settings_controller.hide()
	elif settings_menu:
		settings_menu.visible = false
		
	if pause_controller and pause_controller.has_method("show"):
		pause_controller.show()
	elif pause_menu:
		pause_menu.visible = true

func show_asset_studio() -> void:
	if not FeatureFlagService.is_enabled(FeatureFlagService.ASSET_STUDIO):
		return

	if pause_controller and pause_controller.has_method("hide"):
		pause_controller.hide()
	elif pause_menu:
		pause_menu.visible = false

	if settings_controller and settings_controller.has_method("hide"):
		settings_controller.hide()
	elif settings_menu:
		settings_menu.visible = false

	if asset_studio_controller and asset_studio_controller.has_method("show"):
		asset_studio_controller.show()
	elif asset_studio:
		asset_studio.visible = true


func hide_asset_studio() -> void:
	if asset_studio_controller and asset_studio_controller.has_method("hide"):
		asset_studio_controller.hide()
	elif asset_studio:
		asset_studio.visible = false

	if pause_controller and pause_controller.has_method("show"):
		pause_controller.show()
	elif pause_menu:
		pause_menu.visible = true

func show_game_over(victory: bool, game_over_handler: Object) -> void:
	if game_over_screen:
		game_over_screen.visible = true
		game_over_handler.show_game_over(victory)

func show_difficulty_select() -> void:
	if difficulty_controller and difficulty_controller.has_method("show"):
		difficulty_controller.show()
	elif difficulty_screen:
		difficulty_screen.visible = true

func show_game_mode_select() -> void:
	if game_mode_controller and game_mode_controller.has_method("show"):
		game_mode_controller.show()
	elif game_mode_screen:
		game_mode_screen.visible = true
