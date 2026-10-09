class_name ShopViewData
extends RefCounted

## Structured shop data for the refit screen: stat chips per offer, the build as numbers (not text), and
## a "what if I buy this" copy of that build. ArenaShop keeps the text forms for logs and tests.

## Game stat key -> [UI stat key, icon name, lower_is_better].
const STAT_UI: Dictionary = {
	"damage": ["dmg", "damage", false], "fire_rate": ["rate", "rate", false], "range": ["range", "range", false],
	"rotation_rate": ["rate", "rate", false], "projectile_speed": ["speed", "speed", false],
	"aoe_radius": ["range", "range", false], "knockback_force": ["dmg", "damage", false],
	"chain_count": ["dmg", "damage", false], "slow_intensity": ["slow", "slow", false],
	"slow_duration": ["slow", "slow", false], "player_speed": ["speed", "speed", false],
	"carry_speed": ["speed", "speed", false], "core_move_speed": ["speed", "speed", false],
	"player_max_health": ["hull", "hull", false], "player_health_regen": ["hull", "repair", false],
	"pickup_radius": ["pickup", "pickup", false], "reroll_cost": ["scrap", "reroll", true],
	"turret_penalty_reduction": ["penalty", "penalty", false], "shop_price_mult": ["scrap", "penalty", true],
	"scrap_earn_mult": ["scrap", "scrap", false], "enemy_count_mult": ["kills", "kills", true],
	"player_luck": ["scrap", "star", false], "turret_crit_chance": ["dmg", "kills", false],
	"player_crit_chance": ["dmg", "kills", false], "entrench_stack_seconds": ["rate", "timer", true],
	"entrench_max_stacks": ["rate", "rate", false], "entrench_bonus": ["rate", "rate", false],
	"pierce": ["dmg", "damage", false], "chain_decay": ["dmg", "damage", false], "rehit_delay": ["rate", "rate", true],
	"turret_penalty_increase": ["penalty", "penalty", true], "last_stand_fire_rate": ["rate", "rate", false],
	"reactor_overload": ["dps", "damage", false], "storm_link_damage": ["dmg", "damage", false],
}

## Stat chips for one offer: [{stat, icon, text, tone}]. Special-effect items return none (their rules
## are text only); the card falls back to the description for those.
static func offer_chips(offer: ShopOffer, difficulty_damage_mult: float = 1.0) -> Array[Dictionary]:
	if offer.kind == "turret":
		return _turret_chips(offer.asset_id, difficulty_damage_mult)
	var chips: Array[Dictionary] = []
	if ItemRegistry.get_item_dict(offer.asset_id).has("special_effect"):
		return chips
	for modifier: Dictionary in ItemRegistry.get_modifiers(offer.asset_id):
		var stat := str(modifier["stat"])
		var value := float(modifier["value"])
		var percentage: bool = modifier["operation"] == "increase" or stat == "turret_penalty_reduction"
		var unit := "pp" if stat == "turret_penalty_reduction" else ("%" if percentage else "")
		var ui: Array = STAT_UI.get(stat, ["", "module", false])
		var better := value > 0.0
		if bool(ui[2]):
			better = not better
		chips.append({"stat": ui[0], "icon": ui[1], "tone": 1 if better else -1,
			"text": "%+.0f%s" % [value * 100.0 if percentage else value, unit]})
	return chips

static func _turret_chips(type_id: String, damage_mult: float) -> Array[Dictionary]:
	var stats := TurretStatsService.get_turret_stats(type_id, damage_mult)
	var chips: Array[Dictionary] = []
	if stats.is_empty():
		return chips
	chips.append({"stat": "dmg", "icon": "damage", "tone": 0, "text": "%.1f" % stats["damage"]})
	if float(stats.get("fire_rate", 0.0)) > 0.0:
		chips.append({"stat": "rate", "icon": "rate", "tone": 0, "text": "%.2f" % stats["fire_rate"]})
	elif stats.has("rotation_rate"):
		chips.append({"stat": "rate", "icon": "rate", "tone": 0, "text": "%.0f°/s" % stats["rotation_rate"]})
	chips.append({"stat": "range", "icon": "range", "tone": 0, "text": "%.2fm" % (float(stats["range"]) * WorldGeometry.METRES_PER_PIXEL)})
	if stats.has("slow_intensity"):
		chips.append({"stat": "slow", "icon": "slow", "tone": 0, "text": "%.0f%%" % (float(stats["slow_intensity"]) * 100.0)})
	return chips

## The current build as numbers. `extra_turret` counts one more of that type (used by preview).
static func build_data(world: ArenaWorld, extra_turret: String = "") -> Dictionary:
	var damage_mult := float(world.difficulty_config["turret_damage_mult"])
	var turrets: Array[Dictionary] = []
	var dps := 0.0
	for type_id in ArenaShop.TURRETS:
		var count := int(TurretStatsService.turret_counts.get(type_id, 0)) + (1 if type_id == extra_turret else 0)
		if count <= 0:
			continue
		var stats := TurretStatsService.get_turret_stats(type_id, damage_mult)
		var rate := float(stats.get("fire_rate", 0.0))
		turrets.append({"id": type_id, "name": TurretRegistry.get_short_name(type_id), "count": count,
			"damage": float(stats["damage"]), "fire_rate": rate, "rotation_rate": float(stats.get("rotation_rate", 0.0)),
			"range": float(stats["range"]) * WorldGeometry.METRES_PER_PIXEL})
		dps += count * float(stats["damage"]) * rate
	var max_hull := PlayerStatsService.get_player_max_health(float(world.difficulty_config["player_health_mult"]))
	var items: Array[Dictionary] = []
	for item_id: String in ItemTrackingService.item_counts:
		items.append({"id": item_id, "name": str(ItemRegistry.get_item_dict(item_id)["name"]), "count": int(ItemTrackingService.item_counts[item_id])})
	return {"turrets": turrets, "dps": dps, "max_hull": max_hull, "hull": minf(world.player.health, max_hull),
		"speed": PlayerStatsService.get_player_speed() * WorldGeometry.METRES_PER_PIXEL,
		"pickup": PlayerStatsService.get_pickup_radius() * WorldGeometry.METRES_PER_PIXEL, "items": items}

## build_data after buying `offer`. Items are measured by adding their modifiers to the real modifier
## system for the duration of this call and removing them again, so the numbers come from the same
## code that applies the purchase. Special-effect items change nothing here (their rules are not static).
static func preview(world: ArenaWorld, offer: ShopOffer) -> Dictionary:
	if offer.kind == "turret":
		return build_data(world, offer.asset_id)
	var system := ModifierService.state.modifiers
	var ids: Array[String] = []
	for modifier: Dictionary in ItemRegistry.get_modifiers(offer.asset_id):
		var entry := modifier.duplicate(true)
		entry["id"] = "preview_%s_%d" % [offer.asset_id, ids.size()]
		ids.append(entry["id"])
		system.add_modifier(entry)
	var data := build_data(world)
	for modifier_id in ids:
		system.remove_modifier(modifier_id)
	var found := false
	for item: Dictionary in data["items"]:
		if item["id"] == offer.asset_id:
			item["count"] += 1
			found = true
	if not found:
		data["items"].append({"id": offer.asset_id, "name": str(ItemRegistry.get_item_dict(offer.asset_id)["name"]), "count": 1})
	return data
