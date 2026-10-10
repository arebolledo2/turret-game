extends Node

## Run with --fixed-fps 120 to expose physics/render clock mismatches.
## Tracks the player ground anchor, excluding intentional walking/body animation.
var world: ArenaWorld
var elapsed := 0.0
var samples: Array[float] = []

func _ready() -> void:
	process_priority = 1000
	world = preload("res://scenes/game/arena.tscn").instantiate()
	world.show_hud = false
	add_child(world)
	world.set_physics_process(false)
	world.player.invulnerability = 999
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
	Input.action_press("move_right")

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed > 2.0:
		samples.append(world.camera.unproject_position(world.player.global_position).x)
	if elapsed >= 4.0:
		Input.action_release("move_right")
		var reversals := 0
		for i in range(1, samples.size()):
			if samples[i] - samples[i - 1] < -.05:
				reversals += 1
		var span: float = samples.max() - samples.min()
		print("CAMERA_FOLLOW ", JSON.stringify({"backward_steps": reversals, "screen_span_px": span, "samples": samples.size(), "player_x": world.player.position.x}))
		get_tree().quit(0 if reversals == 0 and span < .1 and world.player.position.x > 5.0 else 1)
