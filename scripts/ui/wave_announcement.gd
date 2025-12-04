class_name WaveAnnouncementUI
extends RefCounted

## Handles wave announcement overlay display

var container: Control
var label: Label
var _owner: Node  # Reference to parent for creating tweens


func setup(nodes: Dictionary, owner: Node) -> void:
	container = nodes.get("container")
	label = nodes.get("label")
	_owner = owner


func show_announcement(wave_number: int) -> void:
	if container and label:
		label.text = "Wave %d" % wave_number
		container.visible = true

		# Animate in
		container.modulate.a = 0.0
		container.scale = Vector2(0.5, 0.5)
		var tween = _owner.create_tween()
		tween.set_parallel(true)
		tween.tween_property(container, "modulate:a", 1.0, 0.3)
		tween.tween_property(container, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func hide_announcement() -> void:
	if container:
		var tween = _owner.create_tween()
		tween.tween_property(container, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func(): container.visible = false)
