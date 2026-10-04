class_name ArenaStage
extends Node3D

## Static arena scenery: floor, rim, markings, lighting and the follow camera. Built once by `ArenaWorld`.
var camera: Camera3D
var camera_rig: CameraRig

func build(arena: ArenaWorld) -> void:
	_build_lighting()
	var half := WorldGeometry.HALF_ARENA
	var ground := StaticBody3D.new()
	ground.collision_layer = WorldGeometry.WORLD_LAYER
	ground.collision_mask = 0
	add_child(ground)
	var floor_size := Vector3(half.x * 2.0 + .6, .35, half.y * 2.0 + .6)
	# The collider is a slab; the visible surface is one textured plane on top of it (a single draw call).
	var floor_plane := PlaneMesh.new()
	floor_plane.size = Vector2(floor_size.x, floor_size.z)
	var floor_visual := MeshInstance3D.new()
	floor_visual.mesh = floor_plane
	floor_visual.material_override = WorldGeometry.floor_material(floor_plane.size)
	floor_visual.position.y = -.02
	ground.add_child(floor_visual)
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = floor_size
	floor_shape.shape = floor_box
	floor_shape.position.y = -.2
	ground.add_child(floor_shape)
	var rim := WorldGeometry.material(Color("258e99"), true)
	for z: float in [-half.y - .05, half.y + .05]:
		WorldGeometry.box(self, Vector3(half.x * 2.0 + .3, .08, .06), Vector3(0, .02, z), rim)
	for x: float in [-half.x - .05, half.x + .05]:
		WorldGeometry.box(self, Vector3(.06, .08, half.y * 2.0 + .1), Vector3(x, .02, 0), rim)
	var markings := WorldGeometry.material(Color("c48c48"))
	var stripe_transforms: Array[Transform3D] = []
	for x: float in [-half.x + .35, half.x - .35]:
		for z in range(-int(half.y) + 1, int(half.y)):
			stripe_transforms.append(Transform3D(Basis(Vector3.UP, -.5), Vector3(x, 0, z)))
	_add_multimesh(Vector3(.16, .015, .4), stripe_transforms, markings)
	camera = Camera3D.new()
	add_child(camera)
	camera_rig = CameraRig.new()
	add_child(camera_rig)
	camera_rig.setup(camera, arena)

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
	settings.ambient_light_energy = .7
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
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_color = Color("d0eaff")
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0 # the follow camera only ever sees a small slice of the arena
	add_child(sun)
	# Warm back light, opposite the sun and without shadows, so silhouettes separate from the teal floor.
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-30, 155, 0)
	rim.light_color = Color("ff7a45")
	rim.light_energy = .55
	rim.shadow_enabled = false
	add_child(rim)

func _add_multimesh(size: Vector3, transforms: Array[Transform3D], mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = mat
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
