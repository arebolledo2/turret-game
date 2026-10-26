class_name RepeaterBowForm
extends TurretForm

## Bow / Repeater Bow and Arrowstorm: each draw queues a volley that leaves the rails one arrow at a time.
func fire_projectile(stats: TurretStats, _heading: Vector3) -> bool:
	var target := actor.target
	var burst := actor.bow_burst
	burst.start(TurretEvolution.volley_size(form_id), actor._new_shot(stats))
	burst.heading = WorldGeometry.planar(target.position - actor.position).normalized()
	burst.aim_point = target.position
	actor._tick_bow_burst(0.0, stats)
	return true
