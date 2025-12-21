extends Node

## Modifier Service Autoload
## Singleton wrapper around ModifierSystem for global access

var active_modifiers: Array = []


func add_modifier(modifier: Dictionary) -> Dictionary:
	active_modifiers.append(modifier)
	return modifier


func remove_modifier(modifier_id: String) -> bool:
	for i in range(active_modifiers.size() - 1, -1, -1):
		if active_modifiers[i].get("id", "") == modifier_id:
			active_modifiers.remove_at(i)
			return true
	return false


func clear_modifiers() -> void:
	active_modifiers.clear()


func apply_modifiers_to_stat(base_value: float, stat_name: String) -> float:
	var add_value: float = 0.0
	var mult_values: Array[float] = []

	for modifier in active_modifiers:
		if modifier.get("stat", "") != stat_name:
			continue

		var operation = modifier.get("operation", "add")
		var value = modifier.get("value", 0.0)

		if operation == "add":
			add_value += value
		elif operation == "multiply":
			mult_values.append(value)

	var result = base_value + add_value
	for mult in mult_values:
		result *= mult

	return result
