class_name GroundZones
extends Node3D

## Enemy-only ground zones (S7). A turret lays a temporary patch of floor (a circle, or a line for a fissure) that slows the
## ENEMIES standing in it and never the hero. Unlike the static terrain mud (`TerrainZones`, which slows both), zones are
## created and expired at run time, so this is a bounded pool:
##   - at most `GameConstants.GROUND_ZONE_MAX` are alive; adding one past the cap recycles the zone closest to expiring;
##   - the visuals are pooled `MeshInstance3D` quads (one shared mesh, one material each), built on demand up to the cap;
##   - time only passes in combat, and every zone is dropped the moment combat stops (wave end, pause, defeat) and on a
##     run reset, like the other transient effects.
## Enemies read it through `speed_factor_at` from `EnemyActor._steer`, where the stronger of the zone slow and any status
## slow wins (slows from different sources never multiply, and the 90% cap holds). The hero never asks.
##
## For turrets: `add_circle(...)` / `add_line(...)` return the `GroundZone`; `enemies_in(zone, world.enemies)` lists the
## enemies standing in it right now (for a one-off hit when it opens); `speed_factor_at` and `covering` are the queries.
const SHADER: Shader = preload("res://assets/shaders/ground_zone.gdshader")
const HEIGHT: float = .035
## Visual margin around the true shape, in metres.
const MARGIN: float = .5
## Seconds a zone takes to open (the visual grows in; the slow is active at once).
const OPEN_SECONDS: float = .3
const STYLES: Dictionary = {GroundZone.STYLE_DISC: 0, GroundZone.STYLE_RIFT: 1}
static var plane: PlaneMesh

var world: ArenaWorld
var zones: Array[GroundZone] = []
## Every visual built so far, and the ones not currently showing a zone.
var nodes: Array[MeshInstance3D] = []
var idle: Array[MeshInstance3D] = []

## A round zone of `radius` metres around `centre`. `slow` is the share of speed it takes (0 for a purely visual patch).
func add_circle(centre: Vector3, radius: float, duration: float, slow: float = 0.0, source_id: int = 0, style: String = GroundZone.STYLE_DISC) -> GroundZone:
	var zone := GroundZone.new()
	zone.shape = GroundZone.Shape.CIRCLE
	zone.centre = WorldGeometry.planar(centre)
	zone.radius = maxf(radius, .05)
	return _add(zone, duration, slow, source_id, style)

## A straight zone from `from` to `to`, `half_width` metres either side of that line, with flat ends.
func add_line(from: Vector3, to: Vector3, half_width: float, duration: float, slow: float = 0.0, source_id: int = 0, style: String = GroundZone.STYLE_RIFT) -> GroundZone:
	var zone := GroundZone.new()
	zone.shape = GroundZone.Shape.LINE
	var span := WorldGeometry.planar(to - from)
	zone.centre = WorldGeometry.planar(from) + span * .5
	zone.half_length = maxf(span.length() * .5, .05)
	zone.direction = span.normalized() if span.length_squared() > .000001 else Vector3(0, 0, -1)
	zone.half_width = maxf(half_width, .05)
	return _add(zone, duration, slow, source_id, style)

func _add(zone: GroundZone, duration: float, slow: float, source_id: int, style: String) -> GroundZone:
	zone.duration = maxf(duration, .05)
	zone.slow = clampf(slow, 0.0, GameConstants.GROUND_ZONE_MAX_SLOW)
	zone.source_id = source_id
	zone.style = style
	if zones.size() >= GameConstants.GROUND_ZONE_MAX:
		_release(_closest_to_expiry())
	zone.node = _take_node()
	_dress(zone)
	zones.append(zone)
	return zone

func has_zones() -> bool:
	return not zones.is_empty()

func count() -> int:
	return zones.size()

## Share of speed an enemy keeps at `position` (1 outside every zone). `margin` is the body radius: standing on the edge counts.
## Overlapping zones do not stack: the strongest wins.
func speed_factor_at(position: Vector3, margin: float = 0.0) -> float:
	var strongest := 0.0
	for zone in zones:
		if zone.slow > strongest and zone.contains(position, margin):
			strongest = zone.slow
	return 1.0 - strongest

func covering(position: Vector3, margin: float = 0.0) -> Array[GroundZone]:
	var found: Array[GroundZone] = []
	for zone in zones:
		if zone.contains(position, margin):
			found.append(zone)
	return found

## Living enemies standing in `zone` right now, taken before any hit lands so death notifications cannot change the set.
func enemies_in(zone: GroundZone, candidates: Array[CombatActor]) -> Array[CombatActor]:
	var found: Array[CombatActor] = []
	for candidate in candidates:
		if is_instance_valid(candidate) and not candidate.dead and zone.contains(candidate.position, candidate.hurtbox_radius()):
			found.append(candidate)
	return found

## Advances every zone's clock, retires the ones that ran out and animates the rest.
func tick(delta: float) -> void:
	for index in range(zones.size() - 1, -1, -1):
		var zone := zones[index]
		zone.age += delta
		if zone.is_expired():
			_release(zone)
		else:
			_animate(zone)

## Drops every zone and hides its visual (combat stopped, or a new run).
func clear() -> void:
	for index in range(zones.size() - 1, -1, -1):
		_release(zones[index])

func _physics_process(delta: float) -> void:
	if world != null and not world.is_combat():
		clear()
		return
	tick(delta)

func _closest_to_expiry() -> GroundZone:
	var best := zones[0]
	for zone in zones:
		if zone.remaining() < best.remaining():
			best = zone
	return best

func _release(zone: GroundZone) -> void:
	zones.erase(zone)
	if zone.node:
		zone.node.visible = false
		idle.append(zone.node)
		zone.node = null

func _take_node() -> MeshInstance3D:
	if not idle.is_empty():
		return idle.pop_back()
	if not plane:
		plane = PlaneMesh.new()
		plane.size = Vector2.ONE
	var instance := MeshInstance3D.new()
	instance.mesh = plane
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = SHADER
	instance.material_override = material
	instance.visible = false
	add_child(instance)
	nodes.append(instance)
	return instance

## Places and styles the visual for a new zone.
func _dress(zone: GroundZone) -> void:
	var instance := zone.node
	var material := instance.material_override as ShaderMaterial
	var circle := zone.shape == GroundZone.Shape.CIRCLE
	var half := Vector2(zone.radius, zone.radius) if circle else Vector2(zone.half_width, zone.half_length)
	var size := (half + Vector2.ONE * MARGIN) * 2.0
	instance.position = Vector3(zone.centre.x, HEIGHT, zone.centre.z)
	instance.rotation = Vector3.ZERO if circle else Vector3(0, atan2(-zone.direction.x, -zone.direction.z), 0)
	instance.scale = Vector3(size.x, 1.0, size.y)
	material.set_shader_parameter("style", int(STYLES.get(zone.style, 0)))
	material.set_shader_parameter("is_circle", circle)
	material.set_shader_parameter("half_size", half)
	material.set_shader_parameter("plane_size", size)
	material.set_shader_parameter("tint", zone.tint)
	material.set_shader_parameter("motion", GameConstants.REDUCED_MOTION_SPEED if FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION) else 1.0)
	_animate(zone)
	instance.visible = true

func _animate(zone: GroundZone) -> void:
	if not zone.node:
		return
	var material := zone.node.material_override as ShaderMaterial
	material.set_shader_parameter("life", zone.fraction())
	material.set_shader_parameter("open", 1.0 if FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION) else clampf(zone.age / OPEN_SECONDS, 0.0, 1.0))
