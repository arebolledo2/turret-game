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
	floor_decals.apply_theme(theme)
	room.apply_theme(theme, rim_color)

## Picks what the ship is flying through outside the room (see `SpaceThemes`).
func set_space_theme(theme: String) -> void:
	if theme != backdrop.theme:
		backdrop.apply_theme(theme)

## Warms the floor's seam lights as the waves climb; boss waves flip them to magenta. Eases over a second.
func set_floor_wave(wave: int, is_boss: bool) -> void:
	var target := SEAM_BOSS if is_boss else SEAM_CALM.lerp(SEAM_HOT, clampf(float(wave - 1) / (SEAM_FULL_WAVE - 1), 0.0, 1.0))
	if _seam_tween:
		_seam_tween.kill()
	if not is_inside_tree():
		_floor_material.emission = target
		return
	_seam_tween = create_tween()
	_seam_tween.tween_property(_floor_material, "emission", target, 1.0)

func _build_lighting() -> void:
	# A dark gradient sky doubles as the ambient and reflection source, so metal parts have something to mirror.
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("0b2233")
	sky_material.sky_horizon_color = Color("2a5a6a")
	sky_material.ground_horizon_color = Color("2a5a6a")
	sky_material.ground_bottom_color = Color("08151e")
	sky_material.sky_energy_multiplier = .9
	var sky := Sky.new()
	sky.sky_material = sky_material
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	settings.ambient_light_energy = .45
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
	var environment := WorldEnvironment.new()
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	# Lower than before so shadows stretch far enough to read from the near-top-down camera.
	sun.rotation_degrees = Vector3(-35, -45, 0)
	sun.light_color = Color("d0eaff")
	sun.light_energy = 1.8
	sun.shadow_enabled = true
	sun.shadow_opacity = .9
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
