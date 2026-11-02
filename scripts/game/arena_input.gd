class_name ArenaInput
extends RefCounted

## Unhandled-input routing for the arena: the preparation phase first, then pause, interact, restart, range rings, camera zoom
## and the gamepad buttons. `ArenaWorld._unhandled_input` forwards here.
var world: ArenaWorld

func handle(event: InputEvent) -> void:
	if world.preparation and world.preparation.handle_input(event):
		world.get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_range") and not event.is_echo() and GameStateService.is_game_active:
		world.toggle_ranges()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE: world.toggle_pause()
			KEY_E: world.interact()
			KEY_R:
				if not GameStateService.is_game_active:
					world.start_run()
	if event is InputEventMouseButton and event.pressed and world.camera_rig:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			world.camera_rig.zoom_steps(1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			world.camera_rig.zoom_steps(-1.0)
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START:
			world.toggle_pause()
		elif event.button_index == JOY_BUTTON_A:
			world.interact()
