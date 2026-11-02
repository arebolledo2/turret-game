class_name ShopDetailText
extends RefCounted

## The text the shop's detail pane shows: the growth summary, the hero weapon and turret before/after numbers, and which offers need
## a turret. Pure functions of the view data (`ShopViewData`) and the run; `ShopScreen` only puts the results into its labels.

static func growth_summary(world: ArenaWorld) -> String:
	if not world.session.state.turret_progression_enabled:
		return "Turret growth is OFF for this run."
	var ledger := world.salvage.last_settlement
	if ledger.is_empty() or int(ledger.get("wave", -1)) != GameStateService.current_wave:
		return "Turret growth is ON · Scrap left on the floor becomes XP at wave end."
	if int(ledger["raw_scrap"]) == 0:
		return "Turret growth · +0 XP — no scrap was left on the floor."
	if int(ledger["xp_awarded"]) == 0:
		return "Turret growth · No turrets to receive XP; salvage returned %d scrap." % ledger["fallback_cash"]
	var levels := 0
	for change: Dictionary in ledger["changes"].values():
		levels += int(change["after"]["level"]) - int(change["before"]["level"])
	var text := "Turret growth · +%d XP from leftover scrap · %d %s gained" % [
		ledger["xp_awarded"], levels, "level" if levels == 1 else "levels"]
	if float(ledger.get("abandoned", 0.0)) > 0.0:
		text += "\nAbandoned scrap · scrap earned +%d%% for the rest of the run" % roundi(float(ledger["abandon_bonus"]) * 100.0)
	return text

static func needs_turret(offer: ShopOffer) -> bool:
	if offer.kind == "turret":
		return true
	for modifier: Dictionary in ItemRegistry.get_modifiers(offer.asset_id):
		if modifier.get("filter", {}).has("attack_family"):
			return true
	return offer.asset_id in ["reactor_overload", "storm_conductor", "mono_type_mastery", "elemental_conduit"]

## One BBCode block per hero weapon and turret: `data` is the build now, `after` the build with the selected offer applied.
static func turret_report(world: ArenaWorld, data: Dictionary, after: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("[b]Hero weapon · %s[/b]\n%s damage · %s shots/s\n%s m reach" % [
		", ".join(world.run_config.hero.families).capitalize(),
		number(data.hero_weapon, after.hero_weapon, "damage", ""),
		number(data.hero_weapon, after.hero_weapon, "fire_rate", ""),
		"%.2f" % (float(after.hero_weapon.range) * WorldGeometry.METRES_PER_PIXEL)])
	for turret: Dictionary in after["turrets"]:
		var was: Dictionary = {}
		for old: Dictionary in data["turrets"]:
			if old["id"] == turret["id"]:
				was = old
		var instances: Array = turret.get("instances", [])
		if instances.is_empty():
			lines.append("[b]%s ×%d[/b]\n%s" % [turret["name"], turret["count"], turret_numbers(was, turret)])
			continue
		for growth: Dictionary in instances:
			var current: Dictionary = growth["combat"]
			var previous: Dictionary = {}
			var previous_gun: Dictionary = {}
			for old_growth: Dictionary in was.get("instances", []):
				if old_growth["id"] == growth["id"]:
					previous = old_growth["combat"]
					previous_gun = old_growth.get("gun", {})
			var caption := "[b]%s #%d · Lv %d[/b]" % [growth["name"], growth["id"], growth["level"]]
			caption += "\nXP %d / %d toward Lv %d" % [growth["xp"], growth["next_cost"], int(growth["level"]) + 1]
			var change: Dictionary = world.salvage.last_settlement.get("changes", {}).get(growth["id"], {})
			if not change.is_empty() and int(world.salvage.last_settlement.get("wave", -1)) == GameStateService.current_wave:
				caption += "\n[color=#8be0c9]+%d XP this wave" % change["xp_awarded"]
				if change["after"]["level"] > change["before"]["level"]:
					caption += " · Lv %d → %d" % [change["before"]["level"], change["after"]["level"]]
				caption += "[/color]"
			lines.append(caption + "\n" + turret_numbers(previous, current))
			if growth.has("gun"):
				lines.append("[b]Gun · Projectile[/b]\n" + turret_numbers(previous_gun, growth["gun"]))
		if int(turret["count"]) > instances.size():
			lines.append("[b]%s · New Lv 1 turret[/b]\n%s" % [turret["name"], turret_numbers({}, turret)])
	return "\n\n".join(lines)

static func turret_numbers(was: Dictionary, turret: Dictionary) -> String:
	if bool(turret.get("utility", false)):
		# A turret that does not attack (the Scrap Press): damage and shots per second mean nothing for it.
		return "No attack · " + number(was, turret, "interval", " s per drop", true) + "\n" + number(was, turret, "range", " m drop reach")
	var cadence_key := "rotation_rate" if turret["rotation_rate"] > 0 else "fire_rate"
	var cadence_unit := "°/s sweep" if cadence_key == "rotation_rate" else (" mines/s" if bool(turret.get("deploys", false)) else (" ticks/s" if bool(turret.get("beam", false)) else " shots/s"))
	if cadence_key == "fire_rate" and int(turret.get("burst_size", 1)) > 1:
		cadence_unit = " bursts/s (%d shots)" % int(turret["burst_size"])
	if cadence_key == "fire_rate" and int(turret.get("drones", 0)) > 0:
		cadence_unit = " shots/s each · %d drones" % int(turret["drones"])
	var numbers := number(was, turret, "damage", " damage") + " · " + number(was, turret, cadence_key, cadence_unit)
	numbers += "\n" + number(was, turret, "range", " m reach")
	if turret["area"] > 0:
		numbers += " · " + number(was, turret, "area", " m area")
	for spec: Array in [["pierce", " pierce"], ["projectile_speed", " m/s projectile"], ["chain_count", " chain jumps"],
		["chain_decay", "% chain damage retained"], ["slow", "% slow strength"], ["slow_duration", " s slow"],
		["rehit_delay", " s rehit"], ["knockback", " m knockback"]]:
		if not was.is_empty() and not is_equal_approx(float(was["stats"][spec[0]]), float(turret["stats"][spec[0]])):
			numbers += "\n" + number(was["stats"], turret["stats"], spec[0], spec[1], spec[0] == "rehit_delay")
	return numbers

## Explicit before/after numbers; colour reinforces the direction without carrying meaning alone.
static func number(before: Dictionary, after: Dictionary, key: String, unit: String, lower_is_better: bool = false) -> String:
	var value := float(after.get(key, 0))
	var old := float(before.get(key, value))
	var format := "%.1f" if key == "damage" else "%.2f"
	if is_equal_approx(old, value):
		return (format % value) + unit
	var better := value < old if lower_is_better else value > old
	return "[color=#%s]%s → %s%s[/color]" % ["8be0c9" if better else "ff9b8c", format % old, format % value, unit]
