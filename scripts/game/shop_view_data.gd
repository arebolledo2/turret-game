class_name ShopViewData
extends RefCounted

## Structured shop data for the shop screen: stat chips per offer, the build as numbers (not text), and
## a "what if I buy this" copy of that build. ArenaShop keeps the text forms for logs and tests.

## Game stat key -> [UI stat key, icon name, lower_is_better].
const STAT_UI: Dictionary = {
	"area_size": ["range", "range", false], "attack_speed": ["rate", "rate", false],
	"damage": ["dmg", "damage", false], "fire_rate": ["rate", "rate", false], "range": ["range", "range", false],
	"rotation_rate": ["rate", "rate", false], "projectile_speed": ["speed", "speed", false],
	"aoe_radius": ["range", "range", false], "knockback_force": ["dmg", "damage", false],
	"chain_count": ["dmg", "damage", false], "slow_intensity": ["slow", "slow", false],
	"slow_duration": ["slow", "slow", false], "player_speed": ["speed", "speed", false],
	"carry_speed": ["speed", "speed", false], "core_move_speed": ["speed", "speed", false],
	"player_max_health": ["hull", "hull", false], "player_health_regen": ["hull", "repair", false],
	"pickup_radius": ["pickup", "pickup", false], "reroll_cost": ["scrap", "reroll", true],
	"turret_penalty_reduction": ["penalty", "penalty", true], "shop_price_mult": ["scrap", "penalty", true],
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
		var view := TurretStats.new(stats)
		var pulse := TurretRegistry.get_fire_mode(type_id) == TurretRegistry.FIRE_PULSE
		var reach := view.range_metres * (view.area_size if pulse else 1.0)
		var rate := float(stats.get("fire_rate", 0.0))
		turrets.append({"id": type_id, "name": TurretRegistry.get_short_name(type_id), "count": count,
			"damage": float(stats["damage"]), "fire_rate": rate, "rotation_rate": float(stats.get("rotation_rate", 0.0)),
			"range": reach, "stats": {"pierce": view.pierce, "projectile_speed": view.projectile_speed_metres,
			"knockback": view.knockback_metres, "chain_count": view.chain_count,
			"chain_decay": float(stats.get("chain_decay", 0)) * 100.0, "slow": view.slow_intensity * 100.0,
			"slow_duration": view.slow_duration, "rehit_delay": view.rehit_delay if stats.has("rehit_delay") else 0.0},
			"area": reach if pulse else view.aoe_radius_metres})
		var instances: Array[Dictionary] = []
		var represented := 0
		if world.session.state.turret_progression_enabled:
			for actor in world.turrets:
				if actor.turret_type != type_id:
					continue
				var growth := actor.progression.snapshot()
				growth["id"] = actor.turret_id
				growth["name"] = actor.display_name()
				growth["combat"] = _actor_numbers(actor)
				if actor.progression.evolution_branch == "gunblade":
					growth["gun"] = _actor_numbers(actor, true)
				instances.append(growth)
				represented += 1
				dps += _actor_dps(actor)
		turrets.back()["instances"] = instances
		dps += maxi(0, count - represented) * float(stats["damage"]) * rate
	var max_hull := PlayerStatsService.get_player_max_health(float(world.difficulty_config["player_health_mult"]))
	var items: Array[Dictionary] = []
	for item_id: String in ItemTrackingService.item_counts:
		items.append({"id": item_id, "name": str(ItemRegistry.get_item_dict(item_id)["name"]), "count": int(ItemTrackingService.item_counts[item_id])})
	var hero_stats := PlayerStatsService.get_weapon_stats(world.run_config.hero, false).duplicate(true)
	world.item_effects.modify_stats(hero_stats, 0, "kinetic" in world.run_config.hero.families)
	return {"hero_weapon": hero_stats, "turrets": turrets, "dps": dps, "max_hull": max_hull, "hull": minf(world.player.health, max_hull),
		"speed": PlayerStatsService.get_player_speed() * WorldGeometry.METRES_PER_PIXEL,
		"pickup": PlayerStatsService.get_pickup_radius() * WorldGeometry.METRES_PER_PIXEL, "items": items}

static func _actor_numbers(actor: TurretActor, secondary: bool = false) -> Dictionary:
	var values := actor.resolve_attack_stats(secondary)
	var stats := TurretStats.new(values)
	var pulse := TurretRegistry.get_fire_mode(actor.turret_type) in [TurretRegistry.FIRE_PULSE, TurretRegistry.FIRE_FLAME] and not secondary
	var reach := stats.range_metres * (stats.area_size if pulse else 1.0)
	return {"damage": stats.damage, "range": reach, "fire_rate": stats.fire_rate,
		"burst_size": maxi(1, actor.progression.evolution_stage) if secondary else ([2, 3, 5][actor.progression.evolution_stage - 1] if actor.progression.evolution_branch == "repeater_bow" else 1),
		"rotation_rate": float(values.get("rotation_rate", 0.0)), "area": reach if pulse else stats.aoe_radius_metres,
		"stats": {"pierce": stats.pierce, "projectile_speed": stats.projectile_speed_metres,
		"knockback": stats.knockback_metres, "chain_count": stats.chain_count,
		"chain_decay": stats.chain_decay * 100.0, "slow": stats.slow_intensity * 100.0,
		"slow_duration": stats.slow_duration, "rehit_delay": stats.rehit_delay if values.has("rehit_delay") else 0.0}}

## Single-target estimate; splash, chains, penetration and ricochets depend on enemy arrangement.
static func _actor_dps(actor: TurretActor) -> float:
	var stats := TurretStats.new(actor.resolve_attack_stats())
	var rate := stats.fire_rate
	var branch := actor.progression.evolution_branch
	var stage := actor.progression.evolution_stage
	if actor.turret_type == "melee":
		var blades := stage if branch == "saber" else 1
		rate = minf(stats.rotation_rate * blades / 360.0, 1.0 / maxf(.01, stats.rehit_delay))
	elif branch == "repeater_bow":
		var arrows: int = [2, 3, 5][stage - 1]
		rate = float(arrows) / (stats.cooldown_seconds + .09 * (arrows - 1))
	elif branch == "machine_gun" and stage >= 2:
		rate *= 1.0 + actor.spool
	var result := stats.damage * rate
	if actor.turret_type == "flamethrower":
		result += stats.damage * float(stats.values.get("burn_ratio", 1.6)) * minf(1.0, rate * float(stats.values.get("burn_duration", 2.0)))
	if branch == "gunblade":
		var gun := TurretStats.new(actor.resolve_attack_stats(true))
		var shots := maxi(1, stage)
		result += gun.damage * float(shots) / (gun.cooldown_seconds + .065 * (shots - 1))
	return result

## build_data after buying `offer`. Items are measured by adding their modifiers to the real modifier
## system for the duration of this call and removing them again, so the numbers come from the same
## code that applies the purchase, including static ownership conditions. Situational rules remain text.
static func preview(world: ArenaWorld, offer: ShopOffer) -> Dictionary:
	# Local simulation uses the same stat resolver, including owned-item and family conditions.
	# Restore dictionaries synchronously; no signals, purchases, RNG or cached actor stats are touched.
	var owned_items := ItemTrackingService.item_counts.duplicate()
	var owned_turrets := TurretStatsService.turret_counts.duplicate()
	var system := ModifierService.state.modifiers
	var ids: Array[String] = []
	if offer.kind == "turret":
		TurretStatsService.turret_counts[offer.asset_id] = int(owned_turrets.get(offer.asset_id, 0)) + 1
	else:
		ItemTrackingService.item_counts[offer.asset_id] = int(owned_items.get(offer.asset_id, 0)) + 1
		for modifier: Dictionary in ItemRegistry.get_modifiers(offer.asset_id):
			var entry := modifier.duplicate(true)
			entry["id"] = "preview_%s_%d" % [offer.asset_id, ids.size()]
			ids.append(entry["id"])
			system.add_modifier(entry)
	var data := build_data(world)
	for modifier_id in ids:
		system.remove_modifier(modifier_id)
	ItemTrackingService.item_counts.assign(owned_items)
	TurretStatsService.turret_counts.assign(owned_turrets)
	return data

static func affected_turrets(world: ArenaWorld, offer: ShopOffer) -> Array[String]:
	var result: Array[String] = []
	var before := build_data(world)
	var after := preview(world, offer)
	for turret: Dictionary in after["turrets"]:
		var old: Dictionary = {}
		for candidate: Dictionary in before["turrets"]:
			if candidate["id"] == turret["id"]:
				old = candidate
		var affected: bool = old.is_empty() or old != turret
		# Conditional effects do not pretend to have a permanently active numeric bonus.
		if offer.asset_id == "reactor_overload":
			affected = "aoe" in TurretRegistry.get_attack_families(turret["id"])
		elif offer.asset_id == "storm_conductor":
			affected = "instant" in TurretRegistry.get_attack_families(turret["id"])
		elif offer.asset_id == "last_stand":
			affected = true
		elif offer.asset_id in ["opening_salvo", "return_address", "slipstream_fletching"]:
			affected = "projectile" in TurretRegistry.get_attack_families(turret["id"]) or turret["id"] == "melee" and _has_gunblade(world)
		elif offer.asset_id in ["follow_through", "counterweight", "victory_lap"]:
			affected = "kinetic" in TurretRegistry.get_attack_families(turret["id"])
		elif offer.asset_id == "cinder_reserve":
			affected = TurretRegistry.get_fire_mode(turret["id"]) == TurretRegistry.FIRE_FLAME
		elif offer.asset_id == "arc_insurance":
			affected = TurretRegistry.get_fire_mode(turret["id"]) == TurretRegistry.FIRE_CHAIN
		elif offer.asset_id in ["rescue_beacon", "close_partnership"]:
			affected = true
		if affected:
			result.append("%s x%d" % [turret["name"], int(turret["count"])])
	return result

static func _has_gunblade(world: ArenaWorld) -> bool:
	for turret in world.turrets:
		if turret.progression.evolution_branch == "gunblade":
			return true
	return false
