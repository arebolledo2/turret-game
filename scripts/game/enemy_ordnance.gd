class_name EnemyOrdnance
extends Node3D

## Hostile-only attacks; never use the friendly projectile pool or offensive item procs.
## World cleanup frees these nodes, while pausing freezes both warning and damage clocks.
var world: ArenaWorld
var source: CombatActor
var kind: String = "bolt"
var to_core: bool = false
var damage: float = 5.0
var heading: Vector3 = Vector3.FORWARD
var target_at: Vector3
var radius: float = .65
var shot_speed: float = 6.75
var warning_time: float = 1.2
var elapsed: float = 0.0
var lifetime: float = 5.0
var fired: bool = false
var dial: MeshInstance3D
var body: Node3D
var origin: Vector3
var beam_length: float = 7.0
var beam_width: float = .22
var hit_clock: float = 0.0
var angular_speed: float = 0.0

static func launch(actor: CombatActor, mode: String, at: Vector3, target: Vector3, amount: float, core_target: bool = false) -> EnemyOrdnance:
	var attack := EnemyOrdnance.new()
	attack.world = actor.world
	attack.source = actor
	attack.kind = mode
	attack.position = at
	attack.origin = at
	attack.target_at = WorldGeometry.planar(target)
	attack.heading = WorldGeometry.planar(target - at).normalized()
	attack.damage = amount
	attack.to_core = core_target
	return attack

func _ready() -> void:
	add_to_group("hostile_ordnance")
	var dark := WorldGeometry.material(Color("382632"))
	var warm := WorldGeometry.material(Color("ff7356"), true)
	var hot := WorldGeometry.material(Color("ffe4a5"), true)
	body = Node3D.new()
	add_child(body)
	if kind == "bolt":
		var shell := WorldGeometry.sphere(body, .12, Vector3.ZERO, dark)
		shell.scale = Vector3(.7, .7, 1.7)
		var core := WorldGeometry.sphere(body, .085, Vector3(0, 0, -.16), hot)
		core.scale.z = 1.8
		for side: float in [-1.0, 1.0]:
			WorldGeometry.box(body, Vector3(.035, .04, .32), Vector3(side * .09, 0, .06), warm)
		var trail := WorldGeometry.sphere(body, .085, Vector3(0, 0, .3), warm)
		trail.scale = Vector3(.6, .6, 4.5)
		body.rotation.y = atan2(-heading.x, -heading.z)
	else:
		if kind == "area":
			position = target_at
			dial = GroundDial.create(self, radius, Color("ff865e"))
			var pearl := WorldGeometry.sphere(body, .12, Vector3(0, 2.5, 0), hot)
			pearl.name = "Shell"
			WorldGeometry.sphere(pearl, .16, Vector3.ZERO, dark).scale = Vector3(.8, 1.4, .8)
		else:
			body.rotation.y = atan2(-heading.x, -heading.z)
			for side: float in [-1.0, 1.0]:
				WorldGeometry.box(body, Vector3(.025, .02, beam_length), Vector3(side * beam_width, .055, -beam_length * .5), warm)
			var ray := MeshInstance3D.new()
			var plane := PlaneMesh.new()
			plane.size = Vector2(beam_width * 4.0, beam_length)
			ray.mesh = plane
			var energy := ShaderMaterial.new()
			energy.shader = preload("res://assets/shaders/hostile_beam.gdshader")
			ray.material_override = energy
			ray.position = Vector3(0, .45, -beam_length * .5)
			body.add_child(ray)
			ray.name = "Ray"
			ray.visible = false

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion() or not is_instance_valid(world) or not world.is_combat():
		return
	elapsed += delta
	if kind == "bolt":
		var previous := position
		position += heading * shot_speed * delta
		if _segment_hits(previous, position, .14):
			_hit()
			world.effects.show_hostile_impact(position, .25)
			queue_free()
		elif elapsed >= lifetime:
			queue_free()
		return
	if (kind == "beam" or not fired) and (not is_instance_valid(source) or source.dead):
		queue_free()
		return
	if kind == "area":
		GroundDial.update(dial, minf(elapsed / warning_time, 1.0), false, 8)
		body.get_node("Shell").position.y = lerpf(2.5, .2, clampf(elapsed / warning_time, 0.0, 1.0))
		if elapsed >= warning_time:
			if _segment_hits(position, position, radius):
				_hit()
			world.effects.show_hostile_impact(position, radius)
			queue_free()
		return
	if elapsed < warning_time:
		return
	fired = true
	body.get_node("Ray").visible = true
	if angular_speed != 0.0:
		heading = heading.rotated(Vector3.UP, angular_speed * delta)
		body.rotation.y = atan2(-heading.x, -heading.z)
	hit_clock -= delta
	if hit_clock <= 0.0 and _segment_hits(position, position + heading * beam_length, beam_width):
		_hit()
		hit_clock = .5
	if elapsed >= warning_time + lifetime:
		queue_free()

func _segment_hits(from: Vector3, to: Vector3, padding: float) -> bool:
	var victim: Node3D = world.core if to_core else world.player
	if not is_instance_valid(victim):
		return false
	var body_radius := world.core.radius if to_core else .23
	var closest := Geometry3D.get_closest_point_to_segment(WorldGeometry.planar(victim.position), WorldGeometry.planar(from), WorldGeometry.planar(to))
	return WorldGeometry.planar(victim.position - closest).length_squared() <= pow(padding + body_radius, 2)

func _hit() -> void:
	if to_core:
		world.damage_core(damage)
	else:
		world.combat.apply_hit(world.player, CombatHit3D.new(damage, position))
