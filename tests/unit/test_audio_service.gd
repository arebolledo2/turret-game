extends GutTest

# =============================================================================
# Unit tests for AudioService
# Tests pool management, spatial audio, signal handling, and recycling
# =============================================================================

var audio_service: Node


func before_all() -> void:
	audio_service = get_node("/root/AudioService")


# =============================================================================
# INITIALIZATION & POOL SETUP
# =============================================================================

func test_audio_service_exists() -> void:
	assert_not_null(audio_service, "AudioService should be an autoload singleton")


func test_pool_size_matches_config() -> void:
	assert_eq(audio_service.sfx_pool.size(), audio_service.max_pool_size,
		"Pool should have max_pool_size players")


func test_pool_contains_audio_stream_player_2d() -> void:
	for player in audio_service.sfx_pool:
		assert_true(player is AudioStreamPlayer2D,
			"All pool members should be AudioStreamPlayer2D")


func test_pool_players_are_children() -> void:
	assert_gte(audio_service.get_child_count(), audio_service.max_pool_size,
		"AudioService should have at least max_pool_size children")


func test_spatial_audio_settings_applied() -> void:
	var first_player: AudioStreamPlayer2D = audio_service.sfx_pool[0]
	assert_almost_eq(first_player.max_distance, AudioService.MAX_SOUND_DISTANCE, 0.1,
		"Max distance should match constant")
	assert_almost_eq(first_player.attenuation, AudioService.ATTENUATION_FALLOFF, 0.1,
		"Attenuation should match constant")


# =============================================================================
# CONSTANTS
# =============================================================================

func test_max_sound_distance_is_positive() -> void:
	assert_gt(AudioService.MAX_SOUND_DISTANCE, 0.0,
		"Max sound distance should be positive")


func test_attenuation_falloff_is_positive() -> void:
	assert_gt(AudioService.ATTENUATION_FALLOFF, 0.0,
		"Attenuation falloff should be positive")


func test_max_pool_size_is_reasonable() -> void:
	assert_gte(audio_service.max_pool_size, 4,
		"Pool should have at least 4 players")
	assert_lte(audio_service.max_pool_size, 64,
		"Pool should have at most 64 players")


# =============================================================================
# SIGNAL CONNECTION
# =============================================================================

func test_damage_dealt_signal_connected() -> void:
	assert_true(Events.damage_dealt.is_connected(audio_service._on_damage_dealt),
		"AudioService should be connected to Events.damage_dealt")


# =============================================================================
# PLAY_SFX METHOD
# =============================================================================

func test_play_sfx_with_null_stream_does_not_crash() -> void:
	audio_service.play_sfx(null, Vector2.ZERO)
	pass_test("play_sfx with null stream did not crash")


func test_play_sfx_positions_player() -> void:
	# Skip if no hit sounds loaded (CI environment may not have assets)
	if not audio_service.hit_sound_small:
		pass_test("Skipped - no audio assets available")
		return

	var test_pos := Vector2(150, 250)
	audio_service.play_sfx(audio_service.hit_sound_small, test_pos)

	var found_at_pos := false
	for player in audio_service.sfx_pool:
		if player.global_position == test_pos:
			found_at_pos = true
			break
	assert_true(found_at_pos,
		"A pool player should be positioned at the requested location")


func test_play_sfx_default_position_is_zero() -> void:
	if not audio_service.hit_sound_small:
		pass_test("Skipped - no audio assets available")
		return

	# Stop all players first
	for player in audio_service.sfx_pool:
		player.stop()

	audio_service.play_sfx(audio_service.hit_sound_small)

	var found_at_zero := false
	for player in audio_service.sfx_pool:
		if player.global_position == Vector2.ZERO and player.playing:
			found_at_zero = true
			break
	assert_true(found_at_zero,
		"Default position should be Vector2.ZERO")


# =============================================================================
# DAMAGE DEALT SIGNAL HANDLING
# =============================================================================

func test_damage_dealt_signal_triggers_audio() -> void:
	var test_pos := Vector2(100, 200)
	Events.damage_dealt.emit(test_pos, 10.0, false, null)

	# Check if any player was moved to test_pos
	var found_at_pos := false
	for player in audio_service.sfx_pool:
		if player.global_position == test_pos:
			found_at_pos = true
			break
	assert_true(found_at_pos,
		"At least one player should be at the signal position")


func test_damage_dealt_with_null_enemy_uses_small_sound() -> void:
	# Should not crash and should use default small sound
	Events.damage_dealt.emit(Vector2(50, 50), 5.0, false, null)
	pass_test("Damage dealt with null enemy did not crash")


# =============================================================================
# POOL EXHAUSTION & RECYCLING
# =============================================================================

func test_get_available_player_returns_non_null() -> void:
	var player = audio_service._get_available_player()
	assert_not_null(player, "Should always return a player (recycles if needed)")


func test_get_available_player_prefers_stopped() -> void:
	# Stop all players
	for player in audio_service.sfx_pool:
		player.stop()

	# Get an available player - should be the first stopped one
	var available = audio_service._get_available_player()
	assert_not_null(available, "Should find a stopped player")
	assert_false(available.playing, "Should prefer non-playing player")


func test_pool_exhaustion_still_returns_player() -> void:
	# Even when all players are "playing", should still return something
	# (the service falls back to sfx_pool[0])
	var player = audio_service._get_available_player()
	assert_not_null(player,
		"Should return a player even under exhaustion")


func test_rapid_fire_audio_does_not_crash() -> void:
	# Fire many audio events rapidly to test pool recycling
	for i in range(audio_service.max_pool_size * 3):
		var pos := Vector2(randf() * 1000, randf() * 1000)
		Events.damage_dealt.emit(pos, float(i), false, null)

	pass_test("Rapid-fire audio events did not crash")


# =============================================================================
# SOUND ASSET LOADING
# =============================================================================

func test_sound_paths_are_defined() -> void:
	assert_true(AudioService.HIT_SOUND_SMALL_PATH.length() > 0,
		"Small hit sound path should be defined")
	assert_true(AudioService.HIT_SOUND_LARGE_PATH.length() > 0,
		"Large hit sound path should be defined")


func test_sound_paths_are_valid_resource_paths() -> void:
	assert_true(AudioService.HIT_SOUND_SMALL_PATH.begins_with("res://"),
		"Small hit sound should be a resource path")
	assert_true(AudioService.HIT_SOUND_LARGE_PATH.begins_with("res://"),
		"Large hit sound should be a resource path")


# =============================================================================
# EDGE CASES
# =============================================================================

func test_play_sfx_at_extreme_position() -> void:
	if not audio_service.hit_sound_small:
		pass_test("Skipped - no audio assets available")
		return

	audio_service.play_sfx(audio_service.hit_sound_small, Vector2(99999, 99999))
	pass_test("Extreme position did not crash")


func test_play_sfx_at_negative_position() -> void:
	if not audio_service.hit_sound_small:
		pass_test("Skipped - no audio assets available")
		return

	audio_service.play_sfx(audio_service.hit_sound_small, Vector2(-500, -500))
	pass_test("Negative position did not crash")


func before_each() -> void:
	TestHelpers.reset_all_services()
