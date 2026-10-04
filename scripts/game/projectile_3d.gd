class_name Projectile3D
extends Node3D

## Reusable projectiles sweep their whole movement segment, including spawn overlaps.
const TRAIL_LENGTH: float = 1.0
var world: ArenaWorld
var active: bool = false
var direction: Vector3 = Vector3.FORWARD
var damage: float = 0.0
var speed: float = 0.0
var remaining: float = 0.0
var sweep: ShapeCast3D
var shot: CombatShot3D
var pierced: Array[CombatActor] = []
var visual: MeshInstance3D
var orb: MeshInstance3D
var trail: MeshInstance3D
var trail_pivot: Node3D # only the streak turns to face the heading; the sweep cast below must stay unrotated
var normal_material: StandardMaterial3D
var plasma_material: StandardMaterial3D

func _ready() -> void:
	normal_material = WorldGeometry.material(Color("8ffff4"), true)
	plasma_material = WorldGeometry.material(Color("b56cff"), true)
	visual = WorldGeometry.sphere(self, .075, Vector3.ZERO, normal_material)
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Camera-facing halo around the core, plus a streak lying along the flight path behind it.
	var orb_quad := QuadMesh.new()
	orb_quad.size = Vector2(.6, .6)
	orb = MeshInstance3D.new()
	orb.mesh = orb_quad
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(orb)
	var trail_plane := PlaneMesh.new()
	trail_plane.size = Vector2(.2, TRAIL_LENGTH)
	trail_plane.center_offset = Vector3(0, 0, TRAIL_LENGTH * .5) # the node faces -Z, so +Z is behind it
	trail = MeshInstance3D.new()
	trail.mesh = trail_plane
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail_pivot = Node3D.new()
	trail_pivot.add_child(trail)
	add_child(trail_pivot)
	sweep = ShapeCast3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = .075
	sweep.shape = sphere
	sweep.collision_mask = WorldGeometry.ENEMY_HURTBOX_LAYER
	sweep.collide_with_areas = true
	sweep.collide_with_bodies = false
	sweep.enabled = false
	add_child(sweep)
	release()

func acquire(origin: Vector3, heading: Vector3, hit_damage: float, shot_speed: float) -> void:
	var spec := CombatShot3D.new()
	spec.damage = hit_damage
	spec.speed = shot_speed
	acquire_shot(origin, heading, spec)

func acquire_shot(origin: Vector3, heading: Vector3, spec: CombatShot3D) -> void:
	position = origin
	direction = WorldGeometry.planar(heading).normalized()
	shot = spec.copy()
	pierced.clear()
	damage = shot.damage
	speed = shot.speed
	var plasma := shot.damage_type == GameEnums.DamageType.PLASMA
	var size := 2.0 if shot.splash_radius > 0.0 else 1.0
	visual.material_override = plasma_material if plasma else normal_material
	visual.scale = Vector3.ONE * size
	var kind := "plasma" if plasma else "ion"
	orb.material_override = EnergyFx.orb_material(kind)
	orb.scale = Vector3.ONE * size * (1.3 if plasma else 1.0)
	trail.material_override = EnergyFx.trail_material(kind)
	trail.scale = Vector3(size * (1.7 if plasma else 1.0), 1.0, size * (.8 if plasma else 1.0))
	trail_pivot.rotation.y = atan2(-direction.x, -direction.z)
	remaining = 3.0
	active = true
	visible = true
	set_physics_process(true)

func release() -> void:
	active = false
	visible = false
	damage = 0.0
	speed = 0.0
	remaining = 0.0
	shot = null
	if visual:
		visual.scale = Vector3.ONE
		visual.material_override = normal_material
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if not active or not world.is_combat():
		return
	advance(delta)

func advance(delta: float) -> void:
	if not active:
		return
	var motion := direction * speed * minf(delta, remaining)
	sweep.target_position = motion
	sweep.force_shapecast_update()
	var hit: CombatActor = null
	var closest: float = INF
	for index in range(sweep.get_collision_count()):
		var area := sweep.get_collider(index) as Area3D
		if not area:
			continue
		var actor := area.get_parent() as CombatActor
		if not actor or actor.dead or actor in pierced:
			continue
		var distance := position.distance_squared_to(sweep.get_collision_point(index))
		if distance < closest:
			closest = distance
			hit = actor
	if hit:
		world.combat.impact(hit, hit.position, direction, shot, world.enemies)
		# The impact can end the run (an exploder's blast killing the hero or core), which releases every projectile.
		if not active:
			return
		if shot.pierce > 0 and shot.splash_radius <= 0.0:
			shot.pierce -= 1
			pierced.append(hit)
		else:
			release()
			return
	position += motion
	remaining -= delta
	if remaining <= 0.0:
		release()
