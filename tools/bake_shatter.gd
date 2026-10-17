extends SceneTree

## Pre-fractures an enemy model into shards for `DeathShatter`. Needs no window.
##   godot --headless --path . -s tools/bake_shatter.gd -- drowse [--cells=40] [--seed=7]
## Writes res://assets/models/clockwork/shatter/cp_<key>.res; the next kill of that enemy picks it up automatically.
## Re-run it whenever the model's meshes change, otherwise the baked paths no longer match.

func _init() -> void:
	var key := ""
	var cells := ShatterBaker.DEFAULT_CELLS
	var seed_value := 7
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cells="):
			cells = int(arg.trim_prefix("--cells="))
		elif arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))
		elif not arg.begins_with("--"):
			key = arg
	if key.is_empty() or not ClockworkModels.available(key):
		push_error("Usage: -s tools/bake_shatter.gd -- <clockwork model key> [--cells=N] [--seed=N]")
		quit(1)
		return
	var model := ClockworkModels.instantiate(key)
	var started := Time.get_ticks_msec()
	var shatter := ShatterBaker.bake(model, cells, seed_value)
	model.free()
	var path := ShatterSet.path_for(key)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var error := ResourceSaver.save(shatter, path, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		push_error("Could not save %s (error %d)" % [path, error])
		quit(1)
		return
	var vertices := 0
	var triangles := 0
	for mesh: ArrayMesh in shatter.meshes.values():
		for surface in mesh.get_surface_count():
			vertices += mesh.surface_get_array_len(surface)
			triangles += mesh.surface_get_array_index_len(surface) / 3
	print("SHATTER_BAKED %s: %d shards, %d meshes, %d vertices, %d triangles in %d ms -> %s" % [key, shatter.shard_count, shatter.meshes.size(), vertices, triangles, Time.get_ticks_msec() - started, path])
	quit()
