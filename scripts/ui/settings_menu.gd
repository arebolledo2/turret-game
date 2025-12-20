class_name SettingsMenuUI
extends RefCounted

## Handles settings menu display and interactions

var container: Control
var show_damage_check: CheckButton
var show_hitboxes_check: CheckButton
var back_button: Button
var _owner: Node


func setup(nodes: Dictionary, owner: Node) -> void:
	container = nodes.get("container")
	show_damage_check = nodes.get("show_damage_check")
	show_hitboxes_check = nodes.get("show_hitboxes_check")
	back_button = nodes.get("back_button")
	_owner = owner

	# Initialize checkbox state
	if show_damage_check:
		show_damage_check.button_pressed = Globals.show_damage_numbers
	if show_hitboxes_check:
		show_hitboxes_check.button_pressed = Globals.show_debug_hitboxes


func show() -> void:
	if container:
		container.modulate.a = 0.0
		container.visible = true
		var tween = _owner.create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(container, "modulate:a", 1.0, 0.15)
		if show_damage_check:
			show_damage_check.grab_focus()


func hide() -> void:
	if container:
		container.visible = false


func on_show_damage_toggled(toggled_on: bool) -> void:
	Globals.show_damage_numbers = toggled_on


func on_show_hitboxes_toggled(toggled_on: bool) -> void:
	Globals.show_debug_hitboxes = toggled_on
	Events.hitbox_debug_toggled.emit(toggled_on)
