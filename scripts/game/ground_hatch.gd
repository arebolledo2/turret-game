class_name GroundHatch
extends RefCounted

## The floor hatch an enemy rises through. The floor itself splits along a jagged seam and its halves slide apart under the
## surrounding floor (`assets/shaders/ground_hatch.gdshader`). Each hatch is one quad that redraws a patch of the arena floor, so
## there is no disc to see: the plates carry whatever the floor theme looks like. All hatches share one material per theme and only
## their instance uniforms differ, so a screen full of hatches costs a quad each and `update` allocates nothing.
const SHADER: Shader = preload("res://assets/shaders/ground_hatch.gdshader")
const TINT := Color("f4a775")
## Half-size of the quad in hatch radii; keep equal to EXTENT in the shader. The opening itself stays inside one radius.
const EXTENT: float = 1.5
## Metres above the floor surface: enough to win the depth test against the floor, too little for any parallax against it.
const LIFT: float = .004
const FLOOR_Y: float = -.02 # `ArenaStage.floor_visual`
static var plane: PlaneMesh
static var _materials: Dictionary = {} # floor theme -> the ShaderMaterial every hatch on that floor shares

## `radius` is the hatch size: the opening is inscribed in it, so an enemy whose footprint is half the radius fits easily.
static func create(parent: Node3D, at: Vector3, radius: float, stage: ArenaStage = null) -> MeshInstance3D:
	if not plane:
		plane = PlaneMesh.new()
		plane.size = Vector2.ONE * 2.0
	var hatch := MeshInstance3D.new()
	hatch.mesh = plane
	hatch.scale = Vector3.ONE * (radius * EXTENT)
	hatch.position = Vector3(at.x, FLOOR_Y + LIFT, at.z)
	hatch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hatch.layers = 1 | FloorDecals.LAYER # the floor's stains and scorches mark the plates too
	hatch.material_override = _material(stage)
	hatch.set_instance_shader_parameter("calm", 1.0 if FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION) else 0.0)
	parent.add_child(hatch)
	return hatch

## `open` is how far the halves have slid apart (0 shut .. 1 open), `fade` fades the hatch in, `age` is seconds since it
## started (it drives dust and flicker, so a paused game freezes them) and `slam` is the impact flash when the halves meet (1 down to 0).
static func update(hatch: MeshInstance3D, open: float, fade: float = 1.0, age: float = 0.0, slam: float = 0.0) -> void:
	hatch.set_instance_shader_parameter("state", Vector4(clampf(open, 0.0, 1.0), clampf(fade, 0.0, 1.0), age, clampf(slam, 0.0, 1.0)))

static func _material(stage: ArenaStage) -> ShaderMaterial:
	var theme: String = stage.floor_theme if stage and stage.floor_theme in WorldGeometry.FLOOR_THEMES else WorldGeometry.DEFAULT_FLOOR_THEME
	var material: ShaderMaterial = _materials.get(theme)
	if not material:
		material = ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("albedo_tex", WorldGeometry.floor_texture(theme, "albedo"))
		material.set_shader_parameter("normal_tex", WorldGeometry.floor_texture(theme, "normal"))
		material.set_shader_parameter("rough_tex", WorldGeometry.floor_texture(theme, "roughness"))
		material.set_shader_parameter("emission_tex", WorldGeometry.floor_texture(theme, "emission"))
		material.set_shader_parameter("gain", WorldGeometry.FLOOR_ALBEDO_GAIN.get(theme, 1.0))
		material.set_shader_parameter("metallic", WorldGeometry.FLOOR_METALLIC.get(theme, 0.3))
		material.set_shader_parameter("emission_energy", WorldGeometry.FLOOR_EMISSION_ENERGY)
		material.set_shader_parameter("tile_metres", WorldGeometry.FLOOR_TILE_METRES)
		material.set_shader_parameter("glow_color", TINT)
		_materials[theme] = material
	var size := stage.floor_size() if stage else WorldGeometry.HALF_ARENA * 2.0 + Vector2.ONE * .6
	material.set_shader_parameter("floor_half", size * .5)
	# The seam lights warm up as the waves climb; the redrawn floor follows so the plates match what is around them.
	material.set_shader_parameter("emission_tint", stage.floor_emission() if stage else Color.WHITE)
	return material
