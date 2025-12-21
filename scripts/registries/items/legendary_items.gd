class_name LegendaryItems
extends RefCounted

## Legendary tier items (Rarity: LEGENDARY, Base Price: 240)
## 4 items total - game-changing effects

static func get_all() -> Dictionary:
	return {
		"elemental_conduit": _create_elemental_conduit(),
		"focused_investment": _create_focused_investment(),
		"synergy_core": _create_synergy_core(),
		"chain_reaction": _create_chain_reaction(),
	}


static func _create_elemental_conduit() -> Item:
	var item := Item.new()
	item.item_id = "elemental_conduit"
	item.name = "Elemental Conduit"
	item.icon = "🌀"
	item.description = "ALL turrets +15% damage per different damage type owned (max +60% with all 4 types)"
	item.rarity = GameEnums.ItemRarity.LEGENDARY
	item.max_stacks = 1
	item.special_effect = "elemental_conduit"
	item.modifiers = []
	return item


static func _create_focused_investment() -> Item:
	var item := Item.new()
	item.item_id = "focused_investment"
	item.name = "Focused Investment"
	item.icon = "🎯"
	item.description = "Your most numerous turret type gains +60% damage, +20% fire rate, +15% range. All others -20% damage"
	item.rarity = GameEnums.ItemRarity.LEGENDARY
	item.max_stacks = 1
	item.special_effect = "focused_investment"
	item.modifiers = []
	return item


static func _create_synergy_core() -> Item:
	var item := Item.new()
	item.item_id = "synergy_core"
	item.name = "Synergy Core"
	item.icon = "✨"
	item.description = "ALL turrets +12% damage per different turret type. +25% bonus if you own all 6 types (max +97%)"
	item.rarity = GameEnums.ItemRarity.LEGENDARY
	item.max_stacks = 1
	item.special_effect = "synergy_core"
	item.modifiers = []
	return item


static func _create_chain_reaction() -> Item:
	var item := Item.new()
	item.item_id = "chain_reaction"
	item.name = "Chain Reaction"
	item.icon = "⚡"
	item.description = "When a turret fires, turrets within 150px +8% fire rate for 2s (stacks 5x = +40%). All turrets -15% damage"
	item.rarity = GameEnums.ItemRarity.LEGENDARY
	item.max_stacks = 1
	item.special_effect = "chain_reaction"
	item.modifiers = [
		Item.create_modifier("damage", "multiply", 0.85)
	]
	return item
