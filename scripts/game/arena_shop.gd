class_name ArenaShop
extends RefCounted

## Every catalogued id. Stock and purchases additionally require `ShopCatalog.is_available` (feature flags).
static var TURRETS: Array[String] = ShopCatalog.ids("turret")
static var ITEMS: Array[String] = ShopCatalog.ids("item")
# Short-run balance: common upgrades start at 10, uncommon at 18, before wave scaling.
const ITEM_PRICE_SCALE: float = .5
var world: ArenaWorld
var rng: RandomNumberGenerator = GameRandom.gameplay

func open() -> void:
	EconomyService.shop_reroll_count = 0
	generate()

## Weapons first, then upgrades fill the remaining slots. Locked offers stay and count toward their group.
func generate() -> void:
	var turrets := ShopCatalog.available_ids("turret")
	var excluded := unavailable_item_ids()
	var kept_turrets: Array[ShopOffer] = []
	var kept_items: Array[ShopOffer] = []
	for offer: ShopOffer in EconomyService.current_shop_offers:
		if offer.locked and not offer.sold:
			if offer.kind == "turret":
				turrets.erase(offer.asset_id)
				kept_turrets.append(offer)
			else:
				excluded.append(offer.asset_id)
				kept_items.append(offer)
	EconomyService.current_shop_offers.clear()
	var turret_count := clampi(roll_turret_count(), kept_turrets.size(), GameConstants.SHOP_OFFER_COUNT - kept_items.size())
	EconomyService.current_shop_offers.append_array(kept_turrets)
	for i in range(turret_count - kept_turrets.size()):
		if turrets.is_empty():
			break
		var type_id: String = turrets.pop_at(rng.randi_range(0, turrets.size() - 1))
		EconomyService.current_shop_offers.append(ShopOffer.new("turret", type_id, world.turret_price(type_id)))
	EconomyService.current_shop_offers.append_array(kept_items)
	for i in range(GameConstants.SHOP_OFFER_COUNT - EconomyService.current_shop_offers.size()):
		var item_id := ItemRegistry.get_weighted_random_item(GameStateService.current_wave,
			PlayerStatsService.get_player_luck(), ItemTrackingService.item_counts, excluded, rng)
		if item_id.is_empty():
			break
		excluded.append(item_id)
		EconomyService.current_shop_offers.append(ShopOffer.new("item", item_id, item_price(item_id)))

## 0 to SHOP_TURRET_MAX weapons, each slot stocked independently (binomial, mean 1.5).
func roll_turret_count() -> int:
	var count := 0
	for i in range(GameConstants.SHOP_TURRET_MAX):
		if rng.randf() < GameConstants.SHOP_TURRET_SLOT_CHANCE:
			count += 1
	return count

func toggle_lock(index: int) -> bool:
	if not is_open() or index < 0 or index >= EconomyService.current_shop_offers.size():
		return false
	var offer := EconomyService.current_shop_offers[index]
	if offer.sold:
		return false
	offer.locked = not offer.locked
	if not offer.locked:
		offer.price = world.turret_price(offer.asset_id) if offer.kind == "turret" else item_price(offer.asset_id)
	return true

func can_reroll() -> bool:
	for offer in EconomyService.current_shop_offers:
		if not offer.locked or offer.sold:
			return true
	return EconomyService.current_shop_offers.is_empty()

func unavailable_item_ids() -> Array:
	var excluded: Array = []
	for item_id in ItemRegistry.get_all_item_ids():
		if not ShopCatalog.is_available("item", item_id) or (item_id in ShopCatalog.CONVOY_ONLY and not world.convoy_mode) or (item_id == "reserve_battery" and not world.core):
			excluded.append(item_id)
	return excluded

## One item from the shop's weighted pool (for rewards outside the shop); "" when nothing is left.
func roll_item_reward() -> String:
	return ItemRegistry.get_weighted_random_item(GameStateService.current_wave, PlayerStatsService.get_player_luck(),
		ItemTrackingService.item_counts, unavailable_item_ids(), rng)

func item_price(item_id: String) -> int:
	var base := maxi(1, roundi(ItemRegistry.get_item_price(item_id) * ITEM_PRICE_SCALE))
	return EconomyService.calculate_item_price(base, GameStateService.current_wave, item_id)

func is_open() -> bool:
	return not world.paused and GameStateService.is_game_active and GameStateMachine.current_state == GameStateMachine.GameState.SHOP

func reroll_cost() -> int:
	var all_sold := not EconomyService.current_shop_offers.is_empty()
	for offer in EconomyService.current_shop_offers:
		all_sold = all_sold and offer.sold
	return 0 if all_sold else EconomyService.get_reroll_cost(GameStateService.current_wave, ItemTrackingService.get_reroll_cost_multiplier())

func reroll() -> bool:
	var cost := reroll_cost()
	if not is_open() or not can_reroll() or not EconomyService.deduct_scrap(cost):
		return false
	world.telemetry.record_spend("reroll", cost)
	EconomyService.shop_reroll_count += 1
	generate()
	world.message = "New supplies available."
	return true

func purchase(index: int) -> bool:
	if not is_open() or index < 0 or index >= EconomyService.current_shop_offers.size():
		return false
	var offer := EconomyService.current_shop_offers[index]
	if offer.sold:
		return false
	var placement := Vector3.INF
	if offer.kind == "turret":
		if not ShopCatalog.is_available("turret", offer.asset_id):
			return false
		placement = world.find_placement()
		if placement == Vector3.INF:
			world.message = "No room for another turret."
			return false
	elif not ShopCatalog.is_available("item", offer.asset_id) or ItemRegistry.is_at_max_stacks(offer.asset_id, ItemTrackingService.item_counts):
		return false
	if not EconomyService.deduct_scrap(offer.price):
		world.message = "Need %d scrap." % offer.price
		return false
	world.audio.play_cue("purchase", world.player.position)
	world.telemetry.record_spend(offer.kind, offer.price)
	offer.sold = true
	offer.locked = false
	if offer.kind == "turret":
		world.add_turret(placement, offer.asset_id)
		EconomyService.turrets_purchased += 1
	else:
		apply_item(offer.asset_id)
	for remaining in EconomyService.current_shop_offers:
		if not remaining.sold and not remaining.locked:
			remaining.price = world.turret_price(remaining.asset_id) if remaining.kind == "turret" else item_price(remaining.asset_id)
	world.message = "Installed: " + offer_name(offer)
	return true

func apply_item(item_id: String) -> void:
	ItemTrackingService.collected_items.append(item_id)
	ItemTrackingService.item_counts[item_id] = int(ItemTrackingService.item_counts.get(item_id, 0)) + 1
	var additions: Array = []
	for modifier: Dictionary in ItemRegistry.get_modifiers(item_id):
		var entry := modifier.duplicate(true)
		entry["id"] = "3d_%s_%d" % [item_id, ModifierService.active_modifiers.size() + additions.size()]
		additions.append(entry)
	ModifierService.add_modifiers(additions)
	world.player.max_health = maxf(1.0, PlayerStatsService.get_player_max_health(float(world.difficulty_config["player_health_mult"])))
	world.player.health = minf(world.player.health, world.player.max_health)

static func offer_name(offer: ShopOffer) -> String:
	if offer.kind == "turret":
		return "Ion Turret" if offer.asset_id == "normal" else str(TurretRegistry.TYPES[offer.asset_id]["name"])
	return str(ItemRegistry.get_item_dict(offer.asset_id)["name"])

static func offer_description(offer: ShopOffer) -> String:
	if offer.kind == "turret":
		return TurretRegistry.get_type(offer.asset_id).get("description", "")
	return ItemRegistry.get_item(offer.asset_id).description

static func item_description(item_id: String) -> String:
	return ItemRegistry.get_item(item_id).description

## "Core 1.38m/s · next route: 3 doors, 58 m, ~1:21" - the planned route at the current core speed.
func convoy_preview_line() -> String:
	var speed := PlayerStatsService.get_core_move_speed()
	var line := "Core %.2fm/s" % speed
	if world.convoy_route:
		var seconds := roundi(world.convoy_route.duration(speed))
		line += " · next route: %d doors, %.0f m, ~%d:%02d" % [world.convoy_route.door_count() - 1, world.convoy_route.total_length(), floori(seconds / 60.0), seconds % 60]
	return line

func build_summary() -> String:
	var lines := PackedStringArray()
	for type_id in TURRETS:
		var count := int(TurretStatsService.turret_counts.get(type_id, 0))
		if count > 0 and type_id == "melee":
			var bat := TurretStatsService.get_turret_stats(type_id, float(world.difficulty_config["turret_damage_mult"]))
			lines.append("Melee ×%d   %.1f dmg · %.0f°/s · %.2fm" % [count, bat["damage"], bat["rotation_rate"], float(bat["range"]) * WorldGeometry.METRES_PER_PIXEL])
		elif count > 0:
			var stats := TurretStatsService.get_turret_stats(type_id, float(world.difficulty_config["turret_damage_mult"]))
			lines.append("%s ×%d   %.1f dmg · %.2f/s · %.2fm" % [TurretRegistry.get_short_name(type_id), count, stats["damage"], stats["fire_rate"], float(stats["range"]) * WorldGeometry.METRES_PER_PIXEL])
	lines.append("Hull %.0f/%.0f · Move %.2fm/s · Pickup %.2fm" % [world.player.health, world.player.max_health, PlayerStatsService.get_player_speed() * WorldGeometry.METRES_PER_PIXEL, PlayerStatsService.get_pickup_radius() * WorldGeometry.METRES_PER_PIXEL])
	if world.convoy_mode:
		lines.append(convoy_preview_line())
	if ItemTrackingService.item_counts.is_empty():
		lines.append("No upgrades installed yet.")

	for item_id: String in ItemTrackingService.item_counts:
		lines.append("%s ×%d" % [ItemRegistry.get_item_dict(item_id)["name"], ItemTrackingService.item_counts[item_id]])
	return "\n".join(lines)
