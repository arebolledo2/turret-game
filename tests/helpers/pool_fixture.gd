extends Control

var pool_release: Callable

func _pool_released() -> void:
	scale = Vector2.ONE
	modulate = Color.WHITE
