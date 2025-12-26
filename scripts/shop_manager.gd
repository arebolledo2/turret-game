extends Node

func _ready() -> void:
	Events.shop_opened.connect(_on_shop_opened)
	Events.shop_closed.connect(_on_shop_closed)

func _on_shop_opened(_wave_number: int) -> void:
	generate_offers()

func _on_shop_closed() -> void:
	# Clear all locks when shop closes (between waves)
	for offer in Globals.current_shop_offers:
		if offer.get("locked", false):
			offer["locked"] = false

func generate_offers() -> void:
	# Preserve locked offers before clearing
	var locked_offers: Array = []
	for offer in Globals.current_shop_offers:
		if offer.get("locked", false) and not offer.get("sold", false):
			locked_offers.append(offer)
	
	Globals.current_shop_offers.clear()

	# Track generated items to avoid duplicates
	var generated_item_ids: Array[String] = []
	# Track generated turrets to avoid duplicates
	var generated_turret_ids: Array[String] = []

	# Roll each slot: 65% item, 35% turret
	# Reduce offer count by number of locked offers
	var base_offer_count = Globals.get_shop_offer_count()
	var new_offer_count = base_offer_count - locked_offers.size()
	
	for i in range(new_offer_count):
		var roll: float = randf()
		if roll < GameConstants.SHOP_ITEM_CHANCE:
			generate_item_offer(generated_item_ids, generated_turret_ids)
		else:
			generate_turret_offer(generated_turret_ids)
	
	# Merge locked offers back into the offer list
	for locked_offer in locked_offers:
		Globals.current_shop_offers.append(locked_offer)

	Events.shop_offers_generated.emit(Globals.current_shop_offers)

func generate_turret_offer(generated_turret_ids: Array[String]) -> void:
	var turret_types: Array = TurretRegistry.get_all_type_ids()

	# Filter out already generated turrets
	var available_turrets: Array[String] = []
	for turret_id in turret_types:
		if turret_id not in generated_turret_ids:
			available_turrets.append(turret_id)

	# If all turrets are already generated, allow duplicates
	if available_turrets.is_empty():
		available_turrets = turret_types

	var random_type: String = available_turrets[randi() % available_turrets.size()]

	# Track this turret as generated
	generated_turret_ids.append(random_type)

	var base_price: int = TurretRegistry.get_base_price(random_type)
	var scaled_price: int = calculate_turret_price(base_price, Globals.current_wave)

	var offer: Dictionary = {
		"type": "turret",
		"turret_id": random_type,
		"price": scaled_price,
		"sold": false,
		"locked": false,
	}
	Globals.current_shop_offers.append(offer)

func generate_item_offer(generated_item_ids: Array[String], generated_turret_ids: Array[String]) -> void:
	# Use weighted rarity selection based on wave and luck
	var random_item_id := ItemRegistry.get_weighted_random_item(
		Globals.current_wave,
		Globals.get_player_luck(),
		Globals.item_counts,
		generated_item_ids
	)

	if random_item_id.is_empty():
		# Fallback to turret if no items available
		generate_turret_offer(generated_turret_ids)
		return
	
	var base_price: int = ItemRegistry.get_item_price(random_item_id)
	var scaled_price: int = calculate_item_price(base_price, Globals.current_wave, random_item_id)

	# Track this item as generated
	generated_item_ids.append(random_item_id)

	var offer: Dictionary = {
		"type": "item",
		"item_id": random_item_id,
		"price": scaled_price,
		"sold": false,
		"locked": false,
	}
	Globals.current_shop_offers.append(offer)

func calculate_turret_price(base_price: int, wave: int) -> int:
	# Include turret purchase penalty: +25% per turret owned (can be reduced by items)
	var wave_multiplier: float = 1.0 + Globals.WAVE_PRICE_SCALE * wave
	var penalty_per_turret: float = Globals.get_turret_purchase_penalty()
	var penalty_multiplier: float = 1.0 + penalty_per_turret * Globals.turrets_purchased
	var shop_price_mult: float = Globals.get_shop_price_multiplier()
	var price: int = int(base_price * wave_multiplier * penalty_multiplier * shop_price_mult)

	# Apply Quantity Discount: Every 3rd turret costs 50%
	if ItemRegistry.has_special_effect("quantity_discount") and Globals.item_counts.get("quantity_discount", 0) > 0:
		# Next purchase will be turrets_purchased + 1
		if (Globals.turrets_purchased + 1) % 3 == 0:
			price = int(price * 0.5)

	return price

func calculate_item_price(base_price: int, wave: int, item_id: String = "") -> int:
	var price := base_price * (1.0 + Globals.WAVE_PRICE_SCALE * wave)

	# Apply Fortune's Favor discount for rare+ items
	if not item_id.is_empty() and ItemRegistry.has_special_effect("fortune_discount"):
		var rarity := ItemRegistry.get_rarity(item_id)
		if rarity >= GameEnums.ItemRarity.RARE:
			# Check if player has Fortune's Favor
			if Globals.item_counts.get("fortunes_favor", 0) > 0:
				price *= 0.85 # 15% discount

	# Apply shop price multiplier from items
	var shop_price_mult: float = Globals.get_shop_price_multiplier()
	price *= shop_price_mult

	return int(price)

func purchase_offer(offer_index: int) -> bool:
	if offer_index < 0 or offer_index >= Globals.current_shop_offers.size():
		return false

	var offer: Dictionary = Globals.current_shop_offers[offer_index]

	if offer.get("sold", false):
		return false

	if Globals.total_gold < offer["price"]:
		Events.shop_insufficient_funds.emit(offer["price"], Globals.total_gold)
		return false

	Globals.total_gold -= offer["price"]
	Events.gold_spent.emit(offer["price"], Globals.total_gold)

	offer["sold"] = true
	offer["locked"] = false # Clear lock when purchased

	if offer["type"] == "turret":
		# Queue turret for spawning at wave start
		Globals.pending_turret_purchases.append(offer["turret_id"])
		Globals.turrets_purchased += 1
		
		# Recalculate remaining turret prices with new turrets_purchased value
		for other_offer in Globals.current_shop_offers:
			if other_offer.get("type") == "turret" and not other_offer.get("sold", false):
				var turret_type = other_offer.get("turret_id", "")
				var base_price = TurretRegistry.get_base_price(turret_type)
				other_offer["price"] = calculate_turret_price(base_price, Globals.current_wave)
	elif offer["type"] == "item":
		apply_item(offer["item_id"])

	Events.shop_purchase_made.emit(offer)
	return true

func apply_item(item_id: String) -> void:
	if not ItemRegistry.has_item(item_id):
		push_error("Invalid item ID: " + item_id)
		return

	var item_data = ItemRegistry.get_item_dict(item_id)
	Globals.collected_items.append(item_id)

	# Track item counts for max_stacks
	if not Globals.item_counts.has(item_id):
		Globals.item_counts[item_id] = 0
	Globals.item_counts[item_id] += 1

	# Add all modifiers from this item to active_modifiers
	var modifiers = ItemRegistry.get_modifiers(item_id)
	for modifier in modifiers:
		var mod_with_id = modifier.duplicate(true)
		mod_with_id["id"] = item_id + "_" + str(Globals.active_modifiers.size())
		Globals.active_modifiers.append(mod_with_id)

	# Update player health if max health changed
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var new_max_health = Globals.get_player_max_health()
		player.max_health = new_max_health
		player.current_health = min(player.current_health, new_max_health)

	Events.item_collected.emit(item_data)

func reroll_shop() -> bool:
	# Removed max reroll limit - infinite rerolls allowed
	var reroll_cost = get_reroll_cost()

	if Globals.total_gold < reroll_cost:
		Events.shop_insufficient_funds.emit(reroll_cost, Globals.total_gold)
		return false

	Globals.total_gold -= reroll_cost
	Events.gold_spent.emit(reroll_cost, Globals.total_gold)
	Globals.shop_reroll_count += 1

	generate_offers()
	Events.shop_rerolled.emit(Globals.current_shop_offers, reroll_cost)
	return true

func get_reroll_cost() -> int:
	# Base cost increases with each reroll this wave
	var reroll_cost := Globals.REROLL_BASE_COST + (Globals.REROLL_COST_INCREMENT * Globals.shop_reroll_count)
	# Apply reroll cost multiplier from modifiers (e.g., Probability Matrix)
	var item_multiplier := Globals.get_reroll_cost_multiplier()
	return int(reroll_cost * item_multiplier)

func can_afford_reroll() -> bool:
	# Only check if player has enough gold (no max reroll limit)
	return Globals.total_gold >= get_reroll_cost()

func lock_offer(offer_index: int) -> bool:
	"""Lock an offer so it persists to next reroll/wave"""
	if offer_index < 0 or offer_index >= Globals.current_shop_offers.size():
		return false
	
	var offer = Globals.current_shop_offers[offer_index]
	
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
	if offer_index < 0 or offer_index >= Globals.current_shop_offers.size():
		return false
	
	var offer = Globals.current_shop_offers[offer_index]
	
	# Can't unlock non-locked offers
	if not offer.get("locked", false):
		return false
	
	offer["locked"] = false
	Events.offer_unlocked.emit(offer_index)
	return true
