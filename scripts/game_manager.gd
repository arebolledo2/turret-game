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
	
	# Expose to other systems via service
	GameStateService.wave_controller = wave_controller

	# Connect events
	Events.player_died.connect(_on_player_died)
	Events.difficulty_selected.connect(_on_difficulty_selected)
	Events.game_mode_selected.connect(_on_game_mode_selected)
	Events.start_settings_applied.connect(_on_start_settings_applied)
	Events.defense_target_destroyed.connect(_on_defense_target_destroyed)
	Events.tunnel_door_breached.connect(_on_tunnel_door_breached)
	Events.escort_reached_destination.connect(_on_escort_reached_destination)
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
	DifficultyService.set_difficulty(difficulty as GameEnums.Difficulty)
	GameStateMachine.transition_to(GameStateMachine.GameState.GAME_MODE_SELECT)
	Events.show_game_mode_select.emit()


func _on_game_mode_selected(game_mode: int) -> void:
	GameModeService.set_mode(game_mode as GameEnums.GameMode)


func show_start_settings() -> void:
	GameStateMachine.force_transition(GameStateMachine.GameState.DIFFICULTY_SELECT) # Reuse state for now
	Events.show_start_settings.emit()


func _on_start_settings_applied(difficulty: int, spawn_mode: int, win_mode: int, arena_mode: int, bg_index: int) -> void:
	DifficultyService.set_difficulty(difficulty as GameEnums.Difficulty)
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
	# Store modes before reset
	var spawn_mode = GameModeService.active_modes.get("spawn_location")
	var win_mode = GameModeService.active_modes.get("win_condition")
	var arena_mode = GameModeService.active_modes.get("arena_type")

	_reset_all_services()

	# Restore modes after reset
	if spawn_mode != null:
		GameModeService.set_mode(spawn_mode as GameEnums.GameMode)
	if win_mode != null:
		GameModeService.set_mode(win_mode as GameEnums.GameMode)
	if arena_mode != null:
		GameModeService.set_mode(arena_mode as GameEnums.GameMode)

	GameStateService.is_game_active = true
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
	if not GameStateService.is_game_active:
		return

	GameStateService.time_survived += delta

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

	# Spawn game mode entities on wave 1 (during announcement so they are ready for combat start)
	# This ensures player can be positioned correctly relative to them before action starts
	# Handle Escort and Defense Mode Setup
	if GameModeService.is_escort_mode_active():
		# Ensure entity exists (Spawn on Wave 1, or if missing)
		if not entity_spawner.has_defense_target():
			entity_spawner.spawn_game_mode_entities()
			
		# Regenerate path and reposition for EVERY wave (Dynamic Paths)
		var defense_target = entity_spawner.get_defense_target()
		if defense_target:
			# Generate fresh random path
			var new_path = GameModeService.generate_escort_path()
			
			# Teleport payload to start
			defense_target.global_position = new_path[0]
			defense_target.initialize_escort(new_path)
			
			# Teleport Player (Formation: Right Side)
			var player = get_tree().get_first_node_in_group("player")
			if player:
				player.global_position = defense_target.global_position + Vector2(80, 0)
			
			# Teleport Turrets (Formation: Left Side)
			# ONLY on Wave 1 (Squad Deploy). For subsequent waves, existing turrets retain positions.
			if turret_manager and GameStateService.current_wave == 1:
				var offset_idx = 0
				for turret in turret_manager.turrets:
					if is_instance_valid(turret):
						# Stack them nicely on the left
						var offset = Vector2(-80 - (offset_idx * 60), 0)
						turret.global_position = defense_target.global_position + offset
						offset_idx += 1
						
	# Tech Defense Setup (Static)
	elif GameModeService.should_spawn_defense_target() and GameStateService.current_wave == 1:
		entity_spawner.spawn_game_mode_entities()


func _start_combat() -> void:
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
	wave_controller.start_combat()

	# Spawn game mode entities on wave 1
	# Moved to _start_wave_announcement for simultaneous spawn effect
	# if GameStateService.current_wave == 1:
	# 	entity_spawner.spawn_game_mode_entities()


func _end_wave() -> void:
	# Special case for Escort Mode: if timer runs out before reaching destination, it's a loss
	if GameModeService.is_escort_mode_active():
		var defense_target = entity_spawner.get_defense_target()
		if defense_target and defense_target.has_method("is_at_destination") and not defense_target.is_at_destination():
			DebugService.log(DebugService.SYSTEMS, "Escort failed: Timer ran out before destination.")
			_trigger_game_over()
			return
			
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
	EconomyService.shop_reroll_count = 0
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
	GameStateService.is_game_active = false
	Events.game_over.emit(true)


func _trigger_game_over() -> void:
	GameStateMachine.force_transition(GameStateMachine.GameState.GAME_OVER)
	GameStateService.is_game_active = false
	wave_controller.stop_spawning()
	Events.game_over.emit(false)


func _on_player_died() -> void:
	_trigger_game_over()


func _on_defense_target_destroyed() -> void:
	_trigger_game_over()


func _on_tunnel_door_breached() -> void:
	if GameStateMachine.is_in_combat():
		_end_wave()


func _on_escort_reached_destination() -> void:
	DebugService.log(DebugService.SYSTEMS, "Escort reached destination! Keep defending until the timer ends.")


# =============================================================================
# AUTO-PAUSE & RESTART
# =============================================================================

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_auto_pause()


func _auto_pause() -> void:
	if GameStateService.is_game_active and not get_tree().paused:
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("pause_game"):
			hud.pause_game()
		elif hud and hud.has_method("toggle_pause"):
			hud.toggle_pause()


func restart_game() -> void:
	get_tree().reload_current_scene()


func skip_wave() -> void:
	"""Debug method to skip the current wave and get gold."""
	var is_announcement = GameStateMachine.current_state == GameStateMachine.GameState.WAVE_ANNOUNCEMENT
	if not (GameStateMachine.is_in_combat() or is_announcement):
		return
	
	# Estimate gold reward based on remaining time
	var wave = GameStateService.current_wave
	var duration = wave_controller.get_wave_duration(wave)
	var difficulty_mult = DifficultyService.get_difficulty_config()["enemy_count_mult"]
	var item_mult = ItemTrackingService.get_enemy_count_multiplier()
	var enemy_count = GameStateService.get_wave_enemy_count(wave, difficulty_mult, item_mult)
	
	# Rate of enemies per second
	var enemy_rate = float(enemy_count) / max(duration, 1.0)
	
	# Use full duration if in announcement, otherwise use remaining timer
	var timer_for_gold = duration if is_announcement else wave_controller.wave_timer
	
	# Give slightly more scrap than time left would normally give (bonus for skipping)
	var scrap_to_give = int(timer_for_gold * enemy_rate * 1.5)

	# Minimum scrap based on wave number
	scrap_to_give = max(scrap_to_give, wave * 5)

	# Use the scrap earn multiplier from items
	var scrap_mult = ItemTrackingService.get_scrap_earn_multiplier()
	EconomyService.add_scrap(scrap_to_give, scrap_mult)
	
	# Force end combat
	_end_wave()
	
	# Resume game (if called from pause menu)
	get_tree().paused = false


func _reset_all_services() -> void:
	DifficultyService.reset_state()
	GameStateService.reset_state()
	EconomyService.reset_state()
	PlayerStatsService.reset_state()
	TurretStatsService.reset_state()
	ItemTrackingService.reset_state()
	ModifierService.clear_modifiers()
	GameModeService.reset_state()
	SettingsService.reset_state()
