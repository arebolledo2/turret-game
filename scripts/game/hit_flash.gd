class_name HitFlash
extends RefCounted

## Short additive flash over every mesh of an actor's model, driven as a material overlay.
## The overlay is attached on trigger and removed when the flash ends, so idle actors draw nothing extra.
const SHADER: Shader = preload("res://assets/shaders/hit_flash.gdshader")
const REDUCED_MOTION_SCALE: float = 0.4

var meshes: Array[MeshInstance3D] = []
var material := ShaderMaterial.new()
var attached: bool = false

func _init(model: Node, color: Color) -> void:
	material.shader = SHADER
	material.set_shader_parameter("flash_color", color)
	material.set_shader_parameter("strength", 0.0)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as MeshInstance3D)

## `fraction` runs 1 -> 0 over the flash. Reduced motion keeps the cue but as a dim, non-strobing glow.
func update(fraction: float, reduced_motion: bool) -> void:
	if fraction <= 0.0:
		clear()
		return
	if not attached:
		for mesh in meshes:
			mesh.material_overlay = material
		attached = true
	var eased := fraction * fraction * (3.0 - 2.0 * fraction)
	material.set_shader_parameter("strength", eased * (REDUCED_MOTION_SCALE if reduced_motion else 1.0))

func clear() -> void:
	if not attached:
		return
	for mesh in meshes:
		if is_instance_valid(mesh):
			mesh.material_overlay = null
	attached = false
