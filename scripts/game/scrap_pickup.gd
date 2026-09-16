class_name ScrapPickup
extends Area3D

var world: Node
var amount: int = 1
var collected: bool = false
var age: float = 0.0
var visual: MeshInstance3D

func _ready() -> void:
	collision_layer = 0
	collision_mask = WorldGeometry.PLAYER_LAYER
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = .4
	shape.shape = sphere
	shape.position.y = .3
	add_child(shape)
	visual = WorldGeometry.box(self, Vector3(.14, .18, .14), Vector3(0, .25, 0), WorldGeometry.material(Color("ffca66"), true))
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if collected or not world.is_combat():
		return
	age += delta
	if not FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION):
		visual.rotation.y += delta * 2.0
		visual.position.y = .25 + sin(age * 4.0) * .05
	else:
		visual.position.y = .25
	var distance := WorldGeometry.planar(world.player.position - position).length()
	if distance < PlayerStatsService.get_pickup_radius() * WorldGeometry.METRES_PER_PIXEL + .45:
		position = position.move_toward(world.player.position, delta * 5.0)
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
	queue_free()
