class_name SliceProjectile
extends Node3D

## Reusable projectiles sweep their whole movement segment, including spawn overlaps.
var world: Node
var active: bool = false
var direction: Vector3 = Vector3.FORWARD
var damage: float = 0.0
var speed: float = 0.0
var remaining: float = 0.0
var sweep: ShapeCast3D
var shot: CombatShot3D
var visual: MeshInstance3D
var normal_material: StandardMaterial3D
var plasma_material: StandardMaterial3D

func _ready() -> void:
	normal_material = SliceGeometry.material(Color("8ffff4"), true)
	plasma_material = SliceGeometry.material(Color("b56cff"), true)
	visual = SliceGeometry.sphere(self, .075, Vector3.ZERO, normal_material)
	sweep = ShapeCast3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = .075
	sweep.shape = sphere
	sweep.collision_mask = SliceGeometry.ENEMY_HURTBOX_LAYER
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
	direction = SliceGeometry.planar(heading).normalized()
	shot = spec.copy()
	damage = shot.damage
	speed = shot.speed
	visual.material_override = plasma_material if shot.damage_type == GameEnums.DamageType.PLASMA else normal_material
	visual.scale = Vector3.ONE * (2.0 if shot.splash_radius > 0.0 else 1.0)
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
	var hit: SliceActor = null
	var closest: float = INF
	for index in range(sweep.get_collision_count()):
		var area := sweep.get_collider(index) as Area3D
		if not area:
			continue
		var actor := area.get_parent() as SliceActor
		if not actor or actor.dead:
			continue
		var distance := position.distance_squared_to(sweep.get_collision_point(index))
		if distance < closest:
			closest = distance
			hit = actor
	if hit:
		world.combat.impact(hit, hit.position, direction, shot, world.enemies)
		release()
		return
	position += motion
	remaining -= delta
	if remaining <= 0.0:
		release()
