class_name WorldGeometry
extends RefCounted

## One conversion boundary from the existing pixel-based balance data.
const METRES_PER_PIXEL: float = 0.01
## 37.5% of the original area, then a further 10% linear reduction.
const ARENA_LINEAR_SCALE: float = sqrt(0.375) * 0.9
## The arena is further narrowed by 20% along x only (depth is unchanged).
const ARENA_WIDTH_SCALE: float = 0.8
const HALF_ARENA: Vector2 = Vector2(28.8 * ARENA_WIDTH_SCALE, 16.2) * ARENA_LINEAR_SCALE # about 12.7 x 8.93 m: the whole arena is about 25.39 x 17.86 m

## Maps a point authored in the original 57.6 x 32.4 m reference space (terrain layouts) into the current arena.
static func from_reference(point: Vector3) -> Vector3:
	return Vector3(point.x * ARENA_WIDTH_SCALE, point.y, point.z) * ARENA_LINEAR_SCALE
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
const FLOOR_THEMES: Array[String] = ["foundry", "concrete", "grating", "hexworks", "marquetry", "orrery", "mosaic", "frost"]
const DEFAULT_FLOOR_THEME: String = "foundry"
## Lower metal keeps the warm rim light from glaring across rough, wet or mineral floors.
const FLOOR_METALLIC := {"foundry": 0.3, "concrete": 0.05, "grating": 0.15, "hexworks": 0.3, "marquetry": 0.0, "orrery": 0.25, "mosaic": 0.0, "frost": 0.05}
const FLOOR_EMISSION_ENERGY: float = 0.9
## Linear multiplier on the floor albedo texture, per theme. The textures are authored dark and flat (mean linear luminance
## 0.008 to 0.026) so the units pop; the gain equalises them so every floor lands near the same on-screen value (about 55/255 under the
## stage lighting). It is applied through `albedo_color`, so it multiplies the texture and the decals still paint over it.
const FLOOR_ALBEDO_GAIN := {"foundry": 2.5, "concrete": 1.4, "grating": 2.65, "hexworks": 3.5, "marquetry": 3.7, "orrery": 5.0, "mosaic": 1.6, "frost": 1.4}
## The floor finish pass (`assets/shaders/floor_overlay.gdshader`, the floor material's next_pass): the cool and warm ends of the
## large-scale tone drift per theme. The painted dash line is the theme's hull accent (`HULL_MOTIFS`) and the wall spill is its
## rim colour (`ArenaStage.RIM_COLORS`). Only the hue matters: the shader scales both to the lit floor's luminance (`level`).
const FLOOR_OVERLAY := {
	"foundry": {"tint_a": Color("2a5e9a"), "tint_b": Color("4a8a82")},
	"concrete": {"tint_a": Color("6e6068"), "tint_b": Color("b0763e")},
	"grating": {"tint_a": Color("2a7a78"), "tint_b": Color("66803c")},
	"hexworks": {"tint_a": Color("3a3aa0"), "tint_b": Color("6a3e98")},
	"marquetry": {"tint_a": Color("6a4a50"), "tint_b": Color("b06a38")},
	"orrery": {"tint_a": Color("2a3a9a"), "tint_b": Color("3a62a0")},
	"mosaic": {"tint_a": Color("2a7a8a"), "tint_b": Color("62805a")},
	"frost": {"tint_a": Color("3a68b8"), "tint_b": Color("86a4c4")},
}
const FLOOR_OVERLAY_SHADER: Shader = preload("res://assets/shaders/floor_overlay.gdshader")
## Linear luminance of the lit floor the overlay's tone and scuffs are scaled to (the gains above land every theme near it).
const FLOOR_OVERLAY_LEVEL: float = 0.05
## Lowest render priority, so the finish is drawn before every other transparent thing (zone rings, glows, telegraphs, shields) and
## those are not tinted or darkened by it.
const FLOOR_OVERLAY_PRIORITY: int = -128

## Keep immutable textures alive across arena teardown; the loader cache alone is weak.
static var _floor_textures: Dictionary = {}

static func _floor_texture(theme: String, map: String) -> Texture2D:
	var path := "res://assets/textures/floor/%s/floor_%s.png" % [theme, map]
	if not _floor_textures.has(path):
		_floor_textures[path] = load(path)
	return _floor_textures[path]

## One of a floor theme's maps (`albedo`, `normal`, `roughness`, `emission`) for effects that redraw the floor, like the spawn hatch's plates.
static func floor_texture(theme: String, map: String) -> Texture2D:
	return _floor_texture(theme, map)

## Tiling floor plating for a flat floor covering `area` metres. Albedo, normal, roughness and emission come from
## `assets/textures/floor/<theme>/`; the emission map carries the seam lines and status lights. With `arena` set (the playfield) the albedo
## is lifted by `FLOOR_ALBEDO_GAIN` and the finish pass `floor_overlay_material` rides along as the next pass; the FLOORS showcase patch
## is lit differently and has no walls, so it passes false and gets the plain textures.
static func floor_material(area: Vector2, theme: String = DEFAULT_FLOOR_THEME, arena: bool = true) -> StandardMaterial3D:
	if theme not in FLOOR_THEMES:
		theme = DEFAULT_FLOOR_THEME
	var result := StandardMaterial3D.new()
	result.albedo_texture = _floor_texture(theme, "albedo")
	if arena:
		# BaseMaterial3D reads albedo_color as sRGB, so the linear gain goes through linear_to_srgb (values above 1 are kept, not clamped).
		var gain: float = FLOOR_ALBEDO_GAIN.get(theme, 1.0)
		result.albedo_color = Color(gain, gain, gain).linear_to_srgb()
		result.next_pass = floor_overlay_material(theme)
	result.roughness = 1.0
	result.roughness_texture = _floor_texture(theme, "roughness")
	result.metallic = FLOOR_METALLIC.get(theme, 0.3)
	result.normal_enabled = true
	result.normal_texture = _floor_texture(theme, "normal")
	result.emission_enabled = true
	result.emission_texture = _floor_texture(theme, "emission")
	# Multiply, so `emission` is a tint on the seam lights (see ArenaStage.set_floor_wave) rather than light added everywhere.
	result.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	result.emission = Color.WHITE
	result.emission_energy_multiplier = FLOOR_EMISSION_ENERGY
	result.uv1_scale = Vector3(area.x / FLOOR_TILE_METRES, area.y / FLOOR_TILE_METRES, 1.0)
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return result

## The arena floor's finish (tone drift, scuffs, wall dash line, rim spill and wall occlusion) in one alpha pass; see floor_overlay.gdshader.
static func floor_overlay_material(theme: String = DEFAULT_FLOOR_THEME) -> ShaderMaterial:
	if theme not in FLOOR_THEMES:
		theme = DEFAULT_FLOOR_THEME
	var palette: Dictionary = FLOOR_OVERLAY[theme]
	var result := ShaderMaterial.new()
	result.shader = FLOOR_OVERLAY_SHADER
	result.render_priority = FLOOR_OVERLAY_PRIORITY
	result.set_shader_parameter("half_arena", HALF_ARENA)
	result.set_shader_parameter("tint_a", palette["tint_a"])
	result.set_shader_parameter("tint_b", palette["tint_b"])
	result.set_shader_parameter("accent", hull_motif(theme)["accent"])
	result.set_shader_parameter("rim_color", ArenaStage.RIM_COLORS.get(theme, ArenaStage.RIM_COLORS[DEFAULT_FLOOR_THEME]))
	result.set_shader_parameter("level", FLOOR_OVERLAY_LEVEL)
	return result

## Base colour of the room's hull plating (`assets/shaders/hull_plating.gdshader`) for each floor theme.
## The ship's light is cool and blue (sun d0eaff, ambient 46568a), which cools every albedo, so the warm themes' hulls are authored
## warmer than they should look and the cool ones greyer; check them with tools/preview_floor_theme.tscn.
const HULL_COLORS := {"foundry": Color("36525a"), "concrete": Color("74503c"), "grating": Color("365f44"), "hexworks": Color("62436a"),
	"marquetry": Color("6e4a30"), "orrery": Color("4a4768"), "mosaic": Color("36605a"), "frost": Color("3c5866")}

static func hull_color(theme: String) -> Color:
	return HULL_COLORS.get(theme, HULL_COLORS[DEFAULT_FLOOR_THEME])

## Plating per floor theme: `motif` (0 plates, 1 hex cells, 2 planks, 3 frosted plates), `panel` size in metres, `metal`, `grime` (rust streaks) and the
## enamel `accent` of the coping inlay.
const HULL_MOTIFS := {
	"foundry": {"motif": 0, "panel": Vector2(1.2, 0.6), "metal": 0.35, "grime": 0.25, "accent": Color("2f9a9a")},
	"concrete": {"motif": 0, "panel": Vector2(1.5, 0.75), "metal": 0.12, "grime": 0.35, "accent": Color("c8a040")},
	"grating": {"motif": 0, "panel": Vector2(1.2, 0.6), "metal": 0.4, "grime": 0.4, "accent": Color("3aa67a")},
	"hexworks": {"motif": 1, "panel": Vector2(0.45, 0.45), "metal": 0.35, "grime": 0.2, "accent": Color("7a6cc8")},
	"marquetry": {"motif": 2, "panel": Vector2(2.4, 0.18), "metal": 0.0, "grime": 0.15, "accent": Color("b08a4e")},
	"orrery": {"motif": 0, "panel": Vector2(1.2, 0.6), "metal": 0.4, "grime": 0.15, "accent": Color("c8a64a")},
	"mosaic": {"motif": 0, "panel": Vector2(0.6, 0.3), "metal": 0.15, "grime": 0.2, "accent": Color("3aa6a0")},
	"frost": {"motif": 3, "panel": Vector2(1.2, 0.6), "metal": 0.2, "grime": 0.1, "accent": Color("7fc4dc")},
}

static func hull_motif(theme: String) -> Dictionary:
	return HULL_MOTIFS.get(theme, HULL_MOTIFS[DEFAULT_FLOOR_THEME])

## The metal of the room's copings, caps and fittings (`assets/shaders/brass_trim.gdshader`) per floor theme: `color` is its
## reflectance at normal incidence (a saturated F0, so it reads as polished metal under the studio sky), `patina` the tint it
## weathers to and `amount` how much of it grows (0 none).
const BRASS_COLORS := {
	"foundry": {"color": Color("d4ae4c"), "patina": Color("2f7a68"), "amount": 1.0},
	"concrete": {"color": Color("bf8258"), "patina": Color("3c8a72"), "amount": 1.1},
	"grating": {"color": Color("b09040"), "patina": Color("3a8a5a"), "amount": 1.5},
	"hexworks": {"color": Color("d9a07c"), "patina": Color("5e5a8c"), "amount": 0.6},
	"marquetry": {"color": Color("9a7040"), "patina": Color("5a5a34"), "amount": 0.7},
	"orrery": {"color": Color("e0b440"), "patina": Color("3a7a78"), "amount": 0.6},
	"mosaic": {"color": Color("c8a850"), "patina": Color("2a8a86"), "amount": 1.0},
	"frost": {"color": Color("9fb8c8"), "patina": Color("5aa0b0"), "amount": 0.8},
}

static func brass_style(theme: String) -> Dictionary:
	return BRASS_COLORS.get(theme, BRASS_COLORS[DEFAULT_FLOOR_THEME])

static func brass_color(theme: String) -> Color:
	return brass_style(theme)["color"]

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
