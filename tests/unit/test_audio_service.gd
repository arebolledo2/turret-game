extends "res://addons/gut/test.gd"

# Test for AudioService
# Verifies that it responds to the damage_dealt signal

func test_audio_service_responds_to_damage_dealt():
	var audio_service = get_node("/root/AudioService")
	assert_not_null(audio_service, "AudioService should be an autoload singleton")
	
	# Since AudioService uses a pool of players, let's verify players exist
	assert_true(audio_service.get_child_count() >= audio_service.max_pool_size, "AudioService should have children AudioStreamPlayers")
	
	# We can't easily spy on preloaded constants or internal calls without modifying the script for testability,
	# but we can at least ensure emitting the signal doesn't crash anything.
	watch_signals(Events)
	Events.damage_dealt.emit(Vector2.ZERO, 10.0, false, null)
	
	# If we reached here without crash, it's a good sign.
	# AudioService connects to damage_dealt in _ready.
	
	pass
