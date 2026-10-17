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

func tick(delta: float, moving: bool, attacking: bool, reduced: bool, stride_speed: float = -1.0) -> void:
	if not player:
		return
	var clip := "Attack" if attacking else ("Walk" if moving else "Idle")
	# Hopper attack clips are a crouch/extension, not a running cycle. During
	# translation use its articulated Walk clip, paced at one cycle per 0.9 m.
	var running := stride_speed > .1
	if running: clip = "Walk"
	if not player.has_animation(clip):
		return
	if clip != current:
		current = clip
		player.play(clip, .12)
	var rate := clampf(stride_speed / .9, .1, 8.0) if running else (.25 if reduced else 1.0)
	player.advance(delta * rate)
