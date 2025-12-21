class_name CommonItems
extends RefCounted

## Common tier items (Rarity: COMMON, Base Price: 40)
## 20 items total - mix of interesting and trade-off items

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
		# DAMAGE TYPE SPECIALIZATION
		# ==========================================================================

		"shielded_capacitors": _create_shielded_capacitors(),
		"heat_vents": _create_heat_vents(),
		"ballistic_plating": _create_ballistic_plating(),
		"plasma_coils": _create_plasma_coils(),

		# ==========================================================================
		# ECONOMY & UTILITY
		# ==========================================================================

		"budget_capacitor": _create_budget_capacitor(),
		"ammo_surplus": _create_ammo_surplus(),
		"targeting_subroutine": _create_targeting_subroutine(),
		"overclock_module": _create_overclock_module(),
		"compact_design": _create_compact_design(),
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
	item.description = "+15% gold from enemy kills"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.modifiers = [
		Item.create_modifier("gold_earn_mult", "multiply", 1.15)
	]
	return item


static func _create_lucky_charm() -> Item:
	var item := Item.new()
	item.item_id = "lucky_charm"
	item.name = "Lucky Charm"
	item.icon = "🍀"
	item.description = "+10 luck. Better items may appear in shops."
	item.rarity = GameEnums.ItemRarity.COMMON
	item.modifiers = [
		Item.create_modifier("player_luck", "add", 0.10)
	]
	return item


static func _create_efficient_scavenger() -> Item:
	var item := Item.new()
	item.item_id = "efficient_scavenger"
	item.name = "Efficient Scavenger"
	item.icon = "🪙"
	item.description = "+30% gold from enemy kills"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.modifiers = [
		Item.create_modifier("gold_earn_mult", "multiply", 1.30)
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
		Item.create_modifier("player_max_health", "add", 15.0),
		Item.create_modifier("player_speed", "multiply", 0.97)
	]
	return item


static func _create_quick_loader() -> Item:
	var item := Item.new()
	item.item_id = "quick_loader"
	item.name = "Quick Loader"
	item.icon = "⏱️"
	item.description = "+10% fire rate, but 3% less damage"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.modifiers = [
		Item.create_modifier("fire_rate", "multiply", 1.10, Item.filter_turret_type(["all"])),
		Item.create_modifier("damage", "multiply", 0.97, Item.filter_turret_type(["all"]))
	]
	return item


static func _create_shock_absorbers() -> Item:
	var item := Item.new()
	item.item_id = "shock_absorbers"
	item.name = "Shock Absorbers"
	item.icon = "🏃"
	item.description = "+10% movement speed, but -5 max HP"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.modifiers = [
		Item.create_modifier("player_speed", "multiply", 1.10),
		Item.create_modifier("player_max_health", "add", -5.0)
	]
	return item


static func _create_dense_rounds() -> Item:
	var item := Item.new()
	item.item_id = "dense_rounds"
	item.name = "Dense Rounds"
	item.icon = "🔩"
	item.description = "+10% damage, but 2% slower fire rate"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.modifiers = [
		Item.create_modifier("damage", "multiply", 1.10, Item.filter_turret_type(["all"])),
		Item.create_modifier("fire_rate", "multiply", 0.98, Item.filter_turret_type(["all"]))
	]
	return item


# ==========================================================================
# DAMAGE TYPE SPECIALIZATION
# ==========================================================================

static func _create_shielded_capacitors() -> Item:
	var item := Item.new()
	item.item_id = "shielded_capacitors"
	item.name = "Shielded Capacitors"
	item.icon = "⚡"
	item.description = "Electric turrets gain +15% fire rate but -5% range"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.modifiers = [
		Item.create_modifier("fire_rate", "multiply", 1.15, Item.filter_damage_type([GameEnums.DamageType.ELECTRIC])),
		Item.create_modifier("range", "multiply", 0.95, Item.filter_damage_type([GameEnums.DamageType.ELECTRIC]))
	]
	return item


static func _create_heat_vents() -> Item:
	var item := Item.new()
	item.item_id = "heat_vents"
	item.name = "Heat Vents"
	item.icon = "🔥"
	item.description = "Fire turrets gain +12% range but -8% fire rate"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.modifiers = [
		Item.create_modifier("range", "multiply", 1.12, Item.filter_damage_type([GameEnums.DamageType.FIRE])),
		Item.create_modifier("fire_rate", "multiply", 0.92, Item.filter_damage_type([GameEnums.DamageType.FIRE]))
	]
	return item


static func _create_ballistic_plating() -> Item:
	var item := Item.new()
	item.item_id = "ballistic_plating"
	item.name = "Ballistic Plating"
	item.icon = "🛡️"
	item.description = "Physical turrets gain +10% damage but -5% projectile speed"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.modifiers = [
		Item.create_modifier("damage", "multiply", 1.10, Item.filter_damage_type([GameEnums.DamageType.PHYSICAL])),
		Item.create_modifier("projectile_speed", "multiply", 0.95, Item.filter_damage_type([GameEnums.DamageType.PHYSICAL]))
	]
	return item


static func _create_plasma_coils() -> Item:
	var item := Item.new()
	item.item_id = "plasma_coils"
	item.name = "Plasma Coils"
	item.icon = "💠"
	item.description = "Plasma turrets gain +8% projectile speed and fire rate, -6% damage"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.modifiers = [
		Item.create_modifier("projectile_speed", "multiply", 1.08, Item.filter_damage_type([GameEnums.DamageType.PLASMA])),
		Item.create_modifier("fire_rate", "multiply", 1.08, Item.filter_damage_type([GameEnums.DamageType.PLASMA])),
		Item.create_modifier("damage", "multiply", 0.94, Item.filter_damage_type([GameEnums.DamageType.PLASMA]))
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
	item.description = "Reroll costs reduced by 20%. All turrets have -5% fire rate"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.modifiers = [
		Item.create_modifier("reroll_cost", "multiply", 0.80),
		Item.create_modifier("fire_rate", "multiply", 0.95, Item.filter_turret_type(["all"]))
	]
	return item


static func _create_ammo_surplus() -> Item:
	var item := Item.new()
	item.item_id = "ammo_surplus"
	item.name = "Ammo Surplus"
	item.icon = "📦"
	item.description = "Projectile turrets gain +8% fire rate but -5% damage"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.modifiers = [
		Item.create_modifier("fire_rate", "multiply", 1.08, Item.filter_attack_style([GameEnums.AttackStyle.PROJECTILE])),
		Item.create_modifier("damage", "multiply", 0.95, Item.filter_attack_style([GameEnums.AttackStyle.PROJECTILE]))
	]
	return item


static func _create_targeting_subroutine() -> Item:
	var item := Item.new()
	item.item_id = "targeting_subroutine"
	item.name = "Targeting Subroutine"
	item.icon = "🎯"
	item.description = "All turrets gain +12% rotation speed but -6% range"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.modifiers = [
		Item.create_modifier("rotation_speed", "multiply", 1.12, Item.filter_turret_type(["all"])),
		Item.create_modifier("range", "multiply", 0.94, Item.filter_turret_type(["all"]))
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
	item.icon = "📐"
	item.description = "Turret purchase penalty reduced by 3% per turret. All turrets -4% range"
	item.rarity = GameEnums.ItemRarity.COMMON
	item.max_stacks = 3
	item.modifiers = [
		Item.create_modifier("turret_penalty_reduction", "add", -0.03),
		Item.create_modifier("range", "multiply", 0.96, Item.filter_turret_type(["all"]))
	]
	return item
