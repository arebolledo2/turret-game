class_name CommonItems
extends RefCounted

## Common tier items (Rarity: COMMON, Base Price: 40)
## Mix of interesting and trade-off items

static func get_all() -> Dictionary:
	return {
		# ==========================================================================
		# INTERESTING COMMONS
		# ==========================================================================

		"scrap_magnet": _create_scrap_magnet(),
		"salvage_optimizer": _create_salvage_optimizer(),
		"lucky_charm": _create_lucky_charm(),
		"efficient_scavenger": _create_efficient_scavenger(),

		# ==========================================================================
		# TRADE-OFF COMMONS (Stats with drawbacks)
		# ==========================================================================

		"reinforced_hull": _create_reinforced_hull(),
		"quick_loader": _create_quick_loader(),
		"shock_absorbers": _create_shock_absorbers(),
		"dense_rounds": _create_dense_rounds(),

		# ==========================================================================
		# ECONOMY & UTILITY
		# ==========================================================================

		"budget_capacitor": _create_budget_capacitor(),
		"ammo_surplus": _create_ammo_surplus(),
		"overclock_module": _create_overclock_module(),
		"compact_design": _create_compact_design(),

		# ==========================================================================
		# HEALTH REGEN ITEMS
		# ==========================================================================

		"regenerative_plating": _create_regenerative_plating(),
		"nanite_injector": _create_nanite_injector(),

		# ==========================================================================
		# CRIT CHANCE ITEMS
		# ==========================================================================

		"precision_lens": _create_precision_lens(),
		"lucky_shot_module": _create_lucky_shot_module(),

		# ==========================================================================
		# MULTI-STAT ITEMS (2 upsides, 1 downside)
		# ==========================================================================

		"adrenaline_core": _create_adrenaline_core(),
		"fortified_magazine": _create_fortified_magazine(),

		# ==========================================================================
		# COMPLEX TRADE-OFF ITEM (3 upsides, 2 downsides)
		# ==========================================================================

		"experimental_chassis": _create_experimental_chassis(),
	}


# ==========================================================================
# INTERESTING COMMONS
# ==========================================================================

static func _create_scrap_magnet() -> Item:
	var item := Item.new()
	item.item_id = "scrap_magnet"
	item.name = "Scrap Magnet"
	item.icon = "🧲"
	item.description = "Increases pickup radius by 30%"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.always_show_description = true
	item.modifiers = [
		Item.create_modifier("pickup_radius", "multiply", 1.3)
	]
	return item


static func _create_salvage_optimizer() -> Item:
	var item := Item.new()
	item.item_id = "salvage_optimizer"
	item.name = "Salvage Optimizer"
	item.icon = "💰"
	item.description = "+10% gold from enemy kills, but -2% turret damage"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.modifiers = [
		Item.create_modifier("gold_earn_mult", "multiply", 1.10),
		Item.create_modifier("damage", "multiply", 0.98, Item.filter_turret_type(["all"]))
	]
	return item


static func _create_lucky_charm() -> Item:
	var item := Item.new()
	item.item_id = "lucky_charm"
	item.name = "Lucky Charm"
	item.icon = "🍀"
	item.description = "+10 luck. Better items may appear in shops. -3% movement speed"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.modifiers = [
		Item.create_modifier("player_luck", "add", 0.10),
		Item.create_modifier("player_speed", "multiply", 0.97)
	]
	return item


static func _create_efficient_scavenger() -> Item:
	var item := Item.new()
	item.item_id = "efficient_scavenger"
	item.name = "Efficient Scavenger"
	item.icon = "🪙"
	item.description = "+15% gold from enemy kills, but -5 max HP"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.modifiers = [
		Item.create_modifier("gold_earn_mult", "multiply", 1.15),
		Item.create_modifier("player_max_health", "add", -1.0)
	]
	return item


# ==========================================================================
# TRADE-OFF COMMONS
# ==========================================================================

static func _create_reinforced_hull() -> Item:
	var item := Item.new()
	item.item_id = "reinforced_hull"
	item.name = "Reinforced Hull"
	item.icon = "🛡️"
	item.description = "+15 max HP, but 3% slower movement"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.modifiers = [
		Item.create_modifier("player_max_health", "add", 4.0),
		Item.create_modifier("player_speed", "multiply", 0.97)
	]
	return item


static func _create_quick_loader() -> Item:
	var item := Item.new()
	item.item_id = "quick_loader"
	item.name = "Quick Loader"
	item.icon = "⏱️"
	item.description = "+5% fire rate, but -2% damage"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.modifiers = [
		Item.create_modifier("fire_rate", "multiply", 1.05, Item.filter_turret_type(["all"])),
		Item.create_modifier("damage", "multiply", 0.98, Item.filter_turret_type(["all"]))
	]
	return item


static func _create_shock_absorbers() -> Item:
	var item := Item.new()
	item.item_id = "shock_absorbers"
	item.name = "Shock Absorbers"
	item.icon = "🏃"
	item.description = "+7% movement speed, but -3 max HP"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.modifiers = [
		Item.create_modifier("player_speed", "multiply", 1.07),
		Item.create_modifier("player_max_health", "add", -1.0)
	]
	return item


static func _create_dense_rounds() -> Item:
	var item := Item.new()
	item.item_id = "dense_rounds"
	item.name = "Dense Rounds"
	item.icon = "🔩"
	item.description = "+6% damage, but -2% fire rate"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.modifiers = [
		Item.create_modifier("damage", "multiply", 1.06, Item.filter_turret_type(["all"])),
		Item.create_modifier("fire_rate", "multiply", 0.98, Item.filter_turret_type(["all"]))
	]
	return item


# ==========================================================================
# ECONOMY & UTILITY
# ==========================================================================

static func _create_budget_capacitor() -> Item:
	var item := Item.new()
	item.item_id = "budget_capacitor"
	item.name = "Budget Capacitor"
	item.icon = "🔋"
	item.description = "Reroll costs reduced by 10%. -3% turret range"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.modifiers = [
		Item.create_modifier("reroll_cost", "multiply", 0.90),
		Item.create_modifier("range", "multiply", 0.97, Item.filter_turret_type(["all"]))
	]
	return item


static func _create_ammo_surplus() -> Item:
	var item := Item.new()
	item.item_id = "ammo_surplus"
	item.name = "Ammo Surplus"
	item.icon = "�"
	item.description = "Projectile turrets gain +6% fire rate but -3% damage"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.modifiers = [
		Item.create_modifier("fire_rate", "multiply", 1.06, Item.filter_attack_style([GameEnums.AttackStyle.PROJECTILE])),
		Item.create_modifier("damage", "multiply", 0.97, Item.filter_attack_style([GameEnums.AttackStyle.PROJECTILE]))
	]
	return item


static func _create_overclock_module() -> Item:
	var item := Item.new()
	item.item_id = "overclock_module"
	item.name = "Overclock Module"
	item.icon = "⚙️"
	item.description = "All turrets gain +6% fire rate and damage. You have -8% max health"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.modifiers = [
		Item.create_modifier("fire_rate", "multiply", 1.06, Item.filter_turret_type(["all"])),
		Item.create_modifier("damage", "multiply", 1.06, Item.filter_turret_type(["all"])),
		Item.create_modifier("player_max_health", "multiply", 0.92)
	]
	return item


static func _create_compact_design() -> Item:
	var item := Item.new()
	item.item_id = "compact_design"
	item.name = "Compact Design"
	item.icon = "�"
	item.description = "Turret purchase penalty reduced by 4% per turret. All turrets -4% range"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.max_stacks = 3
	item.modifiers = [
		Item.create_modifier("turret_penalty_reduction", "add", -0.04),
		Item.create_modifier("range", "multiply", 0.96, Item.filter_turret_type(["all"]))
	]
	return item


# ==========================================================================
# HEALTH REGEN ITEMS
# ==========================================================================

static func _create_regenerative_plating() -> Item:
	var item := Item.new()
	item.item_id = "regenerative_plating"
	item.name = "Regenerative Plating"
	item.icon = "💚"
	item.description = "+3 health regen, but -2% movement speed"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.modifiers = [
		Item.create_modifier("player_health_regen", "add", 3.0),
		Item.create_modifier("player_speed", "multiply", 0.98)
	]
	return item


static func _create_nanite_injector() -> Item:
	var item := Item.new()
	item.item_id = "nanite_injector"
	item.name = "Nanite Injector"
	item.icon = "💉"
	item.description = "+2 health regen, but -10 max HP"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.modifiers = [
		Item.create_modifier("player_health_regen", "add", 2.0),
		Item.create_modifier("player_max_health", "add", -3.0)
	]
	return item


# ==========================================================================
# CRIT CHANCE ITEMS
# ==========================================================================

static func _create_precision_lens() -> Item:
	var item := Item.new()
	item.item_id = "precision_lens"
	item.name = "Precision Lens"
	item.icon = "🔬"
	item.description = "+5% player crit chance, but -2% fire rate"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.modifiers = [
		Item.create_modifier("player_crit_chance", "add", 0.05),
		Item.create_modifier("fire_rate", "multiply", 0.98, Item.filter_turret_type(["all"]))
	]
	return item


static func _create_lucky_shot_module() -> Item:
	var item := Item.new()
	item.item_id = "lucky_shot_module"
	item.name = "Lucky Shot Module"
	item.icon = "🎯"
	item.description = "+5% turret crit chance, but -4% turret damage"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.modifiers = [
		Item.create_modifier("turret_crit_chance", "add", 0.05),
		Item.create_modifier("damage", "multiply", 0.96, Item.filter_turret_type(["all"]))
	]
	return item


# ==========================================================================
# MULTI-STAT ITEMS (2 upsides, 1 downside)
# ==========================================================================

static func _create_adrenaline_core() -> Item:
	var item := Item.new()
	item.item_id = "adrenaline_core"
	item.name = "Adrenaline Core"
	item.icon = "💓"
	item.description = "+5% movement speed, +2% player crit chance, but -8 max HP"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.modifiers = [
		Item.create_modifier("player_speed", "multiply", 1.05),
		Item.create_modifier("player_crit_chance", "add", 0.02),
		Item.create_modifier("player_max_health", "add", -2.0)
	]
	return item


static func _create_fortified_magazine() -> Item:
	var item := Item.new()
	item.item_id = "fortified_magazine"
	item.name = "Fortified Magazine"
	item.icon = "🔰"
	item.description = "+5% turret damage, +1 health regen, but -4% fire rate"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.modifiers = [
		Item.create_modifier("damage", "multiply", 1.05, Item.filter_turret_type(["all"])),
		Item.create_modifier("player_health_regen", "add", 1.0),
		Item.create_modifier("fire_rate", "multiply", 0.96, Item.filter_turret_type(["all"]))
	]
	return item


# ==========================================================================
# COMPLEX TRADE-OFF ITEM (3 upsides, 2 downsides)
# ==========================================================================

static func _create_experimental_chassis() -> Item:
	var item := Item.new()
	item.item_id = "experimental_chassis"
	item.name = "Experimental Chassis"
	item.icon = "�"
	item.description = "+8% turret damage, +4% fire rate, +3% crit chance. -12 max HP, -6% movement speed"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.modifiers = [
		Item.create_modifier("damage", "multiply", 1.08, Item.filter_turret_type(["all"])),
		Item.create_modifier("fire_rate", "multiply", 1.04, Item.filter_turret_type(["all"])),
		Item.create_modifier("turret_crit_chance", "add", 0.03),
		Item.create_modifier("player_max_health", "add", -3.0),
		Item.create_modifier("player_speed", "multiply", 0.94)
	]
	return item
