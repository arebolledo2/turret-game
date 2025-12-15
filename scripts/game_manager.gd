extends Node

enum GameState { IDLE, DIFFICULTY_SELECT, SHOP, WAVE_ANNOUNCEMENT, COMBAT, WAVE_END, VICTORY, GAME_OVER }

var current_state = GameState.IDLE
var wave_timer: float = 0.0
var announcement_timer: float = 0.0
var pause_timer: float = 0.0

var enemy_spawner: Node2D
var turret_manager: Node
var tech_drop_spawner: Node2D

func _ready() -> void:
	# Get node references (siblings in scene tree)
	enemy_spawner = get_node_or_null("../EnemySpawner")
	turret_manager = get_node_or_null("../TurretManager")
	tech_drop_spawner = get_node_or_null("../TechDropSpawner")
	
	# Connect to player death
	Events.player_died.connect(_on_player_died)
	Events.difficulty_selected.connect(_on_difficulty_selected)
	
	# Show difficulty selection
	call_deferred("show_difficulty_select")

func show_difficulty_select() -> void:
	current_state = GameState.DIFFICULTY_SELECT
	Events.show_difficulty_select.emit()

func _on_difficulty_selected(difficulty: int) -> void:
	Globals.set_difficulty(difficulty as Globals.Difficulty)
	start_game()

func start_game() -> void:
	Globals.reset_stats()
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
			pass  # Shop is UI-driven, no processing needed

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

	# Start enemy spawning
	if enemy_spawner:
		enemy_spawner.start_spawning(Globals.current_wave)

	# Start tech drop spawning
	if tech_drop_spawner and tech_drop_spawner.has_method("start_spawning"):
		tech_drop_spawner.start_spawning(Globals.current_wave)

func process_combat(delta: float) -> void:
	wave_timer -= delta
	Events.wave_timer_updated.emit(wave_timer)

	# Update spawn rate based on remaining time
	if enemy_spawner and enemy_spawner.has_method("update_spawn_rate"):
		enemy_spawner.update_spawn_rate(wave_timer)

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
	var turret_mgr = get_node_or_null("../TurretManager")
	if turret_mgr and turret_mgr.has_method("spawn_pending_turrets"):
		turret_mgr.spawn_pending_turrets()

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

func restart_game() -> void:
	get_tree().reload_current_scene()
