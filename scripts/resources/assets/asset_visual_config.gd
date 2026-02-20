extends Resource
class_name AssetVisualConfig

## Visual configuration for a configurable game entity asset.
## Paths are validated by AssetConfigService and are expected to be under
## res://assets/ for this phase.

enum SpriteKind {
	STATIC,
	DIRECTIONAL_TEXTURES,
	ANIMATED,
}

enum OrientationMode {
	FIXED,
	FLIP_X_BY_VELOCITY,
	TEXTURE_LEFT_RIGHT,
	TEXTURE_8_DIR,
	ANIMATED_LEFT_RIGHT,
}

@export var sprite_kind: SpriteKind = SpriteKind.STATIC
@export var orientation_mode: OrientationMode = OrientationMode.FIXED

## Texture lookup keys are implementation-defined per orientation mode.
## Common keys: default, left, right, north, north_east, east, south_east, south,
## south_west, west, north_west, weapon.
@export var texture_paths: Dictionary = {}

## Optional SpriteFrames resource path for AnimatedSprite2D usage.
@export var sprite_frames_path: String = ""

## Optional animation name mapping, e.g. {"left":"move_left","right":"move_right"}.
@export var animation_map: Dictionary = {}
@export var animation_speed_fps: float = 12.0

@export var scale: Vector2 = Vector2.ONE
@export var modulate: Color = Color.WHITE
@export var position_offset: Vector2 = Vector2.ZERO
@export var anchor_bottom: bool = false

@export var idle_bounce_enabled: bool = false
@export var idle_bounce_min_y_scale: float = 0.95
@export var idle_bounce_cycle_seconds: float = 0.6

