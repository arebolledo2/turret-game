class_name SpaceBackdrop
extends MeshInstance3D

## The view outside the room: one huge plane far below the floor, painted by `space_backdrop.gdshader` with the settings
## of a `SpaceThemes` entry. The camera is orthographic, so the shader fakes parallax from the camera position itself.
const SHADER: Shader = preload("res://assets/shaders/space_backdrop.gdshader")
## Below the hull, and large enough that no zoom or camera position reaches its edge.
const DEPTH: float = 30.0
const SIZE: float = 300.0

var theme: String = ""

func _init() -> void:
	name = "SpaceBackdrop"
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * SIZE
	mesh = plane
	position.y = -DEPTH
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Paints a theme. Each call builds a fresh material, so nothing from the previous theme's settings lingers.
func apply_theme(id: String) -> void:
	if not SpaceThemes.is_theme(id):
		id = SpaceThemes.DEFAULT_THEME
	theme = id
	var material := ShaderMaterial.new()
	material.shader = SHADER
	var params := SpaceThemes.shader_params(id)
	for key: String in params:
		material.set_shader_parameter(key, params[key])
	material_override = material
