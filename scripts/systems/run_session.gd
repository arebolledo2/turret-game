class_name RunSession
extends Node

## Composition root for one run's state and references. Preferences remain app-wide.
var state: RunSessionState = RunSessionState.new()

func begin_run() -> void:
	state = RunSessionState.new()
	# Starting settings have already selected the announcement transition's origin.
	state.phase = GameStateMachine.current_state
	bind_state(state)
	EnemyQuery.reset_state()
	ProjectilePool.reset_state()
	OffScreenIndicatorService.tracked_entities.clear()
	Events.modifiers_changed.emit()

static func bind_state(value: RunSessionState) -> void:
	GameStateService.state = value
	GameStateMachine.state = value
	EconomyService.state = value
	PlayerStatsService.state = value
	TurretStatsService.state = value
	ItemTrackingService.state = value
	LootService.state = value
	TechTreeService.state = value
	ModifierService.state = value
	BuffSystem.state = value

func _exit_tree() -> void:
	if GameStateService.state != state:
		return # A newer scene already owns the services.
	bind_state(RunSessionState.new())
	GameStateService.wave_controller = null
	SpecialEffectService.set_turret_manager(null)
	BuffSystem.set_turret_manager(null)
	OffScreenIndicatorService.set_enemy_spawner(null)
	OffScreenIndicatorService.tracked_entities.clear()
	EnemyQuery.reset_state()
	ProjectilePool.reset_state()
