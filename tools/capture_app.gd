extends Node

## Render the actual application shell and its settings, pause and end states.
func _ready() -> void:
	var app := preload("res://scenes/main.tscn").instantiate() as GameApp
	add_child(app)
	await get_tree().process_frame
	await capture("start")
	app.show_settings()
	await capture("settings")
	app.show_home()
	app.start_game()
	await get_tree().process_frame
	app.arena.toggle_pause()
	await capture("pause")
	app.arena.toggle_pause()
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
	app.arena.player.take_damage(1000)
	await capture("defeat")
	app.arena.start_run()
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
	GameStateService.current_wave = 6
	app.arena.finish_wave()
	await capture("victory")
	app.return_to_menu()
	await capture("returned")
	print("APP_CAPTURE_COMPLETE")
	get_tree().quit()

func capture(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "res://.test-results/app-%s.png" % label
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("APP_CAPTURE ", label)
