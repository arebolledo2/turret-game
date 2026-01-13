class_name UncommonItems
extends RefCounted

## Uncommon tier items (Rarity: UNCOMMON, Base Price: 70)
## 8 items total

static func get_all() -> Dictionary:
	return {
		# Interesting
		"overcharged_cells": _create_overcharged_cells(),
		"kinetic_enhancer": _create_kinetic_enhancer(),
		"combat_surplus": _create_combat_surplus(),

		# Trade-offs
		"extended_barrel": _create_extended_barrel(),
		"heavy_plating": _create_heavy_plating(),
		"rapid_coolant": _create_rapid_coolant(),
		"nimble_servos": _create_nimble_servos(),

		# Army size strategy
		"mass_production": _create_mass_production(),

		# Turret variety
		"diversity_matrix": _create_diversity_matrix(),

		# Proximity
		"signal_amplifier": _create_signal_amplifier(),
	}


static func _create_overcharged_cells() -> Item:
	var item := Item.new()
	item.item_id = "overcharged_cells"
	item.name = "Overcharged Cells"
	item.icon = "⚡"
	item.description = "Electric turrets deal 30% more damage but chain to fewer targets"
	item.rarity = GameEnums.ItemRarity.UNCOMMON
	item.modifiers = [
		Item.create_modifier("damage", "increase", 0.3, Item.filter_damage_type([GameEnums.DamageType.ELECTRIC])),
		Item.create_modifier("chain_count", "add", -1, Item.filter_turret_type(["tesla"]))
	]
	return item


static func _create_kinetic_enhancer() -> Item:
	var item := Item.new()
	item.item_id = "kinetic_enhancer"
	item.name = "Kinetic Enhancer"
	item.icon = "⚙️"
	item.description = "Physical turrets +25% damage. Electric turrets -10% damage"
	item.rarity = GameEnums.ItemRarity.UNCOMMON
	item.modifiers = [
		Item.create_modifier("damage", "increase", 0.25, Item.filter_damage_type([GameEnums.DamageType.PHYSICAL])),
		Item.create_modifier("damage", "increase", -0.10, Item.filter_damage_type([GameEnums.DamageType.ELECTRIC]))
	]
	return item


static func _create_combat_surplus() -> Item:
	var item := Item.new()
	item.item_id = "combat_surplus"
	item.name = "Combat Surplus"
	item.icon = "📦"
	item.description = "Waves spawn +15% more enemies. Scrap per enemy +25%"
	item.rarity = GameEnums.ItemRarity.UNCOMMON
	item.modifiers = [
		Item.create_modifier("enemy_count_mult", "increase", 0.15),
		Item.create_modifier("scrap_earn_mult", "increase", 0.25)
	]
	return item


static func _create_extended_barrel() -> Item:
	var item := Item.new()
	item.item_id = "extended_barrel"
	item.name = "Extended Barrel"
	item.icon = "📏"
	item.description = "+15% turret range, but 10% slower fire rate"
	item.rarity = GameEnums.ItemRarity.UNCOMMON
	item.modifiers = [
		Item.create_modifier("range", "increase", 0.15, Item.filter_turret_type(["all"])),
		Item.create_modifier("fire_rate", "increase", -0.10, Item.filter_turret_type(["all"]))
	]
	return item


static func _create_heavy_plating() -> Item:
	var item := Item.new()
	item.item_id = "heavy_plating"
	item.name = "Heavy Plating"
	item.icon = "🪨"
	item.description = "+20 max HP, but 8% slower movement"
	item.rarity = GameEnums.ItemRarity.UNCOMMON
	item.modifiers = [
		Item.create_modifier("player_max_health", "add", 5.0),
		Item.create_modifier("player_speed", "increase", -0.08)
	]
	return item


static func _create_rapid_coolant() -> Item:
	var item := Item.new()
	item.item_id = "rapid_coolant"
	item.name = "Rapid Coolant"
	item.icon = "❄️"
	item.description = "+15% fire rate, but 10% reduced range"
	item.rarity = GameEnums.ItemRarity.UNCOMMON
	item.modifiers = [
		Item.create_modifier("fire_rate", "increase", 0.15, Item.filter_turret_type(["all"])),
		Item.create_modifier("range", "increase", -0.10, Item.filter_turret_type(["all"]))
	]
	return item


static func _create_nimble_servos() -> Item:
	var item := Item.new()
	item.item_id = "nimble_servos"
	item.name = "Nimble Servos"
	item.icon = "🦿"
	item.description = "+8% movement speed, but 5% less turret damage"
	item.rarity = GameEnums.ItemRarity.UNCOMMON
	item.modifiers = [
		Item.create_modifier("player_speed", "increase", 0.08),
		Item.create_modifier("damage", "increase", -0.05, Item.filter_turret_type(["all"]))
	]
	return item


static func _create_mass_production() -> Item:
	var item := Item.new()
	item.item_id = "mass_production"
	item.name = "Mass Production"
	item.icon = "🏭"
	item.description = "Turret purchase penalty reduced from 25% to 15% per turret. All turrets -10% damage"
	item.rarity = GameEnums.ItemRarity.UNCOMMON
	item.max_stacks = 2
	item.modifiers = [
		Item.create_modifier("turret_penalty_reduction", "add", -0.10),
		Item.create_modifier("damage", "increase", -0.10, Item.filter_turret_type(["all"]))
	]
	return item


static func _create_diversity_matrix() -> Item:
	var item := Item.new()
	item.item_id = "diversity_matrix"
	item.name = "Diversity Matrix"
	item.icon = "🔷"
	item.description = "For each different turret type owned, all turrets gain +8% damage (max +48%). Penalty +5% per turret"
	item.rarity = GameEnums.ItemRarity.UNCOMMON
	item.max_stacks = 2
	item.special_effect = "diversity_matrix"
	item.modifiers = [
		Item.create_modifier("turret_penalty_increase", "add", 0.05)
	]
	return item


static func _create_signal_amplifier() -> Item:
	var item := Item.new()
	item.item_id = "signal_amplifier"
	item.name = "Signal Amplifier"
	item.icon = "📡"
	item.description = "Turrets within 200px of another turret +15% range. Isolated turrets -10% fire rate"
	item.rarity = GameEnums.ItemRarity.UNCOMMON
	item.special_effect = "signal_amplifier"
	item.modifiers = []
	return item
