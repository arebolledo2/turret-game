class_name FloorDecals
extends Node3D

## Projected marks that sit on the arena floor only: a big soft blotch and scattered stains that break up the texture
## repeat, plus scorch marks left by explosions. Decals only light surfaces on `LAYER`, so units and props stay clean.
const LAYER: int = 1 << 19
const STAIN_COUNT: int = 30
const MAX_SCORCH: int = 24
const SCORCH_MIN_SPACING: float = 1.0
const DECAL_DEPTH: float = 1.0

## Per-theme tint of the blotch and stains, as (blotch, stain).
const TINTS := {
	"foundry": [Color(0.0, 0.05, 0.08, 0.5), Color(0.02, 0.03, 0.04, 0.55)],
	"concrete": [Color(0.04, 0.035, 0.02, 0.5), Color(0.05, 0.04, 0.03, 0.5)],
	"grating": [Color(0.0, 0.05, 0.03, 0.55), Color(0.03, 0.02, 0.0, 0.6)],
}

var _blotch: Decal
var _stains: Array[Decal] = []
var _scorches: Array[Decal] = []
var _next_scorch: int = 0
var _radial: GradientTexture2D

func _init() -> void:
	name = "FloorDecals"
	_radial = _make_radial()

## Rebuilds the blotch and stains for a floor theme. Seeded by theme, so a theme always looks the same.
func apply_theme(theme: String) -> void:
	for stain in _stains:
		stain.queue_free()
	_stains.clear()
	if is_instance_valid(_blotch):
		_blotch.queue_free()
	var tints: Array = TINTS.get(theme, TINTS[WorldGeometry.DEFAULT_FLOOR_THEME])
	var half := WorldGeometry.HALF_ARENA
	_blotch = _decal(Vector3(half.x * 2.0 + 4.0, DECAL_DEPTH, half.y * 2.0 + 4.0), _make_blotch_texture(hash(theme)), tints[0])
	add_child(_blotch)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(theme + "_stains")
	for index in STAIN_COUNT:
		var size := Vector3(rng.randf_range(2.0, 7.0), DECAL_DEPTH, rng.randf_range(2.0, 7.0))
		var stain := _decal(size, _radial, tints[1])
		stain.position = Vector3(rng.randf_range(-half.x, half.x), 0.0, rng.randf_range(-half.y, half.y))
		stain.rotation.y = rng.randf_range(0.0, TAU)
		stain.modulate.a *= rng.randf_range(0.35, 1.0)
		add_child(stain)
		_stains.append(stain)

## Leaves a burn mark where something exploded. Oldest marks are recycled once the pool is full.
func add_scorch(at: Vector3, radius: float) -> void:
	for scorch in _scorches:
		if scorch.visible and scorch.position.distance_to(Vector3(at.x, 0.0, at.z)) < SCORCH_MIN_SPACING:
			return
	var scorch: Decal
	if _scorches.size() < MAX_SCORCH:
		scorch = _decal(Vector3.ONE, _radial, Color(0.0, 0.0, 0.0, 0.55))
		add_child(scorch)
		_scorches.append(scorch)
	else:
		scorch = _scorches[_next_scorch]
		_next_scorch = (_next_scorch + 1) % MAX_SCORCH
	var diameter := clampf(radius * 1.6, 1.2, 5.0)
	scorch.size = Vector3(diameter, DECAL_DEPTH, diameter)
	scorch.position = Vector3(at.x, 0.0, at.z)
	scorch.rotation.y = fmod(at.x * 12.9898 + at.z * 78.233, TAU)
	scorch.visible = true

func clear_scorches() -> void:
	for scorch in _scorches:
		scorch.visible = false
	_next_scorch = 0

func scorch_count() -> int:
	var count := 0
	for scorch in _scorches:
		if scorch.visible:
			count += 1
	return count

func _decal(size: Vector3, texture: Texture2D, tint: Color) -> Decal:
	var decal := Decal.new()
	decal.size = size
	decal.texture_albedo = texture
	decal.modulate = tint
	decal.cull_mask = LAYER
	decal.upper_fade = 0.0
	decal.lower_fade = 0.0
	return decal

func _make_radial() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 128
	texture.height = 128
	return texture

func _make_blotch_texture(seed_value: int) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	noise.seed = seed_value
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1)])
	ramp.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.color_ramp = ramp
	texture.width = 256
	texture.height = 256
	return texture
