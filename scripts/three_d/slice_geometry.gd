class_name SliceGeometry
extends RefCounted

## One conversion boundary from the existing pixel-based balance data.
const METRES_PER_PIXEL: float = 0.01
const HALF_ARENA: Vector2 = Vector2(9.6, 5.4)
const WORLD_LAYER: int = 1
const ENEMY_HURTBOX_LAYER: int = 2
const PLAYER_LAYER: int = 4

static func planar(value: Vector3) -> Vector3:
	return Vector3(value.x, 0.0, value.z)

static func clamp_position(value: Vector3, margin: float = 0.3) -> Vector3:
	return Vector3(clampf(value.x, -HALF_ARENA.x + margin, HALF_ARENA.x - margin), 0.0,
		clampf(value.z, -HALF_ARENA.y + margin, HALF_ARENA.y - margin))

static func material(color: Color, emission: bool = false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.65
	if emission:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = 1.5
	return result

static func box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = at
	parent.add_child(instance)
	return instance

static func sphere(parent: Node3D, radius: float, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = at
	parent.add_child(instance)
	return instance
