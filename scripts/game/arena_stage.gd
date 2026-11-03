class_name ArenaStage
extends Node3D

## Static arena scenery: floor, rim, room walls, space backdrop, lighting and the follow camera. Built once by `ArenaWorld`.
var camera: Camera3D
var camera_rig: CameraRig
var floor_visual: MeshInstance3D
var floor_decals: FloorDecals
var room: ArenaRoom
var backdrop: SpaceBackdrop
var floor_theme: String = ""
var world_environment: WorldEnvironment
var sky_material: ShaderMaterial
var sun: DirectionalLight3D
var vignette: ArenaVignette
var _floor_material: StandardMaterial3D
var _rim_material: StandardMaterial3D
var _seam_tween: Tween

## Rim glow per floor theme.
const RIM_COLORS := {"foundry": Color("258e99"), "concrete": Color("a08d52"), "grating": Color("2f9a78"),
	"hexworks": Color("7a72c8"), "marquetry": Color("b08a4e"), "orrery": Color("4f78c0"), "mosaic": Color("3aa6a0"), "frost": Color("7fc4dc")}
## Seam light colour multipliers: calm at wave 1, warming as the waves climb, and a hard shift on boss waves.
const SEAM_CALM: Color = Color(1.0, 1.0, 1.0)
const SEAM_HOT: Color = Color(1.0, 0.72, 0.5)
const SEAM_BOSS: Color = Color(1.0, 0.45, 0.85)
const SEAM_FULL_WAVE: int = 20
const SKY_SHADER: Shader = preload("res://assets/shaders/arena_sky.gdshader")
## Ambient light is a flat cool colour (the sky adds only a little), so faces away from the sun and the room's shadowed slopes keep
## form instead of falling to black. The sun's shadows are lighter for the same reason.
const AMBIENT_COLOR: Color = Color("46568a")
const AMBIENT_ENERGY: float = 0.6
const AMBIENT_SKY_CONTRIBUTION: float = 0.3
const SUN_SHADOW_OPACITY: float = 0.72
## Colour grade (Environment adjustments, applied after tone mapping): a little contrast and saturation plus a split-tone lookup
## table that cools the shadows and warms the highlights. Stops are (brightness in, colour out) per channel.
const GRADE_CONTRAST: float = 1.08
const GRADE_SATURATION: float = 1.1
const GRADE_STOPS: Dictionary = {0.0: Color("02050c"), 0.2: Color("30333b"), 0.5: Color("7e8084"), 0.8: Color("ceccc6"), 1.0: Color("fff7eb")}

func build(arena: ArenaWorld) -> void:
	_build_lighting()
	var half := WorldGeometry.HALF_ARENA
	var ground := StaticBody3D.new()
	ground.collision_layer = WorldGeometry.WORLD_LAYER
	ground.collision_mask = 0
	add_child(ground)
	var floor_size := Vector3(half.x * 2.0 + .6, .35, half.y * 2.0 + .6)
	# The collider is a slab; the visible surface is one textured plane on top of it (a single draw call). It ends under
	# the walls: beyond them is space.
	var floor_plane := PlaneMesh.new()
	floor_plane.size = Vector2(floor_size.x, floor_size.z)
	floor_visual = MeshInstance3D.new()
	floor_visual.mesh = floor_plane
	floor_visual.layers = 1 | FloorDecals.LAYER
	floor_visual.position.y = -.02
	ground.add_child(floor_visual)
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = floor_size
	floor_shape.shape = floor_box
	floor_shape.position.y = -.2
	ground.add_child(floor_shape)
	_rim_material = WorldGeometry.material(RIM_COLORS["foundry"], true)
	_rim_material.emission_energy_multiplier = 0.8 # the one continuous light line; kept under the bloom threshold so it stays a coloured line
	for z: float in [-half.y - .05, half.y + .05]:
		WorldGeometry.box(self, Vector3(half.x * 2.0 + .3, .08, .06), Vector3(0, .02, z), _rim_material)
	for x: float in [-half.x - .05, half.x + .05]:
		WorldGeometry.box(self, Vector3(.06, .08, half.y * 2.0 + .1), Vector3(x, .02, 0), _rim_material)
	room = ArenaRoom.new()
	add_child(room)
	room.build()
	backdrop = SpaceBackdrop.new()
	add_child(backdrop)
	backdrop.apply_theme(SpaceThemes.DEFAULT_THEME)
	floor_decals = FloorDecals.new()
	floor_decals.position.y = -.02
	add_child(floor_decals)
	set_floor_theme(WorldGeometry.DEFAULT_FLOOR_THEME)
	camera = Camera3D.new()
	camera.far = 200.0 # the space backdrop sits about 60 m down the view ray
	add_child(camera)
	camera_rig = CameraRig.new()
	add_child(camera_rig)
	camera_rig.setup(camera, arena)

## Swaps the floor textures, rim glow and stain decals for a theme. Cheap enough to call at the start of every run.
func set_floor_theme(theme: String) -> void:
	if theme == floor_theme:
		return
	floor_theme = theme
	var size: Vector2 = (floor_visual.mesh as PlaneMesh).size
	_floor_material = WorldGeometry.floor_material(size, theme)
	floor_visual.material_override = _floor_material
	var rim_color: Color = RIM_COLORS.get(theme, RIM_COLORS["foundry"])
	_rim_material.albedo_color = rim_color
	_rim_material.emission = rim_color
	# The floor rim lights the room from below, so brass and hull slopes reflect its colour (the sky's lower-hemisphere bounce).
	sky_material.set_shader_parameter("bounce_color", rim_color)
	floor_decals.apply_theme(theme)
	room.apply_theme(theme, rim_color)

## The floor plane's size in metres, and the current tint of its seam lights: what an effect needs to redraw a piece of the floor.
func floor_size() -> Vector2:
	return (floor_visual.mesh as PlaneMesh).size

func floor_emission() -> Color:
	return _floor_material.emission

## Picks what the ship is flying through outside the room (see `SpaceThemes`).
func set_space_theme(theme: String) -> void:
	if theme != backdrop.theme:
		backdrop.apply_theme(theme)

## Warms the floor's seam lights as the waves climb; boss waves flip them to magenta. Eases over a second.
func set_floor_wave(wave: int, is_boss: bool) -> void:
	var target := SEAM_BOSS if is_boss else SEAM_CALM.lerp(SEAM_HOT, clampf(float(wave - 1) / (SEAM_FULL_WAVE - 1), 0.0, 1.0))
	room.set_alert(target, 1.0 if is_boss else 0.0) # boss waves pulse the room's lamps in the wave colour
	if _seam_tween:
		_seam_tween.kill()
	if not is_inside_tree():
		_floor_material.emission = target
		return
	_seam_tween = create_tween()
	_seam_tween.tween_property(_floor_material, "emission", target, 1.0)

func _build_lighting() -> void:
	# The sky is a small studio (see arena_sky.gdshader): metal parts mirror it, so it holds a softbox and a coloured bounce. Ambient
	# light is a flat cool colour instead, with only a little of the sky mixed in.
	sky_material = ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = AMBIENT_COLOR
	settings.ambient_light_energy = AMBIENT_ENERGY
	settings.ambient_light_sky_contribution = AMBIENT_SKY_CONTRIBUTION
	settings.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.tonemap_white = 6.0
	# Bloom: only emissive/very bright surfaces cross the threshold, which makes muzzles, eyes and shots glow.
	settings.glow_enabled = true
	settings.glow_intensity = .8
	settings.glow_strength = 1.0
	settings.glow_bloom = .05
	settings.glow_hdr_threshold = 1.0
	settings.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# Contact shadows where models meet the floor and in crevices.
	settings.ssao_enabled = true
	settings.ssao_radius = 1.2
	settings.ssao_intensity = 2.0
	settings.ssao_power = 1.6
	settings.ssil_enabled = true
	settings.ssil_intensity = .6
	# Depth fog pulls the far arena edge into the background colour.
	settings.fog_enabled = true
	settings.fog_light_color = Color("0f2a38")
	settings.fog_density = .012
	settings.fog_sky_affect = .4
	settings.adjustment_enabled = true
	settings.adjustment_contrast = GRADE_CONTRAST
	settings.adjustment_saturation = GRADE_SATURATION
	settings.adjustment_color_correction = _grade_lookup()
	world_environment = WorldEnvironment.new()
	world_environment.environment = settings
	add_child(world_environment)
	vignette = ArenaVignette.new()
	add_child(vignette)
	sun = DirectionalLight3D.new()
	# Lower than before so shadows stretch far enough to read from the near-top-down camera.
	sun.rotation_degrees = Vector3(-35, -45, 0)
	sun.light_color = Color("d0eaff")
	sun.light_energy = 1.8
	sun.shadow_enabled = true
	sun.shadow_opacity = SUN_SHADOW_OPACITY
	sun.shadow_blur = 1.0
	sun.shadow_bias = .07
	sun.shadow_normal_bias = .6
	# Shadows vanish when the cascade distance is cut down to the camera-to-floor distance (~22 m, measured with the
	# orthographic camera), so keep it large and give the near cascade (0-30 m, which holds the whole playfield) its own map.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 200.0
	sun.directional_shadow_split_1 = .15
	add_child(sun)
	# Warm back light, opposite the sun and without shadows, so silhouettes separate from the teal floor.
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-30, 155, 0)
	rim.light_color = Color("ff7a45")
	rim.light_energy = .55
	rim.shadow_enabled = false
	add_child(rim)
	# The sun travels towards +x, which leaves the left-hand wall slopes in self-shadow. A cool fill that lights only the
	# room's own render layer (ArenaRoom.LAYER) brings them up without flattening the floor or the units.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-40, 80, 0)
	fill.light_color = Color("7fb4c8")
	fill.light_energy = .5
	fill.light_cull_mask = ArenaRoom.LAYER
	fill.shadow_enabled = false
	add_child(fill)

## The grade's lookup table: a 1D gradient the tone mapper reads per channel (identity would run black to white).
static func _grade_lookup() -> GradientTexture1D:
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for offset: float in GRADE_STOPS:
		offsets.append(offset)
		colors.append(GRADE_STOPS[offset])
	gradient.offsets = offsets
	gradient.colors = colors
	var lookup := GradientTexture1D.new()
	lookup.gradient = gradient
	lookup.width = 256
	return lookup
