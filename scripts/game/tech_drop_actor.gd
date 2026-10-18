class_name TechDropActor
extends EnemyActor

## A tech drop: a stationary, destructible crate that never moves or attacks.
## It is a CombatActor in `world.enemies`, so turrets and the hero target it like any enemy.
func _init() -> void:
	is_enemy = true
	stationary = true
	enemy_type = "tech_drop"

func _build_enemy_model() -> Node3D:
	return _build_drop_model()

func _leg_sides() -> Array[String]:
	return []

## A destructible cache with a health bar; retain the original plinth for comparison.
func _build_drop_model() -> Node3D:
	var model := Node3D.new()
	if ClockworkModels.available("dropbox"):
		var chest := ClockworkModels.instantiate("dropbox")
		# Exported latch faces -Z; the fixed gameplay camera views from +Z.
		chest.rotation.y = PI
		model.add_child(chest)
		return model
	var plinth_material := WorldGeometry.material(Color("2a3a44"))
	plinth_material.metallic = .5
	var amber := WorldGeometry.material(Color("f4b942"), true)
	WorldGeometry.box(model, Vector3(.9, .3, .9), Vector3(0, .15, 0), plinth_material)
	var crystal := WorldGeometry.box(model, Vector3(.5, .5, .5), Vector3(0, .75, 0), amber)
	crystal.rotation = Vector3(.6, .785, 0)
	for side: float in [-1.0, 1.0]:
		WorldGeometry.box(model, Vector3(.1, .7, .1), Vector3(side * .38, .55, 0), plinth_material)
	return model
