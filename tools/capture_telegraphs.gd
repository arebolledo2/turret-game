extends Node

## Live capture of real enemy wind-ups: `godot --path . res://tools/capture_telegraphs.tscn`.
## Saves up to six frames to .test-results/telegraph-live-N.png while attackers are mid-warning.
var world: ArenaWorld
var shots := 0
var gap := 0.0

func _ready() -> void:
	call_deferred("setup")

func setup() -> void:
	world = ArenaWorld.new()
	world.auto_start = false
	world.run_config = RunConfig.new()
	world.run_config.mode = RunConfig.MODE_CORE
	add_child(world)
	world.start_run()
	world.preparation.deploy()
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
	world.player.set_physics_process(false)
	if world.core: world.core.set_physics_process(false)
	world.player.position = Vector3(0, 0, 1)
	world.player.invulnerability = 999.0
	for turret in world.turrets: turret.set_physics_process(false)
	world.camera_rig.set_zoom(.8)
	world.camera_rig.snap()
	var cast: Array = [["brass_ram", Vector3(-4, 0, -3)], ["hopper", Vector3(4, 0, -3)], ["kite", Vector3(-4, 0, 4)], ["lobber", Vector3(4, 0, 4)], ["prism_conductor", Vector3(0, 0, -5)]]
	for entry in cast:
		var actor := world.spawn_enemy(entry[1], entry[0])
		actor.health = 1e6
		actor.max_health = 1e6
		actor.brain.clock = .2

func _process(delta: float) -> void:
	if not world or shots >= 6:
		return
	gap -= delta
	if world.warning_actors.size() >= 2 and gap <= 0.0:
		gap = .35
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.test-results/telegraph-live-%d.png" % shots))
		shots += 1
		if shots >= 6:
			print("TELEGRAPH_LIVE_COMPLETE")
			get_tree().quit()
