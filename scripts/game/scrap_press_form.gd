class_name ScrapPressForm
extends TurretForm

## Scrap Press / Coin Feeder / Treasury / Academy: the turret that does not attack. One class serves the unevolved press and its
## three forms; the rows in `TurretForms` only change numbers. While combat runs it makes a drop every `1 / fire_rate` seconds
## (the stat, so level speed bonuses quicken it) worth `ScrapIncome.drop_value(wave)` scrap, and sends it down the exits of
## engine piece S5 (`ScrapIncome`):
##   Scrap Press  all of it as a pickup within `range` of the press (the stat; 1.5 m), for the hero to collect or, left at wave
##                end, for salvage to turn into XP for the turrets nearest it.
##   Coin Feeder  `deposit_share` (half) straight to the wallet, the rest as a pickup.
##   Treasury     all of it to the wallet, output +25% (a faster rate), and wave-end interest (`wave_end_scrap`): one scrap per
##                `interest_per` held, at most `interest_cap`.
##   Academy      none of it as scrap: `xp_radius` metres around the press, every turret gains the drop's value as XP.
## A second press keeps 60% of its output and a third 40% (`ScrapIncome.stack_yield`): the share scales the rate and the interest.
## The rank is the number of placed presses with a lower turret id, refreshed with the stats (four times a second), so nothing
## scans the world per tick. The press holds no node and no list: its only state is a charge toward the next drop and the
## fraction of a coin owed to the wallet, both dropped when combat stops, when the press is picked up and when it leaves.
const BURST_HEIGHT: float = .55
const ACADEMY_RING_SECONDS: float = .7

## Progress toward the next drop, in drops (1.0 releases one).
var charge: float = 0.0
## Wallet scrap owed from earlier drops that did not divide evenly (Coin Feeder alternates 0 and 1 on a one-scrap drop).
var carry: float = 0.0
## What this press has produced since it was made (tests and tools read them).
var drops_made: int = 0
var scrap_made: int = 0
var xp_given: int = 0
var _yield: float = 1.0

func deposit_share() -> float:
	return clampf(float(param("deposit_share", 0.0)), 0.0, 1.0)

## Metres around the press that Academy feeds; 0 for the forms that make scrap.
func xp_radius() -> float:
	return float(param("xp_radius", 0.0))

func makes_xp() -> bool:
	return xp_radius() > 0.0

## Seconds between drops at the current stats and stacking yield.
func drop_interval() -> float:
	var stats := actor._current_view(0.0)
	return 1.0 / maxf(stats.fire_rate * _yield, .001)

func current_yield() -> float:
	return _yield

func refresh_stats() -> void:
	_yield = _rank_yield()

## Share of its output this press keeps: 1 for the first press on the field, then 60%, then 40% (see `ScrapIncome.stack_yield`).
func _rank_yield() -> float:
	var world := actor.world
	if not world:
		return 1.0
	var rank := 0
	for other in world.turrets:
		if other != actor and is_instance_valid(other) and not other.carried and other.form is ScrapPressForm and other.turret_id < actor.turret_id:
			rank += 1
	return ScrapIncome.stack_yield(rank)

# --- Per tick ---

func tick(delta: float) -> void:
	if actor.carried:
		clear()
		return
	var stats := actor._current_view(0.0)
	charge += delta * stats.fire_rate * _yield
	# One drop per tick at most: a long hitch does not pay back a backlog.
	if charge >= 1.0:
		charge = fmod(charge, 1.0)
		_drop(stats)

func _drop(stats: TurretStats) -> void:
	var world := actor.world
	var income := world.scrap_income
	var value := ScrapIncome.drop_value(GameStateService.current_wave)
	drops_made += 1
	if makes_xp():
		var given := income.award_xp(income.turrets_near(actor.position, xp_radius()), value)
		xp_given += given
		world.effects.show_wave(actor.position, xp_radius(), xp_radius() / ACADEMY_RING_SECONDS, CombatEffects3D.SCRAP_PRESS_TINT)
		world.effects.show_burst(actor.position + Vector3(0, BURST_HEIGHT, 0), "scrap")
		return
	var share := deposit_share()
	carry += float(value) * share
	var cash := mini(floori(carry), value)
	carry -= float(cash)
	var floor_scrap := value - cash
	scrap_made += value
	if cash > 0:
		income.deposit(cash)
		world.effects.show_burst(actor.position + Vector3(0, BURST_HEIGHT, 0), "scrap")
	if floor_scrap > 0:
		income.lay_pickup(actor.position, stats.range_metres, floor_scrap)

## Treasury's interest, paid when the wave is won (see `ScrapIncome.pay_interest`).
func wave_end_scrap(held: int) -> int:
	var per := int(param("interest_per", 0))
	if per <= 0:
		return 0
	_yield = _rank_yield()
	return ScrapIncome.interest_for(held, per, int(param("interest_cap", 0)), _yield)

## Scrap in the drop it makes next (the same for every press; it rises with the wave).
func drop_value() -> int:
	return ScrapIncome.drop_value(GameStateService.current_wave)

# --- Lifecycle ---

## Combat stopped (wave end, pause, defeat) or the press was picked up: forget the half-made drop. Runs every idle frame, so it
## returns at once when clean.
func clear() -> void:
	if charge == 0.0 and carry == 0.0:
		return
	charge = 0.0
	carry = 0.0

## The press left the arena or took another form: the same, and there is nothing in the world to release.
func removed() -> void:
	clear()
