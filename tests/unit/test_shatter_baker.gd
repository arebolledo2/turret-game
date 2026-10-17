extends GutTest

const KEY := "drowse"

var model: Node3D

func before_each() -> void:
	model = ClockworkModels.instantiate(KEY)
	add_child_autofree(model)

func _mesh_instances() -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for node in model.find_children("*", "MeshInstance3D", true, false):
		found.append(node as MeshInstance3D)
	return found

func _triangles(mesh: Mesh) -> int:
	var total := 0
	for surface in mesh.get_surface_count():
		total += mesh.surface_get_array_index_len(surface) / 3
	return total

func test_bake_keeps_every_mesh_surface_and_triangle() -> void:
	var shards := ShatterBaker.bake(model, 12)
	var instances := _mesh_instances()
	assert_eq(shards.meshes.size(), instances.size(), "One baked mesh per mesh object")
	for instance in instances:
		var baked := shards.meshes[str(model.get_path_to(instance))] as ArrayMesh
		assert_not_null(baked, "Missing %s" % instance.name)
		assert_eq(baked.get_surface_count(), instance.mesh.get_surface_count(), "Surface order drives material assignment")
		assert_eq(_triangles(baked), _triangles(instance.mesh), "Fracturing must not add or drop triangles in %s" % instance.name)

func test_bake_splits_into_shards_with_pivot_and_id_per_vertex() -> void:
	var shards := ShatterBaker.bake(model, 12)
	assert_gt(shards.shard_count, 12, "Each crack cell becomes one shard per mesh it touches")
	var ids: Dictionary = {}
	for baked: ArrayMesh in shards.meshes.values():
		for surface in baked.get_surface_count():
			assert_true(baked.surface_get_format(surface) & Mesh.ARRAY_FORMAT_CUSTOM0 != 0, "Shard pivot and id ride in CUSTOM0")
			assert_true(baked.surface_get_format(surface) & Mesh.ARRAY_FORMAT_TEX_UV2 != 0, "Shard radius rides in UV2")
			var arrays := baked.surface_get_arrays(surface)
			var custom: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
			var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
			assert_eq(custom.size(), uv2.size() * 4)
			for index in uv2.size():
				ids[int(custom[index * 4 + 3])] = true
				assert_gt(uv2[index].x, 0.0, "A shard always has a size")
	assert_eq(ids.size(), shards.shard_count)

func test_bake_is_deterministic() -> void:
	var first := ShatterBaker.bake(model, 12)
	var second := ShatterBaker.bake(model, 12)
	assert_eq(first.shard_count, second.shard_count)
	for path: String in first.meshes:
		var a := (first.meshes[path] as ArrayMesh).surface_get_arrays(0)
		var b := (second.meshes[path] as ArrayMesh).surface_get_arrays(0)
		assert_eq(a[Mesh.ARRAY_CUSTOM0], b[Mesh.ARRAY_CUSTOM0], path)

func test_more_cells_means_more_shards() -> void:
	assert_gt(ShatterBaker.bake(model, 30).shard_count, ShatterBaker.bake(model, 8).shard_count)

func test_committed_bake_still_matches_the_model() -> void:
	var shards := load(ShatterSet.path_for(KEY)) as ShatterSet
	assert_not_null(shards, "Run tools/bake_shatter.gd to (re)create %s" % ShatterSet.path_for(KEY))
	for instance in _mesh_instances():
		var baked := shards.meshes.get(str(model.get_path_to(instance))) as ArrayMesh
		assert_not_null(baked, "%s is missing from the baked set; rebake after changing the model" % instance.name)
		if baked:
			assert_eq(baked.get_surface_count(), instance.mesh.get_surface_count())
			assert_eq(_triangles(baked), _triangles(instance.mesh), "Rebake after changing %s" % instance.name)
