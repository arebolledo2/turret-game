extends Node

## Every acquired frame raises the next price; modifier-adjusted scaling applies to the entire surcharge.
const PROGRESSION_BASE_MULTIPLIER: float = 1.0
const PROGRESSION_LINEAR: float = .50
const PROGRESSION_MODIFIER_BASE: float = .65
const PROGRESSION_QUADRATIC: float = .20

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
var current_shop_offers: Array[ShopOffer]:
	get: return state.current_shop_offers
	set(value): state.current_shop_offers = value

# Turret purchase tracking (for price penalty calculation)
var turrets_purchased: int:
	get: return state.turrets_purchased
	set(value): state.turrets_purchased = value


func reset_state() -> void:
	total_scrap = GameConstants.STARTING_SCRAP
	shop_reroll_count = 0
	current_shop_offers.clear()
	turrets_purchased = 0
	state.additional_turrets_acquired = 0


## Calculate reroll cost based on current reroll count, wave, and modifiers
func get_reroll_cost(wave: int, reroll_cost_multiplier: float) -> int:
	# Wave-based base cost: wave × 1.5
	var wave_base_cost := wave * GameConstants.REROLL_WAVE_BASE_MULTIPLIER
	# Add increment for each reroll this wave
	var total_cost := wave_base_cost + shop_reroll_count * GameConstants.REROLL_COST_INCREMENT
	return int(total_cost * reroll_cost_multiplier)


## Authoritative base payout: SCRAP_WAVE_BONUS_BASE plus SCRAP_WAVE_BONUS_PER_WAVE for each wave number.
func get_wave_scrap_base(wave: int) -> int:
	return GameConstants.SCRAP_WAVE_BONUS_BASE + maxi(wave, 0) * GameConstants.SCRAP_WAVE_BONUS_PER_WAVE


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


## Shared pricing policy for both world presentations.
func calculate_turret_price(base_price: int, wave: int) -> int:
	# Legacy economy counts paid purchases; progression counts every additional frame.
	var wave_multiplier: float = 1.0 + GameConstants.WAVE_PRICE_SCALE * wave
	var penalty_per_turret: float = TurretStatsService.get_turret_purchase_penalty()
	var penalty_multiplier: float = 1.0 + penalty_per_turret * turrets_purchased
	var base_multiplier := 1.0
	if state.turret_progression_enabled:
		base_multiplier = PROGRESSION_BASE_MULTIPLIER
		# The first purchase is at base price; each acquisition after it adds to the surcharge.
		var excess := state.additional_turrets_acquired
		var linear := TurretStatsService.get_turret_purchase_penalty(PROGRESSION_MODIFIER_BASE)
		# Scale the entire surcharge so reduction items never hit a hidden floor.
		penalty_multiplier = 1.0 + (PROGRESSION_LINEAR * excess + PROGRESSION_QUADRATIC * excess * excess) * (linear / PROGRESSION_MODIFIER_BASE)
	var shop_price_mult: float = ItemTrackingService.get_shop_price_multiplier()
	# Avoid flooring an exact integer one scrap low due to binary decimal error.
	var price: int = floori(base_price * base_multiplier * wave_multiplier * penalty_multiplier * shop_price_mult + (0.0000001 if state.turret_progression_enabled else 0.0))

	return maxi(1, price) if state.turret_progression_enabled else price


func calculate_item_price(base_price: int, wave: int, _item_id: String = "") -> int:
	var price := base_price * (1.0 + GameConstants.WAVE_PRICE_SCALE * wave)

	# Apply shop price multiplier from items
	var shop_price_mult: float = ItemTrackingService.get_shop_price_multiplier()
	price *= shop_price_mult

	return int(price)
