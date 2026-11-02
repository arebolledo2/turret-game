class_name TurretRoster
extends RefCounted

## Adding turrets to and removing them from a run: ids, progression records, purchase counters and the per-type counts.
## `ArenaWorld` owns the `turrets` list and exposes `add_turret` / `remove_turret` as forwards to this.
var world: ArenaWorld
var _next_id: int = 1

func reset() -> void:
	_next_id = 1

## `level` and `form` place a turret that arrives already grown (a shop purchase); `value_basis` is what its level 1 self
## cost, or -1 for the type's base price.
func add(at: Vector3, type_id: String, starting: bool, level: int, form: String, value_basis: int) -> TurretActor:
	var turret := TurretActor.new()
	turret.world = world
	turret.turret_type = type_id
	turret.turret_id = _next_id
	_next_id += 1
	if level > 1:
		turret.progression.start_at(level, form)
	turret.value_basis = TurretRegistry.get_base_price(type_id) if value_basis < 0 else value_basis
	turret.raised_prices = not starting
	world.session.state.turret_progression[turret.turret_id] = turret.progression
	if not starting:
		world.session.state.additional_turrets_acquired += 1
	turret.position = at
	world.actor_root.add_child(turret)
	turret.reset_physics_interpolation()
	world.turrets.append(turret)
	TurretStatsService.turret_counts[type_id] = int(TurretStatsService.turret_counts.get(type_id, 0)) + 1
	GameStateService.turrets_spawned = world.turrets.size()
	return turret

## Takes a turret out of the run (a sale). Leaving the tree runs the form's `removed`, which clears its mines, drones and beams.
func remove(turret: TurretActor) -> void:
	if world.placement.carried == turret:
		world.placement.carried = null
	world.turrets.erase(turret)
	world.session.state.turret_progression.erase(turret.turret_id)
	var count := int(TurretStatsService.turret_counts.get(turret.turret_type, 0)) - 1
	if count > 0:
		TurretStatsService.turret_counts[turret.turret_type] = count
	else:
		TurretStatsService.turret_counts.erase(turret.turret_type)
	if turret.raised_prices:
		world.session.state.additional_turrets_acquired = maxi(0, world.session.state.additional_turrets_acquired - 1)
	GameStateService.turrets_spawned = world.turrets.size()
	world.deployables.clear_owner(turret.turret_id)
	world.drones.clear_owner(turret.turret_id)
	world.actor_root.remove_child(turret)
	turret.queue_free()
