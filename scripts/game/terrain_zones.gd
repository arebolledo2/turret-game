class_name TerrainZones
extends RefCounted

## Runtime view of one `ArenaLayout`: a coarse spatial index for position queries and the scene nodes that make each
## zone readable (ground decal, edge ring, rim posts and a Blender prop at the centre).
## Queries take any Vector3 and read only x and z. A cell stores the indices of every zone that overlaps it, so a
## lookup is one cell read plus a shape test per overlapping zone.
const CELL: float = 2.0
const PROP_SCENES: Dictionary = {
	TerrainZone.HIGH_GROUND: preload("res://assets/models/game/zone_high_ground.glb"),
	TerrainZone.MUD: preload("res://assets/models/game/zone_mud.glb"),
	TerrainZone.NO_BUILD: preload("res://assets/models/game/zone_no_build.glb"),
	TerrainZone.POWER_NODE: preload("res://assets/models/game/zone_power_node.glb"),
}
const MARKER_SCENE: PackedScene = preload("res://assets/models/game/zone_marker.glb")
const MARKER_SPACING: float = 1.7
const DECAL_HEIGHT: float = .012
const RING_HEIGHT: float = .022

var layout: ArenaLayout
var zones: Array[TerrainZone] = []
var columns: int = 0
var rows: int = 0
var cells: Array[PackedInt32Array] = []
var has_mud: bool = false
var root: Node3D
var debug_root: Node3D
var debug_shown: bool = false

static var decal_materials: Dictionary = {}
static var marker_materials: Dictionary = {}

func _init(arena_layout: ArenaLayout) -> void:
	layout = arena_layout
	zones = arena_layout.zones
	var half := WorldGeometry.HALF_ARENA
	columns = ceili(half.x * 2.0 / CELL)
	rows = ceili(half.y * 2.0 / CELL)
	cells.resize(columns * rows)
	for index in cells.size():
		cells[index] = PackedInt32Array()
	for zone_index in zones.size():
		var zone := zones[zone_index]
		has_mud = has_mud or zone.type == TerrainZone.MUD
		var low := _cell_xy(zone.centre.x - zone.half_extents.x, zone.centre.y - zone.half_extents.y)
		var high := _cell_xy(zone.centre.x + zone.half_extents.x, zone.centre.y + zone.half_extents.y)
		for cx in range(low.x, high.x + 1):
			for cz in range(low.y, high.y + 1):
				cells[cz * columns + cx].append(zone_index)

func _cell_xy(x: float, z: float) -> Vector2i:
	var half := WorldGeometry.HALF_ARENA
	return Vector2i(clampi(int((x + half.x) / CELL), 0, columns - 1), clampi(int((z + half.y) / CELL), 0, rows - 1))

# ---- Queries ---------------------------------------------------------------------------------------------------

## Strongest bonus of `zone_type` covering the point (0 when none).
func strongest_at(position: Vector3, zone_type: String) -> float:
	var cell := _cell_xy(position.x, position.z)
	var best := 0.0
	for zone_index in cells[cell.y * columns + cell.x]:
		var zone := zones[zone_index]
		if zone.type == zone_type and zone.contains(position.x, position.z):
			best = maxf(best, zone.strength)
	return best

func covers(position: Vector3, zone_type: String) -> bool:
	var cell := _cell_xy(position.x, position.z)
	for zone_index in cells[cell.y * columns + cell.x]:
		var zone := zones[zone_index]
		if zone.type == zone_type and zone.contains(position.x, position.z):
			return true
	return false

func blocks_build(position: Vector3) -> bool:
	return covers(position, TerrainZone.NO_BUILD)

## Movement multiplier from mud (1.0 outside), never below 1 - ZONE_MUD_MAX_SLOW. Called per enemy per tick, so it
## returns at once when the layout has no mud.
func mud_factor_at(position: Vector3) -> float:
	if not has_mud:
		return 1.0
	return 1.0 - minf(strongest_at(position, TerrainZone.MUD), GameConstants.ZONE_MUD_MAX_SLOW)

func range_bonus_at(position: Vector3) -> float:
	return strongest_at(position, TerrainZone.HIGH_GROUND)

func entrench_bonus_at(position: Vector3) -> float:
	return strongest_at(position, TerrainZone.POWER_NODE)

# ---- Visuals ---------------------------------------------------------------------------------------------------

## Adds the zone scenery under `parent` (freed with it) and returns the root node.
func build_visuals(parent: Node3D) -> Node3D:
	root = Node3D.new()
	root.name = "Terrain"
	parent.add_child(root)
	for zone in zones:
		_build_zone(zone)
	return root

func _build_zone(zone: TerrainZone) -> void:
	var colour := zone.color()
	var holder := Node3D.new()
	holder.position = Vector3(zone.centre.x, 0, zone.centre.y)
	root.add_child(holder)
	var decal := MeshInstance3D.new()
	if zone.is_circle:
		var disc := CylinderMesh.new()
		disc.top_radius = zone.radius
		disc.bottom_radius = zone.radius
		disc.height = .01
		disc.radial_segments = 40
		disc.rings = 1
		decal.mesh = disc
	else:
		var slab := BoxMesh.new()
		slab.size = Vector3(zone.half_extents.x * 2.0, .01, zone.half_extents.y * 2.0)
		decal.mesh = slab
	decal.material_override = _decal_material(colour)
	decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	decal.position.y = DECAL_HEIGHT
	holder.add_child(decal)
	var prop := (PROP_SCENES[zone.type] as PackedScene).instantiate() as Node3D
	holder.add_child(prop)
	var posts: Array[Transform3D] = _marker_transforms(zone)
	var marker_mesh := _marker_mesh()
	if marker_mesh and not posts.is_empty():
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = marker_mesh
		multimesh.instance_count = posts.size()
		for index in posts.size():
			multimesh.set_instance_transform(index, posts[index])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.material_override = _marker_material(colour)
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(instance)
	if zone.is_circle:
		var ring := WorldGeometry.ring(holder, zone.radius, colour)
		ring.position.y = RING_HEIGHT

## Posts spaced around the zone's edge, in the holder's local space.
func _marker_transforms(zone: TerrainZone) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	if zone.is_circle:
		var count := maxi(6, roundi(TAU * zone.radius / MARKER_SPACING))
		for index in count:
			var angle := TAU * float(index) / float(count)
			result.append(Transform3D(Basis.IDENTITY, Vector3(cos(angle), 0, sin(angle)) * zone.radius))
		return result
	var hx := zone.half_extents.x
	var hz := zone.half_extents.y
	var along_x := maxi(2, roundi(hx * 2.0 / MARKER_SPACING))
	var along_z := maxi(1, roundi(hz * 2.0 / MARKER_SPACING))
	for index in along_x + 1:
		var x := -hx + hx * 2.0 * float(index) / float(along_x)
		result.append(Transform3D(Basis.IDENTITY, Vector3(x, 0, -hz)))
		result.append(Transform3D(Basis.IDENTITY, Vector3(x, 0, hz)))
	for index in range(1, along_z):
		var z := -hz + hz * 2.0 * float(index) / float(along_z)
		result.append(Transform3D(Basis.IDENTITY, Vector3(-hx, 0, z)))
		result.append(Transform3D(Basis.IDENTITY, Vector3(hx, 0, z)))
	return result

static func _marker_mesh() -> Mesh:
	var instance := MARKER_SCENE.instantiate()
	var mesh_instance := instance.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = (mesh_instance[0] as MeshInstance3D).mesh if not mesh_instance.is_empty() else null
	instance.free()
	return mesh

static func _decal_material(colour: Color) -> StandardMaterial3D:
	if not decal_materials.has(colour):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(colour.r, colour.g, colour.b, .17)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		decal_materials[colour] = material
	return decal_materials[colour]

static func _marker_material(colour: Color) -> StandardMaterial3D:
	if not marker_materials.has(colour):
		marker_materials[colour] = WorldGeometry.material(colour, true)
	return marker_materials[colour]

# ---- Debug draw ------------------------------------------------------------------------------------------------

## Shows or hides labels and bright outlines for every zone (flag `debug_zones`). Cheap to call every frame.
func update_debug(show: bool) -> void:
	if show == debug_shown or not root:
		return
	debug_shown = show
	if not show:
		if debug_root:
			debug_root.visible = false
		return
	if not debug_root:
		debug_root = Node3D.new()
		debug_root.name = "ZoneDebug"
		root.add_child(debug_root)
		for zone in zones:
			var label := Label3D.new()
			label.text = zone.label()
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.no_depth_test = true
			label.font_size = 48
			label.pixel_size = .01
			label.modulate = zone.color()
			label.outline_size = 12
			label.position = Vector3(zone.centre.x, 2.2, zone.centre.y)
			debug_root.add_child(label)
			var pole := MeshInstance3D.new()
			var shaft := CylinderMesh.new()
			shaft.top_radius = .04
			shaft.bottom_radius = .04
			shaft.height = 2.2
			pole.mesh = shaft
			pole.material_override = _marker_material(zone.color())
			pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pole.position = Vector3(zone.centre.x, 1.1, zone.centre.y)
			debug_root.add_child(pole)
	debug_root.visible = true
