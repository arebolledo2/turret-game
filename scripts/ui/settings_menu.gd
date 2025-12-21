class_name SettingsMenuUI
extends RefCounted

## Handles settings menu display and interactions

var container: Control
var show_damage_check: CheckButton
var physics_hitboxes_check: CheckButton
var player_hurtbox_check: CheckButton
var enemy_hurtbox_check: CheckButton
var player_attack_check: CheckButton
var back_button: Button
var _owner: Node


func setup(nodes: Dictionary, owner: Node) -> void:
	container = nodes.get("container")
	show_damage_check = nodes.get("show_damage_check")
	physics_hitboxes_check = nodes.get("physics_hitboxes_check")
	player_hurtbox_check = nodes.get("player_hurtbox_check")
	enemy_hurtbox_check = nodes.get("enemy_hurtbox_check")
	player_attack_check = nodes.get("player_attack_check")
	back_button = nodes.get("back_button")
	_owner = owner

	# Initialize checkbox states
	if show_damage_check:
		show_damage_check.button_pressed = Globals.show_damage_numbers
	
	if physics_hitboxes_check:
		physics_hitboxes_check.button_pressed = Globals.debug_hitbox_flags[Globals.HitboxType.PHYSICS]
	if player_hurtbox_check:
		player_hurtbox_check.button_pressed = Globals.debug_hitbox_flags[Globals.HitboxType.PLAYER_HURTBOX]
	if enemy_hurtbox_check:
		enemy_hurtbox_check.button_pressed = Globals.debug_hitbox_flags[Globals.HitboxType.ENEMY_HURTBOX]
	if player_attack_check:
		player_attack_check.button_pressed = Globals.debug_hitbox_flags[Globals.HitboxType.PLAYER_ATTACK]


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


func on_hitbox_type_toggled(type: int, toggled_on: bool) -> void:
	Globals.debug_hitbox_flags[type] = toggled_on
	Events.hitbox_debug_toggled.emit(type, toggled_on)


# Legacy function kept for transition if needed, but not used by new UI
func on_show_hitboxes_toggled(toggled_on: bool) -> void:
	# Toggle all for convenience if this is called
	for type in Globals.HitboxType.values():
		on_hitbox_type_toggled(type, toggled_on)
