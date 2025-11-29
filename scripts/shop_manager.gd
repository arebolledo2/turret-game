extends Node

func _ready() -> void:
	Events.shop_opened.connect(_on_shop_opened)

func _on_shop_opened(wave_number: int) -> void:
	generate_offers()

func generate_offers() -> void:
	Globals.current_shop_offers.clear()
	var turret_types = Globals.TURRET_TYPES.keys()
	var available_types = turret_types.duplicate()

	# Generate 4 unique turret offers (no duplicates)
	for i in range(Globals.SHOP_OFFER_COUNT):
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

	Events.shop_offers_generated.emit(Globals.current_shop_offers)

func calculate_turret_price(base_price: int, wave: int) -> int:
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

	Events.shop_purchase_made.emit(offer)
	return true

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
