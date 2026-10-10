extends Node

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.test-results"))
	var rows: Array = []
	for id in ShopCatalog.ids("item"):
		var item := ItemRegistry.get_item(id)
		rows.append({"id": id, "name": item.name, "rarity": int(item.rarity), "description": item.description,
			"modifiers": item.modifiers, "special_effect": item.special_effect, "max_stacks": item.max_stacks})
	var file := FileAccess.open("res://.test-results/shop-catalog.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "\t"))
	get_tree().quit()
