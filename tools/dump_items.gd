extends Node

## Developer helper: prints every shop item (id, name, tag, description) for the icon pass.
func _ready() -> void:
	for id: String in ShopCatalog.entries["item"]:
		var d := ItemRegistry.get_item_dict(id)
		print("ITEM|%s|%s|%s|%s" % [id, d.get("name", ""), ItemRegistry.get_tag(id), d.get("description", "")])
	get_tree().quit()
