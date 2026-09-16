class_name ArenaShop
extends RefCounted

## Restricted catalog until each legacy effect has a 3D consumer.
const TURRETS: Array[String] = ["normal", "plasma", "shock"]
const ITEMS: Array[String] = ["scrap_magnet", "reinforced_hull", "quick_loader", "shock_absorbers",
	"dense_rounds", "budget_capacitor", "ammo_surplus", "overclock_module", "compact_design",
	"extended_barrel", "rapid_coolant", "kinetic_enhancer", "heavy_plating"]
# Short-run balance: common upgrades start at 10, uncommon at 18, before wave scaling.
const ITEM_PRICE_SCALE: float = .5
const STAT_NAMES: Dictionary = {"damage": "turret damage", "fire_rate": "turret fire rate",
	"range": "turret range", "player_speed": "move speed", "player_max_health": "max hull",
	"pickup_radius": "pickup radius", "reroll_cost": "reroll cost", "turret_penalty_reduction": "purchase penalty"}
var world: ArenaWorld
var rng: RandomNumberGenerator = GameRandom.gameplay

func open() -> void:
	EconomyService.shop_reroll_count = 0
	generate()

func generate() -> void:
	EconomyService.current_shop_offers.clear()
	var turrets := TURRETS.duplicate()
	# Two weapon choices and two weighted upgrades keep both build routes available.
	for slot in range(2):
		var selected := rng.randi_range(0, turrets.size() - 1)
		var type_id: String = turrets.pop_at(selected)
		EconomyService.current_shop_offers.append(ShopOffer.new("turret", type_id, world.turret_price(type_id)).to_dictionary())
	var excluded: Array = []
	for item_id in ItemRegistry.get_all_item_ids():
		if item_id not in ITEMS:
			excluded.append(item_id)
	for slot in range(2):
		var item_id := ItemRegistry.get_weighted_random_item(GameStateService.current_wave,
			PlayerStatsService.get_player_luck(), ItemTrackingService.item_counts, excluded, rng)
		if item_id.is_empty():
			break
		excluded.append(item_id)
		EconomyService.current_shop_offers.append(ShopOffer.new("item", item_id, item_price(item_id)).to_dictionary())

func item_price(item_id: String) -> int:
	var base := maxi(1, roundi(ItemRegistry.get_item_price(item_id) * ITEM_PRICE_SCALE))
	return EconomyService.calculate_item_price(base, GameStateService.current_wave, item_id)

func is_open() -> bool:
	return not world.paused and GameStateService.is_game_active and GameStateMachine.current_state == GameStateMachine.GameState.SHOP

func reroll_cost() -> int:
	var all_sold := not EconomyService.current_shop_offers.is_empty()
	for offer: Dictionary in EconomyService.current_shop_offers:
		all_sold = all_sold and bool(offer.get("sold", false))
	return 0 if all_sold else EconomyService.get_reroll_cost(GameStateService.current_wave, ItemTrackingService.get_reroll_cost_multiplier())

func reroll() -> bool:
	if not is_open() or not EconomyService.deduct_scrap(reroll_cost()):
		return false
	EconomyService.shop_reroll_count += 1
	generate()
	world.message = "New supplies available."
	return true

func purchase(index: int) -> bool:
	if not is_open() or index < 0 or index >= EconomyService.current_shop_offers.size():
		return false
	var data: Dictionary = EconomyService.current_shop_offers[index]
	var offer := ShopOffer.from_dictionary(data)
	if not offer or offer.sold:
		return false
	var placement := Vector3.INF
	if offer.kind == "turret":
		if offer.asset_id not in TURRETS:
			return false
		placement = world.find_placement()
		if placement == Vector3.INF:
			world.message = "No room for another turret."
			return false
	elif offer.asset_id not in ITEMS or ItemRegistry.is_at_max_stacks(offer.asset_id, ItemTrackingService.item_counts):
		return false
	if not EconomyService.deduct_scrap(offer.price):
		world.message = "Need %d scrap." % offer.price
		return false
	data["sold"] = true
	if offer.kind == "turret":
		world.add_turret(placement, offer.asset_id)
		EconomyService.turrets_purchased += 1
	else:
		apply_item(offer.asset_id)
	for remaining: Dictionary in EconomyService.current_shop_offers:
		if not remaining["sold"]:
			remaining["price"] = world.turret_price(remaining["turret_id"]) if remaining["type"] == "turret" else item_price(remaining["item_id"])
	world.message = "Installed: " + offer_name(data)
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

static func offer_name(offer: Dictionary) -> String:
	if offer["type"] == "turret":
		return "Ion Turret" if offer["turret_id"] == "normal" else str(TurretRegistry.TYPES[offer["turret_id"]]["name"])
	return str(ItemRegistry.get_item_dict(offer["item_id"])["name"])

static func offer_description(offer: Dictionary) -> String:
	if offer["type"] == "turret":
		match offer["turret_id"]:
			"normal": return "Reliable single-target fire"
			"plasma": return "Splash damage + charge-interrupting knockback"
			"shock": return "Electric pulse · 25% slow for 0.5s"
	return item_description(offer["item_id"])

static func item_description(item_id: String) -> String:
	var parts := PackedStringArray()
	for modifier: Dictionary in ItemRegistry.get_modifiers(item_id):
		var value := float(modifier["value"])
		var stat := str(modifier["stat"])
		var percentage: bool = modifier["operation"] == "increase" or stat == "turret_penalty_reduction"
		var unit := "pp" if stat == "turret_penalty_reduction" else ("%" if percentage else "")
		var amount := "%+.0f%s" % [value * 100.0 if percentage else value, unit]
		var label: String = STAT_NAMES.get(stat, stat)
		var filter: Dictionary = modifier.get("filter", {})
		if filter.has("attack_style"):
			label = label.replace("turret", "projectile turret")
		if filter.has("damage_type"):
			label = label.replace("turret", "physical turret" if GameEnums.DamageType.PHYSICAL in filter["damage_type"] else "electric turret")
		parts.append(amount + " " + label)
	return " · ".join(parts)

func build_summary() -> String:
	var lines := PackedStringArray()
	for type_id in TURRETS:
		var count := int(TurretStatsService.turret_counts.get(type_id, 0))
		if count > 0:
			var stats := TurretStatsService.get_turret_stats(type_id, float(world.difficulty_config["turret_damage_mult"]))
			lines.append("%s ×%d   %.1f dmg · %.2f/s · %.2fm" % ["Ion" if type_id == "normal" else type_id.capitalize(), count, stats["damage"], stats["fire_rate"], float(stats["range"]) * .01])
	lines.append("Hull %.0f/%.0f · Move %.2fm/s · Pickup %.2fm" % [world.player.health, world.player.max_health, PlayerStatsService.get_player_speed() * .01, PlayerStatsService.get_pickup_radius() * .01])
	if ItemTrackingService.item_counts.is_empty():
		lines.append("No upgrades installed yet.")
	for item_id: String in ItemTrackingService.item_counts:
		lines.append("%s ×%d" % [ItemRegistry.get_item_dict(item_id)["name"], ItemTrackingService.item_counts[item_id]])
	return "\n".join(lines)
