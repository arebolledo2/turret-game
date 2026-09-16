class_name ChargeController3D
extends RefCounted

## Fixed heading is locked at the START of the warning. No last-moment retarget.
enum Phase { APPROACH, WINDUP, DASH, RECOVER }
var phase: Phase = Phase.APPROACH
var remaining: float = 0.0
var heading: Vector3 = Vector3.FORWARD
var origin: Vector3 = Vector3.ZERO
var detect_radius: float = 2.0
var windup_duration: float = .9
var dash_duration: float = 1.5
var cooldown: float = 2.5
var speed_multiplier: float = 3.0

func configure(params: Dictionary) -> void:
	detect_radius = float(params.get("charge_detect_radius", 200.0)) * WorldGeometry.METRES_PER_PIXEL
	windup_duration = float(params.get("charge_alert_duration", .9))
	dash_duration = float(params.get("charge_duration", 1.5))
	cooldown = float(params.get("charge_cooldown", 2.5))
	speed_multiplier = float(params.get("charge_speed_multiplier", 3.0))

func advance(delta: float, at: Vector3, target: Vector3, speed: float) -> Vector3:
	var toward := WorldGeometry.planar(target - at)
	match phase:
		Phase.APPROACH:
			if toward.length() <= detect_radius:
				origin = WorldGeometry.planar(at)
				heading = toward.normalized() if not toward.is_zero_approx() else Vector3.FORWARD
				phase = Phase.WINDUP
				remaining = windup_duration
				return Vector3.ZERO
			return toward.normalized() * speed
		Phase.WINDUP:
			remaining = maxf(0.0, remaining - delta)
			if remaining <= 0.0:
				phase = Phase.DASH
				remaining = dash_duration
			# Moving starts next tick so warning always lasts its full duration.
			return Vector3.ZERO
		Phase.DASH:
			var step := minf(delta, remaining)
			remaining = maxf(0.0, remaining - delta)
			if remaining <= 0.0:
				phase = Phase.RECOVER
				remaining = cooldown
			return heading * speed * speed_multiplier * (step / maxf(delta, .00001))
		Phase.RECOVER:
			remaining = maxf(0.0, remaining - delta)
			if remaining <= 0.0:
				phase = Phase.APPROACH
			return toward.normalized() * speed * .25
	return Vector3.ZERO

func interrupt() -> void:
	phase = Phase.RECOVER
	remaining = cooldown
