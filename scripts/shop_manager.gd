extends Node

func _ready() -> void:
	Events.shop_opened.connect(_on_shop_opened)

func _on_shop_opened(wave_number: int) -> void:
	generate_offers()

func generate_offers() -> void:
	Globals.current_shop_offers.clear()

	# Track generated items to avoid duplicates
	var generated_item_ids: Array[String] = []

	# Roll each slot: 65% item, 35% turret
	for i in range(Globals.SHOP_OFFER_COUNT):
		var roll = randf()
		if roll < GameConstants.SHOP_ITEM_CHANCE:
			generate_item_offer(generated_item_ids)
		else:
			generate_turret_offer()

	Events.shop_offers_generated.emit(Globals.current_shop_offers)

func generate_turret_offer() -> void:
	var turret_types = Globals.TURRET_TYPES.keys()
	var random_type = turret_types[randi() % turret_types.size()]

	var base_price = Globals.TURRET_BASE_PRICES.get(random_type, 50)
	var scaled_price = calculate_turret_price(base_price, Globals.current_wave)

	var offer = {
		"type": "turret",
		"turret_id": random_type,
		"price": scaled_price,
		"sold": false,
	}
	Globals.current_shop_offers.append(offer)

func generate_item_offer(generated_item_ids: Array[String]) -> void:
	# Get available items (filter out max_stacks items)
	var available_items = ItemRegistry.get_available_item_ids(Globals.item_counts)
	
	# Filter out items already in this shop
	available_items = available_items.filter(func(item_id): return item_id not in generated_item_ids)
	
	if available_items.is_empty():
		# Fallback to turret if no items available
		generate_turret_offer()
		return
	
	var random_item_id = available_items[randi() % available_items.size()]
	var item_data = ItemRegistry.get_item(random_item_id)
	var base_price = ItemRegistry.get_item_price(random_item_id)
	var scaled_price = calculate_item_price(base_price, Globals.current_wave)

	# Track this item as generated
	generated_item_ids.append(random_item_id)

	var offer = {
		"type": "item",
		"item_id": random_item_id,
		"price": scaled_price,
		"sold": false,
	}
	Globals.current_shop_offers.append(offer)

func calculate_turret_price(base_price: int, wave: int) -> int:
	# Include turret purchase penalty: +25% per turret owned
	var wave_multiplier = 1.0 + Globals.WAVE_PRICE_SCALE * wave
	var penalty_multiplier = 1.0 + GameConstants.TURRET_PURCHASE_PENALTY * Globals.turrets_purchased
	return int(base_price * wave_multiplier * penalty_multiplier)

func calculate_item_price(base_price: int, wave: int) -> int:
	return int(base_price * (1.0 + Globals.WAVE_PRICE_SCALE * wave))

func purchase_offer(offer_index: int) -> bool:
	if offer_index < 0 or offer_index >= Globals.current_shop_offers.size():
		return false

	var offer = Globals.current_shop_offers[offer_index]

	if offer.get("sold", false):
		return false

	if Globals.total_gold < offer["price"]:
		Events.shop_insufficient_funds.emit(offer["price"], Globals.total_gold)
		return false

	Globals.total_gold -= offer["price"]
	Events.gold_spent.emit(offer["price"], Globals.total_gold)

	offer["sold"] = true

	if offer["type"] == "turret":
		# Queue turret for spawning at wave start
		Globals.pending_turret_purchases.append(offer["turret_id"])
		Globals.turrets_purchased += 1
		
		# Recalculate remaining turret prices with new turrets_purchased value
		for other_offer in Globals.current_shop_offers:
			if other_offer.get("type") == "turret" and not other_offer.get("sold", false):
				var turret_type = other_offer.get("turret_id", "")
				var base_price = Globals.TURRET_BASE_PRICES.get(turret_type, 50)
				other_offer["price"] = calculate_turret_price(base_price, Globals.current_wave)
	elif offer["type"] == "item":
		apply_item(offer["item_id"])

	Events.shop_purchase_made.emit(offer)
	return true

func apply_item(item_id: String) -> void:
	if not ItemRegistry.has_item(item_id):
		push_error("Invalid item ID: " + item_id)
		return

	var item_data = ItemRegistry.get_item(item_id)
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
	if Globals.shop_reroll_count >= Globals.MAX_REROLLS_PER_WAVE:
		return false

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
	return Globals.REROLL_BASE_COST + (Globals.REROLL_COST_INCREMENT * Globals.shop_reroll_count)

func can_afford_reroll() -> bool:
	if Globals.shop_reroll_count >= Globals.MAX_REROLLS_PER_WAVE:
		return false
	return Globals.total_gold >= get_reroll_cost()
