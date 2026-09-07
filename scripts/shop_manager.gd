extends Node

var rng: RandomNumberGenerator = GameRandom.gameplay

# Session-level duplicate tracking (persists across rerolls)
var _session_turret_types: Array[String] = []
var _session_item_ids: Array[String] = []

func _ready() -> void:
	Events.shop_opened.connect(_on_shop_opened)
	Events.shop_closed.connect(_on_shop_closed)

func _on_shop_opened(_wave_number: int) -> void:
	_session_turret_types.clear()
	_session_item_ids.clear()
	generate_offers()

func _on_shop_closed() -> void:
	_session_turret_types.clear()
	_session_item_ids.clear()

func generate_offers() -> void:
	# Preserve locked offers before clearing
	var locked_offers: Array = []
	for offer in EconomyService.current_shop_offers:
		if offer.get("locked", false) and not offer.get("sold", false):
			locked_offers.append(offer)

	# Extract locked item and turret IDs
	var locked_item_ids: Array[String] = []
	var locked_turret_ids: Array[String] = []
	for locked_offer in locked_offers:
		if locked_offer["type"] == "item":
			locked_item_ids.append(locked_offer["item_id"])
		elif locked_offer["type"] == "turret":
			locked_turret_ids.append(locked_offer["turret_id"])

	EconomyService.current_shop_offers.clear()

	# Track generated items/turrets in THIS generation
	var generated_item_ids: Array[String] = []
	var generated_turret_ids: Array[String] = []

	# Combine session-level + locked for full exclusion list
	var all_excluded_turrets = _session_turret_types + locked_turret_ids
	var all_excluded_items = _session_item_ids + locked_item_ids

	# Roll each slot: 65% item, 35% turret
	var base_offer_count = ItemTrackingService.get_shop_offer_count()
	var new_offer_count = base_offer_count - locked_offers.size()

	for i in range(new_offer_count):
		var roll: float = rng.randf()
		if roll < GameConstants.SHOP_ITEM_CHANCE:
			generate_item_offer(generated_item_ids, generated_turret_ids, all_excluded_items, all_excluded_turrets)
		else:
			# Try to generate turret, fall back to item if duplicate
			var success = generate_turret_offer(generated_turret_ids, all_excluded_turrets, generated_item_ids, all_excluded_items)
			if not success:
				# Turret was duplicate, generate item instead
				generate_item_offer(generated_item_ids, generated_turret_ids, all_excluded_items, all_excluded_turrets)

	# Merge locked offers back
	for locked_offer in locked_offers:
		EconomyService.current_shop_offers.append(locked_offer)

	Events.shop_offers_generated.emit(EconomyService.current_shop_offers)

func generate_turret_offer(
	generated_turret_ids: Array[String],
	excluded_turret_ids: Array[String],
	generated_item_ids: Array[String] = [],
	excluded_item_ids: Array[String] = []
) -> bool:
	"""Returns false if no unique turret available (caller should generate item instead)"""
	var turret_types: Array = TurretRegistry.get_all_type_ids()

	var all_excluded_turret_ids = generated_turret_ids + excluded_turret_ids

	# Filter out excluded turrets AND check tech unlocks
	var available_turrets: Array[String] = []
	for turret_id in turret_types:
		if turret_id not in all_excluded_turret_ids:
			if TechTreeService.is_turret_type_unlocked(turret_id):
				available_turrets.append(turret_id)

	# If no unique turrets available, return false
	if available_turrets.is_empty():
		return false

	var random_type: String = available_turrets[rng.randi() % available_turrets.size()]

	# Track in BOTH generation-level AND session-level
	generated_turret_ids.append(random_type)
	if random_type not in _session_turret_types:
		_session_turret_types.append(random_type)

	var base_price: int = TurretRegistry.get_base_price(random_type)
	var scaled_price: int = calculate_turret_price(base_price, GameStateService.current_wave)

	var offer: Dictionary = {
		"type": "turret",
		"turret_id": random_type,
		"price": scaled_price,
		"sold": false,
		"locked": false,
	}
	EconomyService.current_shop_offers.append(offer)
	return true

func generate_item_offer(
	generated_item_ids: Array[String],
	generated_turret_ids: Array[String],
	excluded_item_ids: Array[String] = [],
	excluded_turret_ids: Array[String] = []
) -> void:
	var all_excluded_item_ids = generated_item_ids + excluded_item_ids

	var random_item_id := ItemRegistry.get_weighted_random_item(
		GameStateService.current_wave,
		PlayerStatsService.get_player_luck(),
		ItemTrackingService.item_counts,
		all_excluded_item_ids, rng
	)

	if random_item_id.is_empty():
		# Fallback to turret if no items available
		generate_turret_offer(generated_turret_ids, excluded_turret_ids, generated_item_ids, excluded_item_ids)
		return

	var base_price: int = ItemRegistry.get_item_price(random_item_id)
	var scaled_price: int = calculate_item_price(base_price, GameStateService.current_wave, random_item_id)

	# Track in BOTH generation-level AND session-level
	generated_item_ids.append(random_item_id)
	if random_item_id not in _session_item_ids:
		_session_item_ids.append(random_item_id)

	var offer: Dictionary = {
		"type": "item",
		"item_id": random_item_id,
		"price": scaled_price,
		"sold": false,
		"locked": false,
	}
	EconomyService.current_shop_offers.append(offer)

func calculate_turret_price(base_price: int, wave: int) -> int:
	# Include turret purchase penalty: +25% per turret owned (can be reduced by items)
	var wave_multiplier: float = 1.0 + GameConstants.WAVE_PRICE_SCALE * wave
	var penalty_per_turret: float = TurretStatsService.get_turret_purchase_penalty()
	var penalty_multiplier: float = 1.0 + penalty_per_turret * EconomyService.turrets_purchased
	var shop_price_mult: float = ItemTrackingService.get_shop_price_multiplier()
	var price: int = int(base_price * wave_multiplier * penalty_multiplier * shop_price_mult)

	# Apply Quantity Discount: Every 3rd turret costs 50%
	if ItemRegistry.has_special_effect("quantity_discount") and ItemTrackingService.item_counts.get("quantity_discount", 0) > 0:
		# Next purchase will be turrets_purchased + 1
		if (EconomyService.turrets_purchased + 1) % 3 == 0:
			price = int(price * 0.5)

	return price

func calculate_item_price(base_price: int, wave: int, item_id: String = "") -> int:
	var price := base_price * (1.0 + GameConstants.WAVE_PRICE_SCALE * wave)

	# Apply Fortune's Favor discount for rare+ items
	if not item_id.is_empty() and ItemRegistry.has_special_effect("fortune_discount"):
		var rarity := ItemRegistry.get_rarity(item_id)
		if rarity >= GameEnums.ItemRarity.RARE:
			# Check if player has Fortune's Favor
			if ItemTrackingService.item_counts.get("fortunes_favor", 0) > 0:
				price *= 0.85 # 15% discount

	# Apply shop price multiplier from items
	var shop_price_mult: float = ItemTrackingService.get_shop_price_multiplier()
	price *= shop_price_mult

	return int(price)

func purchase_offer(offer_index: int) -> bool:
	if offer_index < 0 or offer_index >= EconomyService.current_shop_offers.size():
		return false

	var offer: Dictionary = EconomyService.current_shop_offers[offer_index]

	if offer.get("sold", false):
		return false

	if EconomyService.total_scrap < offer["price"]:
		Events.shop_insufficient_funds.emit(offer["price"], EconomyService.total_scrap)
		return false

	EconomyService.total_scrap -= offer["price"]
	Events.scrap_spent.emit(offer["price"], EconomyService.total_scrap)

	offer["sold"] = true
	offer["locked"] = false # Clear lock when purchased

	if offer["type"] == "turret":
		# Queue turret for spawning at wave start
		EconomyService.pending_turret_purchases.append(offer["turret_id"])
		EconomyService.turrets_purchased += 1
		
		# Recalculate remaining turret prices with new turrets_purchased value
		_recalculate_turret_prices()
	elif offer["type"] == "item":
		apply_item(offer["item_id"])
		# Recalculate turret prices in case item affects penalty/price multipliers
		_recalculate_turret_prices()

	Events.shop_purchase_made.emit(offer)
	return true

func apply_item(item_id: String) -> void:
	if not ItemRegistry.has_item(item_id):
		DebugService.error(DebugService.VALIDATION, "Invalid item ID: " + item_id)
		return

	var item_data = ItemRegistry.get_item_dict(item_id)
	ItemTrackingService.collected_items.append(item_id)

	# Track item counts for max_stacks
	if not ItemTrackingService.item_counts.has(item_id):
		ItemTrackingService.item_counts[item_id] = 0
	ItemTrackingService.item_counts[item_id] += 1

	# Add all modifiers from this item to active_modifiers
	var modifiers = ItemRegistry.get_modifiers(item_id)
	var modifier_service = get_node("/root/ModifierService")
	var additions: Array = []
	for modifier in modifiers:
		var mod_with_id = modifier.duplicate(true)
		mod_with_id["id"] = item_id + "_" + str(modifier_service.active_modifiers.size() + additions.size())
		additions.append(mod_with_id)

	modifier_service.add_modifiers(additions)

	# Update player health if max health changed
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var difficulty_mult = DifficultyService.get_difficulty_config()["player_health_mult"]
		var new_max_health = PlayerStatsService.get_player_max_health(difficulty_mult)
		player.max_health = new_max_health
		player.current_health = min(player.current_health, new_max_health)

	Events.item_collected.emit(item_data)

func reroll_shop() -> bool:
	# Removed max reroll limit - infinite rerolls allowed
	var reroll_cost = get_reroll_cost()

	if EconomyService.total_scrap < reroll_cost:
		Events.shop_insufficient_funds.emit(reroll_cost, EconomyService.total_scrap)
		return false

	EconomyService.total_scrap -= reroll_cost
	Events.scrap_spent.emit(reroll_cost, EconomyService.total_scrap)
	EconomyService.shop_reroll_count += 1

	generate_offers()
	Events.shop_rerolled.emit(EconomyService.current_shop_offers, reroll_cost)
	return true

func _are_all_offers_sold() -> bool:
	"""Check if all shop offers have been purchased"""
	if EconomyService.current_shop_offers.is_empty():
		return false
	
	for offer in EconomyService.current_shop_offers:
		if not offer.get("sold", false):
			return false
	
	return true

func get_reroll_cost() -> int:
	# If all items have been purchased, reroll is free
	if _are_all_offers_sold():
		return 0
	
	# Apply reroll cost multiplier from modifiers (e.g., Probability Matrix)
	var item_multiplier := ItemTrackingService.get_reroll_cost_multiplier()
	# Delegate to EconomyService with wave-based calculation
	return EconomyService.get_reroll_cost(GameStateService.current_wave, item_multiplier)

func can_afford_reroll() -> bool:
	# Only check if player has enough scrap (no max reroll limit)
	return EconomyService.total_scrap >= get_reroll_cost()

func lock_offer(offer_index: int) -> bool:
	"""Lock an offer so it persists to next reroll/wave"""
	if offer_index < 0 or offer_index >= EconomyService.current_shop_offers.size():
		return false

	var offer = EconomyService.current_shop_offers[offer_index]
	
	# Can't lock sold offers
	if offer.get("sold", false):
		return false
	
	# Can't lock already locked offers
	if offer.get("locked", false):
		return false
	
	offer["locked"] = true
	Events.offer_locked.emit(offer_index)
	return true

func unlock_offer(offer_index: int) -> bool:
	"""Unlock an offer"""
	if offer_index < 0 or offer_index >= EconomyService.current_shop_offers.size():
		return false

	var offer = EconomyService.current_shop_offers[offer_index]
	
	# Can't unlock non-locked offers
	if not offer.get("locked", false):
		return false
	
	offer["locked"] = false
	Events.offer_unlocked.emit(offer_index)
	return true

func _recalculate_turret_prices() -> void:
	"""Recalculate prices for all unsold turret offers"""
	for other_offer in EconomyService.current_shop_offers:
		if other_offer.get("type") == "turret" and not other_offer.get("sold", false):
			var turret_type = other_offer.get("turret_id", "")
			var base_price = TurretRegistry.get_base_price(turret_type)
			other_offer["price"] = calculate_turret_price(base_price, GameStateService.current_wave)
