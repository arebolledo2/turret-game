class_name EcologyMotion
extends RefCounted

## Authored rigid clips own their pivots. Never layer the legacy procedural leg pose on these models.
var player: AnimationPlayer
var current: String = ""

func _init(model: Node3D) -> void:
	player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player:
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for clip in player.get_animation_list():
			if clip != "RESET":
				player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR

func tick(delta: float, moving: bool, attacking: bool, reduced: bool) -> void:
	if not player:
		return
	var clip := "Attack" if attacking else ("Walk" if moving else "Idle")
	if not player.has_animation(clip):
		return
	if clip != current:
		current = clip
		player.play(clip, .12)
	player.advance(delta * (.25 if reduced else 1.0))
