class_name EpicItems
extends RefCounted

## Epic tier items (Rarity: EPIC, Base Price: 160)
## 7 items total - all with significant impact

static func get_all() -> Dictionary:
	return {
		"shrapnel_rounds": _create_shrapnel_rounds(),
		"glass_cannon_core": _create_glass_cannon_core(),
		"executioners_mark": _create_executioners_mark(),
		"plasma_destabilizer": _create_plasma_destabilizer(),
		"war_profiteer": _create_war_profiteer(),
		"quantity_discount": _create_quantity_discount(),
		"mono_type_mastery": _create_mono_type_mastery(),
		"personal_space": _create_personal_space(),
		"fortunes_favor": _create_fortunes_favor(),
	}


static func _create_shrapnel_rounds() -> Item:
	var item := Item.new()
	item.item_id = "shrapnel_rounds"
	item.name = "Shrapnel Rounds"
	item.icon = "💥"
	item.description = "Projectiles pierce through 1 additional enemy"
	item.rarity = GameEnums.ItemRarity.EPIC
	item.modifiers = [
		Item.create_modifier("pierce", "add", 1, Item.filter_attack_style([GameEnums.AttackStyle.PROJECTILE]))
	]
	return item


static func _create_glass_cannon_core() -> Item:
	var item := Item.new()
	item.item_id = "glass_cannon_core"
	item.name = "Glass Cannon Core"
	item.icon = "💎"
	item.description = "ALL turrets deal 40% more damage. You have 50% less health."
	item.rarity = GameEnums.ItemRarity.EPIC
	item.max_stacks = 1
	item.modifiers = [
		Item.create_modifier("damage", "multiply", 1.4, Item.filter_turret_type(["all"])),
		Item.create_modifier("player_max_health", "multiply", 0.5)
	]
	return item


static func _create_executioners_mark() -> Item:
	var item := Item.new()
	item.item_id = "executioners_mark"
	item.name = "Executioner's Mark"
	item.icon = "☠️"
	item.description = "Turrets deal 50% bonus damage to enemies below 25% health"
	item.rarity = GameEnums.ItemRarity.EPIC
	item.special_effect = "executioner"
	item.modifiers = []
	return item


static func _create_plasma_destabilizer() -> Item:
	var item := Item.new()
	item.item_id = "plasma_destabilizer"
	item.name = "Plasma Destabilizer"
	item.icon = "💥"
	item.description = "Plasma turrets +80% knockback and +25% explosion radius. -20% projectile speed, -15% fire rate"
	item.rarity = GameEnums.ItemRarity.EPIC
	item.modifiers = [
		Item.create_modifier("knockback_force", "multiply", 1.80, Item.filter_damage_type([GameEnums.DamageType.PLASMA])),
		Item.create_modifier("aoe_radius", "multiply", 1.25, Item.filter_damage_type([GameEnums.DamageType.PLASMA])),
		Item.create_modifier("projectile_speed", "multiply", 0.80, Item.filter_damage_type([GameEnums.DamageType.PLASMA])),
		Item.create_modifier("fire_rate", "multiply", 0.85, Item.filter_damage_type([GameEnums.DamageType.PLASMA]))
	]
	return item


static func _create_war_profiteer() -> Item:
	var item := Item.new()
	item.item_id = "war_profiteer"
	item.name = "War Profiteer"
	item.icon = "💵"
	item.description = "Wave completion bonus scrap +100%. Shop prices +25%"
	item.rarity = GameEnums.ItemRarity.EPIC
	item.max_stacks = 1
	item.modifiers = [
		Item.create_modifier("wave_bonus_mult", "multiply", 2.0),
		Item.create_modifier("shop_price_mult", "multiply", 1.25)
	]
	return item


static func _create_quantity_discount() -> Item:
	var item := Item.new()
	item.item_id = "quantity_discount"
	item.name = "Quantity Discount"
	item.icon = "💲"
	item.description = "Every 3rd turret purchased costs only 50% of its calculated price"
	item.rarity = GameEnums.ItemRarity.EPIC
	item.max_stacks = 1
	item.special_effect = "quantity_discount"
	item.modifiers = []
	return item


static func _create_mono_type_mastery() -> Item:
	var item := Item.new()
	item.item_id = "mono_type_mastery"
	item.name = "Mono-Type Mastery"
	item.icon = "👑"
	item.description = "If you own only ONE turret type, those turrets gain +100% damage and +50% fire rate"
	item.rarity = GameEnums.ItemRarity.EPIC
	item.max_stacks = 1
	item.special_effect = "mono_type_mastery"
	item.modifiers = []
	return item


static func _create_personal_space() -> Item:
	var item := Item.new()
	item.item_id = "personal_space"
	item.name = "Personal Space"
	item.icon = "⭕"
	item.description = "Minimum turret distance increased to 200px. All turrets +35% damage and +20% range"
	item.rarity = GameEnums.ItemRarity.EPIC
	item.max_stacks = 1
	item.special_effect = "personal_space"
	item.modifiers = [
		Item.create_modifier("damage", "multiply", 1.35),
		Item.create_modifier("range", "multiply", 1.20)
	]
	return item


static func _create_fortunes_favor() -> Item:
	var item := Item.new()
	item.item_id = "fortunes_favor"
	item.name = "Fortune's Favor"
	item.icon = "⭐"
	item.description = "+40 luck. Rare+ items cost 15% less."
	item.rarity = GameEnums.ItemRarity.EPIC
	item.max_stacks = 1
	item.modifiers = [
		Item.create_modifier("player_luck", "add", 0.40)
	]
	item.special_effect = "fortune_discount"
	return item
