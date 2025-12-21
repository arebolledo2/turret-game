class_name Item
extends Resource

## Base class for all items in the game
## Uses Godot Resource system for type safety and editor integration

@export var item_id: String = ""
@export var name: String = ""
@export var icon: String = ""
@export_multiline var description: String = ""
@export var rarity: GameEnums.ItemRarity = GameEnums.ItemRarity.COMMON
@export var max_stacks: int = 0  ## 0 = unlimited stacking
@export var always_show_description: bool = false
@export var special_effect: String = ""  ## ID for special effect logic

## Array of modifier dictionaries
## Each modifier: {"stat": String, "operation": String, "value": float, "filter": Dictionary}
@export var modifiers: Array[Dictionary] = []


## Helper to create a modifier dictionary
static func create_modifier(stat: String, operation: String, value: float, filter: Dictionary = {}) -> Dictionary:
	return {
		"stat": stat,
		"operation": operation,
		"value": value,
		"filter": filter
	}


## Helper to create turret type filter
static func filter_turret_type(types: Array) -> Dictionary:
	return {"turret_type": types}


## Helper to create damage type filter
static func filter_damage_type(types: Array) -> Dictionary:
	return {"damage_type": types}


## Helper to create attack style filter
static func filter_attack_style(styles: Array) -> Dictionary:
	return {"attack_style": styles}


## Convert this Item resource to the legacy Dictionary format for backward compatibility
func to_dict() -> Dictionary:
	var dict := {
		"name": name,
		"icon": icon,
		"description": description,
		"rarity": rarity,
		"modifiers": modifiers,
	}

	if max_stacks > 0:
		dict["max_stacks"] = max_stacks

	if always_show_description:
		dict["always_show_description"] = always_show_description

	if not special_effect.is_empty():
		dict["special_effect"] = special_effect

	return dict
