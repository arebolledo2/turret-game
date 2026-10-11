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
const GROUND_SHADER: Shader = preload("res://assets/shaders/zone_ground.gdshader")
const PLANE_MARGIN: float = .5
const LABEL_HEIGHT: float = 1.2 # plus 1.1 m per metre of zone radius, so the name sits just beyond the prop
## Priority when zones overlap at a point (first match wins for text).
const TEXT_PRIORITY: Array[String] = [TerrainZone.NO_BUILD, TerrainZone.MUD, TerrainZone.HIGH_GROUND, TerrainZone.POWER_NODE]
const TURRET_ZONES: Array[String] = [TerrainZone.NO_BUILD, TerrainZone.HIGH_GROUND, TerrainZone.POWER_NODE]

var layout: ArenaLayout
var zones: Array[TerrainZone] = []
var columns: int = 0
var rows: int = 0
var cells: Array[PackedInt32Array] = []
var has_mud: bool = false
var root: Node3D
var parent_node: Node3D
var debug_root: Node3D
var debug_shown: bool = false
## True while the readable look (patterned ground, labels, hints) is built; follows the `zone_readability` flag.
var readable: bool = false
var motion_speed: float = 1.0
var labels: Array[Label3D] = []
var ground_materials: Array[ShaderMaterial] = []

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

## The strongest zone of `zone_type` at the point, or null.
func zone_covering(position: Vector3, zone_type: String) -> TerrainZone:
	var cell := _cell_xy(position.x, position.z)
	var best: TerrainZone = null
	for zone_index in cells[cell.y * columns + cell.x]:
		var zone := zones[zone_index]
		if zone.type == zone_type and zone.contains(position.x, position.z) and (not best or zone.strength > best.strength):
			best = zone
	return best

## "High ground · turrets +25% range" for the ground at the point, or "" on plain floor. `turret_only` skips mud.
func describe_at(position: Vector3, turret_only: bool = false) -> String:
	for zone_type in (TURRET_ZONES if turret_only else TEXT_PRIORITY):
		var zone := zone_covering(position, zone_type)
		if zone:
			return "%s · %s" % [zone.title(), zone.detail()]
	return ""

## One line naming every zone type in the layout and what it does (pause screen, wave announcement).
func legend() -> String:
	var seen: Array[String] = []
	var parts := PackedStringArray()
	for zone in zones:
		if zone.type not in seen:
			seen.append(zone.type)
			parts.append("%s  %s" % [zone.title().to_upper(), zone.detail()])
	return "TERRAIN  %s     %s" % [layout.layout_name.to_upper(), "   |   ".join(parts)]

## Colour for the minimap and anything else that must match what is drawn in the arena.
func tint(zone: TerrainZone) -> Color:
	return zone.color() if readable else zone.legacy_color()

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

## Adds the zone scenery under `parent` (freed with it) and returns the root node. The look follows the
## `zone_readability` flag at build time; `update_frame` rebuilds when the flag changes mid-run.
func build_visuals(parent: Node3D) -> Node3D:
	parent_node = parent
	readable = FeatureFlagService.is_enabled(FeatureFlagService.ZONE_READABILITY)
	labels.clear()
	ground_materials.clear()
	debug_root = null
	debug_shown = false
	motion_speed = _motion_speed()
	root = Node3D.new()
	root.name = "Terrain"
	parent.add_child(root)
	for zone in zones:
		if readable:
			_build_readable_zone(zone)
		else:
			_build_legacy_zone(zone)
	return root

## Per-frame upkeep: follows the readability flag, fades names with hero distance, honours reduced motion, debug draw.
func update_frame(hero_position: Vector3, show_debug: bool) -> void:
	if not root:
		return
	if FeatureFlagService.is_enabled(FeatureFlagService.ZONE_READABILITY) != readable:
		parent_node.remove_child(root)
		root.queue_free()
		build_visuals(parent_node)
	if readable:
		_update_labels(hero_position)
		var motion := _motion_speed()
		if not is_equal_approx(motion, motion_speed):
			motion_speed = motion
			for material in ground_materials:
				material.set_shader_parameter("motion", motion)
	update_debug(show_debug)

static func _motion_speed() -> float:
	return GameConstants.REDUCED_MOTION_SPEED if FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION) else 1.0

func _update_labels(hero_position: Vector3) -> void:
	var fade_span := maxf(GameConstants.ZONE_LABEL_FADE_RANGE - GameConstants.ZONE_LABEL_FULL_RANGE, .1)
	for index in labels.size():
		var distance := zones[index].distance_to(hero_position.x, hero_position.z)
		var alpha := clampf((GameConstants.ZONE_LABEL_FADE_RANGE - distance) / fade_span, 0.0, 1.0)
		var label := labels[index]
		label.visible = alpha > .02
		if label.visible:
			label.modulate.a = alpha
			label.outline_modulate.a = alpha

func _holder(zone: TerrainZone) -> Node3D:
	var holder := Node3D.new()
	holder.position = Vector3(zone.centre.x, 0, zone.centre.y)
	root.add_child(holder)
	return holder

## Patterned ground (see `zone_ground.gdshader`), a prop sized to the zone and a name that fades in on approach.
func _build_readable_zone(zone: TerrainZone) -> void:
	var holder := _holder(zone)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = zone.half_extents * 2.0 + Vector2.ONE * PLANE_MARGIN * 2.0
	ground.mesh = plane
	ground.material_override = _ground_material(zone, plane.size)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground.position.y = DECAL_HEIGHT
	holder.add_child(ground)
	var prop := (PROP_SCENES[zone.type] as PackedScene).instantiate() as Node3D
	prop.scale = Vector3.ONE * _prop_scale(prop, zone)
	holder.add_child(prop)
	var label := Label3D.new()
	label.text = "%s\n%s" % [zone.title().to_upper(), zone.detail()]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 44
	label.pixel_size = .009
	label.outline_size = 10
	label.modulate = Color(zone.color().lightened(.35), 0.0)
	label.outline_modulate = Color(0, 0, 0, 0)
	label.position.y = LABEL_HEIGHT + zone.radius * 1.1
	label.visible = false
	holder.add_child(label)
	labels.append(label)

func _ground_material(zone: TerrainZone, plane_size: Vector2) -> ShaderMaterial:
	var style: Dictionary = TerrainZone.TYPES[zone.type]
	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADER
	material.set_shader_parameter("zone_kind", int(style["kind"]))
	material.set_shader_parameter("is_circle", zone.is_circle)
	material.set_shader_parameter("half_size", zone.half_extents)
	material.set_shader_parameter("plane_size", plane_size)
	material.set_shader_parameter("base_color", style["base"])
	material.set_shader_parameter("accent_color", style["accent"])
	material.set_shader_parameter("fill_alpha", float(style["fill"]))
	material.set_shader_parameter("motion", motion_speed)
	ground_materials.append(material)
	return material

## Grows a prop to fill about half the zone without spilling out of it: `ZONE_PROP_FILL` of the narrowest half-width.
func _prop_scale(prop: Node3D, zone: TerrainZone) -> float:
	var reach := 0.0
	for found in prop.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := found as MeshInstance3D
		var transform_to_prop := Transform3D.IDENTITY
		var node: Node = mesh_instance
		while node != prop and node is Node3D:
			transform_to_prop = (node as Node3D).transform * transform_to_prop
			node = node.get_parent()
		var box := transform_to_prop * mesh_instance.get_aabb()
		reach = maxf(reach, maxf(maxf(absf(box.position.x), absf(box.end.x)), maxf(absf(box.position.z), absf(box.end.z))))
	if reach < .05:
		return 1.0
	var limit := minf(zone.half_extents.x, zone.half_extents.y) * GameConstants.ZONE_PROP_FILL
	return clampf(limit / reach, 1.0, GameConstants.ZONE_PROP_MAX_SCALE)

## The original look: flat translucent tint, edge ring, rim posts and a small prop. Kept behind `zone_readability`.
func _build_legacy_zone(zone: TerrainZone) -> void:
	var colour := zone.legacy_color()
	var holder := _holder(zone)
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
