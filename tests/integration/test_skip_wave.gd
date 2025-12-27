extends GutTest

# =============================================================================
# Integration test for Skip Wave functionality
# =============================================================================

var main_scene: PackedScene
var main: Node
var game_manager: Node
var wave_controller: Node

func before_all() -> void:
    main_scene = load("res://scenes/main.tscn")

func before_each() -> void:
    GameStateService.reset_state()
    main = main_scene.instantiate()
    add_child_autofree(main)
    game_manager = main.get_node("GameManager")
    wave_controller = game_manager.get_node("WaveController")
    await get_tree().process_frame

func _start_game() -> void:
    Events.start_settings_applied.emit(
        GameEnums.Difficulty.EASY,
        GameEnums.GameMode.SENTINEL,
        GameEnums.GameMode.TECH_DEFENSE,
        GameEnums.GameMode.ARENA_ISOMETRIC,
        0
    )
    await get_tree().process_frame

func test_skip_wave_logic():
    await _start_game()
    
    # Directly transition to COMBAT for testing
    GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
    wave_controller.start_combat()
    await get_tree().process_frame

    var initial_gold = EconomyService.total_gold
    
    # Trigger skip wave
    game_manager.skip_wave()
    await get_tree().process_frame
    
    # Verify state transitioned to WAVE_END (and then to SHOP/LOOT after END pause)
    assert_ne(GameStateMachine.current_state, GameStateMachine.GameState.COMBAT, "Should not be in COMBAT after skip")
    assert_gt(EconomyService.total_gold, initial_gold, "Gold should have increased")
    
    # Wait for wave end pause to finish
    await get_tree().create_timer(GameConstants.BETWEEN_WAVE_PAUSE + 0.1).timeout
    await get_tree().process_frame
    
    # Should be in LOOT_REVIEW or SHOP now
    var valid_states = [GameStateMachine.GameState.SHOP, GameStateMachine.GameState.LOOT_REVIEW]
    assert_true(GameStateMachine.current_state in valid_states, "Should be in SHOP or LOOT_REVIEW")
