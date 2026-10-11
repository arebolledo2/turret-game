extends Node
var world: ArenaWorld
func _ready() -> void:
	world = ArenaWorld.new()
	world.auto_start = false
	world.run_config = RunConfig.slice()
	world.run_config.mode = RunConfig.MODE_CORE
	add_child(world)
	world.start_run()
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.camera_rig.set_physics_process(false)
	world.camera.position = Vector3(0, 12, 12)
	world.camera.look_at(Vector3.ZERO)
	world.camera.size = 11
	world.player.position = Vector3(1, 0, 1)
	world.show_ranges = true
	for item in ["follow_through", "victory_lap", "rescue_beacon", "close_partnership"]:
		world.shop.apply_item(item)
	world.turrets[0].position = Vector3(-3, 0, -1)
	var bat := world.add_turret(Vector3(1.8, 0, .3), "melee")
	var bow := world.add_turret(Vector3(3.5, 0, -2), "bow")
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	for turret in world.turrets:
		turret.set_physics_process(false)
		turret.entrench_stacks_cached = 2
		world.item_effects.grant(turret.turret_id, "rescue_beacon")
	for i in 4:
		world.item_effects.grant(bat.turret_id, "follow_through", 5)
	for i in 3:
		world.item_effects.grant(bat.turret_id, "victory_lap", 5)
	world.item_effects.grant(0, "rescue_beacon")
	for turret in world.turrets:
		turret._update_range_ring()
		turret._update_entrench_ring()
	await get_tree().create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.test-results/item-buffs.png"))
	get_tree().quit()
