class_name ShopViewData
extends RefCounted

## Structured shop data for the shop screen: stat chips per offer, the build as numbers (not text), and
## a "what if I buy this" copy of that build. ArenaShop keeps the text forms for logs and tests.

## Game stat key -> [UI stat key, icon name, lower_is_better].
const STAT_UI: Dictionary = {
	"area_size": ["range", "area", false], "attack_speed": ["rate", "rate", false],
	"damage": ["dmg", "damage", false], "fire_rate": ["rate", "rate", false], "range": ["range", "range", false],
	"rotation_rate": ["rate", "rate", false], "projectile_speed": ["speed", "speed", false],
	"aoe_radius": ["range", "area", false], "knockback_force": ["dmg", "knockback", false],
	"chain_count": ["dmg", "chain", false], "slow_intensity": ["slow", "slow", false],
	"slow_duration": ["slow", "slow", false], "player_speed": ["speed", "speed", false],
	"carry_speed": ["speed", "carry", false], "core_move_speed": ["speed", "core_speed", false],
	"player_max_health": ["hull", "hull", false], "player_health_regen": ["hull", "repair", false],
	"pickup_radius": ["pickup", "pickup", false], "reroll_cost": ["scrap", "reroll", true],
	"turret_penalty_reduction": ["penalty", "penalty", true], "shop_price_mult": ["scrap", "penalty", true],
	"scrap_earn_mult": ["scrap", "scrap", false], "enemy_count_mult": ["kills", "kills", true],
	"player_luck": ["scrap", "star", false], "turret_crit_chance": ["dmg", "kills", false],
	"player_crit_chance": ["dmg", "kills", false], "entrench_stack_seconds": ["rate", "timer", true],
	"entrench_max_stacks": ["rate", "entrench_cap", false], "entrench_bonus": ["rate", "entrench", false],
	"pierce": ["dmg", "pierce", false], "chain_decay": ["dmg", "chain", false], "rehit_delay": ["rate", "rate", true],
	"turret_penalty_increase": ["penalty", "penalty", true], "last_stand_fire_rate": ["rate", "rate", false],
	"reactor_overload": ["dps", "damage", false], "storm_link_damage": ["dmg", "damage", false],
}

## Stat chips for one offer: [{stat, icon, text, tone, families}]. `families` lists the attack families a
## family-scoped modifier is limited to (empty: it applies to everything). Special-effect items return none
## (their rules are text only); the card falls back to the description for those.
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
		var families: Array = modifier.get("filter", {}).get("attack_family", [])
		chips.append({"stat": ui[0], "icon": ui[1], "tone": 1 if better else -1, "families": families.duplicate(),
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
			"utility": TurretRegistry.is_no_attack(type_id), "interval": 1.0 / maxf(rate, TurretStats.MIN_FIRE_RATE),
			"deploys": TurretRegistry.get_fire_mode(type_id) == TurretRegistry.FIRE_DEPLOY,
			"beam": TurretRegistry.get_fire_mode(type_id) == TurretRegistry.FIRE_BEAM,
			"drones": _drone_count(type_id, stats),
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
				if actor.has_barrel():
					growth["gun"] = _actor_numbers(actor, true)
				instances.append(growth)
				represented += 1
				dps += _actor_dps(actor)
		turrets.back()["instances"] = instances
		dps += maxi(0, count - represented) * float(stats["damage"]) * rate * float(maxi(_drone_count(type_id, stats), 1))
	var max_hull := PlayerStatsService.get_player_max_health(float(world.difficulty_config["player_health_mult"]))
	var items: Array[Dictionary] = []
	for item_id: String in ItemTrackingService.item_counts:
		items.append({"id": item_id, "name": str(ItemRegistry.get_item_dict(item_id)["name"]), "count": int(ItemTrackingService.item_counts[item_id])})
	var hero_stats := PlayerStatsService.get_weapon_stats(world.run_config.hero, false).duplicate(true)
	world.item_effects.modify_stats(hero_stats, 0, "kinetic" in world.run_config.hero.families)
	return {"hero_weapon": hero_stats, "turrets": turrets, "dps": dps, "max_hull": max_hull, "hull": minf(world.player.health, max_hull),
		"speed": PlayerStatsService.get_player_speed() * WorldGeometry.METRES_PER_PIXEL,
		"pickup": PlayerStatsService.get_pickup_radius() * WorldGeometry.METRES_PER_PIXEL,
		"luck": PlayerStatsService.get_player_luck(), "items": items}

static func _actor_numbers(actor: TurretActor, secondary: bool = false) -> Dictionary:
	var values := actor.resolve_attack_stats(secondary)
	var stats := TurretStats.new(values)
	var pulse := TurretRegistry.get_fire_mode(actor.turret_type) in [TurretRegistry.FIRE_PULSE, TurretRegistry.FIRE_FLAME] and not secondary
	var reach := stats.range_metres * (stats.area_size if pulse else 1.0)
	return {"damage": stats.damage, "range": reach, "fire_rate": stats.fire_rate,
		"utility": TurretRegistry.is_no_attack(actor.turret_type), "interval": stats.cooldown_seconds,
		"deploys": TurretRegistry.get_fire_mode(actor.turret_type) == TurretRegistry.FIRE_DEPLOY,
		"beam": TurretRegistry.get_fire_mode(actor.turret_type) == TurretRegistry.FIRE_BEAM,
		"drones": _drone_count(actor.turret_type, values),
		"burst_size": TurretEvolution.barrel_burst(actor.progression.evolution_form) if secondary else TurretEvolution.volley_size(actor.progression.evolution_form),
		"rotation_rate": float(values.get("rotation_rate", 0.0)), "area": reach if pulse else stats.aoe_radius_metres,
		"stats": {"pierce": stats.pierce, "projectile_speed": stats.projectile_speed_metres,
		"knockback": stats.knockback_metres, "chain_count": stats.chain_count,
		"chain_decay": stats.chain_decay * 100.0, "slow": stats.slow_intensity * 100.0,
		"slow_duration": stats.slow_duration, "rehit_delay": stats.rehit_delay if values.has("rehit_delay") else 0.0}}

## How many drones a Drone Bay's stats keep up (0 for every other turret): the shop shows it beside the per-drone damage and rate.
static func _drone_count(type_id: String, stats: Dictionary) -> int:
	if TurretRegistry.get_fire_mode(type_id) != TurretRegistry.FIRE_DRONES:
		return 0
	return clampi(int(stats.get("drone_count", 2)), 1, DroneBayForm.MAX_PER_BAY)

static func _actor_dps(actor: TurretActor) -> float:
	return TurretForm.dps_of(actor)

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
		var situational := _situational(world, offer, turret["id"])
		if situational >= 0:
			affected = situational == 1
		if affected:
			result.append("%s x%d" % [turret["name"], int(turret["count"])])
	return result

## Conditional effects do not pretend to have a permanently active numeric bonus, so their reach is a
## rule: 1 the offer applies to this turret type, 0 it does not, -1 no rule (compare the numbers instead).
static func _situational(world: ArenaWorld, offer: ShopOffer, type_id: String) -> int:
	var families := TurretRegistry.get_attack_families(type_id)
	match offer.asset_id:
		"reactor_overload":
			return int("aoe" in families)
		"storm_conductor":
			return int("instant" in families)
		"opening_salvo", "return_address", "slipstream_fletching":
			return int("projectile" in families or type_id == "melee" and _has_gunblade(world))
		"follow_through", "counterweight", "victory_lap":
			return int("kinetic" in families)
		"cinder_reserve":
			return int(TurretRegistry.get_fire_mode(type_id) == TurretRegistry.FIRE_FLAME)
		"arc_insurance":
			return int(TurretRegistry.get_fire_mode(type_id) == TurretRegistry.FIRE_CHAIN)
		"last_stand", "rescue_beacon", "close_partnership", "lone_sentry", "crosslink_array":
			return 1
	# Entrenchment is not part of the combat numbers; it helps every turret that can hold position.
	if offer.kind != "item":
		return -1
	for modifier: Dictionary in ItemRegistry.get_modifiers(offer.asset_id):
		if str(modifier["stat"]).begins_with("entrench_"):
			return int(not TurretRegistry.is_no_attack(type_id))
	return -1

## Numbers the squad cards compare: key -> [icon, lower_is_better]. Keys under "stats" are nested.
const IMPACT_KEYS: Dictionary = {
	"damage": ["damage", false], "fire_rate": ["rate", false], "rotation_rate": ["rate", false],
	"range": ["range", false], "area": ["area", false], "interval": ["timer", true],
	"pierce": ["pierce", false], "projectile_speed": ["speed", false], "knockback": ["knockback", false],
	"chain_count": ["chain", false], "chain_decay": ["chain", false], "slow": ["slow", false],
	"slow_duration": ["slow", false], "rehit_delay": ["rate", true],
}

## What buying `offer` does to each deployed turret and the hero, for the squad highlight. Keyed by
## turret_id (int) and "hero": {tone: 1 helps, -1 hurts, 0 mixed; changes: [{icon, text, tone}];
## situational: true when a rule rather than a number says it applies}. Unaffected entries are left out.
## `before`/`after` may be passed in when the caller already has build_data and preview for this offer.
static func turret_impacts(world: ArenaWorld, offer: ShopOffer, before: Dictionary = {}, after: Dictionary = {}) -> Dictionary:
	var result := {}
	if offer.sold:
		return result
	if before.is_empty():
		before = build_data(world)
	if after.is_empty():
		after = preview(world, offer)
	for turret: Dictionary in after["turrets"]:
		var old: Dictionary = {}
		for candidate: Dictionary in before["turrets"]:
			if candidate["id"] == turret["id"]:
				old = candidate
		var situational := _situational(world, offer, turret["id"])
		for actor in world.turrets:
			if actor.turret_type != turret["id"]:
				continue
			var now: Dictionary = turret
			var was: Dictionary = old
			for growth: Dictionary in turret.get("instances", []):
				if growth["id"] == actor.turret_id:
					now = growth["combat"]
			for growth: Dictionary in old.get("instances", []):
				if growth["id"] == actor.turret_id:
					was = growth["combat"]
			var changes := _changes(was, now)
			if situational == 0:
				continue
			if changes.is_empty() and situational != 1:
				continue
			result[actor.turret_id] = _impact(changes, situational == 1 and changes.is_empty())
			result[actor.turret_id]["icon"] = _rule_icon(offer)
	var hero := _changes(before["hero_weapon"], after["hero_weapon"])
	for spec: Array in [["max_hull", "hull"], ["speed", "speed"], ["pickup", "pickup"], ["luck", "star"]]:
		hero.append_array(_changes({spec[0]: before[spec[0]]}, {spec[0]: after[spec[0]]}, spec[1]))
	if not hero.is_empty():
		result["hero"] = _impact(hero, false)
	return result

## Icon for an impact that a rule rather than a number describes: entrenchment, or a plain check.
static func _rule_icon(offer: ShopOffer) -> String:
	if offer.kind == "item":
		for modifier: Dictionary in ItemRegistry.get_modifiers(offer.asset_id):
			if str(modifier["stat"]).begins_with("entrench_"):
				return "entrench"
	return "check"

static func _impact(changes: Array[Dictionary], situational: bool) -> Dictionary:
	var tone := 1
	if not changes.is_empty():
		var tones := changes.map(func(c: Dictionary) -> int: return c["tone"])
		tone = 1 if tones.min() > 0 else -1 if tones.max() < 0 else 0
	return {"tone": tone, "changes": changes, "situational": situational}

## Changed numbers between two stat dictionaries (top level and the nested "stats" block).
static func _changes(was: Dictionary, now: Dictionary, icon_override: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if was.is_empty():
		return result
	var pairs: Array = [[was, now]]
	if was.has("stats") and now.has("stats"):
		pairs.append([was["stats"], now["stats"]])
	for pair: Array in pairs:
		for key: String in (pair[1] as Dictionary):
			var spec: Array = IMPACT_KEYS.get(key, [icon_override, false])
			if str(spec[0]).is_empty() or not (pair[0] as Dictionary).has(key):
				continue
			var old_value: Variant = pair[0][key]
			var new_value: Variant = pair[1][key]
			if not (old_value is float or old_value is int) or is_equal_approx(float(old_value), float(new_value)):
				continue
			var delta := float(new_value) - float(old_value)
			var better := delta < 0.0 if bool(spec[1]) else delta > 0.0
			var text := "%+.0f%%" % (delta / float(old_value) * 100.0) if not is_zero_approx(float(old_value)) else "%+.0f" % delta
			if old_value is int:
				text = "%+d" % int(delta)
			result.append({"key": key, "icon": spec[0], "text": text, "tone": 1 if better else -1})
	return result

static func _has_gunblade(world: ArenaWorld) -> bool:
	for turret in world.turrets:
		if turret.has_barrel():
			return true
	return false
