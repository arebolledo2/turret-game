extends Node
class_name PlayerMovement

## Handles player movement, input, and sprite flipping.
##
## Responsibilities:
## - Collect input (WASD + gamepad)
## - Calculate velocity with speed modifiers
## - Clamp to arena bounds
## - Check turret carry speed penalty

# State
var velocity: Vector2 = Vector2.ZERO
var facing_direction: int = 0 # 0=S, 1=SW, 2=W, 3=NW, 4=N, 5=NE, 6=E, 7=SE
var is_moving: bool = false

# Dependencies (set via initialize)
var player: CharacterBody2D = null
var speed: float = 300.0
var effective_speed: float = 300.0

func initialize(p_player: CharacterBody2D, _p_sprite: Sprite2D = null) -> void:
	"""Initialize component with required references."""
	player = p_player
	speed = PlayerStatsService.get_player_speed()
	effective_speed = speed
	assert(player != null, "PlayerMovement: player reference required")

func process(delta: float) -> Vector2:
	"""Main update function - returns velocity for move_and_slide."""
	var input_vector := Vector2.ZERO

	# Keyboard input
	input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vector.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	# Gamepad input (left stick)
	var gamepad_input := Input.get_vector("gamepad_left", "gamepad_right", "gamepad_up", "gamepad_down")
	if gamepad_input.length() > GameConstants.PLAYER_MOVEMENT_DEADZONE:
		input_vector = gamepad_input

	var has_input := input_vector.length() > GameConstants.PLAYER_MOVEMENT_DEADZONE
	if has_input:
		input_vector = input_vector.normalized()
	else:
		input_vector = Vector2.ZERO

	# Apply speed penalty if carrying turret
	effective_speed = speed
	var turret_handler = player.get_node_or_null("Components/PlayerTurretHandler")
	if turret_handler and turret_handler.is_carrying_turret():
		effective_speed *= GameConstants.TURRET_CARRY_SPEED_PENALTY

	var target_velocity := input_vector * effective_speed
	var response := GameConstants.PLAYER_ACCELERATION if has_input else GameConstants.PLAYER_DECELERATION
	velocity = velocity.move_toward(target_velocity, response * maxf(delta, 0.0))
	if not has_input and velocity.length_squared() < 1.0:
		velocity = Vector2.ZERO

	# Handle sprite flip based on movement direction
	if velocity.length() > GameConstants.PLAYER_MOVEMENT_DEADZONE * maxf(effective_speed, 1.0):
		is_moving = true
	else:
		is_moving = false

	if has_input:
		facing_direction = get_direction_from_vector(input_vector)

	return velocity


func stop() -> void:
	"""Immediately stop movement when the player is clamped by the arena."""
	velocity = Vector2.ZERO
	is_moving = false

func get_direction_from_vector(dir: Vector2) -> int:
	"""Convert movement vector to 8-direction index."""
	# Frame order: S(0), SW(1), W(2), NW(3), N(4), NE(5), E(6), SE(7)
	var angle := dir.angle()
	# Normalize angle to 0-2PI range
	if angle < 0:
		angle += TAU
	# Divide circle into 8 sectors (each 45 degrees = PI/4)
	# Offset by 22.5 degrees so each direction is centered
	var sector := int(round(angle / (TAU / 8))) % 8
	# Map: 0=E, 1=SE, 2=S, 3=SW, 4=W, 5=NW, 6=N, 7=NE
	# We need: 0=S, 1=SW, 2=W, 3=NW, 4=N, 5=NE, 6=E, 7=SE
	var direction_map := [6, 7, 0, 1, 2, 3, 4, 5] # Maps angle sector to frame index
	return direction_map[sector]

func get_facing_direction() -> int:
	"""Returns current facing direction (0-7)."""
	return facing_direction

func get_facing_vector() -> Vector2:
	"""Returns facing direction as a Vector2 for combat systems."""
	var angle_map := [
		PI / 2, # 0: South
		PI * 3 / 4, # 1: Southwest
		PI, # 2: West
		- PI * 3 / 4, # 3: Northwest
		- PI / 2, # 4: North
		- PI / 4, # 5: Northeast
		0, # 6: East
		PI / 4 # 7: Southeast
	]

	var angle: float = angle_map[facing_direction]
	return Vector2(cos(angle), sin(angle))
