extends Node

## Game State Machine
## Manages game state transitions with validation
## Emits state_changed signal for other systems to react

signal state_changed(old_state: GameState, new_state: GameState)

enum GameState {
	IDLE,
	DIFFICULTY_SELECT,
	GAME_MODE_SELECT,
	WAVE_ANNOUNCEMENT,
	COMBAT,
	WAVE_END,
	LOOT_REVIEW,
	SHOP,
	VICTORY,
	GAME_OVER
}

var current_state: GameState = GameState.IDLE


# =============================================================================
# VALID TRANSITIONS
# =============================================================================

const VALID_TRANSITIONS: Dictionary = {
	GameState.IDLE: [GameState.DIFFICULTY_SELECT],
	GameState.DIFFICULTY_SELECT: [GameState.GAME_MODE_SELECT, GameState.WAVE_ANNOUNCEMENT],
	GameState.GAME_MODE_SELECT: [GameState.WAVE_ANNOUNCEMENT],
	GameState.WAVE_ANNOUNCEMENT: [GameState.COMBAT],
	GameState.COMBAT: [GameState.WAVE_END, GameState.VICTORY, GameState.GAME_OVER],
	GameState.WAVE_END: [GameState.LOOT_REVIEW, GameState.SHOP, GameState.VICTORY],
	GameState.LOOT_REVIEW: [GameState.SHOP],
	GameState.SHOP: [GameState.WAVE_ANNOUNCEMENT],
	GameState.VICTORY: [GameState.IDLE],
	GameState.GAME_OVER: [GameState.IDLE]
}


# =============================================================================
# STATE TRANSITIONS
# =============================================================================

## Attempt to transition to a new state
## Returns true if transition was valid and executed
func transition_to(new_state: GameState) -> bool:
	if not _is_valid_transition(current_state, new_state):
		DebugService.warn(DebugService.SYSTEMS, "Invalid state transition: %s -> %s" % [
			get_state_name(current_state),
			get_state_name(new_state)
		])
		return false

	var old_state := current_state
	current_state = new_state
	state_changed.emit(old_state, new_state)
	return true


## Force a state change without validation (for game over, restart)
func force_transition(new_state: GameState) -> void:
	var old_state := current_state
	current_state = new_state
	state_changed.emit(old_state, new_state)


## Check if a transition is valid
func _is_valid_transition(from_state: GameState, to_state: GameState) -> bool:
	if not VALID_TRANSITIONS.has(from_state):
		return false
	return to_state in VALID_TRANSITIONS[from_state]


## Reset to initial state
func reset() -> void:
	current_state = GameState.IDLE


# =============================================================================
# STATE QUERIES
# =============================================================================

func is_playing() -> bool:
	return current_state in [
		GameState.WAVE_ANNOUNCEMENT,
		GameState.COMBAT,
		GameState.WAVE_END,
		GameState.LOOT_REVIEW,
		GameState.SHOP
	]


func is_in_combat() -> bool:
	return current_state == GameState.COMBAT


func is_game_over() -> bool:
	return current_state == GameState.GAME_OVER


func is_victory() -> bool:
	return current_state == GameState.VICTORY


func is_in_menu() -> bool:
	return current_state in [
		GameState.IDLE,
		GameState.DIFFICULTY_SELECT,
		GameState.GAME_MODE_SELECT
	]


# =============================================================================
# UTILITY
# =============================================================================

func get_state_name(state: GameState) -> String:
	match state:
		GameState.IDLE: return "IDLE"
		GameState.DIFFICULTY_SELECT: return "DIFFICULTY_SELECT"
		GameState.GAME_MODE_SELECT: return "GAME_MODE_SELECT"
		GameState.WAVE_ANNOUNCEMENT: return "WAVE_ANNOUNCEMENT"
		GameState.COMBAT: return "COMBAT"
		GameState.WAVE_END: return "WAVE_END"
		GameState.LOOT_REVIEW: return "LOOT_REVIEW"
		GameState.SHOP: return "SHOP"
		GameState.VICTORY: return "VICTORY"
		GameState.GAME_OVER: return "GAME_OVER"
		_: return "UNKNOWN"
