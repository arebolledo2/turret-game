extends Resource
class_name AssetCollisionConfig

## Collision configuration for a configurable game entity asset.
## collision_profile_path is expected to point to a CollisionProfile resource.

@export var enabled: bool = true
@export var collision_profile_path: String = ""
@export var live_apply: bool = true

