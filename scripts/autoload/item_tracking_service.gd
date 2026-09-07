extends Node

var state: RunSessionState = RunSessionState.new()

## Item Tracking Service
## Manages collected items and provides modifier-related queries

# Item tracking
var collected_items: Array[String]:
	get: return state.collected_items
	set(value): state.collected_items = value
var item_counts: Dictionary:
	get: return state.item_counts
	set(value): state.item_counts = value

func reset_state() -> void:
	collected_items.clear()
	item_counts.clear()


## Get reroll cost multiplier (from items like Probability Matrix)
func get_reroll_cost_multiplier() -> float:
	return ModifierService.apply_modifiers_to_stat(1.0, "reroll_cost")


## Get scrap earn multiplier (from items like Salvage Optimizer)
func get_scrap_earn_multiplier() -> float:
	return ModifierService.apply_modifiers_to_stat(1.0, "scrap_earn_mult")


## Get enemy count multiplier (from items like Combat Surplus)
func get_enemy_count_multiplier() -> float:
	return ModifierService.apply_modifiers_to_stat(1.0, "enemy_count_mult")


## Get shop price multiplier (from items like Quality Over Quantity)
func get_shop_price_multiplier() -> float:
	return ModifierService.apply_modifiers_to_stat(1.0, "shop_price_mult")


## Get wave completion bonus multiplier (from items like War Profiteer)
func get_wave_bonus_multiplier() -> float:
	return ModifierService.apply_modifiers_to_stat(1.0, "wave_bonus_mult")


## Get research conversion multiplier (scrap to research points)
func get_research_conversion_multiplier() -> float:
	return ModifierService.apply_modifiers_to_stat(1.0, "research_conversion_mult")


## Get shop offer count (from items like Bargain Hunter)
func get_shop_offer_count() -> int:
	return int(ModifierService.apply_modifiers_to_stat(float(GameConstants.SHOP_OFFER_COUNT), "shop_offer_count"))
