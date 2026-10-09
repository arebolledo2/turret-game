class_name ItemsV2
extends RefCounted

## Phase 2 item pool: commons and uncommons from the item proposal. Entries here override same-id items in the tier files.
## Roles: commons are small trades (two near-free, two weak); uncommons set build direction (Doctrines and specialists).
## Doctrine shape: one family +25% damage, every other turret -8%.

const OTHERS_OF: Dictionary = {
	"ion": ["plasma", "electric", "melee"],
	"plasma": ["ion", "electric", "melee"],
	"electric": ["ion", "plasma", "melee"],
	"melee": ["ion", "plasma", "electric"],
}

static func get_all() -> Dictionary:
	var items: Array[Item] = []

	# ---- Common ------------------------------------------------------------------------------------------------
	items.append(_item("scrap_magnet", "Scrap Magnet", "🧲", "ECON", GameEnums.ItemRarity.COMMON, [
		Item.create_modifier("pickup_radius", "increase", 0.2)], "+20% pickup radius."))
	items.append(_item("polished_barrels", "Polished Barrels", "🔫", "ION", GameEnums.ItemRarity.COMMON, [
		_dmg(.10, ["ion"])], "Ion turrets +10% damage."))
	items.append(_item("blast_charges", "Blast Charges", "💥", "PLASMA", GameEnums.ItemRarity.COMMON, [
		_stat("aoe_radius", .12, ["plasma"]), _stat("knockback_force", .08, ["plasma"]), _stat("fire_rate", -.03, ["plasma"])],
		"Plasma +12% splash radius and +8% knockback, -3% fire rate."))
	items.append(_item("capacitor_bank", "Capacitor Bank", "🔋", "ELECTRIC", GameEnums.ItemRarity.COMMON, [
		_dmg(.08, ["electric"]), _stat("range", -.03, ["electric"])], "Electric +8% damage, -3% range."))
	items.append(_item("weighted_bat", "Weighted Bat", "🏏", "MELEE", GameEnums.ItemRarity.COMMON, [
		_dmg(.12, ["melee"]), _stat("rotation_rate", -.08, ["melee"])], "Melee +12% damage, -8% spin rate."))
	items.append(_item("quick_loader", "Quick Loader", "⏱️", "ANY", GameEnums.ItemRarity.COMMON, [
		_all("fire_rate", .07), _all("damage", -.03)], "+7% fire rate, -3% damage."))
	items.append(_item("dense_rounds", "Dense Rounds", "🔩", "ANY", GameEnums.ItemRarity.COMMON, [
		_all("damage", .07), _all("fire_rate", -.03)], "+7% damage, -3% fire rate."))
	items.append(_item("concrete_footings", "Concrete Footings", "🧱", "TALL", GameEnums.ItemRarity.COMMON, [
		Item.create_modifier("entrench_stack_seconds", "increase", -.15), Item.create_modifier("carry_speed", "increase", -.10)],
		"Entrench stacks arrive 15% faster, carrying a turret is 10% slower.", 3))
	items.append(_item("static_grounding", "Static Grounding", "🌩️", "ELECTRIC", GameEnums.ItemRarity.COMMON, [
		_stat("slow_intensity", .10, ["shock"], "add", "turret_type"), _stat("slow_duration", .2, ["shock"], "add", "turret_type"), _dmg(-.04, ["electric"])],
		"Shock slow +10 points stronger and +0.2s longer, Electric -4% damage."))
	items.append(_item("faulty_wiring", "Faulty Wiring", "🔌", "ANY", GameEnums.ItemRarity.COMMON, [
		_all("fire_rate", .10), _all("damage", -.03)], "+10% fire rate, -3% damage."))

	# ---- Uncommon: Doctrines -------------------------------------------------------------------------------------
	items.append(_doctrine("ion_doctrine", "Ion Doctrine", "🗼", "ION", "ion"))
	items.append(_doctrine("plasma_doctrine", "Plasma Doctrine", "💠", "PLASMA", "plasma"))
	items.append(_doctrine("voltage_doctrine", "Voltage Doctrine", "⚡", "ELECTRIC", "electric"))
	items.append(_doctrine("bat_doctrine", "Bat Doctrine", "⚔️", "MELEE", "melee"))

	# ---- Uncommon: specialists -----------------------------------------------------------------------------------
	items.append(_item("piercing_rounds", "Piercing Rounds", "➶", "ION", GameEnums.ItemRarity.UNCOMMON, [
		_stat("pierce", 1, ["ion"], "add"), _dmg(-.10, ["ion"])], "Ion shots pass through 1 extra enemy, Ion -10% damage.", 2))
	items.append(_item("cluster_warheads", "Cluster Warheads", "🎇", "PLASMA", GameEnums.ItemRarity.UNCOMMON, [
		_stat("aoe_radius", .30, ["plasma"]), _stat("projectile_speed", -.20, ["plasma"])], "Plasma +30% splash radius, orbs 20% slower.", 2))
	items.append(_item("superconductors", "Superconductors", "🧲", "ELECTRIC", GameEnums.ItemRarity.UNCOMMON, [
		_stat("chain_count", 1, ["tesla"], "add", "turret_type"), _stat("slow_intensity", .25, ["shock"], "increase", "turret_type"),
		_stat("fire_rate", -.12, ["electric"])], "Tesla +1 chain jump, Shock slow 25% stronger, Electric -12% fire rate.", 2))
	items.append(_item("spiked_bat", "Spiked Bat", "🦔", "MELEE", GameEnums.ItemRarity.UNCOMMON, [
		_stat("knockback_force", .40, ["melee"]), _stat("range", .20, ["melee"]), _stat("rotation_rate", -.12, ["melee"])],
		"Melee +40% knockback and +20% reach, -12% spin rate.", 2))
	items.append(_item("hardpoint", "Hardpoint", "🏗️", "TALL", GameEnums.ItemRarity.UNCOMMON, [
		Item.create_modifier("entrench_max_stacks", "add", 2), Item.create_modifier("entrench_bonus", "increase", .5),
		Item.create_modifier("carry_speed", "increase", -.25)], "Entrench max stacks +2 and +50% bonus per stack, carrying a turret is 25% slower.", 2))

	# ---- Convoy (only stocked in Convoy runs; see ShopCatalog.CONVOY_ONLY) ----------------------------------------------
	items.append(_item("tracked_chassis", "Tracked Chassis", "🛞", "CONVOY", GameEnums.ItemRarity.COMMON, [
		Item.create_modifier("core_move_speed", "increase", .15)], "Core drives 15% faster.", 3))
	items.append(_item("overdrive_engine", "Overdrive Engine", "🏎️", "CONVOY", GameEnums.ItemRarity.UNCOMMON, [
		Item.create_modifier("core_move_speed", "increase", .30), _all("fire_rate", -.05)],
		"Core drives 30% faster, all turrets -5% fire rate.", 2))
	items.append(_item("heavy_hauler", "Heavy Hauler", "🚛", "CONVOY", GameEnums.ItemRarity.UNCOMMON, [
		Item.create_modifier("core_move_speed", "increase", -.20), Item.create_modifier("scrap_earn_mult", "increase", .15)],
		"Core drives 20% slower (longer rounds, more enemies), +15% scrap from kills.", 2))

	# ---- Rare -----------------------------------------------------------------------------------------------------
	var rare := GameEnums.ItemRarity.RARE
	items.append(_item("arc_rod", "Arc Rod", "🌩️", "ELECTRIC", rare, [
		_stat("chain_count", 2, ["tesla"], "add", "turret_type"), _stat("chain_decay", .15, ["tesla"], "add", "turret_type"),
		_dmg(-.15, ["tesla"], "turret_type")], "Tesla +2 chain jumps and chain decay 0.70 to 0.85, Tesla -15% damage.", 2))
	items.append(_item("plasma_capacitor", "Plasma Capacitor", "🔆", "PLASMA", rare, [
		_stat("aoe_radius", .60, ["plasma"]), _stat("knockback_force", .50, ["plasma"]), _stat("fire_rate", -.10, ["plasma"])],
		"Plasma +60% splash radius and +50% knockback, -10% fire rate.", 2))
	items.append(_item("killzone_bat", "Killzone Bat", "🔪", "MELEE", rare, [
		_stat("rehit_delay", -.5, ["melee"]), _stat("knockback_force", -.25, ["melee"])],
		"Melee hits the same enemy twice as often, -25% knockback.", 2))
	items.append(_item("overwatch_optics", "Overwatch Optics", "🔭", "ION", rare, [
		_stat("range", .30, ["ion"]), _dmg(.10, ["ion"]), _stat("fire_rate", -.10, ["ion"])],
		"Ion +30% range and +10% damage, -10% fire rate.", 2))
	items.append(_special("army_doctrine", "Army Doctrine", "🪖", "WIDE", rare, "army_doctrine", [
		_all("range", -.10)], "+3% fire rate per turret beyond the 3rd (max +30%), all turrets -10% range.", 1))
	items.append(_item("last_stand", "Last Stand", "🩸", "HULL", rare, [
		Item.create_modifier("last_stand_fire_rate", "add", .4), Item.create_modifier("player_max_health", "increase", -.2)],
		"Below 30% hull, turrets fire 40% faster. -20% max hull.", 1))

	# ---- Epic -----------------------------------------------------------------------------------------------------
	var epic := GameEnums.ItemRarity.EPIC
	items.append(_item("reactor_overload", "Reactor Overload", "☢️", "PLASMA", epic, [
		Item.create_modifier("reactor_overload", "add", 1), _dmg(-.20, ["plasma"])],
		"Plasma kills explode for 40% of the killing damage in 60% of the radius, and those kills chain. Plasma -20% damage.", 1))
	items.append(_item("storm_conductor", "Storm Conductor", "⛈️", "ELECTRIC", epic, [
		Item.create_modifier("storm_link_damage", "add", .35), _stat("range", -.15, ["electric"])],
		"Shock and Tesla turrets within 4 m of another Electric turret deal +35% damage. Electric -15% range.", 1))

	# ---- Legendary ------------------------------------------------------------------------------------------------
	var legendary := GameEnums.ItemRarity.LEGENDARY
	items.append(_special("elemental_conduit", "Elemental Conduit", "🌀", "WIDE", legendary, "elemental_conduit", [],
		"All turrets +15% damage per turret family owned (max +60% with Ion, Plasma, Electric and Melee).", 1))
	items.append(_item("whirlwind_frame", "Whirlwind Frame", "🌪️", "MELEE", legendary, [
		_stat("rotation_rate", 1.0, ["melee"]), _stat("range", .50, ["melee"]),
		_stat("slow_intensity", .25, ["melee"], "add", "family"), _stat("slow_duration", .5, ["melee"], "add"),
		_dmg(-.30, ["ion", "plasma", "electric"])],
		"Bat spin rate doubled, reach +50%, hits slow 25% for 0.5s. All other turrets -30% damage.", 1))

	var result: Dictionary = {}
	for item in items:
		result[item.item_id] = item
	return result


static func _item(id: String, display_name: String, icon: String, tag: String, rarity: GameEnums.ItemRarity,
		modifiers: Array, description: String, stacks: int = 0) -> Item:
	var item := Item.new()
	item.item_id = id
	item.name = display_name
	item.icon = icon
	item.tag = tag
	item.rarity = rarity
	item.description = description
	item.max_stacks = stacks
	for modifier in modifiers:
		item.modifiers.append(modifier)
	return item

static func _special(id: String, display_name: String, icon: String, tag: String, rarity: GameEnums.ItemRarity,
		effect: String, modifiers: Array, description: String, stacks: int) -> Item:
	var item := _item(id, display_name, icon, tag, rarity, modifiers, description, stacks)
	item.special_effect = effect
	return item

static func _doctrine(id: String, display_name: String, icon: String, tag: String, family: String) -> Item:
	return _item(id, display_name, icon, tag, GameEnums.ItemRarity.UNCOMMON, [
		_dmg(.25, [family]), _dmg(-.08, OTHERS_OF[family])],
		"%s turrets +25%% damage, every other turret -8%%." % family.capitalize(), 2)

static func _dmg(amount: float, families: Array, filter_key: String = "family") -> Dictionary:
	return _stat("damage", amount, families, "increase", filter_key)

## Increase (or `operation`) on `stat` for turrets in `families`; `filter_key` "turret_type" lists turret ids instead.
static func _stat(stat: String, amount: float, families: Array, operation: String = "increase", filter_key: String = "family") -> Dictionary:
	var filter := {"turret_type": families} if filter_key == "turret_type" else Item.filter_family(families)
	return Item.create_modifier(stat, operation, amount, filter)

static func _all(stat: String, amount: float) -> Dictionary:
	return Item.create_modifier(stat, "increase", amount, Item.filter_turret_type(["all"]))
