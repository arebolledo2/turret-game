class_name RunOutcome
extends RefCounted

## How a run ends and what the hero and core carry between waves: core health, damage to the core, defeat and the free heal.
## `ArenaWorld` exposes these as forwards to this.
var world: ArenaWorld

func core_max_health() -> float:
	return GameConstants.PLAYER_BASE_MAX_HEALTH * GameConstants.CORE_HEALTH_MULT * float(world.difficulty_config.get("core_health_mult", 1.0))

## Enemy contact and blasts land here. Ends the run when the core falls.
func damage_core(amount: float) -> void:
	var core := world.core
	if not core or core.dead or world.god_mode or not world.is_combat():
		return
	var applied := core.take_hit(amount)
	if applied > 0.0:
		world.effects.damage_numbers.show_damage(core, applied, true)
		world.audio.play_cue("hull", core.position)
		if core.dead:
			end_in_defeat("CORE DESTROYED")

func end_in_defeat(reason: String) -> void:
	world.defeat_reason = reason
	world.audio.reset()
	world.audio.play_cue("defeat", world.player.position)
	GameStateService.is_game_active = false
	GameStateMachine.transition_to(GameStateMachine.GameState.GAME_OVER)
	world.effects.reset(true)
	world.ground_zones.clear()
	world.deployables.clear()
	world.drones.clear()
	for enemy in world.enemies:
		enemy.clear_transients()
	for projectile in world.projectiles:
		projectile.release()

## Between waves the hero and the core are fully healed for free.
func heal_between_waves() -> void:
	var player := world.player
	var core := world.core
	if is_instance_valid(player) and not player.dead: player.health = player.max_health
	if is_instance_valid(core) and not core.dead: core.repair(core.max_health)
