class_name GroundDial
extends RefCounted

## Flat antialiased indicators. Radius is the exact build boundary, independent of progress.
const SHADER: Shader = preload("res://assets/shaders/ground_dial.gdshader")
static var plane: PlaneMesh

static func create(parent: Node3D, radius: float, color: Color, compact: bool = false) -> MeshInstance3D:
	if not plane:
		plane = PlaneMesh.new()
		plane.size = Vector2.ONE * 2.0
	var dial := MeshInstance3D.new()
	dial.mesh = plane
	dial.scale = Vector3.ONE * (radius / .88)
	dial.position.y = .045
	dial.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("tint", color)
	material.set_shader_parameter("compact", compact)
	dial.material_override = material
	parent.add_child(dial)
	return dial

static func update(dial: MeshInstance3D, progress: float, pending: bool = false, segments: int = 3) -> void:
	var material := dial.material_override as ShaderMaterial
	material.set_shader_parameter("progress", clampf(progress, 0.0, 1.0))
	material.set_shader_parameter("pending", pending)
	material.set_shader_parameter("segments", float(maxi(segments, 1)))

## Resize without changing the shader's exact boundary radius.
static func resize(dial: MeshInstance3D, radius: float) -> void:
	dial.scale = Vector3.ONE * (radius / .88)

static func recolor(dial: MeshInstance3D, color: Color) -> void:
	(dial.material_override as ShaderMaterial).set_shader_parameter("tint", color)
