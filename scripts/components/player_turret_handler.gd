extends Node
class_name PlayerTurretHandler

## Handles turret pickup, placement, and carry mechanics for the player.
##
## Responsibilities:
## - Detect nearby turrets within pickup range
## - Handle pickup/placement/drop input
## - Update carried turret position
## - Emit events for turret state changes

# State
var carried_turret: Node2D = null
var nearby_turret: Node2D = null
var pickup_action_just_pressed: bool = false

# Dependencies (set via initialize)
var player: CharacterBody2D = null

func initialize(p_player: CharacterBody2D) -> void:
	"""Initialize component with required references."""
	player = p_player
	assert(player != null, "PlayerTurretHandler: player reference required")

func process(_delta: float) -> void:
	"""Main update function - call from player's _physics_process."""
	# Detect input (check for just_pressed to toggle)
	if Input.is_action_just_pressed("pickup_turret"):
		pickup_action_just_pressed = true

	# If carrying a turret, update its position
	if carried_turret and is_instance_valid(carried_turret):
		update_carried_turret_position()

		# Check for placement input
		if pickup_action_just_pressed:
			place_turret()
			pickup_action_just_pressed = false
	else:
		# Not carrying - look for nearby turrets
		find_nearby_turret()

		# Check for pickup input
		if pickup_action_just_pressed and nearby_turret and is_instance_valid(nearby_turret):
			pickup_turret(nearby_turret)
			pickup_action_just_pressed = false

func find_nearby_turret() -> void:
	"""Find the nearest turret within pickup range and manage indicators."""
	var turrets = player.get_tree().get_nodes_in_group("turrets")
	var closest_distance: float = Globals.TURRET_PICKUP_RANGE
	var previous_nearby := nearby_turret
	nearby_turret = null

	for turret in turrets:
		if not is_instance_valid(turret):
			continue
		var distance := player.global_position.distance_to(turret.global_position)
		if distance < closest_distance:
			closest_distance = distance
			nearby_turret = turret

	# Manage indicator state changes
	if previous_nearby != nearby_turret:
		if previous_nearby and is_instance_valid(previous_nearby):
			if previous_nearby.has_method("hide_pickup_indicator"):
				previous_nearby.hide_pickup_indicator()
		if nearby_turret and is_instance_valid(nearby_turret):
			if nearby_turret.has_method("show_pickup_indicator"):
				nearby_turret.show_pickup_indicator()

func pickup_turret(turret: Node2D) -> void:
	"""Pick up a turret (drops current if carrying one)."""
	# Quick swap: drop current turret first
	if carried_turret and is_instance_valid(carried_turret):
		place_turret()

	carried_turret = turret

	if turret.has_method("hide_pickup_indicator"):
		turret.hide_pickup_indicator()

	Events.turret_picked_up.emit(turret)

func place_turret() -> void:
	"""Place the carried turret at its current position."""
	if not carried_turret or not is_instance_valid(carried_turret):
		carried_turret = null
		return

	var placement_pos := carried_turret.global_position
	Events.turret_placed.emit(carried_turret, placement_pos)

	carried_turret = null

func update_carried_turret_position() -> void:
	"""Update the position of the carried turret to follow the player."""
	if not carried_turret or not is_instance_valid(carried_turret):
		carried_turret = null
		return

	carried_turret.global_position = player.global_position + Globals.TURRET_CARRY_OFFSET

func force_drop() -> void:
	"""Force drop the carried turret (called on player death)."""
	if carried_turret and is_instance_valid(carried_turret):
		Events.turret_dropped.emit(carried_turret, carried_turret.global_position)
		carried_turret = null

func is_carrying_turret() -> bool:
	"""Returns true if currently carrying a turret."""
	return carried_turret != null and is_instance_valid(carried_turret)
