extends Resource
class_name EntityAssetConfig

const AssetVisualConfigClass = preload("res://scripts/resources/assets/asset_visual_config.gd")
const AssetCollisionConfigClass = preload("res://scripts/resources/assets/asset_collision_config.gd")

enum EntityKind {
	ENEMY,
	TURRET,
	PLAYER,
}

@export var entity_kind: EntityKind = EntityKind.ENEMY
@export var asset_id: String = ""
@export var display_name: String = ""
@export var visual: AssetVisualConfig = AssetVisualConfigClass.new()
@export var collision: AssetCollisionConfig = AssetCollisionConfigClass.new()

