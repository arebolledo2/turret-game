class_name TurretShowcaseFire
extends Node3D

## Looping fire animation for a turret on the showcase turntable. It borrows the actor's own firing visuals (barrel recoil,
## aim kick, rotor spool, bowling hardware) and adds stand-in effects per fire mode, since the real attacks need an arena.
## Effects live under this node (outside the spinning pivot), so they stay in world space while the turret turns.

const PERIOD := 1.1
const BOLT_SPEED := 16.0
const RECOIL := .16
const AIM_KICK := .045
const BARREL_SETTLE_RATE := 10.0
const AIM_SETTLE_RATE := 16.0
const SWEEP_SPEED := 3.5
const BEAM_ON_FRACTION := .75

var actor: TurretActor
var fire_mode := TurretRegistry.FIRE_PROJECTILE
var floor_y := 0.0
var reach := 3.0
var clock := 0.0
var shots_fired := 0
var beam: MeshInstance3D
## Short-lived effect nodes: {"node", "velocity", "life", "age", "grow"}.
var effects: Array[Dictionary] = []

func setup(turret: TurretActor, bounds: AABB) -> void:
	clear()
	actor = turret
	fire_mode = TurretRegistry.get_fire_mode(turret.turret_type)
	floor_y = bounds.position.y
	reach = maxf(bounds.size.length() * 1.2, 1.5)
	clock = PERIOD * .6 # the first shot comes quickly
	shots_fired = 0
	if fire_mode == TurretRegistry.FIRE_BEAM:
		beam = _emissive_mesh(_box(Vector3(.07, .07, 1.0)), _color())
		add_child(beam)

func clear() -> void:
	for effect in effects:
		if is_instance_valid(effect["node"]):
			effect["node"].free()
	effects.clear()
	if is_instance_valid(beam):
		beam.free()
	beam = null
	actor = null

func advance(delta: float) -> void:
	if not is_instance_valid(actor) or actor.muzzle == null:
		return
	_settle(delta)
	if actor.form:
		actor.form.tick_mechanisms(delta, true)
	if actor.bowling_hardware:
		actor.bowling_hardware.advance(delta, false)
	if fire_mode == TurretRegistry.FIRE_SWEEP:
		actor.aim.rotation.y = wrapf(actor.aim.rotation.y + SWEEP_SPEED * delta, -PI, PI)
	clock += delta
	if clock >= PERIOD:
		clock -= PERIOD
		_fire()
	if is_instance_valid(beam):
		_update_beam()
	_update_effects(delta)

## Barrel and aim arm ease back to rest after each kick, like `TurretActor._tick_mechanisms` and `_physics_process`.
func _settle(delta: float) -> void:
	if actor.recoil_barrel:
		actor.recoil_barrel.position = actor.recoil_barrel.position.lerp(actor.barrel_rest, minf(1.0, delta * BARREL_SETTLE_RATE))
	actor.aim.position = actor.aim.position.lerp(actor.aim_rest, minf(1.0, delta * AIM_SETTLE_RATE))
	if actor.loaded_ball:
		actor.loaded_ball.visible = clock > PERIOD * .7
	for arrow in actor.bow_loaded_arrows:
		if arrow:
			arrow.visible = clock > PERIOD * .65

func _fire() -> void:
	shots_fired += 1
	var origin := actor.muzzle.global_position
	var forward := -actor.muzzle.global_basis.z.normalized()
	match fire_mode:
		TurretRegistry.FIRE_PULSE, TurretRegistry.FIRE_NONE, TurretRegistry.FIRE_DEPLOY, TurretRegistry.FIRE_DRONES:
			_spawn_ring()
			return
		TurretRegistry.FIRE_SWEEP, TurretRegistry.FIRE_BEAM:
			return
		TurretRegistry.FIRE_FLAME:
			_spawn_flames(origin, forward)
		TurretRegistry.FIRE_INSTANT:
			_spawn_streak(origin, forward)
		TurretRegistry.FIRE_CHAIN:
			_spawn_streak(origin, forward, .35)
		_:
			_spawn_bolt(origin, forward)
	_spawn_flash(origin)
	_kick(forward)

func _kick(forward: Vector3) -> void:
	if actor.recoil_barrel:
		actor.recoil_barrel.position.z += RECOIL
	elif fire_mode != TurretRegistry.FIRE_FLAME:
		var parent_basis := (actor.aim.get_parent() as Node3D).global_basis
		actor.aim.position += parent_basis.inverse() * -forward * AIM_KICK
	if actor.bowling_hardware:
		actor.bowling_hardware.kick()

func _spawn_flash(at: Vector3) -> void:
	var flash := _emissive_mesh(_sphere(.16), _color().lightened(.5))
	add_child(flash)
	flash.global_position = at
	effects.append({"node": flash, "velocity": Vector3.ZERO, "life": .09, "age": 0.0, "grow": 1.8})

func _spawn_bolt(at: Vector3, forward: Vector3) -> void:
	var bolt := _emissive_mesh(_box(Vector3(.06, .06, .5)), _color())
	add_child(bolt)
	bolt.global_position = at
	bolt.look_at(at + forward)
	effects.append({"node": bolt, "velocity": forward * BOLT_SPEED, "life": .5, "age": 0.0, "grow": 0.0})

## A hit-scan line: appears whole and fades.
func _spawn_streak(at: Vector3, forward: Vector3, life: float = .16) -> void:
	var length := reach * 1.6
	var streak := _emissive_mesh(_box(Vector3(.045, .045, length)), _color())
	add_child(streak)
	streak.global_position = at + forward * length * .5
	streak.look_at(at + forward * length)
	effects.append({"node": streak, "velocity": Vector3.ZERO, "life": life, "age": 0.0, "grow": 0.0})

func _spawn_flames(at: Vector3, forward: Vector3) -> void:
	for index in 9:
		var puff := _emissive_mesh(_sphere(.11), Color("ff9a3c") if index % 2 == 0 else Color("ffd27a"))
		add_child(puff)
		puff.global_position = at
		var spread := Vector3(randf_range(-.18, .18), randf_range(-.08, .2), randf_range(-.18, .18))
		effects.append({"node": puff, "velocity": (forward + spread).normalized() * randf_range(3.0, 6.0), "life": .45, "age": 0.0, "grow": 2.5})

func _spawn_ring() -> void:
	var ring := _emissive_mesh(_torus(.9, 1.0), _color())
	add_child(ring)
	ring.global_position = Vector3(actor.global_position.x, floor_y + .05, actor.global_position.z)
	ring.scale = Vector3.ONE * .2
	effects.append({"node": ring, "velocity": Vector3.ZERO, "life": .7, "age": 0.0, "grow": reach * 2.0, "base_scale": .2})

func _update_beam() -> void:
	var on := clock < PERIOD * BEAM_ON_FRACTION
	beam.visible = on
	if not on:
		return
	var origin := actor.muzzle.global_position
	var forward := -actor.muzzle.global_basis.z.normalized()
	var length := reach * 1.4
	beam.global_position = origin + forward * length * .5
	beam.look_at(origin + forward * length)
	beam.scale = Vector3(1, 1, length)

func _update_effects(delta: float) -> void:
	for index in range(effects.size() - 1, -1, -1):
		var effect := effects[index]
		var node: MeshInstance3D = effect["node"]
		effect["age"] += delta
		var t: float = clampf(effect["age"] / effect["life"], 0.0, 1.0)
		node.global_position += effect["velocity"] * delta
		if effect["grow"] != 0.0:
			var base := float(effect.get("base_scale", 1.0))
			node.scale = Vector3.ONE * (base + effect["grow"] * t)
		var material := node.material_override as StandardMaterial3D
		material.albedo_color.a = 1.0 - t
		if t >= 1.0:
			node.queue_free()
			effects.remove_at(index)

func _color() -> Color:
	match fire_mode:
		TurretRegistry.FIRE_FLAME: return Color("ff9a3c")
		TurretRegistry.FIRE_CHAIN: return Color("7fe8ff")
		TurretRegistry.FIRE_BEAM: return Color("ff6a8a")
		TurretRegistry.FIRE_INSTANT: return Color("ffe9a8")
	return UiPalette.TEAL_HI

func _emissive_mesh(mesh: Mesh, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance

func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh

func _torus(inner: float, outer: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	return mesh
