class_name BeamLines
extends Node3D

## The drawn side of engine piece S11: a fixed set of straight beam segments, each one a stretched glowing box that is moved
## and shown or hidden, never created or freed while a beam runs. A turret's form makes one set (as many slots as it has beams,
## plus any flare) when it first needs it and frees it in `free_lines()` when the turret leaves or evolves; the slots are
## children of the turret, drawn in world space (`top_level`), so nothing outlives the turret. Hidden slots cost nothing to draw.
## Colours: player beams are cyan (the Prism Conductor boss owns the warm beams); the flare is white-hot.

const BEAM_COLOR := Color(.35, .95, 1.0, .85)
const FLARE_COLOR := Color(.85, 1.0, 1.0, .95)
const MAX_SLOTS: int = 8

static var beam_material: StandardMaterial3D
static var flare_material: StandardMaterial3D

var slots: Array[MeshInstance3D] = []

func _init(count: int = 1) -> void:
	top_level = true
	name = "BeamLines"
	_ensure_materials()
	for index in mini(count, MAX_SLOTS):
		var slot := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		slot.mesh = mesh
		slot.material_override = beam_material
		slot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		slot.visible = false
		add_child(slot)
		slots.append(slot)

static func _ensure_materials() -> void:
	if beam_material:
		return
	beam_material = _glow(BEAM_COLOR, 2.4)
	flare_material = _glow(FLARE_COLOR, 3.2)

static func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material

## Shows slot `index` as a segment from `from` to `to`, `width` metres thick; `flare` draws it white-hot.
func set_segment(index: int, from: Vector3, to: Vector3, width: float, flare: bool = false) -> void:
	if index < 0 or index >= slots.size():
		return
	var length := from.distance_to(to)
	if length < .01:
		slots[index].visible = false
		return
	var direction := (to - from) / length
	var up := Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > .99 else Vector3.UP
	var slot := slots[index]
	slot.material_override = flare_material if flare else beam_material
	slot.transform = Transform3D(Basis.looking_at(direction, up), (from + to) * .5)
	slot.scale = Vector3(width, width, length)
	slot.visible = true

func hide_slot(index: int) -> void:
	if index >= 0 and index < slots.size():
		slots[index].visible = false

func hide_all() -> void:
	for slot in slots:
		slot.visible = false

func visible_count() -> int:
	var count := 0
	for slot in slots:
		if slot.visible:
			count += 1
	return count

## Removes the set from the tree and frees it (safe to call twice).
func free_lines() -> void:
	if is_queued_for_deletion():
		return
	if get_parent():
		get_parent().remove_child(self)
	queue_free()
