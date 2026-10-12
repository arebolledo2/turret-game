class_name DevCommands
extends RefCounted

## Developer commands (dev panel and tests). None of these are reachable from normal play.
## Acts on the `ArenaWorld` that owns it.
var world: ArenaWorld

func add_scrap(amount: int) -> bool:
	EconomyService.total_scrap = maxi(0, EconomyService.total_scrap + amount)
	return true

func restore_hull() -> bool:
	if not is_instance_valid(world.player) or not GameStateService.is_game_active:
		return false
	world.player.health = world.player.max_health
	if world.core:
		world.core.reset(world.core.max_health)
	return true

func spawn_enemy(type_id: String, count: int = 1) -> int:
	if not is_instance_valid(world.player) or not GameStateService.is_game_active or not EnemyRegistry.TYPES.has(type_id):
		return 0
	for index in count:
		world.spawn_enemy(world.waves.spawn_position(), type_id)
	return count

## Defeats every living enemy through the normal damage path, so drops and telemetry behave as usual.
func kill_all_enemies() -> int:
	var was_paused := world.paused
	world.paused = false
	var killed := 0
	for enemy in world.enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.dead and world.combat.apply_hit(enemy, CombatHit3D.new(enemy.health + 1.0, enemy.position)) > 0.0:
			killed += 1
	world.paused = was_paused
	return killed

## Lands in the shop that precedes `target_wave` (deploy to start it). Clears the field without rewards.
func jump_to_wave(target_wave: int) -> bool:
	if not GameStateService.is_game_active or GameStateMachine.current_state not in [GameStateMachine.GameState.PREPARATION, GameStateMachine.GameState.WAVE_ANNOUNCEMENT,
			GameStateMachine.GameState.COMBAT, GameStateMachine.GameState.SHOP]:
		return false
	target_wave = clampi(target_wave, 1, world.wave_limit)
	world.clear_field(false)
	GameStateService.current_wave = target_wave - 1
	GameStateMachine.force_transition(GameStateMachine.GameState.SHOP)
	world.shop.open()
	world.message = "Dev: ready to deploy wave %d." % target_wave
	return true

## Deploys the next wave immediately when the shop is open.
func skip_shop() -> bool:
	return GameStateMachine.current_state == GameStateMachine.GameState.SHOP and world.begin_next_wave()

