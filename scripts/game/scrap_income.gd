class_name ScrapIncome
extends RefCounted

## Engine piece S5: scrap that does not come from a kill. The Scrap Press (`ScrapPressForm`) makes it on a timer; this class
## is where that scrap goes, so a second income turret reuses it instead of reimplementing the three exits:
##   pickup   a real `ScrapPickup` on the floor, collected by the hero or, left at wave end, turned into XP by `WaveSalvage`
##            (so it is also counted in the wave's drops and in the abandoned share, exactly like scrap from a kill);
##   cash     `deposit`, straight to the wallet through `ArenaWorld.collect_scrap`, so earn-multiplier items apply;
##   XP       `award_xp`, straight to turrets' progression. `WaveSalvage` keeps the tally and folds it into that wave's
##            settlement ledger, so the wave-end report and telemetry show it next to the salvage XP.
## It owns no live nodes and no timers (the press owns its own), only run counters, so there is nothing to clean up on
## pause, wave end or turret removal. The pickups it spawns are cleared with the field; the direct-XP tally is consumed
## by `WaveSalvage.settle` and dropped by `ArenaWorld.clear_field` and on a new run.
var world: ArenaWorld
var rng := RandomNumberGenerator.new()
## Run counters (tests, telemetry and tools read them): wallet scrap added directly, pickups laid, direct XP handed out.
var cash_deposited: int = 0
var pickups_laid: int = 0
var xp_awarded: int = 0

func reset(run_seed: int) -> void:
	rng.seed = run_seed ^ 0x53435250
	cash_deposited = 0
	pickups_laid = 0
	xp_awarded = 0

## Scrap in one press drop on `wave`: 1 for the first few waves, then one more every `SCRAP_PRESS_WAVES_PER_STEP`.
static func drop_value(wave: int) -> int:
	return 1 + floori(float(maxi(wave - 1, 0)) / float(GameConstants.SCRAP_PRESS_WAVES_PER_STEP))

## How much of its output the press at `rank` (0 for the first on the field) keeps: a second press yields 60%, a third 40%,
## and any later one stays at 40%.
static func stack_yield(rank: int) -> float:
	var table := GameConstants.SCRAP_PRESS_STACK_YIELD
	return table[clampi(rank, 0, table.size() - 1)]

## Interest on `held` scrap: one per `per` held, at most `cap`, scaled by `share` and rounded.
static func interest_for(held: int, per: int, cap: int, share: float) -> int:
	if per <= 0 or held <= 0:
		return 0
	return roundi(float(mini(floori(float(held) / float(per)), cap)) * share)

## Wallet scrap, straight in (the earn multiplier applies, as for picked-up scrap). Returns what the wallet gained.
func deposit(amount: int) -> int:
	if amount <= 0:
		return 0
	var before := EconomyService.total_scrap
	world.collect_scrap(amount)
	var gained := EconomyService.total_scrap - before
	cash_deposited += gained
	return gained

## Lays `amount` scrap on the floor within `reach` metres of `around`, kept inside the arena. `clearance` is a ring round `around`
## that stays empty (the turret's own body); a reach inside it is stretched to just beyond it.
func lay_pickup(around: Vector3, reach: float, amount: int, clearance: float = 0.0) -> ScrapPickup:
	if amount <= 0:
		return null
	var angle := rng.randf() * TAU
	var outer := maxf(reach, clearance + .3)
	# Uniform over the ring's area: lerp the squared radii.
	var distance := sqrt(lerpf(clearance * clearance, outer * outer, rng.randf()))
	var at := WorldGeometry.clamp_position(around + Vector3(cos(angle), 0.0, sin(angle)) * distance)
	pickups_laid += 1
	return world.spawn_scrap_pickup(at, amount)

## `amount` XP straight to each of `recipients` (full value each). Needs turret progression; returns the XP handed out in all.
func award_xp(recipients: Array[TurretActor], amount: int) -> int:
	if amount <= 0 or not world.session.state.turret_progression_enabled:
		return 0
	var total := 0
	for turret in recipients:
		if is_instance_valid(turret) and not turret.is_queued_for_deletion():
			world.salvage.award_direct(turret, amount)
			total += amount
	xp_awarded += total
	return total

## Turrets within `radius` metres of `centre` that can take XP: placed, not queued for deletion. The caller's own turret counts.
func turrets_near(centre: Vector3, radius: float) -> Array[TurretActor]:
	var result: Array[TurretActor] = []
	var limit := radius * radius
	for turret in world.turrets:
		if is_instance_valid(turret) and not turret.carried and not turret.is_queued_for_deletion() \
				and WorldGeometry.planar(turret.position - centre).length_squared() <= limit:
			result.append(turret)
	return result

## Wave-end scrap from every placed turret whose form pays some (`TurretForm.wave_end_scrap`: the Treasury's interest).
## Called once from `WaveDirector.finish_wave`, after the wave bonus, so the held total includes it. Returns what the wallet gained.
func pay_interest() -> int:
	var held := EconomyService.total_scrap
	var total := 0
	for turret in world.turrets:
		if is_instance_valid(turret) and not turret.carried and turret.form:
			total += turret.form.wave_end_scrap(held)
	return deposit(total)
