extends Node

func _ready() -> void:
	Events.shop_opened.connect(_on_shop_opened)

func _on_shop_opened(wave_number: int) -> void:
	generate_offers()

func generate_offers() -> void:
	Globals.current_shop_offers.clear()

	# Generate 3 turrets and 1 item (4 total offers)
	var turret_count = 3
	var item_count = 1

	# Generate turret offers
	var turret_types = Globals.TURRET_TYPES.keys()
	var available_types = turret_types.duplicate()
	for i in range(turret_count):
		if available_types.is_empty():
			break

		var random_index = randi() % available_types.size()
		var random_type = available_types[random_index]
		available_types.remove_at(random_index)  # Remove to prevent duplicates

		var base_price = Globals.TURRET_BASE_PRICES.get(random_type, 50)
		var scaled_price = calculate_turret_price(base_price, Globals.current_wave)

		var offer = {
			"type": "turret",
			"turret_id": random_type,
			"price": scaled_price,
			"sold": false,
		}
		Globals.current_shop_offers.append(offer)

	# Generate item offers
	var item_ids = Globals.ITEMS.keys()
	for i in range(item_count):
		var random_item_id = item_ids[randi() % item_ids.size()]
		var item_data = Globals.ITEMS[random_item_id]
		var base_price = Globals.ITEM_BASE_PRICES[item_data["rarity"]]
		var scaled_price = calculate_item_price(base_price, Globals.current_wave)

		var offer = {
			"type": "item",
			"item_id": random_item_id,
			"price": scaled_price,
			"sold": false,
		}
		Globals.current_shop_offers.append(offer)

	Events.shop_offers_generated.emit(Globals.current_shop_offers)

func calculate_turret_price(base_price: int, wave: int) -> int:
	return int(base_price * (1.0 + Globals.WAVE_PRICE_SCALE * wave))

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
	elif offer["type"] == "item":
		apply_item(offer["item_id"])

	Events.shop_purchase_made.emit(offer)
	return true

func apply_item(item_id: String) -> void:
	if not Globals.ITEMS.has(item_id):
		push_error("Invalid item ID: " + item_id)
		return

	var item_data = Globals.ITEMS[item_id]
	Globals.collected_items.append(item_id)

	# Add all modifiers from this item to active_modifiers
	for modifier in item_data["modifiers"]:
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
