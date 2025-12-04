class_name DifficultySelectUI
extends RefCounted

## Handles difficulty selection screen

var container: Control
var easy_button: Button
var _owner: Node


func setup(nodes: Dictionary, owner: Node) -> void:
	container = nodes.get("container")
	easy_button = nodes.get("easy_button")
	_owner = owner


func show() -> void:
	if container:
		container.visible = true
		container.modulate.a = 0.0
		var tween = _owner.create_tween()
		tween.tween_property(container, "modulate:a", 1.0, 0.3)
		if easy_button:
			easy_button.grab_focus()


func hide_and_emit(difficulty: Globals.Difficulty) -> void:
	if container:
		var tween = _owner.create_tween()
		tween.tween_property(container, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func():
			container.visible = false
			Events.difficulty_selected.emit(difficulty)
		)
