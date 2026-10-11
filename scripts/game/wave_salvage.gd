class_name WaveSalvage
extends RefCounted

## Synchronous wave-end transaction. The ledger contains values, never live actor references,
## so future animation can replay an already committed award without deciding rewards itself.
var world: ArenaWorld
var rng := RandomNumberGenerator.new()
var settlements: Dictionary = {}
var last_settlement: Dictionary = {}

func reset(run_seed: int) -> void:
	rng.seed = run_seed ^ 0x585053414C
	settlements.clear()
	last_settlement = {}

static func weight(from: Vector3, to: Vector3) -> float:
	var distance_squared := WorldGeometry.planar(from - to).length_squared()
	return .15 + 1.0 / (1.0 + distance_squared / 16.0)

func settle(wave: int) -> bool:
	if not world.session.state.turret_progression_enabled or settlements.has(wave):
		return false
	if not GameStateService.is_game_active or GameStateMachine.current_state != GameStateMachine.GameState.WAVE_END:
		return false
	var recipients: Array[TurretActor] = []
	var targets: Array[Dictionary] = []
	for turret in world.turrets:
		if is_instance_valid(turret) and not turret.is_queued_for_deletion():
			recipients.append(turret)
			targets.append({"id": turret.turret_id, "position": turret.global_position, "carried": turret.carried})
	var entries: Array[Dictionary] = []
	var awards: Dictionary = {}
	var consumed: Array[ScrapPickup] = []
	var raw_scrap := 0
	for pickup: ScrapPickup in world.pickup_root.get_children():
		if pickup.collected or pickup.is_queued_for_deletion():
			continue
		var amount := maxi(0, pickup.amount)
		var allocations: Dictionary = {}
		var weights: Array[float] = []
		var total_weight := 0.0
		for target in targets:
			var value := weight(pickup.global_position, target["position"])
			weights.append(value)
			total_weight += value
		if not targets.is_empty():
			for unit in amount:
				var roll := rng.randf() * total_weight
				var index := targets.size() - 1
				for candidate in weights.size():
					roll -= weights[candidate]
					if roll < 0.0:
						index = candidate
						break
				var id: int = targets[index]["id"]
				allocations[id] = int(allocations.get(id, 0)) + 1
				awards[id] = int(awards.get(id, 0)) + 1
		entries.append({"position": pickup.global_position, "amount": amount, "allocations": allocations})
		consumed.append(pickup)
		raw_scrap += amount
	# Reserve the wave and consume pickups before any currency/notification calls.
	var ledger := {"wave": wave, "raw_scrap": raw_scrap, "xp_awarded": 0,
		"fallback_cash": 0, "targets": targets, "pickups": entries, "changes": {}}
	settlements[wave] = ledger
	last_settlement = ledger
	for pickup in consumed:
		pickup.collected = true
		pickup.queue_free()
	for turret in recipients:
		var amount := int(awards.get(turret.turret_id, 0))
		if amount > 0:
			ledger["changes"][turret.turret_id] = turret.progression.award(amount)
			turret.cached_stats.clear()
			ledger["xp_awarded"] += amount
	if recipients.is_empty() and raw_scrap > 0:
		var before := EconomyService.total_scrap
		world.collect_scrap(raw_scrap)
		ledger["fallback_cash"] = EconomyService.total_scrap - before
	world.telemetry.record_salvage(ledger)
	return true
