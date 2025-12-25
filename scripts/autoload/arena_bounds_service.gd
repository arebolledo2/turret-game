class_name ArenaBoundsServiceType
extends Node

## Service for managing arena geometry (rectangular vs isometric diamond bounds)
##
## The arena can be either:
## - RECTANGULAR: Classic x/y rectangle (default)
## - ISOMETRIC: Diamond shape for two-wall isometric AI backgrounds
##
## All systems (player, enemy, turret) should use this service's methods
## instead of hardcoding bound checks.

# Current arena type
var _arena_type: GameEnums.ArenaType = GameEnums.ArenaType.RECTANGULAR

# Fixed arena dimensions (must match arena_setup.gd)
const FIXED_ARENA_WIDTH: int = 1920
const FIXED_ARENA_HEIGHT: int = 1080

# Arena dimensions (half-sizes for centered coordinate system)
var _half_width: float = FIXED_ARENA_WIDTH / 2.0
var _half_height: float = FIXED_ARENA_HEIGHT / 2.0

# =============================================================================
# ARENA TYPE MANAGEMENT
# =============================================================================

func get_arena_type() -> GameEnums.ArenaType:
	return _arena_type

func set_arena_type(type: GameEnums.ArenaType) -> void:
	_arena_type = type
	print("Arena type set to: ", "ISOMETRIC" if type == GameEnums.ArenaType.ISOMETRIC else "RECTANGULAR")

func is_isometric() -> bool:
	return _arena_type == GameEnums.ArenaType.ISOMETRIC

# =============================================================================
# BOUNDS CHECKING
# =============================================================================

func is_inside_arena(pos: Vector2, margin: float = 0.0) -> bool:
	"""Check if a position is inside the current arena bounds."""
	match _arena_type:
		GameEnums.ArenaType.ISOMETRIC:
			return _is_inside_isometric(pos, margin)
		_:
			return _is_inside_rectangular(pos, margin)

func _is_inside_rectangular(pos: Vector2, margin: float) -> bool:
	"""Check if position is inside rectangular bounds."""
	var max_x := _half_width - margin
	var max_y := _half_height - margin
	return abs(pos.x) <= max_x and abs(pos.y) <= max_y

func _is_inside_isometric(pos: Vector2, margin: float) -> bool:
	"""Check if position is inside isometric diamond bounds.
	
	Diamond equation: |x|/W + |y|/H <= 1
	With margin, we shrink the diamond by the margin amount.
	"""
	var effective_half_width := _half_width - margin
	var effective_half_height := _half_height - margin
	
	if effective_half_width <= 0 or effective_half_height <= 0:
		return false
	
	var normalized_dist: float = abs(pos.x) / effective_half_width + abs(pos.y) / effective_half_height
	# Use small epsilon for floating point tolerance (edge points should be considered inside)
	return normalized_dist <= 1.0 + 0.0001

# =============================================================================
# CLAMPING TO BOUNDS
# =============================================================================

func clamp_to_arena(pos: Vector2, margin: float = 0.0) -> Vector2:
	"""Clamp a position to the nearest valid arena position."""
	match _arena_type:
		GameEnums.ArenaType.ISOMETRIC:
			return _clamp_to_isometric(pos, margin)
		_:
			return _clamp_to_rectangular(pos, margin)

func _clamp_to_rectangular(pos: Vector2, margin: float) -> Vector2:
	"""Clamp position to rectangular bounds."""
	var max_x := _half_width - margin
	var max_y := _half_height - margin
	return Vector2(
		clamp(pos.x, -max_x, max_x),
		clamp(pos.y, -max_y, max_y)
	)

func _clamp_to_isometric(pos: Vector2, margin: float) -> Vector2:
	"""Clamp position to isometric diamond bounds.
	
	If outside the diamond, project onto the nearest edge.
	The diamond has four edges connecting the four cardinal vertices.
	"""
	var effective_half_width := _half_width - margin
	var effective_half_height := _half_height - margin
	
	if effective_half_width <= 0 or effective_half_height <= 0:
		return Vector2.ZERO
	
	# Check if already inside
	var normalized_dist: float = abs(pos.x) / effective_half_width + abs(pos.y) / effective_half_height
	if normalized_dist <= 1.0:
		return pos
	
	# Project onto the diamond edge
	# Determine which quadrant we're in and project to that edge
	var sign_x := signf(pos.x) if pos.x != 0 else 1.0
	var sign_y := signf(pos.y) if pos.y != 0 else 1.0
	
	# The edge equation for each quadrant is:
	# x/W + y/H = 1 (first quadrant, +x +y)
	# We want to find the point on this edge closest to our position
	
	# Convert to first quadrant for calculation
	var abs_x: float = abs(pos.x)
	var abs_y: float = abs(pos.y)
	
	# Project onto edge: find point on line x/W + y/H = 1 closest to (abs_x, abs_y)
	# Using parametric form of the edge from vertex (W,0) to (0,H):
	# P(t) = (W,0) + t * ((0,H) - (W,0)) = (W - W*t, H*t) for t in [0,1]
	# P(t) = (W*(1-t), H*t)
	
	# Minimize distance: d^2 = (W*(1-t) - abs_x)^2 + (H*t - abs_y)^2
	# Take derivative and set to zero:
	# 2*(W*(1-t) - abs_x)*(-W) + 2*(H*t - abs_y)*H = 0
	# -W^2*(1-t) + W*abs_x + H^2*t - H*abs_y = 0
	# -W^2 + W^2*t + W*abs_x + H^2*t - H*abs_y = 0
	# t*(W^2 + H^2) = W^2 - W*abs_x + H*abs_y
	# t = (W^2 - W*abs_x + H*abs_y) / (W^2 + H^2)
	
	var W := effective_half_width
	var H := effective_half_height
	var t: float = (W * W - W * abs_x + H * abs_y) / (W * W + H * H)
	t = clamp(t, 0.0, 1.0)
	
	var clamped_x: float = W * (1.0 - t) * sign_x
	var clamped_y: float = H * t * sign_y
	
	return Vector2(clamped_x, clamped_y)

# =============================================================================
# SPAWN POSITION HELPERS
# =============================================================================

func get_random_arena_position(margin: float = 40.0) -> Vector2:
	"""Get a random position inside the arena bounds."""
	match _arena_type:
		GameEnums.ArenaType.ISOMETRIC:
			return _get_random_isometric_position(margin)
		_:
			return _get_random_rectangular_position(margin)

func _get_random_rectangular_position(margin: float) -> Vector2:
	"""Get random position inside rectangular bounds."""
	return Vector2(
		randf_range(-_half_width + margin, _half_width - margin),
		randf_range(-_half_height + margin, _half_height - margin)
	)

func _get_random_isometric_position(margin: float) -> Vector2:
	"""Get random position inside isometric diamond.
	
	Uses rejection sampling for uniform distribution.
	"""
	var effective_half_width := _half_width - margin
	var effective_half_height := _half_height - margin
	
	# Rejection sampling - try random points in bounding box until one is inside diamond
	for _i in range(100): # Safety limit
		var pos := Vector2(
			randf_range(-effective_half_width, effective_half_width),
			randf_range(-effective_half_height, effective_half_height)
		)
		if _is_inside_isometric(pos, margin):
			return pos
	
	# Fallback: return center
	return Vector2.ZERO

func get_random_edge_spawn_position(edge_inset: float = 20.0, spawn_depth: float = 200.0) -> Vector2:
	"""Get a random spawn position near the arena edges.
	
	For rectangular: spawns near one of the 4 edges
	For isometric: spawns near one of the 4 diagonal edges
	"""
	match _arena_type:
		GameEnums.ArenaType.ISOMETRIC:
			return _get_isometric_edge_spawn(edge_inset, spawn_depth)
		_:
			return _get_rectangular_edge_spawn(edge_inset, spawn_depth)

func _get_rectangular_edge_spawn(edge_inset: float, spawn_depth: float) -> Vector2:
	"""Spawn near one of the 4 rectangular edges."""
	var edge := randi() % 4
	var x: float = 0.0
	var y: float = 0.0
	
	match edge:
		0: # Top
			x = randf_range(-_half_width + edge_inset, _half_width - edge_inset)
			y = randf_range(-_half_height + edge_inset, -_half_height + edge_inset + spawn_depth)
		1: # Bottom
			x = randf_range(-_half_width + edge_inset, _half_width - edge_inset)
			y = randf_range(_half_height - edge_inset - spawn_depth, _half_height - edge_inset)
		2: # Left
			x = randf_range(-_half_width + edge_inset, -_half_width + edge_inset + spawn_depth)
			y = randf_range(-_half_height + edge_inset, _half_height - edge_inset)
		3: # Right
			x = randf_range(_half_width - edge_inset - spawn_depth, _half_width - edge_inset)
			y = randf_range(-_half_height + edge_inset, _half_height - edge_inset)
	
	return Vector2(x, y)

func _get_isometric_edge_spawn(edge_inset: float, spawn_depth: float) -> Vector2:
	"""Spawn near one of the 4 diamond edges.
	
	The diamond has vertices at (±W, 0) and (0, ±H).
	Each edge connects two adjacent vertices.
	We pick a random edge, then pick a point along it, then offset inward slightly.
	"""
	var W := _half_width - edge_inset
	var H := _half_height - edge_inset
	
	# Pick a random edge (0-3)
	var edge := randi() % 4
	var t := randf() # Parameter along the edge [0, 1]
	
	var edge_point := Vector2.ZERO
	var inward_dir := Vector2.ZERO
	
	match edge:
		0: # Top-right edge: from (W, 0) to (0, -H)
			edge_point = Vector2(W * (1.0 - t), -H * t)
			inward_dir = Vector2(-1, 1).normalized() # Points toward center
		1: # Top-left edge: from (0, -H) to (-W, 0)
			edge_point = Vector2(-W * t, -H * (1.0 - t))
			inward_dir = Vector2(1, 1).normalized()
		2: # Bottom-left edge: from (-W, 0) to (0, H)
			edge_point = Vector2(-W * (1.0 - t), H * t)
			inward_dir = Vector2(1, -1).normalized()
		3: # Bottom-right edge: from (0, H) to (W, 0)
			edge_point = Vector2(W * t, H * (1.0 - t))
			inward_dir = Vector2(-1, -1).normalized()
	
	# Offset inward by a random amount within spawn_depth
	var depth_offset := randf_range(0, spawn_depth * 0.5) # Halved for diamond since it's smaller
	return edge_point + inward_dir * depth_offset

# =============================================================================
# UTILITY
# =============================================================================

func get_arena_dimensions() -> Vector2:
	"""Return the full arena dimensions (width, height)."""
	return Vector2(_half_width * 2.0, _half_height * 2.0)

func get_half_dimensions() -> Vector2:
	"""Return the half dimensions (half_width, half_height)."""
	return Vector2(_half_width, _half_height)

func update_dimensions(width: float, height: float) -> void:
	"""Update arena dimensions (called by arena_setup.gd)."""
	_half_width = width / 2.0
	_half_height = height / 2.0

func reset_state() -> void:
	"""Reset to default state."""
	_arena_type = GameEnums.ArenaType.RECTANGULAR
	_half_width = FIXED_ARENA_WIDTH / 2.0
	_half_height = FIXED_ARENA_HEIGHT / 2.0
