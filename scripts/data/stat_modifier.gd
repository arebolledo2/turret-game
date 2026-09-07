class_name StatModifier
extends RefCounted

## Typed internal record; dictionaries are copied only at the public boundary.
var id: String
var stat: String
var operation: String
var value: float
var filter: Dictionary
var _source: Dictionary

func _init(data: Dictionary) -> void:
	_source = data.duplicate(true)
	id = str(data.get("id", ""))
	stat = str(data.get("stat", ""))
	operation = str(data.get("operation", "add"))
	if operation == "multiply":
		operation = "more"
	value = float(data.get("value", 0.0))
	filter = data.get("filter", {}).duplicate(true)

func to_dictionary() -> Dictionary:
	return _source.duplicate(true)
