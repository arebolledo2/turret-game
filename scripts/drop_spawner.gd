extends Node

# Listens for enemy deaths and spawns scrap drops

var scrap_drop_scene: PackedScene

func _ready() -> void:
	scrap_drop_scene = preload("res://scenes/scrap_drop.tscn")
	Events.scrap_dropped.connect(_on_scrap_dropped)

func _on_scrap_dropped(position: Vector2, amount: int) -> void:
	if scrap_drop_scene == null:
		return

	# Defer spawn to avoid physics callback error
	call_deferred("_spawn_scrap_drop", position, amount)

func _spawn_scrap_drop(position: Vector2, amount: int) -> void:
	var drop := scrap_drop_scene.instantiate()
	drop.global_position = position
	drop.scrap_value = amount

	var drop_container = get_node_or_null("../DropContainer")
	if drop_container:
		drop_container.add_child(drop)
	else:
		get_parent().add_child(drop)
