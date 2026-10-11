class_name RunSession
extends Node

## Composition root for one run's state and references. Preferences remain app-wide.
var state: RunSessionState = RunSessionState.new()

func begin_run() -> void:
	state = RunSessionState.new()
	state.turret_progression_enabled = FeatureFlagService.is_enabled(FeatureFlagService.TURRET_PROGRESSION)
	# Starting settings have already selected the announcement transition's origin.
	state.phase = GameStateMachine.current_state
	bind_state(state)
	Events.modifiers_changed.emit()

static func bind_state(value: RunSessionState) -> void:
	GameStateService.state = value
	GameStateMachine.state = value
	EconomyService.state = value
	PlayerStatsService.state = value
	TurretStatsService.state = value
	ItemTrackingService.state = value
	TechTreeService.state = value
	ModifierService.state = value

func _exit_tree() -> void:
	if GameStateService.state != state:
		return # A newer scene already owns the services.
	bind_state(RunSessionState.new())
