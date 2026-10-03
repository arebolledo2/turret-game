@tool
extends EditorScenePostImport

## Blender bakes ambient occlusion into COLOR_0. Godot imports it but does not enable it,
## so turn it on for every material of the model family (emission is unaffected).
func _post_import(scene: Node) -> Object:
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface) as BaseMaterial3D
			if material:
				material.vertex_color_use_as_albedo = true
	return scene
