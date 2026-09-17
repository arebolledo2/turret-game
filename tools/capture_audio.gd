extends Node

## Native audio loopback for reviewing the actual spatial SFX bus; no microphone.
func _ready() -> void:
	var world := ArenaWorld.new()
	world.show_hud = false
	add_child(world)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.turrets[0].set_physics_process(false)
	world.audio.reset()
	SettingsService.set_sfx_volume(.7, false)
	var bus := AudioServer.get_bus_index("SFX")
	var record := AudioEffectRecord.new()
	AudioServer.add_bus_effect(bus, record)
	record.set_recording_active(true)
	for cue: String in ["ion", "plasma", "shock", "impact", "warning", "hull", "pickup", "purchase", "wave", "victory", "defeat"]:
		world.audio.play_cue(cue, world.player.position + Vector3(1, 0, -1))
		await get_tree().create_timer(.85).timeout
	record.set_recording_active(false)
	var recording := record.get_recording()
	var result := recording.save_to_wav(ProjectSettings.globalize_path("res://.test-results/audio-preview.wav"))
	print("AUDIO_CAPTURE result=", result, " seconds=", recording.get_length())
	get_tree().quit(0 if result == OK else 1)
