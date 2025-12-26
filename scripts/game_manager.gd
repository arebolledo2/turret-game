extends Node

## Game Manager
## Coordinator that orchestrates game flow using sub-components:
## - GameStateMachine (autoload) - state transitions
## - WaveController - wave timing and spawning
## - GameModeEntitySpawner - defense targets, tunnel doors

# Sub-components
var wave_controller: Node = null
var entity_spawner: Node = null

# Scene references (siblings in scene tree)
var enemy_spawner: Node2D
var turret_manager: Node
var tech_drop_spawner: Node2D


func _ready() -> void:
	# Create sub-components
	wave_controller = preload("res://scripts/wave_controller.gd").new()
	wave_controller.name = "WaveController"
	add_child(wave_controller)

	entity_spawner = preload("res://scripts/game_mode_entity_spawner.gd").new()
	entity_spawner.name = "GameModeEntitySpawner"
	add_child(entity_spawner)

	# Get scene node references
	enemy_spawner = get_node_or_null("../EnemySpawner")
	turret_manager = get_node_or_null("../TurretManager")
	tech_drop_spawner = get_node_or_null("../TechDropSpawner")

	# Inject dependencies into WaveController
	wave_controller.enemy_spawner = enemy_spawner
	wave_controller.turret_manager = turret_manager
	wave_controller.tech_drop_spawner = tech_drop_spawner

	# Connect events
	Events.player_died.connect(_on_player_died)
	Events.difficulty_selected.connect(_on_difficulty_selected)
	Events.game_mode_selected.connect(_on_game_mode_selected)
	Events.start_settings_applied.connect(_on_start_settings_applied)
	Events.defense_target_destroyed.connect(_on_defense_target_destroyed)
	Events.tunnel_door_breached.connect(_on_tunnel_door_breached)
	Events.loot_review_completed.connect(_on_loot_review_completed)

	# Start game flow
	call_deferred("show_start_settings")


# =============================================================================
# MENU FLOW
# =============================================================================

func show_difficulty_select() -> void:
	GameStateMachine.force_transition(GameStateMachine.GameState.DIFFICULTY_SELECT)
	Events.show_difficulty_select.emit()


func _on_difficulty_selected(difficulty: int) -> void:
	Globals.set_difficulty(difficulty as GameEnums.Difficulty)
	GameStateMachine.transition_to(GameStateMachine.GameState.GAME_MODE_SELECT)
	Events.show_game_mode_select.emit()


func _on_game_mode_selected(game_mode: int) -> void:
	Globals.set_game_mode(game_mode as GameEnums.GameMode)


func show_start_settings() -> void:
	GameStateMachine.force_transition(GameStateMachine.GameState.DIFFICULTY_SELECT) # Reuse state for now
	Events.show_start_settings.emit()


func _on_start_settings_applied(difficulty: int, spawn_mode: int, win_mode: int, arena_mode: int, bg_index: int) -> void:
	Globals.set_difficulty(difficulty as GameEnums.Difficulty)
	GameModeService.set_mode(spawn_mode as GameEnums.GameMode)
	GameModeService.set_mode(win_mode as GameEnums.GameMode)
	GameModeService.set_mode(arena_mode as GameEnums.GameMode)
	
	# Notify systems that depend on game mode
	Events.game_mode_selected.emit(win_mode)
	Events.arena_background_selected.emit(bg_index)
	
	start_game()


# =============================================================================
# GAME START
# =============================================================================

func start_game() -> void:
	# Guard against double-starting within the same process
	if Globals.is_game_active:
		return
		
	# Store modes before reset
	var spawn_mode = Globals.game_mode_service.active_modes.get("spawn_location")
	var win_mode = Globals.game_mode_service.active_modes.get("win_condition")
	var arena_mode = Globals.game_mode_service.active_modes.get("arena_type")

	Globals.reset_stats()

	# Restore modes after reset
	if spawn_mode != null:
		GameModeService.set_mode(spawn_mode as GameEnums.GameMode)
	if win_mode != null:
		GameModeService.set_mode(win_mode as GameEnums.GameMode)
	if arena_mode != null:
		GameModeService.set_mode(arena_mode as GameEnums.GameMode)

	Globals.is_game_active = true
	Events.game_started.emit()

	# Spawn free starting turret
	if turret_manager and turret_manager.has_method("spawn_starting_turret"):
		turret_manager.spawn_starting_turret()

	# Start wave 1
	_start_wave_announcement()


# =============================================================================
# GAME LOOP
# =============================================================================

func _process(delta: float) -> void:
	if not Globals.is_game_active:
		return

	Globals.time_survived += delta

	match GameStateMachine.current_state:
		GameStateMachine.GameState.WAVE_ANNOUNCEMENT:
			if wave_controller.process_announcement(delta):
				_start_combat()

		GameStateMachine.GameState.COMBAT:
			if wave_controller.process_combat(delta):
				_end_wave()

		GameStateMachine.GameState.WAVE_END:
			if wave_controller.process_wave_end(delta):
				_finish_wave_end()


# =============================================================================
# WAVE PHASES
# =============================================================================

func _start_wave_announcement() -> void:
	GameStateMachine.transition_to(GameStateMachine.GameState.WAVE_ANNOUNCEMENT)
	wave_controller.start_wave_announcement()


func _start_combat() -> void:
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
	wave_controller.start_combat()

	# Spawn game mode entities on wave 1
	if GameStateService.current_wave == 1:
		entity_spawner.spawn_game_mode_entities()


func _end_wave() -> void:
	GameStateMachine.transition_to(GameStateMachine.GameState.WAVE_END)
	wave_controller.end_wave()

	# Check for victory
	if wave_controller.is_final_wave():
		_trigger_victory()


func _finish_wave_end() -> void:
	wave_controller.award_wave_bonus()
	_start_loot_review_or_shop()


func _start_loot_review_or_shop() -> void:
	"""Check for pending loot before opening shop."""
	if LootService.has_pending_loot():
		_start_loot_review()
	else:
		_start_shop_phase()


func _start_loot_review() -> void:
	"""Show loot review screen for found items."""
	GameStateMachine.transition_to(GameStateMachine.GameState.LOOT_REVIEW)
	Events.loot_review_started.emit(LootService.get_found_items())


func _on_loot_review_completed() -> void:
	"""Called when player finishes reviewing loot."""
	LootService.clear_found_items()
	_start_shop_phase()


func _start_shop_phase() -> void:
	GameStateMachine.transition_to(GameStateMachine.GameState.SHOP)
	Globals.shop_reroll_count = 0
	Events.shop_opened.emit(GameStateService.current_wave)


func end_shop_phase() -> void:
	"""Called externally when player closes shop."""
	wave_controller.reset_wave_state()

	# Spawn purchased turrets
	if turret_manager and turret_manager.has_method("spawn_pending_turrets"):
		turret_manager.spawn_pending_turrets()

	Events.shop_closed.emit()
	_start_wave_announcement()


# =============================================================================
# GAME END CONDITIONS
# =============================================================================

func _trigger_victory() -> void:
	GameStateMachine.force_transition(GameStateMachine.GameState.VICTORY)
	Globals.is_game_active = false
	Events.game_over.emit(true)


func _trigger_game_over() -> void:
	GameStateMachine.force_transition(GameStateMachine.GameState.GAME_OVER)
	Globals.is_game_active = false
	wave_controller.stop_spawning()
	Events.game_over.emit(false)


func _on_player_died() -> void:
	_trigger_game_over()


func _on_defense_target_destroyed() -> void:
	_trigger_game_over()


func _on_tunnel_door_breached() -> void:
	if GameStateMachine.is_in_combat():
		_end_wave()


# =============================================================================
# AUTO-PAUSE & RESTART
# =============================================================================

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_auto_pause()


func _auto_pause() -> void:
	if Globals.is_game_active and not get_tree().paused:
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("pause_game"):
			hud.pause_game()
		elif hud and hud.has_method("toggle_pause"):
			hud.toggle_pause()


func restart_game() -> void:
	get_tree().reload_current_scene()
