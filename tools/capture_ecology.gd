extends Node

## Reproducible rendered review of the actual imported models, runtime clips and health UI.
var world: ArenaWorld
var actors: Array[CombatActor] = []
var elapsed := 0.0
var captured := false
var mode := "roster"

func _ready() -> void:
	call_deferred("setup")

func setup() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ecology="): mode = arg.trim_prefix("--ecology=")
	world = ArenaWorld.new()
	world.auto_start = false
	world.run_config = RunConfig.new()
	world.run_config.mode = RunConfig.MODE_CONVOY if mode == "route" else RunConfig.MODE_CORE
	add_child(world)
	world.start_run()
	world.set_physics_process(false)
	if mode == "prep":
		world.add_turret(Vector3(-4, 0, 0), "plasma")
		world.add_turret(Vector3(4, 0, 0), "melee")
		world.add_turret(Vector3(0, 0, 4), "tesla")
		world.preparation.begin()
		world.camera_rig.set_zoom(.75)
		world.camera_rig.snap()
		return
	world.preparation.deploy()
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
	world.player.set_physics_process(false)
	world.player.position = Vector3(0, 0, 0)
	for turret in world.turrets: turret.set_physics_process(false)
	if mode == "danger":
		world.player.health = world.player.max_health * .15
		world.core.health = world.core.max_health * .15
		world.camera_rig.snap()
		return
	if mode == "route":
		for at in [Vector3(-4, 0, 1), Vector3(-2.6, 0, 1), Vector3(-4, 0, 2.4), Vector3(-2.6, 0, 2.4)]:
			world.waves.warn_spawn("drowse", at)
		world.waves.advance_spawn_warnings(.6)
		world.camera_rig.set_zoom(.65)
		world.camera_rig.snap()
		world.camera_rig.set_physics_process(false)
		return
	var kinds := ["drowse", "hopper", "kite", "lobber", "tender", "skitter"] if mode == "roster" else ["brass_ram", "prism_conductor", "grand_marionettist"]
	if mode == "effects": kinds = ["kite", "lobber", "prism_conductor", "grand_marionettist"]
	if mode == "support": kinds = ["skitter", "lens", "anchor", "puppet"]
	if mode == "health": kinds = ["brass_ram"]
	for index in kinds.size():
		var at := Vector3((index - (kinds.size() - 1) * .5) * 3.3, 0, 0)
		if mode == "effects": at = Vector3((index % 2 - .5) * 7, 0, (index / 2 - .5) * 4.2)
		if mode == "roster": at = Vector3((index % 3 - 1) * 3.5, 0, (index / 3 - .5) * 3.4)
		var actor := world.spawn_enemy(at, kinds[index])
		actor.set_physics_process(false)
		actor.visual.rotation.y = PI - .35
		actors.append(actor)
		if mode != "health":
			var label := Label3D.new()
			label.text = EnemyEcology.TYPES[kinds[index]].name
			label.font_size = 36
			label.no_depth_test = true
			label.pixel_size = .005
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.position = at + Vector3(0, .3, 1.1)
			world.actor_root.add_child(label)
	if mode == "effects":
		var kite := actors[0]
		kite.brain._line(kite.position, Vector3.RIGHT, 2.0, .025)
		var bolt := EnemyOrdnance.launch(kite, "bolt", kite.position + Vector3(.8, .45, 0), kite.position + Vector3(3, 0, 0), 5)
		world.actor_root.add_child(bolt)
		bolt.set_physics_process(false)
		var shell := EnemyOrdnance.launch(actors[1], "area", actors[1].position, actors[1].position + Vector3(-1.8, 0, .4), 5)
		world.actor_root.add_child(shell)
		shell._physics_process(.75)
		shell.set_physics_process(false)
		var beam := EnemyOrdnance.launch(actors[2], "beam", actors[2].position, actors[2].position + Vector3(2, 0, .5), 8)
		beam.warning_time = .01
		beam.beam_length = 2.6
		world.actor_root.add_child(beam)
		beam._physics_process(.02)
		beam.set_physics_process(false)
		actors[3].brain._sector(Vector3.FORWARD, 2.0, PI - .5, true)
	world.camera_rig.set_zoom(1.1 if mode == "roster" else 1.0)
	world.camera_rig.snap()
	world.camera_rig.set_physics_process(false)
	if mode == "health":
		actors[0].health *= .68
		var chest := world.drops.spawn(Vector3(2, 0, 2))
		chest.set_physics_process(false)
		chest.health *= .6
	else:
		world.hud.hide()
		world.player.hide()
		if world.core: world.core.hide()
		for turret in world.turrets: turret.hide()

func _process(delta: float) -> void:
	if not world: return
	elapsed += delta
	for actor in actors:
		if actor.ecology_motion: actor.ecology_motion.tick(delta, true, false, false)
	if elapsed > 1.5 and not captured:
		captured = true
		capture.call_deferred()

func capture() -> void:
	await RenderingServer.frame_post_draw
	var path := "res://.test-results/ecology-%s.png" % mode
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("ECOLOGY_CAPTURE ", path)
	get_tree().quit()
