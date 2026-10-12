class_name ShotBurst
extends RefCounted

## A queue of follow-up shots released a fixed interval apart. The owner decides what each shot is and where it goes.
var interval: float
var left: int = 0
var clock: float = 0.0
var shot: CombatShot3D
var heading := Vector3.FORWARD
var aim_point := Vector3.ZERO

func _init(shot_interval: float) -> void:
	interval = shot_interval

func start(count: int, burst_shot: CombatShot3D, first_delay: float = 0.0) -> void:
	left = count
	shot = burst_shot
	clock = first_delay

func cancel() -> void:
	left = 0

func advance(delta: float) -> void:
	clock -= delta

## True while another shot is due this tick.
func is_due() -> bool:
	return left > 0 and clock <= 0.0

## Marks the due shot as released and schedules the next one.
func consume() -> void:
	left -= 1
	clock += interval
