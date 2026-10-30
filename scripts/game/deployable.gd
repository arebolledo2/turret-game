class_name Deployable
extends RefCounted

## One thing a turret leaves on the floor (engine piece S8): a proximity mine, or a limpet that rides an enemy. `Deployables`
## owns the list, the clock and the visual; this is the state and the numbers. A deployable is struck from a shot template
## made when it was laid (damage, blast radius, knockback, source id), so its blast does not depend on the turret again, but it
## is always tied to its owner turret's id and is removed with it.
##
## Life of a mine:  ARMING (harmless, `arm_seconds`) -> ARMED (an enemy in `trigger_radius` sets it off) -> blast ->
##   gone, or ARMING again after `rearm_seconds` when the mine re-arms. It also ends when `lifetime` runs out (0 = no limit).
## Life of a limpet: FLYING toward its `host` enemy -> FUSED on it for `fuse_seconds` -> blast (at once when the host dies).
## A chained mine goes ARMED -> FUSED for the chain delay -> blast.
enum State {ARMING, ARMED, FUSED, FLYING}

const KIND_MINE: String = "mine"
const KIND_LIMPET: String = "limpet"

var kind: String = KIND_MINE
var state: State = State.ARMING
## `TurretActor.turret_id` of the layer; 0 for none.
var owner_id: int = 0
var position := Vector3.ZERO
## Seconds left in the current state (arming, fuse).
var timer: float = 0.0
var age: float = 0.0
## Seconds before it fizzles away unarmed-for-good; 0 for never.
var lifetime: float = 0.0
## Metres from the mine's centre within which an enemy's body sets it off.
var trigger_radius: float = .4
var arm_seconds: float = .8
## Seconds a mine stays dark after a blast before it arms again; 0 means one blast and it is gone.
var rearm_seconds: float = 0.0
## The blast: damage, splash radius, knockback, stamps. The caller builds it (`TurretActor._new_shot`).
var shot: CombatShot3D
## Chain: how many links a blast started by an enemy passes on (0 for none), how many are left for the blast now going off,
## and how far a neighbouring mine may be.
var chain_depth: int = 0
var links_left: int = 0
var chain_reach: float = 0.0
## Limpet: the enemy it rides, seconds it burns once stuck, how fast it flies, and how many new limpets its blast sticks on.
var host: CombatActor
var fuse_seconds: float = 1.5
var speed: float = 14.0
var stick_count: int = 0
## 0 for what a turret laid itself, +1 for a limpet a blast stuck on. Only generation 0 counts toward the layer's cap.
var generation: int = 0
## Looks (see `Deployables`): the pooled mesh showing it, and the state it last drew.
var tint := Color("e83a1c")
var node: MeshInstance3D
var drawn_state: int = -1
## Set when it has been taken out of the field, so a loop over a snapshot of the list skips it.
var spent: bool = false
## Instance id of the enemy it is counted as riding (0 for none); kept so removing it never touches a freed host.
var rider_id: int = 0

func is_limpet() -> bool:
	return kind == KIND_LIMPET

func counts_toward_cap() -> bool:
	return generation == 0

## Armed and waiting: nothing but an enemy or a chain can make it blast.
func is_armed() -> bool:
	return state == State.ARMED

func is_live_host() -> bool:
	return is_instance_valid(host) and not host.dead
