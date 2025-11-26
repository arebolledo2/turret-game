extends Node

# Listens for enemy deaths and spawns XP drops

var xp_drop_scene: PackedScene

func _ready() -> void:
	xp_drop_scene = preload("res://scenes/xp_drop.tscn")
	Events.xp_dropped.connect(_on_xp_dropped)

func _on_xp_dropped(position: Vector2, amount: int) -> void:
	if xp_drop_scene == null:
		return
	
	var drop := xp_drop_scene.instantiate()
	drop.global_position = position
	drop.xp_value = amount
	
	var drop_container = get_node_or_null("../DropContainer")
	if drop_container:
		drop_container.add_child(drop)
	else:
		get_parent().add_child(drop)
