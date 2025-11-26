extends Node

enum GameState { IDLE, DIFFICULTY_SELECT, WAVE_ANNOUNCEMENT, COMBAT, WAVE_END, VICTORY, GAME_OVER }

var current_state: GameState = GameState.IDLE
var wave_timer: float = 0.0
var announcement_timer: float = 0.0
var pause_timer: float = 0.0

@onready var enemy_spawner: Node2D = get_node_or_null("../EnemySpawner")
@onready var turret_manager: Node = get_node_or_null("../TurretManager")

func _ready() -> void:
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
	start_wave_announcement()

func _process(delta: float) -> void:
	if not Globals.is_game_active:
		return
	
	Globals.time_survived += delta
	
	match current_state:
		GameState.WAVE_ANNOUNCEMENT:
			process_announcement(delta)
		GameState.COMBAT:
			process_combat(delta)
		GameState.WAVE_END:
			process_wave_end(delta)

func start_wave_announcement() -> void:
	Globals.current_wave += 1
	current_state = GameState.WAVE_ANNOUNCEMENT
	announcement_timer = Globals.WAVE_ANNOUNCEMENT_TIME
	
	# Emit announcement signal for UI
	Events.wave_announcement_started.emit(Globals.current_wave)
	Events.show_wave_announcement.emit(Globals.current_wave)
	
	# Spawn turret (except wave 1 - player starts with nothing)
	if turret_manager and Globals.current_wave >= 1:
		turret_manager.spawn_turret()

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

func process_combat(delta: float) -> void:
	wave_timer -= delta
	Events.wave_timer_updated.emit(wave_timer)
	
	if wave_timer <= 0:
		end_wave()

func end_wave() -> void:
	current_state = GameState.WAVE_END
	pause_timer = Globals.BETWEEN_WAVE_PAUSE
	
	# Stop spawning
	if enemy_spawner:
		enemy_spawner.stop_spawning()
	
	Events.wave_ended.emit(Globals.current_wave)
	
	# Check for victory
	if Globals.current_wave >= Globals.MAX_WAVES:
		trigger_victory()

func process_wave_end(delta: float) -> void:
	pause_timer -= delta
	if pause_timer <= 0:
		start_wave_announcement()

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
	
	Events.game_over.emit(false)

func restart_game() -> void:
	get_tree().reload_current_scene()

