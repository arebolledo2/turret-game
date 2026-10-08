class_name ArenaShop
extends RefCounted

## Every catalogued id. Stock and purchases additionally require `ShopCatalog.is_available` (feature flags).
static var TURRETS: Array[String] = ShopCatalog.ids("turret")
static var ITEMS: Array[String] = ShopCatalog.ids("item")
# Short-run balance: common upgrades start at 10, uncommon at 18, before wave scaling.
const ITEM_PRICE_SCALE: float = .5
const STAT_NAMES: Dictionary = {"damage": "turret damage", "fire_rate": "turret fire rate",
	"range": "turret range", "player_speed": "move speed", "player_max_health": "max hull",
	"pickup_radius": "pickup radius", "reroll_cost": "reroll cost", "turret_penalty_reduction": "purchase penalty",
	"aoe_radius": "turret splash radius", "knockback_force": "turret knockback", "chain_count": "turret chain jumps",
	"slow_intensity": "turret slow strength", "slow_duration": "turret slow duration", "rotation_rate": "turret spin rate",
	"projectile_speed": "turret projectile speed", "scrap_earn_mult": "scrap from kills", "enemy_count_mult": "enemies per wave",
	"shop_price_mult": "shop prices", "player_luck": "luck", "turret_crit_chance": "turret crit chance",
	"player_crit_chance": "crit chance", "player_health_regen": "hull regen", "entrench_stack_seconds": "entrench stack time",
	"entrench_max_stacks": "entrench stacks", "entrench_bonus": "entrench bonus", "carry_speed": "carry speed"}
var world: ArenaWorld
var rng: RandomNumberGenerator = GameRandom.gameplay

func open() -> void:
	EconomyService.shop_reroll_count = 0
	generate()

func generate() -> void:
	EconomyService.current_shop_offers.clear()
	var turrets := ShopCatalog.available_ids("turret")
	# One weapon choice and three weighted upgrades: the build is steered by items, the turret is a supplement.
	for slot in range(mini(GameConstants.SHOP_TURRET_SLOTS, turrets.size())):
		var selected := rng.randi_range(0, turrets.size() - 1)
		var type_id: String = turrets.pop_at(selected)
		EconomyService.current_shop_offers.append(ShopOffer.new("turret", type_id, world.turret_price(type_id)))
	var excluded := unavailable_item_ids()
	for slot in range(GameConstants.SHOP_ITEM_SLOTS):
		var item_id := ItemRegistry.get_weighted_random_item(GameStateService.current_wave,
			PlayerStatsService.get_player_luck(), ItemTrackingService.item_counts, excluded, rng)
		if item_id.is_empty():
			break
		excluded.append(item_id)
		EconomyService.current_shop_offers.append(ShopOffer.new("item", item_id, item_price(item_id)))

func unavailable_item_ids() -> Array:
	var excluded: Array = []
	for item_id in ItemRegistry.get_all_item_ids():
		if not ShopCatalog.is_available("item", item_id):
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
	if not is_open() or not EconomyService.deduct_scrap(cost):
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
	if offer.kind == "turret":
		world.add_turret(placement, offer.asset_id)
		EconomyService.turrets_purchased += 1
	else:
		apply_item(offer.asset_id)
	for remaining in EconomyService.current_shop_offers:
		if not remaining.sold:
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

## "ION 2 · TALL 1": how many installed items carry each build tag, so a direction is visible at a glance.
static func tag_summary() -> String:
	var counts: Dictionary = {}
	for item_id: String in ItemTrackingService.item_counts:
		var tag := ItemRegistry.get_tag(item_id)
		counts[tag] = int(counts.get(tag, 0)) + int(ItemTrackingService.item_counts[item_id])
	var parts := PackedStringArray()
	for tag in ItemRegistry.TAGS:
		if counts.has(tag):
			parts.append("%s %d" % [tag, counts[tag]])
	return "Tags: " + " · ".join(parts)

static func offer_name(offer: ShopOffer) -> String:
	if offer.kind == "turret":
		return "Ion Turret" if offer.asset_id == "normal" else str(TurretRegistry.TYPES[offer.asset_id]["name"])
	return str(ItemRegistry.get_item_dict(offer.asset_id)["name"])

static func offer_description(offer: ShopOffer) -> String:
	if offer.kind == "turret":
		match offer.asset_id:
			"normal": return "Reliable single-target fire"
			"plasma": return "Splash damage + charge-interrupting knockback"
			"shock": return "Electric pulse · 25% slow for 0.5s"
			"tesla": return "Chain lightning · jumps to 3 more enemies"
			"melee": return "Spinning bat · contact damage + knockback"
	return item_description(offer.asset_id)

static func item_description(item_id: String) -> String:
	# Special-effect items (Army Doctrine, Mono-Type Mastery...) carry rules the modifier list cannot show.
	var info := ItemRegistry.get_item_dict(item_id)
	if info.has("special_effect") or ItemRegistry.get_modifiers(item_id).is_empty():
		return str(info.get("description", ""))
	var parts := PackedStringArray()
	for modifier: Dictionary in ItemRegistry.get_modifiers(item_id):
		var value := float(modifier["value"])
		var stat := str(modifier["stat"])
		var percentage: bool = modifier["operation"] == "increase" or stat == "turret_penalty_reduction"
		var unit := "pp" if stat == "turret_penalty_reduction" else ("%" if percentage else "")
		var amount := "%+.0f%s" % [value * 100.0 if percentage else value, unit]
		var label: String = STAT_NAMES.get(stat, stat)
		parts.append(amount + " " + _scoped_label(label, modifier.get("filter", {})))
	return " · ".join(parts)

## Narrows "turret x" to the filter's audience: "Ion turret x", "projectile turret x", "electric turret x".
static func _scoped_label(label: String, filter: Dictionary) -> String:
	var scope := ""
	if filter.has("family"):
		scope = " / ".join(PackedStringArray((filter["family"] as Array).map(func(family: String) -> String: return family.capitalize())))
	elif filter.has("turret_type") and not ("all" in filter["turret_type"]):
		scope = " / ".join(PackedStringArray((filter["turret_type"] as Array).map(func(type_id: String) -> String: return TurretRegistry.get_short_name(type_id))))
	elif filter.has("attack_style"):
		scope = "projectile"
	elif filter.has("damage_type"):
		scope = " / ".join(PackedStringArray((filter["damage_type"] as Array).map(func(kind: int) -> String: return GameEnums.DamageType.keys()[kind].to_lower())))
	if scope.is_empty() or not label.begins_with("turret "):
		return label
	return scope + " " + label

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
	if ItemTrackingService.item_counts.is_empty():
		lines.append("No upgrades installed yet.")
	else:
		lines.append(tag_summary())
	for item_id: String in ItemTrackingService.item_counts:
		lines.append("%s ×%d" % [ItemRegistry.get_item_dict(item_id)["name"], ItemTrackingService.item_counts[item_id]])
	return "\n".join(lines)
