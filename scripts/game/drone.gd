class_name Drone
extends RefCounted

## The state and numbers of one drone (engine piece S10). A turret builds one, hands it to `Drones.launch`, and steers it by
## setting its `mode` and the points it reads; `Drones` moves it, ages it, draws it and removes it. Nothing here knows which turret
## owns it. A drone is a point with a height: it flies over the arena, collides with nothing, and cannot be hurt (enemies attack
## only the hero and the core, and turrets are never harmed), so the only ways it leaves are the owner taking it down, its
## airframe wearing out (`life`) and the arena emptying (`Drones.clear`). The owner replaces it from its own slot.
##
## Modes (what `Drones` steers it toward):
##   DOCKED   sits on `home` and does not move.
##   SEEK     flies to `point` (a ground point) and hovers there.
##   ORBIT    circles `anchor` at `orbit_radius`, `orbit_rate` radians a second, starting from `orbit_angle`.
##   HOLD     hovers `hold_distance` from `target` on the side it is already on, drifting round it at `orbit_rate`
##            (a strafing run). With no live target it stays where it is: the owner notices and gives it a new order.
##   RETURN   flies to `home` and docks there.
enum Mode {DOCKED, SEEK, ORBIT, HOLD, RETURN}

## Hover height above the floor (metres) and how far it bobs, the height it rests at on its dock, and how fast it climbs or descends.
const HEIGHT: float = 1.1
const BOB: float = .05
const DOCK_HEIGHT: float = .22
const CLIMB_RATE: float = 2.5

var owner_id: int = 0
var mode: Mode = Mode.DOCKED
## Planar position (the height is `HEIGHT` plus a bob, applied when drawn) and velocity in metres per second.
var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
## Top speed (m/s) and acceleration (m/s^2).
var speed: float = 8.0
var accel: float = 40.0
var home: Vector3 = Vector3.ZERO
var anchor: Vector3 = Vector3.ZERO
var point: Vector3 = Vector3.ZERO
var orbit_radius: float = 1.0
var orbit_angle: float = 0.0
var orbit_rate: float = 2.0
var hold_distance: float = 1.0
var target: CombatActor
## Seconds it has been alive, and the seconds of airframe it has (0 = it never wears out).
var age: float = 0.0
var life: float = 0.0
## True for a drone that is not one of its owner's permanent slots (it is not replaced when it goes).
var temporary: bool = false
## The owner's slot this drone fills (-1 for none); the owner reads it back to replace the drone.
var slot: int = -1
## Most live drones the owner may have, this one included (0 = no limit beyond the arena's).
var owner_cap: int = 0
var tint: Color = Color(.55, .95, 1.0)
## Seconds until the owner may let this drone shoot or do its next job again (the owner counts it down).
var cooldown: float = 0.0
## A second, independent countdown for a drone with two jobs (the Guardian Wing's shoot-down).
var aux_cooldown: float = 0.0
## Seconds it has held its current job (the owner's sortie clock).
var job_clock: float = 0.0
## True once it has been taken out; a spent drone is never steered again.
var spent: bool = false
## The yaw (radians) it is drawn at.
var yaw: float = 0.0
var bob_phase: float = 0.0
## Height above the floor now (it climbs from the dock and settles back onto it).
var altitude: float = DOCK_HEIGHT
## The height it rests at while docked: `DOCK_HEIGHT` on the floor, or the owner's own perch (the Drone Bay's dishes).
var dock_height: float = DOCK_HEIGHT

func is_docked() -> bool:
	return mode == Mode.DOCKED

## True while it holds a live enemy it is working on.
func has_target() -> bool:
	return is_instance_valid(target) and not target.dead

## The height it is drawn at.
func height() -> float:
	return altitude + (BOB * sin(age * 3.0 + bob_phase) if altitude > dock_height + .01 else 0.0)

## Orders it to circle `centre` from `angle`.
func orbit(centre: Vector3, angle: float = NAN) -> void:
	mode = Mode.ORBIT
	anchor = centre
	target = null
	if not is_nan(angle):
		orbit_angle = angle

## Orders it to work on `enemy`, hovering `distance` metres from it.
func engage(enemy: CombatActor, distance: float) -> void:
	mode = Mode.HOLD
	target = enemy
	hold_distance = distance

## Orders it to fly to `ground_point`.
func go_to(ground_point: Vector3) -> void:
	mode = Mode.SEEK
	point = ground_point
	target = null

## Orders it back to its dock.
func recall() -> void:
	mode = Mode.RETURN
	target = null
	job_clock = 0.0
