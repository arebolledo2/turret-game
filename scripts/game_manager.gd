extends Node

enum GameState {IDLE, DIFFICULTY_SELECT, GAME_MODE_SELECT, SHOP, WAVE_ANNOUNCEMENT, COMBAT, WAVE_END, VICTORY, GAME_OVER}

var current_state: GameState = GameState.IDLE
var wave_timer: float = 0.0
var announcement_timer: float = 0.0
var pause_timer: float = 0.0

var enemy_spawner: Node2D
var turret_manager: Node
var tech_drop_spawner: Node2D

# Game mode entities
var defense_target_scene = preload("res://scenes/defense_target.tscn")
var tunnel_door_scene = preload("res://scenes/tunnel_door.tscn")
var current_defense_target: Node2D = null
var current_tunnel_door: Node2D = null

func _ready() -> void:
	# Get node references (siblings in scene tree)
	enemy_spawner = get_node_or_null("../EnemySpawner")
	turret_manager = get_node_or_null("../TurretManager")
	tech_drop_spawner = get_node_or_null("../TechDropSpawner")
	
	# Connect to player death (guard against duplicate connections)
	if not Events.player_died.is_connected(_on_player_died):
		Events.player_died.connect(_on_player_died)
	if not Events.difficulty_selected.is_connected(_on_difficulty_selected):
		Events.difficulty_selected.connect(_on_difficulty_selected)
	if not Events.game_mode_selected.is_connected(_on_game_mode_selected):
		Events.game_mode_selected.connect(_on_game_mode_selected)
	
	# Connect game mode entity events
	if not Events.defense_target_destroyed.is_connected(_on_defense_target_destroyed):
		Events.defense_target_destroyed.connect(_on_defense_target_destroyed)
	if not Events.tunnel_door_breached.is_connected(_on_tunnel_door_breached):
		Events.tunnel_door_breached.connect(_on_tunnel_door_breached)
	
	# Show difficulty selection
	call_deferred("show_difficulty_select")

func show_difficulty_select() -> void:
	current_state = GameState.DIFFICULTY_SELECT
	Events.show_difficulty_select.emit()

func _on_difficulty_selected(difficulty: int) -> void:
	Globals.set_difficulty(difficulty as GameEnums.Difficulty)
	show_game_mode_select()

func show_game_mode_select() -> void:
	current_state = GameState.GAME_MODE_SELECT
	Events.show_game_mode_select.emit()

func _on_game_mode_selected(game_mode: int) -> void:
	Globals.set_game_mode(game_mode as GameEnums.GameMode)
	start_game()

func start_game() -> void:
	# Store ALL mode groups before reset
	var spawn_mode = Globals.game_mode_service.active_modes.get("spawn_location")
	var win_mode = Globals.game_mode_service.active_modes.get("win_condition")
	var arena_mode = Globals.game_mode_service.active_modes.get("arena_type")
	
	print("DEBUG start_game: Preserving modes - spawn:", spawn_mode, " win:", win_mode, " arena:", arena_mode)
	
	Globals.reset_stats()
	
	# Restore ALL modes after reset
	if spawn_mode != null:
		GameModeService.set_mode(spawn_mode as GameEnums.GameMode)
	if win_mode != null:
		GameModeService.set_mode(win_mode as GameEnums.GameMode)
	if arena_mode != null:
		GameModeService.set_mode(arena_mode as GameEnums.GameMode)
	
	print("DEBUG start_game: After restore - spawn:", GameModeService.active_modes.get("spawn_location"), " win:", GameModeService.active_modes.get("win_condition"), " arena:", GameModeService.active_modes.get("arena_type"))
		
	Globals.is_game_active = true
	Events.game_started.emit()
	
	# Spawn free starting turret (skip initial shop phase)
	if turret_manager and turret_manager.has_method("spawn_starting_turret"):
		turret_manager.spawn_starting_turret()
	
	# Go directly to wave 1
	start_wave_announcement()

func _process(delta: float) -> void:
	if Globals == null or not Globals.is_game_active:
		return
	
	Globals.time_survived += delta
	
	match current_state:
		GameState.WAVE_ANNOUNCEMENT:
			process_announcement(delta)
		GameState.COMBAT:
			process_combat(delta)
		GameState.WAVE_END:
			process_wave_end(delta)
		GameState.SHOP:
			pass # Shop is UI-driven, no processing needed

func start_wave_announcement() -> void:
	Globals.current_wave += 1
	current_state = GameState.WAVE_ANNOUNCEMENT
	announcement_timer = Globals.WAVE_ANNOUNCEMENT_TIME
	
	# Emit announcement signal for UI
	Events.wave_announcement_started.emit(Globals.current_wave)
	Events.show_wave_announcement.emit(Globals.current_wave)

func process_announcement(delta: float) -> void:
	announcement_timer -= delta
	if announcement_timer <= 0:
		start_combat()

func start_combat() -> void:
	current_state = GameState.COMBAT
	wave_timer = Globals.get_wave_duration(Globals.current_wave)

	Events.hide_wave_announcement.emit()
	Events.wave_started.emit(Globals.current_wave)
	
	# Spawn game mode entities on wave 1 (now current_wave is set correctly)
	if Globals.current_wave == 1:
		_spawn_game_mode_entities()

	# Start enemy spawning
	if enemy_spawner:
		enemy_spawner.start_spawning(Globals.current_wave)

	# Start tech drop spawning
	if tech_drop_spawner and tech_drop_spawner.has_method("start_spawning"):
		tech_drop_spawner.start_spawning(Globals.current_wave)

func process_combat(delta: float) -> void:
	wave_timer -= delta
	Events.wave_timer_updated.emit(wave_timer)

	# Spawn rate is now handled internally by enemy_spawner with constant rate + randomness

	if wave_timer <= 0:
		end_wave()

func end_wave() -> void:
	current_state = GameState.WAVE_END
	pause_timer = Globals.BETWEEN_WAVE_PAUSE

	# Stop spawning
	if enemy_spawner:
		enemy_spawner.stop_spawning()

	# Stop tech drop spawning
	if tech_drop_spawner and tech_drop_spawner.has_method("stop_spawning"):
		tech_drop_spawner.stop_spawning()

	Events.wave_ended.emit(Globals.current_wave)
	
	# Check for victory
	if Globals.current_wave >= Globals.MAX_WAVES:
		trigger_victory()

func process_wave_end(delta: float) -> void:
	pause_timer -= delta
	if pause_timer <= 0:
		# Award wave completion bonus with multiplier
		var wave_bonus_base = Globals.GOLD_WAVE_BONUS_BASE + (Globals.current_wave * 5)
		var wave_bonus = int(wave_bonus_base * Globals.get_wave_bonus_multiplier())
		Globals.total_gold += wave_bonus
		Events.gold_collected.emit(wave_bonus, Globals.total_gold)

		# Shop opens after wave 1 (skip shop before first wave)
		if Globals.current_wave >= 1:
			start_shop_phase()
		else:
			start_wave_announcement()

func start_shop_phase() -> void:
	current_state = GameState.SHOP
	Globals.shop_reroll_count = 0
	Events.shop_opened.emit(Globals.current_wave)

func end_shop_phase() -> void:
	current_state = GameState.WAVE_ANNOUNCEMENT
	Events.shop_closed.emit()

	# Reset game state for the new wave
	reset_wave_state()

	# Spawn purchased turrets before wave starts
	if turret_manager and turret_manager.has_method("spawn_pending_turrets"):
		turret_manager.spawn_pending_turrets()

	start_wave_announcement()

func reset_wave_state() -> void:
	# Clear all enemies
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()

	# Clear all tech drops (despawn with no rewards)
	if tech_drop_spawner and tech_drop_spawner.has_method("clear_all_drops"):
		tech_drop_spawner.clear_all_drops()

	# Reset player health
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("reset_health"):
		player.reset_health()

	# Turrets maintain their positions between waves

func trigger_victory() -> void:
	current_state = GameState.VICTORY
	Globals.is_game_active = false
	Events.game_over.emit(true)

func _on_player_died() -> void:
	current_state = GameState.GAME_OVER
	Globals.is_game_active = false

	# Stop spawning
	if enemy_spawner:
		enemy_spawner.stop_spawning()

	# Stop tech drop spawning
	if tech_drop_spawner and tech_drop_spawner.has_method("stop_spawning"):
		tech_drop_spawner.stop_spawning()

	Events.game_over.emit(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_auto_pause()

func _auto_pause() -> void:
	# Only auto-pause if the game is active and not already paused
	if Globals.is_game_active and not get_tree().paused:
		# We use the event system to trigger pause if possible, 
		# or we can rely on HUD to listen to focus loss.
		# For now, let's emit a pause request if we had one, 
		# but since we don't, we'll use Events.game_paused.emit() 
		# and hope HUD handles it, OR better: trigger HUD directly if we can find it.
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("pause_game"):
			hud.pause_game()
		elif hud and hud.has_method("toggle_pause"):
			hud.toggle_pause()

func restart_game() -> void:
	get_tree().reload_current_scene()

# =============================================================================
# GAME MODE ENTITY MANAGEMENT
# =============================================================================

func _spawn_game_mode_entities() -> void:
	"""Spawn entities based on the active win_condition game mode."""
	var difficulty_config = Globals.get_difficulty_config()
	
	print("DEBUG: _spawn_game_mode_entities called")
	print("DEBUG: Win condition mode: ", GameModeService.get_win_condition_mode())
	print("DEBUG: Should spawn defense target: ", GameModeService.should_spawn_defense_target())
	print("DEBUG: Should spawn tunnel door: ", GameModeService.should_spawn_tunnel_door())
	
	# Tech Defense Mode - spawn defense target
	if GameModeService.should_spawn_defense_target():
		print("DEBUG: Spawning defense target...")
		current_defense_target = defense_target_scene.instantiate()
		get_tree().current_scene.add_child(current_defense_target)
		current_defense_target.global_position = Vector2.ZERO # Center of arena
		current_defense_target.initialize(Globals.current_wave, difficulty_config)
		Events.defense_target_spawned.emit(current_defense_target, Vector2.ZERO)
		print("DEBUG: Defense target spawned at: ", current_defense_target.global_position)
		print("DEBUG: Defense target visible: ", current_defense_target.visible)
	
	# Tunneling Modes - spawn door
	if GameModeService.should_spawn_tunnel_door():
		print("DEBUG: Spawning tunnel door...")
		current_tunnel_door = tunnel_door_scene.instantiate()
		get_tree().current_scene.add_child(current_tunnel_door)
		# Position door at right edge of arena
		var door_x = GameConstants.ARENA_WIDTH / 2.0 - 100
		current_tunnel_door.global_position = Vector2(door_x, 0)
		current_tunnel_door.initialize(Globals.current_wave, difficulty_config)
		print("DEBUG: Tunnel door spawned at: ", current_tunnel_door.global_position)

func _on_defense_target_destroyed() -> void:
	"""Handle defense target destruction - trigger game over."""
	current_state = GameState.GAME_OVER
	Globals.is_game_active = false
	
	# Stop spawning
	if enemy_spawner:
		enemy_spawner.stop_spawning()
	if tech_drop_spawner and tech_drop_spawner.has_method("stop_spawning"):
		tech_drop_spawner.stop_spawning()
	
	Events.game_over.emit(false)

func _on_tunnel_door_breached() -> void:
	"""Handle tunnel door breached - complete wave early."""
	# Only trigger if we're in COMBAT state
	if current_state == GameState.COMBAT:
		end_wave()
