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
var custom_visual: Node3D
var custom_key: String = ""
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
	if shot.visual_key == "bowling_ball":
		position.y = maxf(position.y, shot.radius)
	pierced.clear()
	damage = shot.damage
	speed = shot.speed
	var plasma := shot.damage_type == GameEnums.DamageType.PLASMA
	var size := maxf(shot.radius / .075, 2.0 if shot.splash_radius > 0.0 else 1.0)
	(sweep.shape as SphereShape3D).radius = maxf(.01, shot.radius)
	visual.material_override = plasma_material if plasma else normal_material
	visual.scale = Vector3.ONE * size
	var kind := "plasma" if plasma else "ion"
	orb.material_override = EnergyFx.orb_material(kind)
	orb.scale = Vector3.ONE * size * (1.3 if plasma else 1.0)
	trail.material_override = EnergyFx.trail_material(kind)
	trail.scale = Vector3(size * (1.7 if plasma else 1.0), 1.0, size * (.8 if plasma else 1.0))
	trail_pivot.rotation.y = atan2(-direction.x, -direction.z)
	if custom_visual:
		custom_visual.visible = false
	if not shot.visual_key.is_empty() and ClockworkModels.available(shot.visual_key):
		if custom_key != shot.visual_key:
			if custom_visual:
				remove_child(custom_visual)
				custom_visual.queue_free()
			custom_visual = ClockworkModels.instantiate(shot.visual_key)
			add_child(custom_visual)
			custom_key = shot.visual_key
		custom_visual.scale = Vector3.ONE * shot.visual_scale
		custom_visual.rotation = Vector3(0, atan2(-direction.x, -direction.z), 0)
		custom_visual.visible = true
	visual.visible = not (custom_visual and custom_visual.visible)
	orb.visible = shot.visual_key.is_empty()
	trail.visible = shot.visual_key.is_empty()
	remaining = shot.lifetime
	active = true
	visible = true
	reset_physics_interpolation() # Pooled shots must start at the new muzzle, not their previous hit.
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
	# Combat is planar. An elevated carried muzzle must still hit short enemies.
	# Only the visual flight height descends from the muzzle toward the normal firing plane.
	sweep.global_position = Vector3(position.x, .35, position.z)
	sweep.target_position = motion
	# ShapeCast reports the earliest collision group, not the entire segment.
	# Recast with those areas excluded so piercing cannot tunnel through later enemies.
	sweep.clear_exceptions()
	var contacts: Array[CombatActor] = []
	while true:
		sweep.force_shapecast_update()
		var excluded_any := false
		for index in range(sweep.get_collision_count()):
			var area := sweep.get_collider(index) as Area3D
			if not area:
				continue
			sweep.add_exception(area)
			excluded_any = true
			var actor := area.get_parent() as CombatActor
			if actor and not actor.dead and actor not in pierced and not contacts.has(actor):
				contacts.append(actor)
		if not excluded_any:
			break
	sweep.clear_exceptions()
	contacts.sort_custom(func(a: CombatActor, b: CombatActor) -> bool:
		return _contact_distance(a) < _contact_distance(b))
	for hit in contacts:
		if not is_instance_valid(hit) or hit.dead:
			continue
		var contact_distance := clampf(_contact_distance(hit), 0.0, motion.length())
		world.combat.impact(hit, hit.position, direction, shot, world.enemies)
		# The impact can end the run (an exploder's blast killing the hero or core), which releases every projectile.
		if not active:
			return
		if shot.ricochets > 0 and shot.splash_radius <= 0.0:
			pierced.append(hit)
			var recipient := _ricochet_target(position + direction * contact_distance)
			if recipient:
				_move_along_heading(contact_distance)
				shot.ricochets -= 1
				var elapsed := contact_distance / maxf(speed, .001)
				remaining -= elapsed
				direction = WorldGeometry.planar(recipient.position - position).normalized()
				trail_pivot.rotation.y = atan2(-direction.x, -direction.z)
				# Re-sweep the remainder along the new heading, discarding old-path contacts.
				advance(maxf(0.0, delta - elapsed))
				return
		if shot.pierce > 0 and shot.splash_radius <= 0.0:
			shot.pierce -= 1
			pierced.append(hit)
		else:
			release()
			return
	_move_along_heading(motion.length())
	remaining -= delta
	if remaining <= 0.0:
		release()

func _move_along_heading(distance: float) -> void:
	position += direction * distance
	position.y = move_toward(position.y, shot.radius if shot.visual_key == "bowling_ball" else .45, distance * .8)
	if custom_visual and custom_visual.visible and shot.visual_key == "bowling_ball":
		custom_visual.rotate(direction.cross(Vector3.UP).normalized(), distance / maxf(.01, shot.radius))

func _contact_distance(actor: CombatActor) -> float:
	var offset := WorldGeometry.planar(actor.position - position)
	var along := offset.dot(direction)
	var lateral_sq := maxf(0.0, offset.length_squared() - along * along)
	var radius := actor.hurtbox_radius() + shot.radius
	return maxf(0.0, along - sqrt(maxf(0.0, radius * radius - lateral_sq)))

func _ricochet_target(origin: Vector3) -> CombatActor:
	var result: CombatActor
	var best := shot.ricochet_range * shot.ricochet_range
	for enemy in world.enemies:
		if not is_instance_valid(enemy) or enemy.dead or enemy in pierced:
			continue
		var distance := WorldGeometry.planar(enemy.position - origin).length_squared()
		if distance < best:
			best = distance
			result = enemy
	return result
