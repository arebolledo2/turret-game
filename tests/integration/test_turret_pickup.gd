extends GutTest

# =============================================================================
# Integration tests for turret pickup system
# Tests player-turret pickup interactions and signals
# =============================================================================

var player_scene: PackedScene
var turret_scene: PackedScene
var player: CharacterBody2D
var turret: Node2D


func before_all() -> void:
	player_scene = load("res://scenes/player.tscn")
	turret_scene = load("res://scenes/turret.tscn")


func before_each() -> void:
	GameStateService.reset_state()
	DifficultyService.set_difficulty(GameEnums.Difficulty.EASY)
	GameStateService.is_game_active = true
	
	player = player_scene.instantiate()
	add_child_autofree(player)
	player.global_position = Vector2.ZERO
	
	turret = turret_scene.instantiate()
	add_child_autofree(turret)
	turret.global_position = Vector2(50, 0)  # Within pickup range


# =============================================================================
# TURRET PICKUP SIGNAL TESTS
# =============================================================================

func test_turret_picked_up_signal_exists():
	assert_has_signal(Events, "turret_picked_up")


func test_turret_placed_signal_exists():
	assert_has_signal(Events, "turret_placed")


func test_turret_dropped_signal_exists():
	assert_has_signal(Events, "turret_dropped")


func test_pickup_signal_emitted():
	watch_signals(Events)
	
	# Simulate picking up turret
	player.pickup_turret(turret)
	
	assert_signal_emitted(Events, "turret_picked_up")


func test_place_signal_emitted():
	watch_signals(Events)
	
	# Pick up then place
	player.pickup_turret(turret)
	player.place_turret()
	
	assert_signal_emitted(Events, "turret_placed")


# =============================================================================
# PLAYER CARRYING STATE TESTS
# =============================================================================

func test_player_carries_turret_after_pickup():
	player.pickup_turret(turret)
	
	assert_eq(player.carried_turret, turret, 
		"Player should have reference to carried turret")


func test_player_no_turret_after_place():
	player.pickup_turret(turret)
	player.place_turret()
	
	assert_null(player.carried_turret, 
		"Player should not have turret after placing")


func test_carried_turret_follows_player():
	player.pickup_turret(turret)
	player.global_position = Vector2(200, 100)
	player.update_carried_turret_position()
	
	var expected_pos = player.global_position + GameConstants.TURRET_CARRY_OFFSET
	assert_eq(turret.global_position, expected_pos, 
		"Carried turret should follow player with offset")


# =============================================================================
# SPEED PENALTY TESTS
# =============================================================================

func test_speed_penalty_constant_is_reasonable():
	# Speed penalty should slow player (0.5 to 0.9 is reasonable range)
	assert_gt(GameConstants.TURRET_CARRY_SPEED_PENALTY, 0.4, 
		"Speed penalty shouldn't make player too slow")
	assert_lt(GameConstants.TURRET_CARRY_SPEED_PENALTY, 1.0, 
		"Speed penalty should actually reduce speed")


# =============================================================================
# NEARBY TURRET DETECTION
# =============================================================================

func test_finds_turret_in_pickup_range():
	# Turret at 50 units, pickup range is 60
	turret.global_position = Vector2(50, 0)
	
	player.find_nearby_turret()
	
	assert_eq(player.nearby_turret, turret, 
		"Should detect nearby turret within pickup range")


func test_ignores_turret_outside_range():
	# Move turret far away
	turret.global_position = Vector2(500, 0)
	
	player.find_nearby_turret()
	
	assert_null(player.nearby_turret, 
		"Should not detect turret outside pickup range")


func test_finds_closest_turret():
	# Create second turret closer
	var turret2 = turret_scene.instantiate()
	add_child_autofree(turret2)
	turret2.global_position = Vector2(30, 0)  # Closer than first turret
	
	await get_tree().physics_frame
	
	player.find_nearby_turret()
	
	assert_eq(player.nearby_turret, turret2, 
		"Should detect the closest turret")


# =============================================================================
# TURRET INDICATOR TESTS
# =============================================================================

func test_turret_has_pickup_indicator_methods():
	assert_true(turret.has_method("show_pickup_indicator"), 
		"Turret should have show_pickup_indicator method")
	assert_true(turret.has_method("hide_pickup_indicator"), 
		"Turret should have hide_pickup_indicator method")


func test_turret_tracks_in_range_state():
	assert_false(turret.is_in_pickup_range, 
		"Turret should not be in pickup range initially")
	
	turret.show_pickup_indicator()
	assert_true(turret.is_in_pickup_range, 
		"Turret should track when in pickup range")
	
	turret.hide_pickup_indicator()
	assert_false(turret.is_in_pickup_range, 
		"Turret should track when leaving pickup range")
