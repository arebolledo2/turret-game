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

## Places a free turret of a shop-stocked type beside the hero. Returns its id, or 0 if unavailable.
## It counts as a starter, so it leaves the purchase-price ladder alone.
func add_turret(type_id: String) -> int:
	if not is_instance_valid(world.player) or not GameStateService.is_game_active or not ShopCatalog.ids("turret").has(type_id):
		return 0
	var angle := float(world.turrets.size()) * 2.4
	var at := world.player.position + Vector3(sin(angle), 0.0, cos(angle)) * 2.0
	return world.add_turret(at, type_id, true).turret_id

## Awards exactly the XP for `levels` more levels through the normal progression path.
## Evolution milestones still queue and resolve in the shop like earned ones.
func level_up_turret(turret_id: int, levels: int = 1) -> bool:
	var turret := _find_turret(turret_id)
	if not turret or not world.session.state.turret_progression_enabled or levels < 1:
		return false
	var growth := turret.progression
	var target := growth.level + levels
	while growth.level < target:
		growth.award(TurretProgression.cost_to_next(growth.level) - growth.xp)
	turret.invalidate_stats()
	return true

## Levels a turret up to its next unspent evolution milestone (5/10/15), if one remains.
func level_up_to_milestone(turret_id: int) -> bool:
	var turret := _find_turret(turret_id)
	if not turret:
		return false
	var growth := turret.progression
	for milestone: int in TurretProgression.EVOLUTION_LEVELS:
		if milestone > growth.level and milestone not in growth.pending_evolutions:
			return level_up_turret(turret_id, milestone - growth.level)
	return false

func _find_turret(turret_id: int) -> TurretActor:
	for turret in world.turrets:
		if is_instance_valid(turret) and turret.turret_id == turret_id:
			return turret
	return null

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

