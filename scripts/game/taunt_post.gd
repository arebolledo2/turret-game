class_name TauntPost
extends RefCounted

## One taunting turret as enemies see it (S1). The Decoy publishes a post to `ArenaWorld.taunts`; enemies inside `radius`
## walk at it instead of at the hero. The post reads the turret's position live, so a carried-and-redeployed Decoy needs no
## re-publishing. Radii are metres.
## `ranged` is whether Kites, Lobbers and Tenders also aim at it (Maelstrom); melee enemies always do.
## `hook_ring` is the inner orbit radius of the enemies it has hooked (`TauntField.hook_anchor`).
var owner_id: int = 0
var turret: TurretActor
var radius: float = 0.0
var ranged: bool = false
var hook_ring: float = 0.0

func _init(owner_turret: TurretActor = null) -> void:
	turret = owner_turret
	owner_id = owner_turret.turret_id if owner_turret else 0

## A carried Decoy rides on the hero, so it draws nothing away from the hero.
func is_live() -> bool:
	return is_instance_valid(turret) and not turret.carried

func origin() -> Vector3:
	return turret.position

## True when a body at `position` is inside the taunt.
func covers(position: Vector3) -> bool:
	return WorldGeometry.planar(position - turret.position).length_squared() <= radius * radius
