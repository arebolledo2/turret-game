extends CanvasLayer

## Main HUD controller - orchestrates UI components
##
## This script delegates to focused UI component classes:
## - GameHUD: Health bar, wave timer, gold/xp counters
## - WaveAnnouncementUI: Wave start overlay
## - GameOverScreenUI: Victory/defeat screen
## - DifficultySelectUI: Pre-game difficulty picker
## - PauseMenuUI: Pause menu with stats, turrets, items
## - SettingsMenuUI: Settings toggles

# Preload UI component scripts
const GameHUDScript = preload("res://scripts/ui/game_hud.gd")
const WaveAnnouncementScript = preload("res://scripts/ui/wave_announcement.gd")
const GameOverScreenScript = preload("res://scripts/ui/game_over_screen.gd")
const DifficultySelectScript = preload("res://scripts/ui/difficulty_select.gd")
const PauseMenuScript = preload("res://scripts/ui/pause_menu.gd")
const SettingsMenuScript = preload("res://scripts/ui/settings_menu.gd")

# Node references
@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/TopRow/HealthBar
@onready var wave_label: Label = $MarginContainer/VBoxContainer/TopRow/WaveInfo/WaveLabel
@onready var timer_label: Label = $MarginContainer/VBoxContainer/TopRow/WaveInfo/TimerLabel
@onready var xp_label: Label = $MarginContainer/VBoxContainer/TopRow/StatsContainer/XPLabel
@onready var gold_label: Label = $MarginContainer/VBoxContainer/TopRow/StatsContainer/GoldLabel
@onready var turret_label: Label = $MarginContainer/VBoxContainer/TopRow/StatsContainer/TurretLabel
@onready var wave_announcement: Control = $WaveAnnouncement
@onready var wave_announcement_label: Label = $WaveAnnouncement/WaveLabel
@onready var game_over_screen: Control = $GameOverScreen
@onready var game_over_title: Label = $GameOverScreen/Panel/VBoxContainer/Title
@onready var stats_label: Label = $GameOverScreen/Panel/VBoxContainer/StatsLabel
@onready var difficulty_screen: Control = $DifficultySelect
@onready var hud_container: MarginContainer = $MarginContainer
@onready var pause_menu: Control = $PauseMenu
@onready var settings_menu: Control = $SettingsMenu
@onready var show_damage_check: CheckButton = $SettingsMenu/Panel/VBoxContainer/SettingsContainer/ShowDamageCheck
@onready var settings_back_button: Button = $SettingsMenu/Panel/VBoxContainer/BackButton
@onready var easy_button: Button = $DifficultySelect/Panel/VBoxContainer/ButtonContainer/EasyButton
@onready var restart_button: Button = $GameOverScreen/Panel/VBoxContainer/RestartButton

# Pause Menu References
@onready var resume_button: Button = $PauseMenu/MainPanel/MainVBox/TopSection/LeftPanel/ResumeButton
@onready var level_label: Label = $PauseMenu/MainPanel/MainVBox/TopSection/LeftPanel/LevelLabel
@onready var pause_wave_label: Label = $PauseMenu/MainPanel/MainVBox/TopSection/LeftPanel/WaveLabel
@onready var stats_grid: GridContainer = $PauseMenu/MainPanel/MainVBox/TopSection/StatsPanel/StatsGrid
@onready var turrets_title: Label = $PauseMenu/MainPanel/MainVBox/TurretsSection/TurretsHeader/TurretsTitle
@onready var turret_icons_row: HBoxContainer = $PauseMenu/MainPanel/MainVBox/TurretsSection/TurretIconsRow
@onready var turret_details_panel: PanelContainer = $PauseMenu/MainPanel/MainVBox/TurretsSection/TurretDetailsPanel
@onready var turret_name_label: Label = $PauseMenu/MainPanel/MainVBox/TurretsSection/TurretDetailsPanel/TurretDetailsVBox/TurretName
@onready var turret_stats_container: HBoxContainer = $PauseMenu/MainPanel/MainVBox/TurretsSection/TurretDetailsPanel/TurretDetailsVBox/StatsHBox
@onready var items_title: Label = $PauseMenu/MainPanel/MainVBox/ItemsSection/ItemsTitle
@onready var items_hint: Label = $PauseMenu/MainPanel/MainVBox/ItemsSection/ItemsHint
@onready var items_scroll: ScrollContainer = $PauseMenu/MainPanel/MainVBox/ItemsSection/ItemsScrollContainer
@onready var items_hbox: HBoxContainer = $PauseMenu/MainPanel/MainVBox/ItemsSection/ItemsScrollContainer/ItemsHBox

# UI Components (using preloaded scripts)
var _game_hud
var _wave_announcement
var _game_over
var _difficulty_select
var _pause_menu
var _settings_menu

var player: Node2D = null
var damage_number_scene: PackedScene
var is_paused: bool = false


func _ready() -> void:
	# Hide overlays and HUD initially
	wave_announcement.visible = false
	game_over_screen.visible = false
	difficulty_screen.visible = false
	hud_container.visible = false
	pause_menu.visible = false
	settings_menu.visible = false

	# Load damage number scene
	damage_number_scene = preload("res://scenes/damage_number.tscn")

	# Initialize UI components
	_setup_components()

	# Connect to events
	Events.player_damaged.connect(_on_player_damaged)
	Events.wave_timer_updated.connect(_on_wave_timer_updated)
	Events.wave_started.connect(_on_wave_started)
	Events.xp_collected.connect(_on_xp_collected)
	Events.gold_collected.connect(_on_gold_changed)
	Events.gold_spent.connect(_on_gold_changed)
	Events.turret_spawned.connect(_on_turret_spawned)
	Events.show_wave_announcement.connect(_on_show_wave_announcement)
	Events.hide_wave_announcement.connect(_on_hide_wave_announcement)
	Events.game_over.connect(_on_game_over)
	Events.show_difficulty_select.connect(_on_show_difficulty_select)
	Events.game_started.connect(_on_game_started)
	Events.damage_dealt.connect(_on_damage_dealt)


func _setup_components() -> void:
	# Game HUD component
	_game_hud = GameHUDScript.new()
	_game_hud.setup({
		"health_bar": health_bar,
		"wave_label": wave_label,
		"timer_label": timer_label,
		"xp_label": xp_label,
		"gold_label": gold_label,
		"turret_label": turret_label,
	})

	# Wave announcement component
	_wave_announcement = WaveAnnouncementScript.new()
	_wave_announcement.setup({
		"container": wave_announcement,
		"label": wave_announcement_label,
	}, self)

	# Game over screen component
	_game_over = GameOverScreenScript.new()
	_game_over.setup({
		"container": game_over_screen,
		"title": game_over_title,
		"stats": stats_label,
		"restart_button": restart_button,
	}, self)

	# Difficulty select component
	_difficulty_select = DifficultySelectScript.new()
	_difficulty_select.setup({
		"container": difficulty_screen,
		"easy_button": easy_button,
	}, self)

	# Pause menu component
	_pause_menu = PauseMenuScript.new()
	_pause_menu.setup({
		"container": pause_menu,
		"resume_button": resume_button,
		"level_label": level_label,
		"wave_label": pause_wave_label,
		"stats_grid": stats_grid,
		"turrets_title": turrets_title,
		"turret_icons_row": turret_icons_row,
		"turret_details_panel": turret_details_panel,
		"turret_name_label": turret_name_label,
		"turret_stats_container": turret_stats_container,
		"items_title": items_title,
		"items_hint": items_hint,
		"items_scroll": items_scroll,
		"items_hbox": items_hbox,
	}, self)

	# Settings menu component
	_settings_menu = SettingsMenuScript.new()
	_settings_menu.setup({
		"container": settings_menu,
		"show_damage_check": show_damage_check,
		"back_button": settings_back_button,
	}, self)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and Globals.is_game_active:
		if settings_menu.visible:
			_on_settings_back_pressed()
		elif pause_menu.visible:
			toggle_pause()
		else:
			toggle_pause()


# =============================================================================
# GAME EVENTS
# =============================================================================
func _on_game_started() -> void:
	hud_container.visible = true
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if player:
		_game_hud.update_health_bar(player.current_health, player.max_health)
		_pause_menu.set_player(player)


func _on_player_damaged(current_health: float, max_health: float) -> void:
	_game_hud.update_health_bar(current_health, max_health)


func _on_wave_timer_updated(time_remaining: float) -> void:
	_game_hud.update_wave_timer(time_remaining)


func _on_wave_started(wave_number: int) -> void:
	_game_hud.update_wave_number(wave_number)


func _on_xp_collected(_amount: int, total: int) -> void:
	_game_hud.update_xp(total)


func _on_gold_changed(_amount: int, total: int) -> void:
	_game_hud.update_gold(total)


func _on_turret_spawned(_turret: Node2D, _position: Vector2) -> void:
	_game_hud.update_turret_count(Globals.turrets_spawned)


func _on_show_wave_announcement(wave_number: int) -> void:
	_wave_announcement.show_announcement(wave_number)


func _on_hide_wave_announcement() -> void:
	_wave_announcement.hide_announcement()


func _on_game_over(victory: bool) -> void:
	_game_over.show_game_over(victory)


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


# =============================================================================
# DIFFICULTY SELECTION
# =============================================================================
func _on_show_difficulty_select() -> void:
	_difficulty_select.show()


func _on_easy_pressed() -> void:
	_difficulty_select.hide_and_emit(Globals.Difficulty.EASY)


func _on_medium_pressed() -> void:
	_difficulty_select.hide_and_emit(Globals.Difficulty.MEDIUM)


func _on_hard_pressed() -> void:
	_difficulty_select.hide_and_emit(Globals.Difficulty.HARD)


# =============================================================================
# PAUSE MENU
# =============================================================================
func toggle_pause() -> void:
	is_paused = not is_paused
	get_tree().paused = is_paused

	if is_paused:
		_pause_menu.show()
		Events.game_paused.emit()
	else:
		_pause_menu.hide()
		Events.game_resumed.emit()


func _on_resume_pressed() -> void:
	toggle_pause()


func _on_settings_pressed() -> void:
	_pause_menu.hide()
	_settings_menu.show()


func _on_quit_pressed() -> void:
	get_tree().paused = false
	is_paused = false
	get_tree().reload_current_scene()


func _on_settings_back_pressed() -> void:
	_settings_menu.hide()
	_pause_menu.show()
	if resume_button:
		resume_button.grab_focus()


func _on_show_damage_toggled(toggled_on: bool) -> void:
	_settings_menu.on_show_damage_toggled(toggled_on)


# =============================================================================
# DAMAGE NUMBERS
# =============================================================================
func _on_damage_dealt(pos: Vector2, amount: float) -> void:
	if not Globals.show_damage_numbers:
		return
	if damage_number_scene == null:
		return

	var damage_number = damage_number_scene.instantiate()
	get_tree().current_scene.add_child(damage_number)
	damage_number.global_position = pos + Vector2(randf_range(-10, 10), -20)
	damage_number.setup(amount)


# =============================================================================
# LEGACY API (kept for backward compatibility)
# =============================================================================
func update_health_bar(current: float, maximum: float) -> void:
	_game_hud.update_health_bar(current, maximum)

func update_xp(total: int) -> void:
	_game_hud.update_xp(total)

func update_gold(total: int) -> void:
	_game_hud.update_gold(total)

func update_turret_count(count: int) -> void:
	_game_hud.update_turret_count(count)

func update_pause_menu_stats() -> void:
	_pause_menu.update_stats()

func update_turrets_panel() -> void:
	_pause_menu.update_turrets_panel()

func update_turret_details(type: String) -> void:
	_pause_menu.update_turret_details(type)

func update_items_panel() -> void:
	_pause_menu.update_items_panel()
