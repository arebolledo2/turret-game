class_name ShatterBaker
extends RefCounted

## Offline pre-fracture of an enemy model into shards. Run through `tools/bake_shatter.gd`; the game never runs this.
##
## All triangles of the model are clustered into `cells` crack cells (area-weighted k-means over their centroids in model
## space, with the assignment wobbled by noise so the cracks are ragged). A shard is one cell inside one mesh object: it
## keeps the mesh's own space, so animated parts such as the feet still shatter from wherever the pose left them.
## Vertices on a crack are duplicated per shard, which is why each surface is rebuilt rather than reused.
const DEFAULT_CELLS: int = 16
const WARP_METRES: float = .05
const LLOYD_STEPS: int = 3
const ID_STRIDE: int = 8192

class Part:
	var path: String
	var mesh: ArrayMesh
	var to_root: Transform3D
	var surface_arrays: Array = []
	## Index of this part's first triangle in the model-wide triangle arrays.
	var first_triangle: int = 0
	## Triangle offset of each surface within the part, plus the part's total as the last entry.
	var surface_base: PackedInt32Array = PackedInt32Array()
	## Crack cell -> shard id, for the cells that touch this part.
	var shard_of_cell: Dictionary = {}

static func bake(model: Node3D, cells: int = DEFAULT_CELLS, seed_value: int = 7) -> ShatterSet:
	var parts := _collect_parts(model)
	var centroids := PackedVector3Array() # model space, used to cluster
	var local_centroids := PackedVector3Array() # mesh space, used for the shard pivot
	var areas := PackedFloat32Array()
	_gather_triangles(parts, centroids, local_centroids, areas)
	if centroids.is_empty():
		return ShatterSet.new()

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var warp := FastNoiseLite.new()
	warp.seed = seed_value
	warp.frequency = 9.0
	var warped := PackedVector3Array()
	warped.resize(centroids.size())
	for index in centroids.size():
		var p := centroids[index]
		warped[index] = p + Vector3(warp.get_noise_3dv(p), warp.get_noise_3dv(p + Vector3(31.4, 0.0, 0.0)), warp.get_noise_3dv(p + Vector3(0.0, 17.2, 0.0))) * WARP_METRES

	var seeds := _seed_cells(centroids, areas, mini(cells, centroids.size()), rng)
	var cell_of := PackedInt32Array()
	cell_of.resize(centroids.size())
	for step in LLOYD_STEPS + 1:
		_assign(warped, seeds, cell_of)
		if step < LLOYD_STEPS:
			_recentre(centroids, areas, cell_of, seeds)

	var result := ShatterSet.new()
	result.shard_count = _make_shards(parts, cell_of)
	assert(result.shard_count < ID_STRIDE, "Too many shards for the vertex remap key")
	for part in parts:
		result.meshes[part.path] = _rebuild_mesh(part, cell_of, local_centroids, areas)
	return result

static func _collect_parts(model: Node3D) -> Array[Part]:
	var parts: Array[Part] = []
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		var source := instance.mesh as ArrayMesh
		if not source:
			continue
		var part := Part.new()
		part.path = str(model.get_path_to(instance))
		part.mesh = source
		var transform := Transform3D.IDENTITY
		var walker: Node3D = instance
		while walker != model:
			transform = walker.transform * transform
			walker = walker.get_parent() as Node3D
		part.to_root = transform
		var running := 0
		part.surface_base.append(0)
		for surface in source.get_surface_count():
			assert(source.surface_get_primitive_type(surface) == Mesh.PRIMITIVE_TRIANGLES, "Shatter bake needs triangle surfaces")
			var arrays := source.surface_get_arrays(surface)
			part.surface_arrays.append(arrays)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			running += indices.size() / 3
			part.surface_base.append(running)
		parts.append(part)
	return parts

static func _gather_triangles(parts: Array[Part], centroids: PackedVector3Array, local_centroids: PackedVector3Array, areas: PackedFloat32Array) -> void:
	for part in parts:
		part.first_triangle = centroids.size()
		for arrays: Array in part.surface_arrays:
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for corner in range(0, indices.size(), 3):
				var a := vertices[indices[corner]]
				var b := vertices[indices[corner + 1]]
				var c := vertices[indices[corner + 2]]
				var local_centre := (a + b + c) / 3.0
				local_centroids.append(local_centre)
				centroids.append(part.to_root * local_centre)
				# Floor the weight so slivers still count towards where the seeds land.
				areas.append(maxf((b - a).cross(c - a).length() * .5, 1e-7))

## k-means++: each new seed is drawn with probability proportional to area x squared distance from the nearest seed.
static func _seed_cells(centroids: PackedVector3Array, areas: PackedFloat32Array, cells: int, rng: RandomNumberGenerator) -> PackedVector3Array:
	var seeds := PackedVector3Array()
	seeds.append(centroids[_pick_weighted(areas, rng)])
	var nearest := PackedFloat32Array()
	nearest.resize(centroids.size())
	for index in centroids.size():
		nearest[index] = centroids[index].distance_squared_to(seeds[0])
	var weights := PackedFloat32Array()
	weights.resize(centroids.size())
	while seeds.size() < cells:
		for index in centroids.size():
			weights[index] = nearest[index] * areas[index]
		var chosen := centroids[_pick_weighted(weights, rng)]
		seeds.append(chosen)
		for index in centroids.size():
			nearest[index] = minf(nearest[index], centroids[index].distance_squared_to(chosen))
	return seeds

static func _pick_weighted(weights: PackedFloat32Array, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for weight in weights:
		total += weight
	var target := rng.randf() * total
	for index in weights.size():
		target -= weights[index]
		if target <= 0.0:
			return index
	return weights.size() - 1

static func _assign(points: PackedVector3Array, seeds: PackedVector3Array, cell_of: PackedInt32Array) -> void:
	for index in points.size():
		var best := 0
		var best_distance := INF
		for cell in seeds.size():
			var distance := points[index].distance_squared_to(seeds[cell])
			if distance < best_distance:
				best_distance = distance
				best = cell
		cell_of[index] = best

static func _recentre(centroids: PackedVector3Array, areas: PackedFloat32Array, cell_of: PackedInt32Array, seeds: PackedVector3Array) -> void:
	var sums := PackedVector3Array()
	sums.resize(seeds.size())
	var weights := PackedFloat32Array()
	weights.resize(seeds.size())
	for index in centroids.size():
		sums[cell_of[index]] += centroids[index] * areas[index]
		weights[cell_of[index]] += areas[index]
	for cell in seeds.size():
		if weights[cell] > 0.0:
			seeds[cell] = sums[cell] / weights[cell]

## Gives every (mesh, cell) pair a shard id and returns how many shards the model has.
static func _make_shards(parts: Array[Part], cell_of: PackedInt32Array) -> int:
	var next_id := 0
	for part in parts:
		for triangle in range(part.first_triangle, part.first_triangle + part.surface_base[part.surface_base.size() - 1]):
			if not part.shard_of_cell.has(cell_of[triangle]):
				part.shard_of_cell[cell_of[triangle]] = next_id
				next_id += 1
	return next_id

static func _rebuild_mesh(part: Part, cell_of: PackedInt32Array, local_centroids: PackedVector3Array, areas: PackedFloat32Array) -> ArrayMesh:
	# Pivot = area-weighted centre of the shard's triangles (mesh space); radius = furthest corner from it.
	var pivot_sum: Dictionary = {}
	var pivot_weight: Dictionary = {}
	for surface in part.surface_arrays.size():
		var indices: PackedInt32Array = part.surface_arrays[surface][Mesh.ARRAY_INDEX]
		for triangle in indices.size() / 3:
			var global := part.first_triangle + part.surface_base[surface] + triangle
			var shard: int = part.shard_of_cell[cell_of[global]]
			pivot_sum[shard] = Vector3(pivot_sum.get(shard, Vector3.ZERO)) + local_centroids[global] * areas[global]
			pivot_weight[shard] = float(pivot_weight.get(shard, 0.0)) + areas[global]
	var pivots: Dictionary = {}
	for shard in pivot_sum:
		pivots[shard] = Vector3(pivot_sum[shard]) / float(pivot_weight[shard])
	var radii: Dictionary = {}
	for surface in part.surface_arrays.size():
		var vertices: PackedVector3Array = part.surface_arrays[surface][Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = part.surface_arrays[surface][Mesh.ARRAY_INDEX]
		for triangle in indices.size() / 3:
			var shard: int = part.shard_of_cell[cell_of[part.first_triangle + part.surface_base[surface] + triangle]]
			for corner in 3:
				radii[shard] = maxf(float(radii.get(shard, 0.0)), vertices[indices[triangle * 3 + corner]].distance_to(pivots[shard]))

	var rebuilt := ArrayMesh.new()
	rebuilt.resource_name = part.mesh.resource_name
	var flags := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	for surface in part.surface_arrays.size():
		var arrays: Array = part.surface_arrays[surface]
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var out_vertices := PackedVector3Array()
		var out_normals := PackedVector3Array()
		var out_uvs := PackedVector2Array()
		var out_uv2 := PackedVector2Array()
		var out_custom := PackedFloat32Array()
		var out_indices := PackedInt32Array()
		var remap: Dictionary = {}
		for triangle in indices.size() / 3:
			var shard: int = part.shard_of_cell[cell_of[part.first_triangle + part.surface_base[surface] + triangle]]
			var pivot: Vector3 = pivots[shard]
			for corner in 3:
				var source := indices[triangle * 3 + corner]
				var key := source * ID_STRIDE + shard
				if not remap.has(key):
					remap[key] = out_vertices.size()
					out_vertices.append(vertices[source])
					out_normals.append(normals[source])
					out_uvs.append(uvs[source] if not uvs.is_empty() else Vector2.ZERO)
					out_uv2.append(Vector2(radii[shard], 0.0))
					out_custom.append(pivot.x)
					out_custom.append(pivot.y)
					out_custom.append(pivot.z)
					out_custom.append(float(shard))
				out_indices.append(remap[key])
		var out: Array = []
		out.resize(Mesh.ARRAY_MAX)
		out[Mesh.ARRAY_VERTEX] = out_vertices
		out[Mesh.ARRAY_NORMAL] = out_normals
		out[Mesh.ARRAY_TEX_UV] = out_uvs
		out[Mesh.ARRAY_TEX_UV2] = out_uv2
		out[Mesh.ARRAY_CUSTOM0] = out_custom
		out[Mesh.ARRAY_INDEX] = out_indices
		rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out, [], {}, flags)
	return rebuilt
