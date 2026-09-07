extends Node

var state: RunSessionState = RunSessionState.new()

var rng: RandomNumberGenerator = GameRandom.gameplay

## Economy Service
## Manages scrap, shop offers, rerolls, and turret purchases

# Scrap tracking
var total_scrap: int:
	get: return state.total_scrap
	set(value): state.total_scrap = value

# Shop system
var shop_reroll_count: int:
	get: return state.shop_reroll_count
	set(value): state.shop_reroll_count = value
var current_shop_offers: Array:
	get: return state.current_shop_offers
	set(value): state.current_shop_offers = value
var pending_turret_purchases: Array[String]:
	get: return state.pending_turret_purchases
	set(value): state.pending_turret_purchases = value

# Turret purchase tracking (for price penalty calculation)
var turrets_purchased: int:
	get: return state.turrets_purchased
	set(value): state.turrets_purchased = value


func reset_state() -> void:
	total_scrap = GameConstants.STARTING_SCRAP
	shop_reroll_count = 0
	current_shop_offers.clear()
	pending_turret_purchases.clear()
	turrets_purchased = 0


## Calculate reroll cost based on current reroll count, wave, and modifiers
func get_reroll_cost(wave: int, reroll_cost_multiplier: float) -> int:
	# Wave-based base cost: wave Ã— 1.5
	var wave_base_cost := wave * GameConstants.REROLL_WAVE_BASE_MULTIPLIER
	# Add increment for each reroll this wave
	var total_cost := wave_base_cost + shop_reroll_count * GameConstants.REROLL_COST_INCREMENT
	return int(total_cost * reroll_cost_multiplier)


## Authoritative base payout. Wave 1 awards 5 scrap; each wave adds 5.
func get_wave_scrap_base(wave: int) -> int:
	return GameConstants.SCRAP_WAVE_BONUS_BASE + maxi(wave, 0) * 5


## Calculate wave completion scrap bonus
func get_wave_scrap_bonus(wave: int, wave_bonus_mult: float) -> int:
	var base_bonus := get_wave_scrap_base(wave)
	return int(base_bonus * wave_bonus_mult)


## Add scrap with multiplier applied using probabilistic rounding for fractional amounts
## returns the actual amount added
func add_scrap_probabilistic(base_amount: int, multiplier: float) -> int:
	var calculated: float = float(base_amount) * multiplier
	var actual_amount: int = floori(calculated)
	var chance: float = calculated - actual_amount

	if rng.randf() < chance:
		actual_amount += 1

	total_scrap += actual_amount
	return actual_amount


## Add scrap with multiplier applied (Legacy - prefer add_scrap_probabilistic)
func add_scrap(amount: int, scrap_earn_mult: float) -> void:
	add_scrap_probabilistic(amount, scrap_earn_mult)


## Deduct scrap (returns true if successful, false if insufficient funds)
func deduct_scrap(amount: int) -> bool:
	if total_scrap >= amount:
		total_scrap -= amount
		return true
	return false
