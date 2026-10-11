extends Node
func _ready() -> void:
	var world := ArenaWorld.new()
	world.auto_start = false
	add_child(world)
	world.start_run()
	world.set_physics_process(false)
	world.present_wave_rewards = false
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	world.drops.queue_item("dense_rounds")
	world.drops.queue_item("scrap_magnet")
	world.finish_wave()
	await get_tree().create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.test-results/chest-reward.png"))
	get_tree().quit()
