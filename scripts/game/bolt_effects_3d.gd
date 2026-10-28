class_name BoltEffects3D
extends RefCounted

## Hit-scan tracers (Sniper), chain-lightning arcs and their strike flashes. `CombatEffects3D` owns one and ticks it; the
## pooled meshes and lights are children of `host`, and every pool is capped.
const MAX_ARCS: int = 16
const MAX_TRACERS: int = 8
const TRACER_LIFETIME: float = .16
const TRACER_WIDTH: float = .07
const ARC_LIFETIME: float = .26
## The bolt's shape is re-rolled this often while it lives, which is what makes it crackle instead of sit still.
const ARC_REROLL_INTERVAL: float = .05
## Each chain jump lights this much later than the one before it, so the chain visibly travels.
const ARC_HOP_DELAY: float = .045
## Midpoint-displacement passes for the main bolt (2^n + 1 points) and for its forks.
const BOLT_PASSES: int = 5
const FORK_PASSES: int = 3
const BOLT_JAG: float = .26
const BOLT_HALF_WIDTH: float = .15
const MAX_ARC_LIGHTS: int = 4
const ARC_LIGHT_LIFETIME: float = .14
const ARC_LIGHT_ENERGY: float = 3.0
var host: CombatEffects3D
var arcs: Array[MeshInstance3D] = []
var arc_lifetimes: Array[float] = []
## Per-arc endpoints (from, to), seconds until the arc lights, and seconds until its shape is next re-rolled.
var arc_ends: Array[PackedVector3Array] = []
var arc_delays: Array[float] = []
var arc_rerolls: Array[float] = []
var arc_lights: Array[OmniLight3D] = []
## Hit-scan tracers (Sniper): a stretched box that thins out over TRACER_LIFETIME. Age 0 means the slot is free.
var tracers: Array[MeshInstance3D] = []
var tracer_ages: Array[float] = []
var tracer_lengths: Array[float] = []
var tracer_material := WorldGeometry.material(Color(1.7, 1.55, 1.15), true)
var arc_light_ages: Array[float] = []
var next_arc_light: int = 0
## Decorative noise only: its own stream, so bolt shapes never consume the combat random stream.
var bolt_rng := RandomNumberGenerator.new()
var arc_shader := preload("res://assets/shaders/lightning_bolt.gdshader")

func _init(owner: CombatEffects3D) -> void:
	host = owner
	bolt_rng.seed = 20260711

func update(delta: float) -> void:
	_update_arcs(delta)
	_update_arc_lights(delta)
	_update_tracers(delta)

func reset() -> void:
	for index in range(arc_lights.size()):
		arc_light_ages[index] = -1.0
		arc_lights[index].visible = false
	for index in range(arcs.size()):
		arc_lifetimes[index] = 0.0
		arc_delays[index] = 0.0
		arcs[index].visible = false
	for index in range(tracers.size()):
		tracer_ages[index] = 0.0
		tracers[index].visible = false

## A straight, brief bright line from `from` to `to` for hit-scan shots. Pooled; silently dropped when the pool is full.
func show_tracer(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < .01:
		return
	var index := tracer_ages.find(0.0)
	if index < 0:
		if tracers.size() >= MAX_TRACERS:
			return
		var tracer := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		tracer.mesh = mesh
		tracer.material_override = tracer_material
		tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tracer.visible = false
		host.add_child(tracer)
		tracers.append(tracer)
		tracer_ages.append(0.0)
		tracer_lengths.append(0.0)
		index = tracers.size() - 1
	var direction := (to - from) / length
	var up := Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > .99 else Vector3.UP
	tracers[index].transform = Transform3D(Basis.looking_at(direction, up), (from + to) * .5)
	tracer_lengths[index] = length
	tracer_ages[index] = TRACER_LIFETIME
	_pose_tracer(index)

func _pose_tracer(index: int) -> void:
	var fade := tracer_ages[index] / TRACER_LIFETIME
	tracers[index].scale = Vector3(TRACER_WIDTH * fade, TRACER_WIDTH * fade, tracer_lengths[index])
	tracers[index].visible = tracer_ages[index] > 0.0

func _update_tracers(delta: float) -> void:
	for index in range(tracers.size()):
		if tracer_ages[index] > 0.0:
			tracer_ages[index] = maxf(0.0, tracer_ages[index] - delta)
			_pose_tracer(index)

## Queues one lightning bolt. `hop` is the chain jump number (0 = first strike); later hops light a beat after the one
## before so the chain visibly travels. The bolt's shape is decorative and never touches the combat random stream.
func show_arc(from: Vector3, to: Vector3, hop: int = 0) -> void:
	if from.distance_squared_to(to) < .0001:
		return
	var index := arc_lifetimes.find(0.0)
	if index < 0:
		if arcs.size() >= MAX_ARCS:
			return
		var arc := MeshInstance3D.new()
		arc.mesh = ImmediateMesh.new()
		var material := ShaderMaterial.new()
		material.shader = arc_shader
		arc.material_override = material
		arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arc.visible = false
		host.add_child(arc)
		arcs.append(arc)
		arc_lifetimes.append(0.0)
		arc_ends.append(PackedVector3Array())
		arc_delays.append(0.0)
		arc_rerolls.append(0.0)
		index = arcs.size() - 1
	arc_ends[index] = PackedVector3Array([from, to])
	arc_delays[index] = maxi(hop, 0) * ARC_HOP_DELAY
	arc_lifetimes[index] = ARC_LIFETIME
	arcs[index].visible = false
	if arc_delays[index] <= 0.0:
		_start_arc(index)

## Lights a queued arc: first frame of its shape, the impact burst, and the short light flash at the strike point.
func _start_arc(index: int) -> void:
	var material := arcs[index].material_override as ShaderMaterial
	material.set_shader_parameter("age", 0.0)
	material.set_shader_parameter("reduced_motion", FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION))
	arc_rerolls[index] = ARC_REROLL_INTERVAL
	_build_bolt(index)
	arcs[index].visible = true
	var to := arc_ends[index][1]
	host.show_burst(to, "shock")
	host._show_spark(to, host.shock_material, .18, .08)
	_flash_light(to + Vector3(0, .6, 0))

func _update_arcs(delta: float) -> void:
	var reduced := FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION)
	for index in range(arcs.size()):
		if arc_lifetimes[index] <= 0.0:
			arcs[index].visible = false
			continue
		if arc_delays[index] > 0.0:
			arc_delays[index] -= delta
			if arc_delays[index] <= 0.0:
				arc_delays[index] = 0.0
				_start_arc(index)
			continue
		arc_lifetimes[index] = maxf(0.0, arc_lifetimes[index] - delta)
		arcs[index].visible = arc_lifetimes[index] > 0.0
		if not arcs[index].visible:
			continue
		(arcs[index].material_override as ShaderMaterial).set_shader_parameter("age", 1.0 - arc_lifetimes[index] / ARC_LIFETIME)
		arc_rerolls[index] -= delta
		if arc_rerolls[index] <= 0.0 and not reduced:
			arc_rerolls[index] = ARC_REROLL_INTERVAL
			_build_bolt(index)

## Rebuilds the arc's mesh: one jagged main bolt plus a few fading forks, as camera-facing ribbons.
func _build_bolt(index: int) -> void:
	var mesh := arcs[index].mesh as ImmediateMesh
	mesh.clear_surfaces()
	var from := arc_ends[index][0]
	var to := arc_ends[index][1]
	var length := from.distance_to(to)
	var heading := (to - from) / length
	var spine := _bolt_points(from, to, BOLT_PASSES)
	_add_ribbon(mesh, spine, BOLT_HALF_WIDTH, 1.0, false)
	for fork in range(bolt_rng.randi_range(2, 3)):
		var start := spine[bolt_rng.randi_range(int(spine.size() * .2), int(spine.size() * .8))]
		var turn := deg_to_rad(bolt_rng.randf_range(18.0, 42.0)) * (1.0 if bolt_rng.randf() < .5 else -1.0)
		var tip := start + heading.rotated(Vector3.UP, turn) * length * bolt_rng.randf_range(.16, .3)
		_add_ribbon(mesh, _bolt_points(start, tip, FORK_PASSES), BOLT_HALF_WIDTH * .55, .7, true)

## Midpoint displacement: split every segment, push its midpoint sideways by a fraction of the segment length, repeat.
## Endpoints stay pinned, and the offsets shrink with the segments, which gives the fractal lightning silhouette.
func _bolt_points(from: Vector3, to: Vector3, passes: int) -> PackedVector3Array:
	var points := PackedVector3Array([from, to])
	for _pass in range(passes):
		var refined := PackedVector3Array()
		for i in range(points.size() - 1):
			var a := points[i]
			var b := points[i + 1]
			var along := b - a
			var side := along.cross(Vector3.UP)
			side = side.normalized() if side.length_squared() > .000001 else Vector3.RIGHT
			var push := along.length() * BOLT_JAG
			refined.append(a)
			refined.append((a + b) * .5 + side * bolt_rng.randf_range(-1.0, 1.0) * push + Vector3.UP * bolt_rng.randf_range(-1.0, 1.0) * push * .3)
		refined.append(points[points.size() - 1])
		points = refined
	return points

## Camera-facing triangle strip along `points`. Strength is the shader's per-vertex brightness; forks fade and thin out.
func _add_ribbon(mesh: ImmediateMesh, points: PackedVector3Array, half_width: float, strength: float, taper: bool) -> void:
	var view := Vector3.UP
	if host.world and host.world.camera:
		view = host.world.camera.global_transform.basis.z
	var last := points.size() - 1
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(points.size()):
		var side := (points[mini(i + 1, last)] - points[maxi(i - 1, 0)]).cross(view)
		side = side.normalized() if side.length_squared() > .000001 else Vector3.RIGHT
		var t := float(i) / float(last)
		var width := half_width * (1.0 - t * .85) if taper else half_width
		mesh.surface_set_color(Color(strength * (1.0 - t) if taper else strength, 0.0, 0.0))
		mesh.surface_set_uv(Vector2(0.0, t))
		mesh.surface_add_vertex(points[i] - side * width)
		mesh.surface_set_uv(Vector2(1.0, t))
		mesh.surface_add_vertex(points[i] + side * width)
	mesh.surface_end()

## Short pooled omni flash at a strike so the floor and nearby enemies light up with the bolt.
func _flash_light(at: Vector3) -> void:
	var index := next_arc_light
	if arc_lights.size() < MAX_ARC_LIGHTS:
		index = arc_lights.size()
		var light := OmniLight3D.new()
		light.light_color = Color(.55, .8, 1.0)
		light.omni_range = 4.5
		light.shadow_enabled = false
		light.visible = false
		host.add_child(light)
		arc_lights.append(light)
		arc_light_ages.append(-1.0)
	else:
		next_arc_light = (next_arc_light + 1) % MAX_ARC_LIGHTS
	arc_lights[index].position = at
	arc_lights[index].light_energy = ARC_LIGHT_ENERGY
	arc_lights[index].visible = true
	arc_light_ages[index] = 0.0

func _update_arc_lights(delta: float) -> void:
	var reduced := FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION)
	for index in range(arc_lights.size()):
		if arc_light_ages[index] < 0.0:
			continue
		arc_light_ages[index] += delta
		if arc_light_ages[index] >= ARC_LIGHT_LIFETIME:
			arc_light_ages[index] = -1.0
			arc_lights[index].visible = false
			continue
		var remaining := 1.0 - arc_light_ages[index] / ARC_LIGHT_LIFETIME
		arc_lights[index].light_energy = ARC_LIGHT_ENERGY * (.35 if reduced else 1.0) * remaining * remaining
