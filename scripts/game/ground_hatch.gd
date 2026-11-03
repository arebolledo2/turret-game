class_name GroundHatch
extends RefCounted

## The floor hatch an enemy rises through. Radius is the exact hatch boundary; `open` is the aperture (0..1).
const SHADER: Shader = preload("res://assets/shaders/ground_hatch.gdshader")
const TINT := Color("f4a775")
static var plane: PlaneMesh

static func create(parent: Node3D, radius: float) -> MeshInstance3D:
	if not plane:
		plane = PlaneMesh.new()
		plane.size = Vector2.ONE * 2.0
	var hatch := MeshInstance3D.new()
	hatch.mesh = plane
	hatch.scale = Vector3.ONE * (radius / .88)
	hatch.position.y = .045
	hatch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("tint", TINT)
	material.set_shader_parameter("pulse", 0.0 if FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION) else 1.0)
	hatch.material_override = material
	parent.add_child(hatch)
	return hatch

static func update(hatch: MeshInstance3D, open: float, fade: float = 1.0) -> void:
	var material := hatch.material_override as ShaderMaterial
	material.set_shader_parameter("open", clampf(open, 0.0, 1.0))
	material.set_shader_parameter("fade", clampf(fade, 0.0, 1.0))
