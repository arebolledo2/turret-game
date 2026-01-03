extends Node

## Economy Service
## Manages gold, shop offers, rerolls, and turret purchases

# Gold tracking
var total_gold: int = 0

# Shop system
var shop_reroll_count: int = 0
var current_shop_offers: Array = []
var pending_turret_purchases: Array[String] = []

# Turret purchase tracking (for price penalty calculation)
var turrets_purchased: int = 0


func reset_state() -> void:
	total_gold = GameConstants.STARTING_GOLD
	shop_reroll_count = 0
	current_shop_offers.clear()
	pending_turret_purchases.clear()
	turrets_purchased = 0


## Calculate reroll cost based on current reroll count, wave, and modifiers
func get_reroll_cost(wave: int, reroll_cost_multiplier: float) -> int:
	# Wave-based base cost: wave × 1.5
	var wave_base_cost := wave * GameConstants.REROLL_WAVE_BASE_MULTIPLIER
	# Add increment for each reroll this wave
	var total_cost := wave_base_cost + shop_reroll_count * GameConstants.REROLL_COST_INCREMENT
	return int(total_cost * reroll_cost_multiplier)


## Calculate wave completion gold bonus
func get_wave_gold_bonus(wave: int, wave_bonus_mult: float) -> int:
	var base_bonus := GameConstants.GOLD_WAVE_BONUS_BASE + (wave - 1) * 5
	return int(base_bonus * wave_bonus_mult)


## Add gold with multiplier applied using probabilistic rounding for fractional amounts
## returns the actual amount added
func add_gold_probabilistic(base_amount: int, multiplier: float) -> int:
	var calculated: float = float(base_amount) * multiplier
	var actual_amount: int = floori(calculated)
	var chance: float = calculated - actual_amount
	
	if randf() < chance:
		actual_amount += 1
		
	total_gold += actual_amount
	return actual_amount


## Add gold with multiplier applied (Legacy - prefer add_gold_probabilistic)
func add_gold(amount: int, gold_earn_mult: float) -> void:
	add_gold_probabilistic(amount, gold_earn_mult)


## Deduct gold (returns true if successful, false if insufficient funds)
func deduct_gold(amount: int) -> bool:
	if total_gold >= amount:
		total_gold -= amount
		return true
	return false
