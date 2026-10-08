class_name TechDropActor
extends CombatActor

## A tech drop: a stationary, destructible crate that never moves or attacks.
## It is a CombatActor in `world.enemies`, so turrets and the hero target it like any enemy.
var drop_bar_fill: MeshInstance3D

func _init() -> void:
	is_enemy = true
	stationary = true
	enemy_type = "tech_drop"

func _build_enemy_model() -> Node3D:
	return _build_drop_model()

func _leg_sides() -> Array[String]:
	return []

func _on_health_changed() -> void:
	var fraction := clampf(health / maxf(max_health, .001), 0.0, 1.0)
	drop_bar_fill.scale.x = maxf(fraction, .001)
	drop_bar_fill.position.x = -.6 * (1.0 - fraction)

## A tech drop: dark plinth, amber crystal and a health bar that shrinks as it takes damage.
func _build_drop_model() -> Node3D:
	var model := Node3D.new()
	var plinth_material := WorldGeometry.material(Color("2a3a44"))
	plinth_material.metallic = .5
	var amber := WorldGeometry.material(Color("f4b942"), true)
	WorldGeometry.box(model, Vector3(.9, .3, .9), Vector3(0, .15, 0), plinth_material)
	var crystal := WorldGeometry.box(model, Vector3(.5, .5, .5), Vector3(0, .75, 0), amber)
	crystal.rotation = Vector3(.6, .785, 0)
	for side: float in [-1.0, 1.0]:
		WorldGeometry.box(model, Vector3(.1, .7, .1), Vector3(side * .38, .55, 0), plinth_material)
	var bar_back := WorldGeometry.material(Color("14232b"))
	var bar_front := WorldGeometry.material(Color("f4b942"), true)
	WorldGeometry.box(model, Vector3(1.24, .12, .1), Vector3(0, 1.55, 0), bar_back)
	drop_bar_fill = WorldGeometry.box(model, Vector3(1.2, .13, .12), Vector3(0, 1.55, 0), bar_front)
	return model
