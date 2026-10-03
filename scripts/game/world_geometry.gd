class_name WorldGeometry
extends RefCounted

## One conversion boundary from the existing pixel-based balance data.
const METRES_PER_PIXEL: float = 0.01
const HALF_ARENA: Vector2 = Vector2(28.8, 16.2) # 57.6 x 32.4 m: three times the original single-screen arena
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

static var ring_meshes: Dictionary = {}
static var ring_materials: Dictionary = {}

static func ring(parent: Node3D, radius: float, color: Color) -> MeshInstance3D:
	# Shared immutable resources permit renderer batching across identical markers.
	if not ring_meshes.has(radius):
		var mesh := TorusMesh.new()
		mesh.inner_radius = maxf(.01, radius - .025)
		mesh.outer_radius = radius + .025
		mesh.rings = 24
		mesh.ring_segments = 6
		ring_meshes[radius] = mesh
	if not ring_materials.has(color):
		ring_materials[color] = material(color, true)
	var instance := MeshInstance3D.new()
	instance.mesh = ring_meshes[radius]
	instance.material_override = ring_materials[color]
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

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
