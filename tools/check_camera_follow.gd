extends Node

## Run with --fixed-fps 120 to expose physics/render clock mismatches.
## Tracks the player ground anchor, excluding intentional walking/body animation.
var world: ArenaWorld
var enemy: CombatActor
var enemy_samples: Array[float] = []
var elapsed := 0.0
var samples: Array[float] = []

func _ready() -> void:
	process_priority = 1000
	if "--slow-physics" in OS.get_cmdline_user_args():
		Engine.physics_ticks_per_second = 10
	world = preload("res://scenes/game/arena.tscn").instantiate()
	world.show_hud = false
	add_child(world)
	world.set_physics_process(false)
	world.player.invulnerability = 999
	for turret in world.turrets:
		turret.set_physics_process(false)
	enemy = world.spawn_enemy(Vector3(-5, 0, 1))
	enemy.health = 10000
	world.preparation.deploy()
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
	Input.action_press("move_right")

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed > 2.0:
		var camera_pose := world.camera.get_global_transform_interpolated()
		var player_pose := world.player.get_global_transform_interpolated()
		var relative := camera_pose.affine_inverse() * player_pose.origin
		samples.append(relative.x * get_viewport().get_visible_rect().size.y / world.camera.size)
		enemy_samples.append(enemy.get_global_transform_interpolated().origin.x)
	if elapsed >= 4.0:
		Input.action_release("move_right")
		var reversals := 0
		for i in range(1, samples.size()):
			if samples[i] - samples[i - 1] < -.05:
				reversals += 1
		var held_frames := 0
		for i in range(1, enemy_samples.size()):
			if absf(enemy_samples[i] - enemy_samples[i - 1]) < .00001:
				held_frames += 1
		var span: float = samples.max() - samples.min()
		print("CAMERA_FOLLOW ", JSON.stringify({"enemy_span": enemy_samples.max() - enemy_samples.min(), "enemy_held_frames": held_frames, "backward_steps": reversals, "screen_span_px": span, "samples": samples.size(), "player_x": world.player.position.x}))
		get_tree().quit(0 if reversals == 0 and span < .1 and world.player.position.x > 5.0 and held_frames == 0 and enemy_samples.max() - enemy_samples.min() > 1.0 else 1)
