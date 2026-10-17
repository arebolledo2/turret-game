class_name ShatterSet
extends Resource

## A pre-fractured copy of one enemy model, written by `ShatterBaker` and played by `DeathShatter`.
## `meshes` maps a MeshInstance3D's path under the model root to a replacement ArrayMesh with the same surfaces in the
## same order. Its vertices are split along crack lines and every vertex carries its shard's pivot (CUSTOM0.xyz, mesh
## space), a shard id (CUSTOM0.w) and the shard radius (UV2.x), which is all `shatter.gdshader` needs to throw it.
const DIRECTORY: String = "res://assets/models/clockwork/shatter/"

@export var meshes: Dictionary = {}
@export var shard_count: int = 0

## Where the baked shards of a ClockworkModels key live. Dropping a file here is all it takes to enable the effect.
static func path_for(key: String) -> String:
	return "%scp_%s.res" % [DIRECTORY, key]
