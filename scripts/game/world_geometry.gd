class_name WorldGeometry
extends RefCounted

## One conversion boundary from the existing pixel-based balance data.
const METRES_PER_PIXEL: float = 0.01
## Halve the playing area while preserving its aspect ratio and entity/weapon scale.
const ARENA_LINEAR_SCALE: float = sqrt(0.5)
const HALF_ARENA: Vector2 = Vector2(28.8, 16.2) * ARENA_LINEAR_SCALE # approximately 40.73 x 22.91 m
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

const FLOOR_TILE_METRES: float = 6.4 # one repeat of the floor textures; keep in sync with tools/build_floor_textures.py
const FLOOR_THEMES: Array[String] = ["foundry", "concrete", "grating"]
const DEFAULT_FLOOR_THEME: String = "foundry"
## Lower metal keeps the warm rim light from glaring across rough, wet or mineral floors.
const FLOOR_METALLIC := {"foundry": 0.3, "concrete": 0.05, "grating": 0.15}
const FLOOR_EMISSION_ENERGY: float = 0.9

static func _floor_texture(theme: String, map: String) -> Texture2D:
	return load("res://assets/textures/floor/%s/floor_%s.png" % [theme, map])

## Tiling floor plating for a flat floor covering `area` metres. Albedo, normal, roughness and emission come from
## `assets/textures/floor/<theme>/`; the emission map carries the seam lines and status lights.
static func floor_material(area: Vector2, theme: String = DEFAULT_FLOOR_THEME) -> StandardMaterial3D:
	if theme not in FLOOR_THEMES:
		theme = DEFAULT_FLOOR_THEME
	var result := StandardMaterial3D.new()
	result.albedo_texture = _floor_texture(theme, "albedo")
	result.roughness = 1.0
	result.roughness_texture = _floor_texture(theme, "roughness")
	result.metallic = FLOOR_METALLIC.get(theme, 0.3)
	result.normal_enabled = true
	result.normal_texture = _floor_texture(theme, "normal")
	result.emission_enabled = true
	result.emission_texture = _floor_texture(theme, "emission")
	result.emission_energy_multiplier = FLOOR_EMISSION_ENERGY
	result.uv1_scale = Vector3(area.x / FLOOR_TILE_METRES, area.y / FLOOR_TILE_METRES, 1.0)
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return result

static var ring_materials: Dictionary = {}

## Shared, immutable floor indicators; use GroundDial.create for individually animated dials.
static func ring(parent: Node3D, radius: float, color: Color) -> MeshInstance3D:
	var instance := GroundDial.create(parent, radius, color)
	if not ring_materials.has(color):
		ring_materials[color] = instance.material_override
	instance.material_override = ring_materials[color]
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
