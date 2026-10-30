extends Node

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui/turrets"))
	var forms: Array[Dictionary] = []
	for base: String in TurretEvolution.bases():
		forms.append({"base": base, "form": "", "stage": 0})
		for stage in 2:
			for option in TurretEvolution.options(base, stage):
				# Tesla's forms are not implemented yet but share the Tesla chassis, so they still get portraits.
				if TurretEvolution.is_implemented(option) or base == "tesla":
					forms.append({"base": base, "form": option, "stage": stage + 1})
	# --only=<key>,<key> renders just those portraits (every other portrait is left untouched).
	var only: PackedStringArray = []
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			only = argument.trim_prefix("--only=").split(",")
	for form in forms:
		var key := ShopArt.turret_portrait_key(form.base, form.form)
		if not only.is_empty() and key not in only:
			continue
		var viewport := SubViewport.new()
		viewport.size = Vector2i(512, 512)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.transparent_bg = true
		viewport.own_world_3d = true
		viewport.msaa_3d = Viewport.MSAA_4X
		add_child(viewport)
		var stage := Node3D.new()
		viewport.add_child(stage)
		# Use the actual actor assembly, including additional evolved saber arms.
		var actor := TurretActor.new()
		actor.turret_type = form.base
		actor.progression.evolution_form = form.form
		actor.progression.evolution_stage = form.stage
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		stage.add_child(actor)
		var model := actor.model
		var bounds := AABB()
		var first := true
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		var environment := WorldEnvironment.new()
		var settings := Environment.new()
		settings.background_mode = Environment.BG_COLOR
		settings.background_color = Color(0, 0, 0, 0)
		settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		settings.ambient_light_color = Color("a9d6dd")
		settings.ambient_light_energy = .75
		settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		environment.environment = settings
		stage.add_child(environment)
		for spec: Array in [[Vector3(-40, -30, 0), 1.6, Color("ffe4b0")], [Vector3(-20, 140, 0), 1.0, Color("75dacc")]]:
			var light := DirectionalLight3D.new()
			light.rotation_degrees = spec[0]
			light.light_energy = spec[1]
			light.light_color = spec[2]
			stage.add_child(light)
		var camera := Camera3D.new()
		stage.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)) * 1.45
		# Looks at the model's front: -z, or +z for a model the actor turned half a circle (the Scrap Press faces the game camera).
		camera.position = bounds.get_center() + (Vector3(-2, 1.7, -2.6).normalized() * 6.0).rotated(Vector3.UP, model.rotation.y)
		camera.look_at(bounds.get_center())
		camera.current = true
		for frame in range(4):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://assets/ui/turrets/%s.png" % key))
		viewport.queue_free()
		await get_tree().process_frame
	print("SHOP_PORTRAITS_COMPLETE")
	get_tree().quit()
