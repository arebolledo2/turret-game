class_name Telegraph
extends RefCounted

## Fill-gauge attack warnings: a soft outlined footprint that fills toward the far edge over the wind-up.
## One shared quad and shader cover every enemy and boss attack; callers `create`, `place_*` once per attack and
## call `set_progress` each tick (0 = wind-up started, 1 = damage lands).
enum Shape { LINE, CIRCLE, SECTOR }

const SHADER: Shader = preload("res://assets/shaders/telegraph.gdshader")
## Colour follows the attack type so players learn the vocabulary: orange charges, amber shots, red blasts.
const CHARGE := Color("ff8a3d")
const SHOT := Color("ffc267")
const BLAST := Color("ff5a4a")
const SWEEP := Color("ff743d")
const SUMMON := Color("eab66b")
## Thin laser lines would be unreadable as a gauge, so lines never narrow below this.
const MIN_LINE_WIDTH := .24
const FLOOR_LIFT := .06
static var quad: PlaneMesh

static func create(parent: Node3D, shape: Shape, color: Color) -> MeshInstance3D:
	if not quad:
		quad = PlaneMesh.new()
		quad.size = Vector2.ONE
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.top_level = true
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("shape", int(shape))
	material.set_shader_parameter("tint", color)
	material.set_shader_parameter("flow", 0.0 if FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION) else 1.0)
	node.material_override = material
	node.visible = false
	parent.add_child(node)
	return node

## Rectangle from `origin` along `direction`.
static func place_line(node: MeshInstance3D, origin: Vector3, direction: Vector3, length: float, width: float) -> void:
	var heading := WorldGeometry.planar(direction).normalized()
	if heading.is_zero_approx():
		heading = Vector3.FORWARD
	width = maxf(width, MIN_LINE_WIDTH)
	length = maxf(length, .1)
	node.scale = Vector3(width, 1.0, length)
	node.global_position = WorldGeometry.planar(origin) + heading * length * .5 + Vector3(0, FLOOR_LIFT, 0)
	node.global_rotation = Vector3(0, atan2(-heading.x, -heading.z), 0)
	_extent(node, Vector2(width, length))
	node.visible = true

static func place_circle(node: MeshInstance3D, center: Vector3, radius: float) -> void:
	node.scale = Vector3(radius * 2.0, 1.0, radius * 2.0)
	node.global_position = WorldGeometry.planar(center) + Vector3(0, FLOOR_LIFT, 0)
	node.global_rotation = Vector3.ZERO
	_extent(node, Vector2(radius * 2.0, radius * 2.0))
	node.visible = true

## Cone from `origin` opening toward `direction` (or behind it when `rear`).
static func place_sector(node: MeshInstance3D, origin: Vector3, direction: Vector3, radius: float, half_angle: float, rear: bool = false) -> void:
	var heading := WorldGeometry.planar(direction).normalized()
	if heading.is_zero_approx():
		heading = Vector3.FORWARD
	node.scale = Vector3(radius * 2.0, 1.0, radius * 2.0)
	node.global_position = WorldGeometry.planar(origin) + Vector3(0, FLOOR_LIFT, 0)
	node.global_rotation = Vector3(0, atan2(-heading.x, -heading.z) + (PI if rear else 0.0), 0)
	_extent(node, Vector2(radius * 2.0, radius * 2.0))
	(node.material_override as ShaderMaterial).set_shader_parameter("half_angle", half_angle)
	node.visible = true

static func set_progress(node: MeshInstance3D, progress: float) -> void:
	(node.material_override as ShaderMaterial).set_shader_parameter("progress", clampf(progress, 0.0, 1.0))

static func recolor(node: MeshInstance3D, color: Color) -> void:
	(node.material_override as ShaderMaterial).set_shader_parameter("tint", color)

static func _extent(node: MeshInstance3D, size: Vector2) -> void:
	(node.material_override as ShaderMaterial).set_shader_parameter("extent", size)
