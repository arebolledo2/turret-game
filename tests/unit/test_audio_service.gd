extends "res://addons/gut/test.gd"

# Test for AudioService
# Verifies that it responds to the damage_dealt signal

func test_audio_service_responds_to_damage_dealt():
	var audio_service = get_node("/root/AudioService")
	assert_not_null(audio_service, "AudioService should be an autoload singleton")
	
	# Verify spatial audio setup
	assert_true(audio_service.get_child_count() >= audio_service.max_pool_size, "AudioService should have children AudioStreamPlayers")
	var first_player = audio_service.sfx_pool[0]
	assert_true(first_player is AudioStreamPlayer2D, "Players should be AudioStreamPlayer2D")
	
	# Verify signal handling sets position
	var test_pos = Vector2(100, 200)
	Events.damage_dealt.emit(test_pos, 10.0, false, null)
	
	# Check if any player was used and moved to test_pos
	var found_at_pos = false
	for player in audio_service.sfx_pool:
		if player.global_position == test_pos:
			found_at_pos = true
			break
	assert_true(found_at_pos, "At least one player should have been moved to the signal position")
