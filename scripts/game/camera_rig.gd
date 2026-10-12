class_name CameraRig
extends Node

## Follows the player with the fixed-angle orthographic camera. Only the camera's position changes, so
## camera-relative movement stays valid. The view is clamped so it never shows past the arena floor.
const OFFSET: Vector3 = Vector3(0, 17, 13)
const REFERENCE_ASPECT: float = 16.0 / 9.0

var camera: Camera3D
var world: Node3D
var aspect: float = REFERENCE_ASPECT
var zoom: float = GameConstants.CAMERA_DEFAULT_ZOOM
var target_zoom: float = GameConstants.CAMERA_DEFAULT_ZOOM
var focus: Vector3 = Vector3.ZERO

## Ground depth covered per unit of screen height: the camera looks down at this tilt.
static func ground_depth_scale() -> float:
	return OFFSET.length() / OFFSET.y

static func aspect_for(viewport_size: Vector2) -> float:
	return viewport_size.x / maxf(viewport_size.y, 1.0)

func setup(new_camera: Camera3D, new_world: Node3D) -> void:
	# Run after the player: both transforms must be presented from the same physics tick.
	process_physics_priority = 100
	camera = new_camera
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	world = new_world
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = OFFSET
	camera.look_at(Vector3.ZERO)
	camera.current = true
	refresh_aspect()
	if is_inside_tree():
		get_viewport().size_changed.connect(refresh_aspect)
	snap()

func refresh_aspect() -> void:
	if is_inside_tree():
		aspect = aspect_for(get_viewport().get_visible_rect().size)
	_apply()

## Vertical orthographic size at the given zoom. Narrow windows widen the view so the horizontal span never shrinks.
func view_size(zoom_value: float) -> float:
	return GameConstants.CAMERA_BASE_SIZE * maxf(1.0, REFERENCE_ASPECT / aspect) / zoom_value

## Half the ground area visible at the given zoom (x = width, y = depth), in metres.
func visible_half_extents(zoom_value: float) -> Vector2:
	var size := view_size(zoom_value)
	return Vector2(size * aspect * 0.5, size * 0.5 * ground_depth_scale())

func clamp_focus(value: Vector3, zoom_value: float) -> Vector3:
	var half := visible_half_extents(zoom_value)
	var limit_x := maxf(0.0, WorldGeometry.HALF_ARENA.x + GameConstants.CAMERA_EDGE_MARGIN - half.x)
	var limit_z := maxf(0.0, WorldGeometry.HALF_ARENA.y + GameConstants.CAMERA_EDGE_MARGIN - half.y)
	return Vector3(clampf(value.x, -limit_x, limit_x), 0.0, clampf(value.z, -limit_z, limit_z))

func set_zoom(value: float) -> void:
	target_zoom = clampf(value, GameConstants.CAMERA_ZOOM_MIN, GameConstants.CAMERA_ZOOM_MAX)

## Positive steps zoom in. One wheel notch is one step.
func zoom_steps(steps: float) -> void:
	set_zoom(target_zoom * pow(GameConstants.CAMERA_ZOOM_WHEEL_STEP, steps))

func snap() -> void:
	zoom = target_zoom
	focus = clamp_focus(_follow_point(), zoom)
	_apply()
	camera.reset_physics_interpolation()

func advance(delta: float) -> void:
	var held := Input.get_action_strength("zoom_in") - Input.get_action_strength("zoom_out")
	if held != 0.0:
		set_zoom(target_zoom * exp(held * GameConstants.CAMERA_ZOOM_HELD_RATE * delta))
	zoom = lerpf(zoom, target_zoom, 1.0 - exp(-GameConstants.CAMERA_ZOOM_SPEED * delta))
	var wanted := clamp_focus(_follow_point(), zoom)
	focus = clamp_focus(focus.lerp(wanted, 1.0 - exp(-GameConstants.CAMERA_FOLLOW_SPEED * delta)), zoom)
	_apply()

## Advancing in render frames against a physics-driven player makes the hero slide
## backwards between ticks, then jump forward on the next movement update.
func _physics_process(delta: float) -> void:
	if camera:
		advance(delta)

func _follow_point() -> Vector3:
	if is_instance_valid(world) and world.preparation and world.preparation.active:
		return world.preparation.view_focus
	var player: Variant = world.get("player") if is_instance_valid(world) else null
	if player is Node3D and is_instance_valid(player):
		return WorldGeometry.planar((player as Node3D).position)
	return focus

func _apply() -> void:
	if not camera:
		return
	camera.size = view_size(zoom)
	camera.position = focus + OFFSET
