extends CanvasLayer

## Main HUD controller - orchestrates UI components
## REFACTORED: Reduced from 374 to ~150 lines by extracting components

# Preload UI component scripts
const GameHUDScript = preload("res://scripts/ui/game_hud.gd")
const WaveAnnouncementScript = preload("res://scripts/ui/wave_announcement.gd")
const GameOverScreenScript = preload("res://scripts/ui/game_over_screen.gd")
const DifficultySelectScript = preload("res://scripts/ui/difficulty_select.gd")
const PauseMenuScript = preload("res://scripts/ui/pause_menu.gd")
const SettingsMenuScript = preload("res://scripts/ui/settings_menu.gd")
const GameModeSelectScript = preload("res://scripts/ui/game_mode_select.gd")
const StartSettingsScript = preload("res://scripts/ui/start_settings.gd")
const LootReviewScreenScript = preload("res://scripts/ui/loot_review_screen.gd")

# Node references
@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/TopRow/HealthBar
@onready var health_label: Label = $MarginContainer/VBoxContainer/TopRow/HealthBar/HealthLabel
@onready var wave_label: Label = $MarginContainer/VBoxContainer/TopRow/WaveInfo/WaveLabel
@onready var timer_label: Label = $MarginContainer/VBoxContainer/TopRow/WaveInfo/TimerLabel
@onready var xp_label: Label = $MarginContainer/VBoxContainer/TopRow/StatsContainer/XPLabel
@onready var gold_label: Label = $MarginContainer/VBoxContainer/TopRow/StatsContainer/GoldLabel
@onready var turret_label: Label = $MarginContainer/VBoxContainer/TopRow/StatsContainer/TurretLabel
@onready var wave_announcement: Control = $WaveAnnouncement
@onready var wave_announcement_label: Label = $WaveAnnouncement/Panel/WaveLabel
@onready var game_over_screen: Control = $GameOverScreen
@onready var game_over_title: Label = $GameOverScreen/Panel/VBoxContainer/Title
@onready var stats_label: Label = $GameOverScreen/Panel/VBoxContainer/StatsLabel
@onready var difficulty_screen: Control = $DifficultySelect
@onready var game_mode_screen: Control = $GameModeSelect
@onready var start_settings_screen: Control = $StartSettings
@onready var hud_container: MarginContainer = $MarginContainer
@onready var pause_menu: Control = $PauseMenu
@onready var settings_menu: Control = $SettingsMenu
@onready var show_damage_check: CheckButton = $SettingsMenu/Panel/VBoxContainer/SettingsContainer/ShowDamageCheck
@onready var isometric_debug_check: CheckButton = $SettingsMenu/Panel/VBoxContainer/SettingsContainer/IsometricDebugCheck
@onready var physics_hitboxes_check: CheckButton = $SettingsMenu/Panel/VBoxContainer/SettingsContainer/PhysicsHitboxes/PhysicsHitboxesCheck
@onready var player_hurtbox_check: CheckButton = $SettingsMenu/Panel/VBoxContainer/SettingsContainer/PlayerHurtbox/PlayerHurtboxCheck
@onready var enemy_hurtbox_check: CheckButton = $SettingsMenu/Panel/VBoxContainer/SettingsContainer/EnemyHurtbox/EnemyHurtboxCheck
@onready var player_attack_check: CheckButton = $SettingsMenu/Panel/VBoxContainer/SettingsContainer/PlayerAttack/PlayerAttackCheck
@onready var add_item_dropdown: OptionButton = $SettingsMenu/Panel/VBoxContainer/SettingsContainer/DebugItemContainer/AddItemDropdown
@onready var add_item_button: Button = $SettingsMenu/Panel/VBoxContainer/SettingsContainer/DebugItemContainer/AddItemButton
@onready var debug_item_description_label: Label = $SettingsMenu/Panel/VBoxContainer/SettingsContainer/ItemDescriptionLabel
@onready var settings_back_button: Button = $SettingsMenu/Panel/VBoxContainer/BackButton
@onready var easy_button: Button = $DifficultySelect/Panel/VBoxContainer/ButtonContainer/EasyButton
@onready var sentinel_button: Button = $GameModeSelect/Panel/VBoxContainer/ButtonContainer/SentinelButton
@onready var invasion_button: Button = $GameModeSelect/Panel/VBoxContainer/ButtonContainer/InvasionButton
@onready var survival_button: Button = $GameModeSelect/Panel/VBoxContainer/ButtonContainer/SurvivalButton
@onready var tech_defense_button: Button = $GameModeSelect/Panel/VBoxContainer/ButtonContainer/TechDefenseButton
@onready var tunneling_timed_button: Button = $GameModeSelect/Panel/VBoxContainer/ButtonContainer/TunnelingTimedButton
@onready var tunneling_alert_button: Button = $GameModeSelect/Panel/VBoxContainer/ButtonContainer/TunnelingAlertButton
@onready var classic_arena_button: Button = $GameModeSelect/Panel/VBoxContainer/ButtonContainer/ClassicArenaButton
@onready var isometric_arena_button: Button = $GameModeSelect/Panel/VBoxContainer/ButtonContainer/IsometricArenaButton
@onready var restart_button: Button = $GameOverScreen/Panel/VBoxContainer/RestartButton
@onready var loot_review_screen: Control = $LootReview

# Pause Menu References
@onready var resume_button: Button = $PauseMenu/MainPanel/MainVBox/TopSection/LeftPanel/ResumeButton
@onready var level_label: Label = $PauseMenu/MainPanel/MainVBox/TopSection/LeftPanel/LevelLabel
@onready var pause_wave_label: Label = $PauseMenu/MainPanel/MainVBox/TopSection/LeftPanel/WaveLabel
@onready var stats_grid: GridContainer = $PauseMenu/MainPanel/MainVBox/TopSection/StatsPanel/StatsGrid

# New Component Handlers
var game_display: HUDGameDisplay
var menu_manager: HUDMenuManager

# UI Components (using preloaded scripts)
var _game_hud
var _wave_announcement
var _game_over
var _difficulty_select
var _game_mode_select
var _start_settings
var _pause_menu
var _settings_menu
var _loot_review

var player: Node2D = null
var damage_number_scene: PackedScene


func _ready() -> void:
	# Add to "hud" group so GameManager can find us for auto-pause
	add_to_group("hud")

	# Hide overlays and HUD initially
	wave_announcement.visible = false
	game_over_screen.visible = false
	difficulty_screen.visible = false
	hud_container.visible = false
	pause_menu.visible = false
	settings_menu.visible = false
	loot_review_screen.visible = false

	# Load damage number scene
	damage_number_scene = preload("res://scenes/damage_number.tscn")

	# Initialize new component handlers
	game_display = HUDGameDisplay.new()
	add_child(game_display)
	game_display.initialize({
		"health_bar": health_bar,
		"health_label": health_label,
		"wave_label": wave_label,
		"timer_label": timer_label,
		"xp_label": xp_label,
		"gold_label": gold_label,
		"turret_label": turret_label,
	})

	menu_manager = HUDMenuManager.new()
	add_child(menu_manager)
	menu_manager.initialize({
		"pause_menu": pause_menu,
		"settings_menu": settings_menu,
		"game_over_screen": game_over_screen,
		"difficulty_screen": difficulty_screen,
		"game_mode_screen": game_mode_screen,
	})

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
	Events.show_game_mode_select.connect(_on_show_game_mode_select)
	Events.show_start_settings.connect(_on_show_start_settings)
	Events.game_started.connect(_on_game_started)
	Events.damage_dealt.connect(_on_damage_dealt)
	Events.dot_damage_dealt.connect(_on_dot_damage_dealt)
	Events.loot_review_started.connect(_on_loot_review_started)

	# Connect Granular Hitbox Toggles
	physics_hitboxes_check.toggled.connect(_on_physics_hitboxes_toggled)
	player_hurtbox_check.toggled.connect(_on_player_hurtbox_toggled)
	enemy_hurtbox_check.toggled.connect(_on_enemy_hurtbox_toggled)
	player_attack_check.toggled.connect(_on_player_attack_toggled)


func _setup_components() -> void:
	# Game HUD component
	_game_hud = GameHUDScript.new()
	_game_hud.setup({
		"health_bar": health_bar,
		"health_label": health_label,
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
		"panel": $WaveAnnouncement/Panel,
		"label": wave_announcement_label,
	}, self)

	# Game over screen component
	_game_over = GameOverScreenScript.new()
	_game_over.setup({
		"container": game_over_screen,
		"panel": $GameOverScreen/Panel,
		"title": game_over_title,
		"stats": stats_label,
		"restart_button": restart_button,
	}, self)

	# Difficulty select component
	_difficulty_select = DifficultySelectScript.new()
	_difficulty_select.setup({
		"container": difficulty_screen,
		"panel": $DifficultySelect/Panel,
		"easy_button": easy_button,
	}, self)

	_game_mode_select = GameModeSelectScript.new()
	_game_mode_select.setup({
		"container": game_mode_screen,
		"panel": $GameModeSelect/Panel,
		"title_label": $GameModeSelect/Panel/VBoxContainer/Title,
		"subtitle_label": $GameModeSelect/Panel/VBoxContainer/Subtitle,
		"button_container": $GameModeSelect/Panel/VBoxContainer/ButtonContainer,
		"sentinel_button": sentinel_button,
		"invasion_button": invasion_button,
		"survival_button": survival_button,
		"tech_defense_button": tech_defense_button,
		"tunneling_timed_button": tunneling_timed_button,
		"tunneling_alert_button": tunneling_alert_button,
		"classic_arena_button": classic_arena_button,
		"isometric_arena_button": isometric_arena_button,
	}, self)

	_start_settings = StartSettingsScript.new()
	_start_settings.setup({
		"container": start_settings_screen,
		"panel": $StartSettings/Panel,
		"difficulty_dropdown": $StartSettings/Panel/VBoxContainer/SettingsGrid/DifficultyDropdown,
		"spawn_dropdown": $StartSettings/Panel/VBoxContainer/SettingsGrid/SpawnDropdown,
		"mode_dropdown": $StartSettings/Panel/VBoxContainer/SettingsGrid/ModeDropdown,
		"arena_dropdown": $StartSettings/Panel/VBoxContainer/SettingsGrid/ArenaDropdown,
		"bg_dropdown": $StartSettings/Panel/VBoxContainer/SettingsGrid/BGDropdown,
		"start_button": $StartSettings/Panel/VBoxContainer/StartButton,
	}, self)

	# Pause menu component
	_pause_menu = PauseMenuScript.new()
	_pause_menu.setup({
		"container": pause_menu,
		"panel": $PauseMenu/MainPanel,
		"resume_button": resume_button,
		"level_label": level_label,
		"wave_label": pause_wave_label,
		"stats_grid": stats_grid,
		"inventory_section": $PauseMenu/MainPanel/MainVBox/TurretsSection,
	}, self)

	# Settings menu component
	_settings_menu = SettingsMenuScript.new()
	_settings_menu.setup({
		"container": settings_menu,
		"panel": $SettingsMenu/Panel,
		"show_damage_check": show_damage_check,
		"isometric_debug_check": isometric_debug_check,
		"physics_hitboxes_check": physics_hitboxes_check,
		"player_hurtbox_check": player_hurtbox_check,
		"enemy_hurtbox_check": enemy_hurtbox_check,
		"player_attack_check": player_attack_check,
		"add_item_dropdown": add_item_dropdown,
		"add_item_button": add_item_button,
		"item_description_label": debug_item_description_label,
		"back_button": settings_back_button,
	}, self)

	# Loot review screen component
	_loot_review = LootReviewScreenScript.new()
	_loot_review.setup({
		"container": loot_review_screen,
		"panel": loot_review_screen.get_node("CenterContainer/Panel"),
		"title_label": loot_review_screen.get_node("CenterContainer/Panel/MarginContainer/VBoxContainer/TitleLabel"),
		"item_name_label": loot_review_screen.get_node("CenterContainer/Panel/MarginContainer/VBoxContainer/ItemCard/ItemVBox/ItemNameLabel"),
		"item_description_label": loot_review_screen.get_node("CenterContainer/Panel/MarginContainer/VBoxContainer/ItemCard/ItemVBox/ItemDescriptionLabel"),
		"item_rarity_label": loot_review_screen.get_node("CenterContainer/Panel/MarginContainer/VBoxContainer/ItemCard/ItemVBox/RarityLabel"),
		"counter_label": loot_review_screen.get_node("CenterContainer/Panel/MarginContainer/VBoxContainer/CounterLabel"),
		"keep_button": loot_review_screen.get_node("CenterContainer/Panel/MarginContainer/VBoxContainer/ButtonContainer/KeepButton"),
		"discard_button": loot_review_screen.get_node("CenterContainer/Panel/MarginContainer/VBoxContainer/ButtonContainer/DiscardButton"),
		"shop_manager": get_node_or_null("../ShopManager"),
	}, self)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and Globals.is_game_active:
		if settings_menu.visible:
			_on_settings_back_pressed()
		else:
			menu_manager.toggle_pause()


# =============================================================================
# GAME EVENTS
# =============================================================================
func _on_game_started() -> void:
	hud_container.visible = true
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if player:
		game_display.update_health_bar(player.current_health, player.max_health)
		_pause_menu.set_player(player)


func _on_player_damaged(current_health: float, max_health: float) -> void:
	game_display.update_health_bar(current_health, max_health)


func _on_wave_timer_updated(time_remaining: float) -> void:
	game_display.update_wave_timer(time_remaining)


func _on_wave_started(wave_number: int) -> void:
	game_display.update_wave_number(wave_number)


func _on_xp_collected(_amount: int, total: int) -> void:
	game_display.update_xp(total)


func _on_gold_changed(_amount: int, total: int) -> void:
	game_display.update_gold(total)


func _on_turret_spawned(_turret: Node2D, _position: Vector2) -> void:
	game_display.update_turret_count(Globals.turrets_spawned)


func _on_show_wave_announcement(wave_number: int) -> void:
	_wave_announcement.show_announcement(wave_number)


func _on_hide_wave_announcement() -> void:
	_wave_announcement.hide_announcement()


func _on_game_over(victory: bool) -> void:
	menu_manager.show_game_over(victory, _game_over)


func _on_loot_review_started(item_ids: Array) -> void:
	_loot_review.show_review(item_ids)


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


# =============================================================================
# DIFFICULTY SELECTION
# =============================================================================
func _on_show_difficulty_select() -> void:
	menu_manager.show_difficulty_select()


func _on_easy_pressed() -> void:
	_difficulty_select.hide_and_emit(GameEnums.Difficulty.EASY)


func _on_medium_pressed() -> void:
	_difficulty_select.hide_and_emit(GameEnums.Difficulty.MEDIUM)


func _on_hard_pressed() -> void:
	_difficulty_select.hide_and_emit(GameEnums.Difficulty.HARD)


# =============================================================================
# GAME MODE SELECTION
# =============================================================================
func _on_show_game_mode_select() -> void:
	_game_mode_select.show()


func _on_sentinel_pressed() -> void:
	_game_mode_select.on_spawn_mode_selected(GameEnums.GameMode.SENTINEL)


func _on_invasion_pressed() -> void:
	_game_mode_select.on_spawn_mode_selected(GameEnums.GameMode.INVASION)


func _on_survival_pressed() -> void:
	_game_mode_select.on_win_condition_selected(GameEnums.GameMode.SURVIVAL)


func _on_tech_defense_pressed() -> void:
	_game_mode_select.on_win_condition_selected(GameEnums.GameMode.TECH_DEFENSE)


func _on_tunneling_timed_pressed() -> void:
	_game_mode_select.on_win_condition_selected(GameEnums.GameMode.TUNNELING_TIMED)


func _on_tunneling_alert_pressed() -> void:
	_game_mode_select.on_win_condition_selected(GameEnums.GameMode.TUNNELING_ALERT)


func _on_classic_arena_pressed() -> void:
	_game_mode_select.on_arena_type_selected(GameEnums.GameMode.ARENA_RECTANGULAR)


func _on_isometric_arena_pressed() -> void:
	_game_mode_select.on_arena_type_selected(GameEnums.GameMode.ARENA_ISOMETRIC)


# =============================================================================
# START SETTINGS
# =============================================================================
func _on_show_start_settings() -> void:
	_start_settings.show()


# =============================================================================
# PAUSE MENU
# =============================================================================
func toggle_pause() -> void:
	menu_manager.toggle_pause()


func pause_game() -> void:
	menu_manager.pause()


func _on_resume_pressed() -> void:
	menu_manager.toggle_pause()


func _on_settings_pressed() -> void:
	menu_manager.show_settings()


func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_settings_back_pressed() -> void:
	menu_manager.hide_settings()
	if resume_button:
		resume_button.grab_focus()


func _on_show_damage_toggled(toggled_on: bool) -> void:
	_settings_menu.on_show_damage_toggled(toggled_on)


func _on_physics_hitboxes_toggled(toggled_on: bool) -> void:
	_settings_menu.on_hitbox_type_toggled(GameEnums.HitboxType.PHYSICS, toggled_on)


func _on_player_hurtbox_toggled(toggled_on: bool) -> void:
	_settings_menu.on_hitbox_type_toggled(GameEnums.HitboxType.PLAYER_HURTBOX, toggled_on)


func _on_enemy_hurtbox_toggled(toggled_on: bool) -> void:
	_settings_menu.on_hitbox_type_toggled(GameEnums.HitboxType.ENEMY_HURTBOX, toggled_on)


func _on_player_attack_toggled(toggled_on: bool) -> void:
	_settings_menu.on_hitbox_type_toggled(GameEnums.HitboxType.PLAYER_ATTACK, toggled_on)


# =============================================================================
# DAMAGE NUMBERS
# =============================================================================
func _on_damage_dealt(pos: Vector2, amount: float, is_crit: bool = false) -> void:
	if not Globals.show_damage_numbers:
		return
	if damage_number_scene == null:
		return

	var damage_number = damage_number_scene.instantiate()
	get_tree().current_scene.add_child(damage_number)
	damage_number.global_position = pos + Vector2(randf_range(-10, 10), -20)
	damage_number.setup(amount, is_crit)


func _on_dot_damage_dealt(pos: Vector2, amount: float) -> void:
	"""Handle DoT damage numbers with orange color for fire damage."""
	if not Globals.show_damage_numbers:
		return
	if damage_number_scene == null:
		return

	var damage_number = damage_number_scene.instantiate()
	get_tree().current_scene.add_child(damage_number)
	damage_number.global_position = pos + Vector2(randf_range(-10, 10), -20)
	damage_number.setup(amount)
	
	# Set orange color for DoT damage
	if damage_number.has_node("Label"):
		var label = damage_number.get_node("Label")
		label.modulate = Color(1.0, 0.6, 0.2, 1.0) # Orange for fire DoT


# =============================================================================
# LEGACY API (kept for backward compatibility)
# =============================================================================
func update_health_bar(current: float, maximum: float) -> void:
	game_display.update_health_bar(current, maximum)

func update_xp(total: int) -> void:
	game_display.update_xp(total)

func update_gold(total: int) -> void:
	game_display.update_gold(total)

func update_turret_count(count: int) -> void:
	game_display.update_turret_count(count)

func update_pause_menu_stats() -> void:
	_pause_menu.update_stats()

func update_turrets_panel() -> void:
	_pause_menu.update_turrets_panel()

func update_turret_details(type: String) -> void:
	_pause_menu.update_turret_details(type)

func update_items_panel() -> void:
	_pause_menu.update_items_panel()
