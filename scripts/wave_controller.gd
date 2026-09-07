extends Node

## Wave Controller
## Handles wave timing, progression, and spawning coordination
## Works with GameStateMachine for state transitions

signal wave_timer_tick(time_remaining: float)
signal wave_completed(wave_number: int)
signal spawning_started(wave_number: int)
signal spawning_stopped()

# Timers
var wave_timer: float = 0.0
var wave_max_duration: float = 0.0
var announcement_timer: float = 0.0
var pause_timer: float = 0.0

# Node references (set by GameManager)
var enemy_spawner: Node2D = null
var tech_drop_spawner: Node2D = null
var turret_manager: Node = null


func _ready() -> void:
	if not FeatureFlagService.flag_changed.is_connected(_on_feature_flag_changed):
		FeatureFlagService.flag_changed.connect(_on_feature_flag_changed)


func _on_feature_flag_changed(flag_id: String, enabled: bool) -> void:
	if not GameStateMachine.is_in_combat():
		return

	if flag_id == FeatureFlagService.ENEMY_SPAWNING and enemy_spawner:
		if enabled:
			enemy_spawner.start_spawning(GameStateService.current_wave)
		else:
			enemy_spawner.stop_spawning()
	elif flag_id == FeatureFlagService.TECH_DROPS and tech_drop_spawner:
		if enabled and tech_drop_spawner.has_method("start_spawning"):
			tech_drop_spawner.start_spawning(GameStateService.current_wave)
		elif not enabled and tech_drop_spawner.has_method("stop_spawning"):
			tech_drop_spawner.stop_spawning()


# =============================================================================
# WAVE ANNOUNCEMENT
# =============================================================================

func start_wave_announcement() -> void:
	GameStateService.current_wave += 1
	announcement_timer = GameConstants.WAVE_ANNOUNCEMENT_TIME

	Events.wave_announcement_started.emit(GameStateService.current_wave)
	Events.show_wave_announcement.emit(GameStateService.current_wave)


func process_announcement(delta: float) -> bool:
	"""Process announcement timer. Returns true when announcement is complete."""
	announcement_timer -= delta
	return announcement_timer <= 0


# =============================================================================
# COMBAT PHASE
# =============================================================================

func start_combat() -> void:
	wave_max_duration = get_wave_duration(GameStateService.current_wave)
	wave_timer = wave_max_duration

	Events.hide_wave_announcement.emit()
	Events.wave_started.emit(GameStateService.current_wave)

	# Start enemy spawning
	if enemy_spawner:
		enemy_spawner.start_spawning(GameStateService.current_wave)
		spawning_started.emit(GameStateService.current_wave)

	# Start tech drop spawning only when the feature is enabled.
	if FeatureFlagService.is_enabled(FeatureFlagService.TECH_DROPS) and tech_drop_spawner and tech_drop_spawner.has_method("start_spawning"):
		tech_drop_spawner.start_spawning(GameStateService.current_wave)
	elif tech_drop_spawner and tech_drop_spawner.has_method("stop_spawning"):
		tech_drop_spawner.stop_spawning()


func process_combat(delta: float) -> bool:
	"""Process combat timer. Returns true when wave time is up."""
	wave_timer -= delta
	Events.wave_timer_updated.emit(wave_timer)
	wave_timer_tick.emit(wave_timer)
	return wave_timer <= 0


func get_wave_progress() -> float:
	"""Returns normalized progress (0.0 to 1.0) of the current combat wave."""
	if wave_max_duration <= 0:
		return 0.0
	return clamp(1.0 - (wave_timer / wave_max_duration), 0.0, 1.0)


# =============================================================================
# WAVE END
# =============================================================================

func end_wave() -> void:
	pause_timer = GameConstants.BETWEEN_WAVE_PAUSE
	stop_spawning()
	Events.wave_ended.emit(GameStateService.current_wave)


func process_wave_end(delta: float) -> bool:
	"""Process end-of-wave pause. Returns true when pause is complete."""
	pause_timer -= delta
	if pause_timer <= 0:
		# Convert uncollected scrap to research points before transitioning
		_convert_scrap_to_research()
		return true
	return false


func award_wave_bonus() -> void:
	"""Award scrap for completing the wave."""
	var wave_bonus_base = EconomyService.get_wave_scrap_base(GameStateService.current_wave)

	# Use probabilistic addition for consistency (though less critical for large numbers)
	var wave_bonus = EconomyService.add_scrap_probabilistic(wave_bonus_base, ItemTrackingService.get_wave_bonus_multiplier())
	Events.scrap_collected.emit(wave_bonus, EconomyService.total_scrap)
	wave_completed.emit(GameStateService.current_wave)


func stop_spawning() -> void:
	"""Stop all spawning."""
	if enemy_spawner:
		enemy_spawner.stop_spawning()

	if tech_drop_spawner and tech_drop_spawner.has_method("stop_spawning"):
		tech_drop_spawner.stop_spawning()

	spawning_stopped.emit()


func _convert_scrap_to_research() -> void:
	"""Convert all uncollected scrap on the ground to research points."""
	var scrap_drops = get_tree().get_nodes_in_group("pickups")
	var total_scrap_value: int = 0

	# Count all uncollected scrap
	for drop in scrap_drops:
		if is_instance_valid(drop) and "scrap_value" in drop:
			total_scrap_value += drop.scrap_value

	# Apply conversion (base 1:1 ratio, modifiable by items/techs)
	if total_scrap_value > 0:
		var conversion_ratio: float = ItemTrackingService.get_research_conversion_multiplier()
		var research_gained: int = int(total_scrap_value * conversion_ratio)

		TechTreeService.add_research_points(research_gained)
		Events.research_points_gained.emit(research_gained, TechTreeService.total_research_points)

		DebugService.log(DebugService.SYSTEMS, "Converted ", total_scrap_value, " scrap to ", research_gained, " research (ratio: ", conversion_ratio, ")")

		# Despawn scrap drops with animation
		for drop in scrap_drops:
			if is_instance_valid(drop):
				_despawn_scrap_drop(drop)


func _despawn_scrap_drop(drop: Node2D) -> void:
	"""Animate and despawn a scrap drop."""
	# Create upward float and fade animation
	var tween = drop.create_tween()
	tween.set_parallel(true)
	tween.tween_property(drop, "position:y", drop.position.y - 100, 0.5)
	tween.tween_property(drop, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(drop.queue_free)


# =============================================================================
# WAVE STATE RESET
# =============================================================================

func reset_wave_state() -> void:
	"""Clear enemies and reset player for next wave."""
	# Clear all enemies
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()

	# Clear all tech drops
	if tech_drop_spawner and tech_drop_spawner.has_method("clear_all_drops"):
		tech_drop_spawner.clear_all_drops()

	# Reset player health
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("reset_health"):
		player.reset_health()


# =============================================================================
# WAVE CALCULATIONS
# =============================================================================

func get_wave_duration(wave: int) -> float:
	return GameStateService.get_wave_duration(wave)


func is_final_wave() -> bool:
	return GameStateService.current_wave >= GameConstants.MAX_WAVES


func get_current_wave() -> int:
	return GameStateService.current_wave
