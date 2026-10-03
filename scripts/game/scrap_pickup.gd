class_name ScrapPickup
extends Area3D

## Scrap drop: a spinning energy crystal with salvaged plates, a pulsing light pool underneath, a small pop when it
## spawns and a pull that accelerates once the magnet has it. Collecting it bursts into sparks.
const MODEL: PackedScene = preload("res://assets/models/game/scrap_shard.glb")
const POP_TIME: float = .3
const REST_HEIGHT: float = .25
const PULL_SPEED: float = 5.0
const PULL_RAMP: float = 18.0 # extra m/s per second of being pulled, capped below
const PULL_MAX_EXTRA: float = 12.0

var world: Node
var amount: int = 1
var collected: bool = false
var age: float = 0.0
var pulled_for: float = 0.0
var visual: Node3D
var glow: MeshInstance3D

static var glow_mesh: PlaneMesh

func _ready() -> void:
	collision_layer = 0
	collision_mask = WorldGeometry.PLAYER_LAYER
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = .4
	shape.shape = sphere
	shape.position.y = .3
	add_child(shape)
	visual = Node3D.new()
	visual.position.y = REST_HEIGHT
	add_child(visual)
	visual.add_child(MODEL.instantiate())
	# Bigger drops (tanks, heavies) read bigger.
	visual.scale = Vector3.ONE * _base_scale()
	if not glow_mesh:
		glow_mesh = PlaneMesh.new()
		glow_mesh.size = Vector2(1.0, 1.0)
	glow = MeshInstance3D.new()
	glow.mesh = glow_mesh
	glow.material_override = EnergyFx.ground_glow_material()
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.position.y = .03
	add_child(glow)
	body_entered.connect(_on_body_entered)

func _base_scale() -> float:
	return 1.0 + .12 * minf(float(amount - 1), 5.0)

func _physics_process(delta: float) -> void:
	if collected or not world.is_combat():
		return
	age += delta
	var pop := clampf(age / POP_TIME, 0.0, 1.0)
	if not FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION):
		var grow := 1.0
		if pop < 1.0: # ease-out-back: overshoots slightly, then settles
			grow = 1.0 + 2.70158 * pow(pop - 1.0, 3.0) + 1.70158 * pow(pop - 1.0, 2.0)
		visual.scale = Vector3.ONE * _base_scale() * maxf(grow, 0.0) * (.85 if pulled_for > 0.0 else 1.0)
		visual.rotation.y += delta * (2.0 + minf(pulled_for * 10.0, 8.0))
		visual.position.y = REST_HEIGHT + sin(age * 4.0) * .05 + sin(pop * PI) * .28 * (1.0 - pop)
	else:
		visual.position.y = REST_HEIGHT
	var distance := WorldGeometry.planar(world.player.position - position).length()
	if distance < PlayerStatsService.get_pickup_radius() * WorldGeometry.METRES_PER_PIXEL + .45:
		pulled_for += delta
		position = position.move_toward(world.player.position, delta * (PULL_SPEED + minf(pulled_for * PULL_RAMP, PULL_MAX_EXTRA)))
	else:
		pulled_for = 0.0
	if distance < .3:
		collect()

func _on_body_entered(body: Node3D) -> void:
	if body == world.player and world.is_combat():
		collect()

func collect() -> void:
	if collected:
		return
	collected = true
	world.collect_scrap(amount)
	world.effects.show_burst(position + Vector3(0, .3, 0), "scrap")
	queue_free()
